# Tuist mishandles a static C xcframework (mismatched-header module map) reached through a cached dynamic-framework wrapper

Reproducible bugs in **Tuist `4.199.2`** (Xcode 26, explicit modules) in how
[`StaticXCFrameworkModuleMapGraphMapper`](https://github.com/tuist/tuist/blob/main/cli/Sources/TuistKit/Mappers/Graph/StaticXCFrameworkModuleMapGraphMapper.swift)
re-exposes a **static C xcframework** that is linked by a **precompiled dynamic
framework** (produced by the binary cache).

## The graph

```
App/Feature (framework)  ──▶  Wrapper/MathCoreLib (framework)  ──▶  .external("MathCore")
```

- `MathCore` is a **static C xcframework** whose clang module map references a header
  whose name does **not** match the xcframework basename:
  ```
  MathCore.xcframework/ios-arm64/Headers/
  ├── math_core.h          # ← snake_case, ≠ "MathCore"
  └── module.modulemap     # module MathCore { header "math_core.h" export * }
  ```
- `MathCoreLib` is a thin framework wrapper that links `MathCore` (`-all_load`) and is
  shared by consumers. It lives in its own project (the `Wrapper` project), exactly like
  a real "link the static C archive once" target.
- `Feature` `import MathCore` (reached transitively through `MathCoreLib`).

## Why the binary cache is required

`StaticXCFrameworkModuleMapGraphMapper` only fires when a **precompiled dynamic**
framework/xcframework has the static xcframework as a graph dependency
(`precompiledDynamicLibrariesAndFrameworks` → `filterDependencies(from:)`). A plain Tuist
`.target` is **never** precompiled
([`GraphDependency.isPrecompiled`](https://github.com/tuist/tuist/blob/main/cli/Sources/XcodeGraph/Sources/XcodeGraph/Graph/GraphDependency.swift)
returns `false` for `.target`), so the wrapper *target* alone can't trigger it.

Tuist's **binary cache** materializes `MathCoreLib` as a **precompiled dynamic
xcframework** that depends on the static `MathCore` xcframework — and *that*
precompiled-dynamic → static edge is what fires the mapper. So the bug only reproduces
when a consumer is built against the **cached** wrapper.

## Reproduce (verified)

Requires a Tuist account (binary cache). Set `fullHandle` in `Tuist.swift` to your own
project and log in:

```bash
tuist auth login
# tuist project create <account>/<handle> --build-system xcode   # if you need one

sh Fixtures/build_fixtures.sh          # build MathCore.xcframework (static C, mismatched header)
tuist install
tuist generate
tuist cache MathCoreLib                # cache the wrapper → precompiled dynamic xcframework
tuist cache Feature                    # build the consumer against the cached wrapper
```

The last step **fails**:

```
error: clang dependency scanning failure:
  …/Tuist/.build/tuist-derived/XCFrameworks/MathCore/Headers/module.modulemap:2:12:
  error: header 'math_core.h' not found
fatal error: could not build module 'MathCore'
App/Sources/Feature/Feature.swift:1:8: error: unable to resolve module dependency: 'MathCore'
```

(The mapper created `Tuist/.build/tuist-derived/XCFrameworks/MathCore/Headers/module.modulemap`,
but the header it references was never copied next to it.)

## The bugs

### Bug 1 — derived umbrella header never copied (header name ≠ xcframework name) — **reproduced above**
[`generateModuleMapAndUmbrellaHeader`](https://github.com/tuist/tuist/blob/main/cli/Sources/TuistKit/Mappers/Graph/StaticXCFrameworkModuleMapGraphMapper.swift)
globs the umbrella header by the **xcframework basename**:

```swift
let name = xcframework.path.basenameWithoutExt          // "MathCore"
let umbrellaHeader = try await fileSystem
    .glob(directory: xcframework.path, include: ["**/\(name).h"])   // looks for **/MathCore.h
    .collect().first
```

The real header is `math_core.h`, so the glob returns `nil`, the header is never copied
next to the derived module map, and the build fails with `header 'math_core.h' not found`.
**Fix:** resolve the umbrella header from the module map's own `header "…"` declaration
(or copy the whole `Headers` directory), instead of assuming the xcframework name.

### Bug 2 — module declared twice → "redefinition of module" (behind Bug 1)
The mapper sets `-fmodule-map-file` to the **derived** module map *and* `HEADER_SEARCH_PATHS`
to the **original** `Headers` dir (which also contains a `module.modulemap`). Once Bug 1 is
worked around (header provided), Xcode 26's explicit-module scanner sees two module maps for
the same module → `redefinition of module 'MathCore'`. **Fix:** don't add the original
`Headers` dir to `HEADER_SEARCH_PATHS` when the module is already provided via
`-fmodule-map-file`.

### Bug 3 — `enforceExplicitDependencies` can't resolve a transitively-imported C module
Independently of the cache: with `enforceExplicitDependencies: true`, a target that imports
the C module transitively through the wrapper fails the explicit-module build
(`unable to resolve module dependency: 'MathCore'`) while
`tuist inspect dependencies --only implicit` reports **no issue** — Tuist's implicit
analysis and its enforcement disagree. **Fix:** emit an `extern module` entry for the
xcframework's module into each consumer's `-deps.modulemap`, or make `inspect` flag the
same case the build rejects.

## Summary of Tuist-side fixes

1. Derive the umbrella header from the module map's `header "…"` declaration, not the xcframework name.
2. Stop double-declaring the module (`-fmodule-map-file` + `HEADER_SEARCH_PATHS` to a dir containing a module map).
3. Under `enforceExplicitDependencies`, register the static xcframework's module in consumers' `-deps.modulemap` (and align `inspect dependencies` with it).

## Layout

| Path | Purpose |
| --- | --- |
| `Fixtures/build_fixtures.sh`, `Fixtures/src/` | Builds `MathCore.xcframework` (static C; header `math_core.h` ≠ `MathCore`). |
| `Fixtures/MathCore.xcframework` | Pre-built fixture, committed. |
| `Vendor/Package.swift` | SwiftPM package vending `MathCore` as a binary target. |
| `Wrapper/Project.swift` | `MathCoreLib` framework wrapper (`.external("MathCore")`, `-all_load`). |
| `App/Project.swift` | `Feature` framework that `import MathCore` through the wrapper. |
| `Workspace.swift` | Ties the `App` and `Wrapper` projects together. |
| `Tuist.swift` | `enableCaching` + `enforceExplicitDependencies`; set your own `fullHandle`. |
