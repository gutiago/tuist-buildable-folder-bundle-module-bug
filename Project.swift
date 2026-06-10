import ProjectDescription

let project = Project(
  name: "App",
  targets: [
    // Issue A: infoPlist + xcconfigs live INSIDE the "App" buildable folder.
    // Tuist generates a flat root-level PBXFileReference for each of them,
    // duplicating the entries already shown inside the synchronized folder.
    .target(
      name: "App",
      destinations: .iOS,
      product: .app,
      bundleId: "io.tuist.repro.app",
      deploymentTargets: .iOS("17.0"),
      infoPlist: .file(path: "App/Supporting/App-Info.plist"),
      buildableFolders: [
        .folder(
          "App",
          exceptions: [
            // Keep the manifest-referenced Info.plist out of the build phases
            // so it isn't double-copied; the flat root-level reference is
            // still generated regardless.
            .exception(excluded: ["Supporting/App-Info.plist"]),
          ]
        ),
      ],
      settings: .settings(
        configurations: [
          .debug(name: "Debug", xcconfig: "App/Supporting/Configurations/App-Debug.xcconfig"),
          .release(name: "Release", xcconfig: "App/Supporting/Configurations/App-Release.xcconfig"),
        ]
      )
    ),
    // Issue B: SharedStub.swift physically lives inside App's buildable
    // folder but must also compile into AppTests. The only manifest API is an
    // explicit sources: glob, which materialises another flat root-level
    // PBXFileReference. Xcode models this natively with a
    // PBXFileSystemSynchronizedBuildFileExceptionSet whose target is the
    // foreign target — no API for that in Tuist.
    .target(
      name: "AppTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "io.tuist.repro.tests",
      deploymentTargets: .iOS("17.0"),
      sources: [
        .glob("App/SharedStub.swift"),
      ],
      buildableFolders: ["AppTests"],
      dependencies: [
        .target(name: "App"),
      ]
    ),
  ]
)
