import ProjectDescription

let project = Project(
  name: "MyLib",
  targets: [
    .target(
      name: "MyLib",
      destinations: [.iPhone, .iPad],
      // The bug trigger. Switch to `.framework` (dynamic) and the build works.
      product: .staticFramework,
      bundleId: "com.example.mylib",
      deploymentTargets: .iOS("17.0"),
      // `buildableFolders` is Xcode 16's filesystem-synchronized groups. With
      // .staticFramework + a .xcassets in the folder, Tuist creates a
      // `membershipException` excluding Resources/Media.xcassets from this
      // framework target. Xcode never runs GenerateAssetSymbols for the
      // framework, so `Image(.actionDeleted)` cannot resolve.
      buildableFolders: ["Sources/MyLib"]
    ),
  ]
)
