import ProjectDescription

// NOTE: `resourceSynthesizers: []` mirrors how a project that supplies its own
// asset / string generation pipeline configures Tuist (i.e. not relying on
// SwiftGen's defaults). With the default synthesizers, the
// `containsSynthesizedFilesInBuildableFolders` check in
// `ResourcesProjectMapper.mapTarget` returns true for `.png` / `.jpg` / `.ttf`
// and masks this bug. Disabling them surfaces it — and matches a real
// production setup that uses Tuist's `buildableFolders:`.
let project = Project(
  name: "BugReproApp",
  targets: [
    // Broken case: `buildableFolders:` + resources whose extensions are
    // outside `Target.validResourceExtensions`
    // (e.g. `.jpg`, `.png`, `.ttf`, `.heic`, `.aar`).
    // `BuildableFolderChecker.containsResources` returns false →
    // `ResourcesProjectMapper.mapTarget` early-returns →
    // `TuistBundle+BugRepro.swift` is NOT generated →
    // `Bundle.module` does not resolve and the target fails to compile.
    .target(
      name: "BugRepro",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.example.bugrepro",
      deploymentTargets: .iOS("16.0"),
      infoPlist: .default,
      buildableFolders: [
        "Sources/BugRepro",
      ]
    ),
    // Working case: identical Swift, identical resource files, but the target
    // uses explicit `sources:` + `resources:` globs.
    // `target.resources.resources.isEmpty == false` short-circuits the early
    // return, Tuist synthesises `TuistBundle+BugReproWorkaround.swift`,
    // and `Bundle.module` resolves.
    .target(
      name: "BugReproWorkaround",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.example.bugreproworkaround",
      deploymentTargets: .iOS("16.0"),
      infoPlist: .default,
      sources: [
        "SourcesWorkaround/BugReproWorkaround/**/*.swift",
      ],
      resources: [
        "SourcesWorkaround/BugReproWorkaround/Resources/**",
      ]
    ),
  ],
  resourceSynthesizers: []
)
