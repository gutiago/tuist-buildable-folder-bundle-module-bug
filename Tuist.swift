import ProjectDescription

// `enforceExplicitDependencies: true` enables Xcode's explicit-module build and
// makes Tuist isolate each target to only its explicitly-declared modules — this is
// what surfaces the verified bug (see README).
let tuist = Tuist(
  project: .tuist(
    generationOptions: .options(enforceExplicitDependencies: true)
  )
)
