import ProjectDescription

// Reproducing bugs #1/#2 requires Tuist's *binary cache* to materialize the
// `MathCoreLib` wrapper as a precompiled dynamic xcframework (set your own
// `fullHandle` and be logged in: `tuist auth login`). Building a consumer against
// that cached dynamic xcframework — which depends on the static `MathCore`
// xcframework — fires `StaticXCFrameworkModuleMapGraphMapper`.
// `enforceExplicitDependencies` enables the explicit-module build (bug #3).
let tuist = Tuist(
  fullHandle: "gustavo/static-xcf-modmap",
  project: .tuist(
    generationOptions: {
      var options = Tuist.GenerationOptions.options(enforceExplicitDependencies: true)
      options.enableCaching = true
      return options
    }(),
    cacheOptions: .options(
      profiles: .profiles(["all": .profile(.allPossible)], default: "all")
    )
  )
)
