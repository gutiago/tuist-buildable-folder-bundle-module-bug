# Tuist `buildableFolders:` skips `Bundle.module` synthesis when resources are outside the allowlist

Minimal reproducible bug for **Tuist `4.170.0`**.

## The bug

When a target uses `buildableFolders:` and its resource files all have
extensions outside Tuist's hard-coded allowlist (e.g. `.jpg`, `.png`, `.ttf`,
`.heic`, `.aar`), Tuist treats the target as having no resources and skips
synthesis of `TuistBundle+<Target>.swift`. As a result, `Bundle.module` does
not resolve and any code referencing it fails to compile with
`error: type 'Bundle' has no member 'module'`. The same target switched from
`buildableFolders:` to explicit `sources:` + `resources:` builds successfully.

## Reproduce

```bash
tuist install
tuist generate --no-open

# Confirms TuistBundle+BugReproWorkaround.swift exists,
# but TuistBundle+BugRepro.swift is missing:
ls Derived/Sources/

# Broken target — fails to compile:
xcodebuild -workspace BugReproApp.xcworkspace \
           -scheme BugRepro \
           -destination "generic/platform=iOS Simulator" build

# Working target — same code, same files, succeeds:
xcodebuild -workspace BugReproApp.xcworkspace \
           -scheme BugReproWorkaround \
           -destination "generic/platform=iOS Simulator" build
```

Expected build error for `BugRepro`:

```
Sources/BugRepro/BugRepro.swift:10:12: error: type 'Bundle' has no member 'module'
    Bundle.module.url(forResource: "sample", withExtension: "png")
           ^~~~~~
```

## Root cause (Tuist 4.170.0 source links)

1. [`ResourcesProjectMapper.mapTarget`](https://github.com/tuist/tuist/blob/4.170.0/cli/Sources/TuistGenerator/Mappers/ResourcesProjectMapper.swift#L41-L48)
   early-returns when the target has no recognised resources, skipping bundle
   synthesis.
2. [`BuildableFolderChecker.containsResources`](https://github.com/tuist/tuist/blob/4.170.0/cli/Sources/TuistGenerator/Generator/BuildableFolderChecker.swift#L25-L31)
   only reports a folder as containing resources if files match an allowlist.
3. [`Target.validResourceExtensions`](https://github.com/tuist/tuist/blob/4.170.0/cli/Sources/XcodeGraph/Sources/XcodeGraph/Models/Target.swift#L16-L25) —
   the allowlist. It excludes `.jpg`, `.png`, `.ttf`, `.heic`, `.aar`, and
   many other common image/font/binary extensions.

`Project.swift` sets `resourceSynthesizers: []`. With Tuist's default
synthesizers, `containsSynthesizedFilesInBuildableFolders` returns true for
`.png`/`.jpg`/`.ttf` (because they are SwiftGen synthesizer extensions) and
masks this bug. Disabling the synthesizers — common in projects that supply
their own asset / string generation pipeline — surfaces it.

## Affected extensions discovered in a real production codebase

Inventory of files under `Sources/.../Resources/` and `Tests/.../Resources/`
that are NOT covered by Tuist's allowlist. None trigger bundle synthesis
under `buildableFolders:` + `resourceSynthesizers: []`:

| Extension | Where seen        | In allowlist? |
| --------- | ----------------- | ------------- |
| `.png`    | sources + tests   | No            |
| `.jpg`    | sources + tests   | No            |
| `.ttf`    | sources           | No            |
| `.aar`    | sources + tests   | No            |
| `.heic`   | tests             | No            |
| `.pem`    | tests             | No            |
| `.html`   | tests             | No            |
| `.csv`    | tests             | No            |
| `.der`    | tests             | No            |
| `.crt`    | tests             | No            |

## Workaround

For affected targets, drop `buildableFolders:` and use explicit `sources:` +
`resources:` globs (see the `BugReproWorkaround` target). Tuist then keys
synthesis off `target.resources.resources.isEmpty == false`, so the bundle
accessor is generated regardless of extension.
