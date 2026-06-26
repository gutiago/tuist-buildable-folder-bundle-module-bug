import ProjectDescription

// Thin framework wrapper around the static C `.external("MathCore")` xcframework —
// mirrors a real "link the static C archive once" target. Binary caching materializes
// this as a precompiled dynamic xcframework that depends on the static MathCore
// xcframework, which is what fires `StaticXCFrameworkModuleMapGraphMapper`.
let project = Project(
  name: "Wrapper",
  targets: [
    .target(
      name: "MathCoreLib",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.example.mathcorelib",
      deploymentTargets: .iOS("16.0"),
      infoPlist: .default,
      buildableFolders: ["Sources/MathCoreLib"],
      dependencies: [
        .external(name: "MathCore"),
      ],
      // Nothing in the wrapper references the C archive; -all_load keeps its members.
      settings: .settings(base: ["OTHER_LDFLAGS": ["$(inherited)", "-all_load"]])
    ),
  ]
)
