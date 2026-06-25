// Thin wrapper around the MathCore static C xcframework. It intentionally does
// NOT `import MathCore`; `-all_load` keeps the static archive's members so
// consumers can resolve the C symbols. A framework wrapper around an
// `.external(name:)` static C xcframework is the exact shape Tuist mishandles.
public enum MathCoreWrapper {}
