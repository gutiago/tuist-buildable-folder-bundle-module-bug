import ProjectDescription

// Mirrors the real graph that triggers the bug:
//   Feature (framework)  ──▶  MathCoreLib (.dynamicOrStatic wrapper)  ──▶  .external("MathCore")
// where MathCore is a STATIC C xcframework with a clang module map whose header
// name (`math_core.h`) does not match the xcframework name (`MathCore`).
let project = Project(
  name: "ReproApp",
  targets: [
    // Thin framework wrapper that links the static C archive once, shared by consumers.
    .target(
      name: "MathCoreLib",
      destinations: .iOS,
      product: .framework, // dynamic framework (what `.dynamicOrStatic` resolves to here)
      bundleId: "com.example.mathcorelib",
      deploymentTargets: .iOS("16.0"),
      infoPlist: .default,
      buildableFolders: ["Sources/MathCoreTarget"],
      dependencies: [
        .external(name: "MathCore"),
      ],
      // Nothing in the wrapper references the C archive; -all_load keeps its members.
      settings: .settings(base: ["OTHER_LDFLAGS": ["$(inherited)", "-all_load"]])
    ),
    // Feature module that imports the C module transitively through the wrapper.
    .target(
      name: "Feature",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.example.feature",
      deploymentTargets: .iOS("16.0"),
      infoPlist: .default,
      sources: ["Sources/Feature/**"],
      dependencies: [
        .target(name: "MathCoreLib"),
      ]
    ),
  ]
)
