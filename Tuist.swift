import ProjectDescription

// `enforceExplicitDependencies: true` enables Xcode's explicit-module build and
// makes Tuist isolate each target to only its explicitly-declared modules.
// This is what surfaces Bug #3 below.
let tuist = Tuist(
  project: .tuist(
    generationOptions: .options(enforceExplicitDependencies: true)
  )
)
