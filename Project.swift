import ProjectDescription

let project = Project(
  name: "BugReproApp",
  targets: [
    .target(
      name: "BugReproApp",
      destinations: .iOS,
      product: .app,
      bundleId: "com.example.bugreproapp",
      deploymentTargets: .iOS("17.0"),
      infoPlist: .extendingDefault(with: [
        "UILaunchScreen": [:],
      ]),
      sources: ["App/**/*.swift"],
      dependencies: [
        .project(target: "MyLib", path: "Packages/MyLib"),
      ]
    ),
  ]
)
