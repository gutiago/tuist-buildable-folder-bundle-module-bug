import ProjectDescription

// Feature consumes the static C library through the cross-project `MathCoreLib`
// wrapper. When focused-generate caches the wrapper as a precompiled dynamic
// xcframework, the precompiled-dynamic → static-xcframework edge fires the mapper.
let project = Project(
  name: "App",
  targets: [
    .target(
      name: "Feature",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.example.feature",
      deploymentTargets: .iOS("16.0"),
      infoPlist: .default,
      sources: ["Sources/Feature/**"],
      dependencies: [
        .project(target: "MathCoreLib", path: "../Wrapper"),
      ]
    ),
  ]
)
