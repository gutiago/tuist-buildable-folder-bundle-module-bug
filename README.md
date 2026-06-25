# `enforceExplicitDependencies` can't resolve a C module from a static xcframework reached through a dynamic-framework wrapper

Reproducible bug for **Tuist `4.199.2`** (Xcode 26, explicit modules).

## The bug

A common vendoring shape:

```
Feature (framework)  ──▶  MathCoreLib (framework wrapper)  ──▶  .external("MathCore")
```

- `MathCore` is a **static C xcframework** with a clang module map (`module MathCore { header "math_core.h" }`).
- `MathCoreLib` is a thin **framework** that wraps it (mirrors a real "link the C archive once" wrapper target). It depends on `.external(name: "MathCore")` and force-loads it (`-all_load`); it does not itself `import MathCore`.
- `Feature` `import MathCore` and is built **through** `MathCoreLib` — so `MathCore` is a *transitive* module dependency of `Feature`.

With `enforceExplicitDependencies: true` the build fails:

```
error: unable to resolve module dependency: 'MathCore'
import MathCore
       ^ (in target 'Feature')
```

The same project builds fine with the flag off, **and** Tuist's own
`tuist inspect dependencies --only implicit` reports **no issue** — so Tuist's
implicit-dependency analysis and its `enforceExplicitDependencies` build
**disagree**.

## Reproduce (verified)

```bash
sh Fixtures/build_fixtures.sh     # build MathCore.xcframework (static C, mismatched header)
tuist install
tuist generate --no-open

# Tuist says the graph is clean:
tuist inspect dependencies --only implicit
#  ▸ "We did not find any dependency issues in your project (checked: implicit)."

# …but the build fails (flag ON):
xcodebuild build -workspace ReproApp.xcworkspace -scheme Feature \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation
#  ▸ error: unable to resolve module dependency: 'MathCore'
```

Control — set `Tuist.swift` to `let tuist = Tuist()` (flag off), regenerate, build the same scheme → **BUILD SUCCEEDED**. (`enforceExplicitDependencies` is what turns on `-explicit-module-build` here.)

| Configuration | `tuist inspect … --only implicit` | `xcodebuild` |
| --- | --- | --- |
| `enforceExplicitDependencies: true`  | passes (no issue) | **fails** — unable to resolve `MathCore` |
| flag off                             | passes (no issue) | succeeds |

## Root cause

`enforceExplicitDependencies` makes Tuist build with `-explicit-module-build` and
gives each target a generated `Derived/ModuleMaps/<Target>-deps.modulemap` that the
Swift dependency scanner reads. That file lists the target's clang-module
dependencies as `extern module …` entries — **but the C module from a static
xcframework reached transitively through the framework wrapper is omitted**. The
module is available to the linker/compiler search paths, yet it is never registered
with the explicit-module scanner, so `import MathCore` cannot be resolved.

Crucially this is inconsistent with [`GraphTraverser`](https://github.com/tuist/tuist/blob/main/cli/Sources/TuistCore/Graph/GraphTraverser.swift)'s
implicit-dependency analysis (what `tuist inspect dependencies --only implicit`
uses): it treats the transitively-reachable `MathCore` as satisfied and reports
nothing, so a user gets a clean bill of health and then a broken build with no
guidance once the flag is enabled.

**Fix:** when `enforceExplicitDependencies` is on, emit an `extern module`
entry (pointing at the xcframework's module map) into the `-deps.modulemap` of
every target that transitively imports a clang module from a static xcframework —
or make `inspect dependencies --only implicit` flag the same case the
`enforceExplicitDependencies` build rejects, so detection and enforcement agree.

## Two related issues in the same code path

When the static xcframework is instead reached as a **static-xcframework-linked-by-a-dynamic-xcframework** (handled by [`StaticXCFrameworkModuleMapGraphMapper`](https://github.com/tuist/tuist/blob/main/cli/Sources/TuistKit/Mappers/Graph/StaticXCFrameworkModuleMapGraphMapper.swift)), the same mismatched-header xcframework also triggers:

1. **Header never copied (header name ≠ xcframework name).**
   [`generateModuleMapAndUmbrellaHeader`](https://github.com/tuist/tuist/blob/main/cli/Sources/TuistKit/Mappers/Graph/StaticXCFrameworkModuleMapGraphMapper.swift)
   globs `**/<xcframeworkBasename>.h` (`MathCore.h`) for the umbrella header, but the
   real header is `math_core.h`, so it returns `nil` and the header is not copied next
   to the derived module map → `module map references header 'math_core.h' not found`.
   *Fix:* read the header from the module map's `header "…"` declaration instead of
   assuming the xcframework name.

2. **Module declared twice → "redefinition of module".**
   The mapper sets `-fmodule-map-file` to the **derived** module map *and*
   `HEADER_SEARCH_PATHS` to the **original** `Headers` directory (which also contains a
   `module.modulemap`). Xcode 26's explicit-module scanner then sees two module maps for
   the same module → `redefinition of module 'MathCore'`. *Fix:* don't add the original
   `Headers` dir to `HEADER_SEARCH_PATHS` when the module is already provided via
   `-fmodule-map-file`.

These two require the dynamic-xcframework→static-xcframework graph edge (a real
binary distribution) to trigger and are **not** reproduced by this minimal sample;
they are documented here because they share the same root cause — Tuist handling a
static xcframework whose clang module map uses a non-matching header name.

## What's in this repo

| Path | Purpose |
| --- | --- |
| `Fixtures/build_fixtures.sh`, `Fixtures/src/` | Builds `MathCore.xcframework` (static C, header `math_core.h` ≠ `MathCore`, hand-written module map). |
| `Fixtures/MathCore.xcframework` | Pre-built fixture, committed so the sample is self-contained. |
| `Vendor/Package.swift` | SwiftPM package vending `MathCore` as a binary target. |
| `Project.swift` | `MathCoreLib` framework wrapper + `Feature` consumer. |
| `Tuist.swift` | `generationOptions: .options(enforceExplicitDependencies: true)`. |
| `Sources/Feature/Feature.swift` | `import MathCore`. |
