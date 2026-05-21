# Tuist `buildableFolders` + `.staticFramework` + `.xcassets` drops auto-generated `ImageResource` symbols

Minimal reproducible bug for **Tuist `4.192.0`** + **Xcode `26.4.1`**.

## The bug

When a Tuist target declares:
- `product: .staticFramework`
- `buildableFolders: ["…"]` (Xcode 16's filesystem-synchronized groups)
- a `.xcassets` somewhere inside the buildable folder

Tuist generates an Xcode project where the framework target's
`PBXFileSystemSynchronizedRootGroup` carries a
`PBXFileSystemSynchronizedBuildFileExceptionSet` that lists
`Resources/Media.xcassets` under `membershipExceptions`. That removes the
`.xcassets` from the framework target's membership and routes it to a separate
`<Project>_<Target>` bundle target instead.

Because the `.xcassets` is no longer in the framework target's source/resource
membership, Xcode never runs the `GenerateAssetSymbols` build step for that
target. The framework's `DerivedSources/GeneratedAssetSymbols.swift` is never
written, so any Swift code in the framework that references
`Image(.assetName)`, `ImageResource.assetName`, or `Color(.assetName)` fails
to compile with:

```
error: type 'ImageResource' has no member 'assetName'
```

Switching the same target to `product: .framework` (dynamic) makes the build
succeed — the `.xcassets` stays in the framework target's membership,
`GenerateAssetSymbols` runs, the symbol extension file is populated, and the
references resolve.

## Reproduce

```bash
tuist install
tuist generate --no-open

xcodebuild -workspace BugReproApp.xcworkspace \
           -scheme BugReproApp \
           -destination "generic/platform=iOS Simulator" \
           build
```

Expected error:

```
Packages/MyLib/Sources/MyLib/MyLib.swift:9:12: error: type 'ImageResource' has no member 'actionDeleted'
    Image(.actionDeleted)
           ^~~~~~~~~~~~~
```

## The smoking gun in the generated pbxproj

In `Packages/MyLib/MyLib.xcodeproj/project.pbxproj`:

```
/* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {
    isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
    membershipExceptions = (
        Resources/Media.xcassets,
    );
    target = … /* MyLib */;
};
```

The framework target (`MyLib`) explicitly excludes the `.xcassets` from its
own membership. A second exception set excludes the framework target's Swift
files from the bundle target's membership. Net effect: `.xcassets` lives in
the bundle target, Swift files live in the framework target — but the symbol
generation step is bound to the framework target's `.xcassets` membership,
which no longer exists.

## Workaround

Switch the affected target from `.staticFramework` to `.framework` in its
`Project.swift`:

```swift
.target(
    name: "MyLib",
    product: .framework,         // was: .staticFramework
    …
    buildableFolders: ["Sources/MyLib"]
)
```

That keeps the `.xcassets` in the framework target's membership and restores
the `GenerateAssetSymbols` step. The trade-off is a dynamic framework instead
of a static one for this target.

## Repo layout

```
.
├── Project.swift                    # App target → .project(target: "MyLib", path: "Packages/MyLib")
├── Tuist.swift
├── App/AppMain.swift                # @main App showing MyLibView
└── Packages/MyLib/
    ├── Project.swift                # .staticFramework + buildableFolders ["Sources/MyLib"]
    └── Sources/MyLib/
        ├── MyLib.swift              # Image(.actionDeleted) — fails to compile
        └── Resources/Media.xcassets/
            ├── action-deleted.imageset/
            ├── ai-doc-converter.imageset/
            └── ai-prompt.imageset/
```
