// Thin wrapper that links the static MathCore C xcframework once and shares it with
// consumers. It intentionally does not `import MathCore`; the dependency edge
// (MathCoreLib → MathCore) is what matters for the bug.
public enum MathCoreLib {}
