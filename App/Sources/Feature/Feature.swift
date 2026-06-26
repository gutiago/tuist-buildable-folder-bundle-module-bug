import MathCore // C module from the static xcframework, reached through MathCoreLib

// A feature module that uses the vendored C library through the wrapper framework.
public func feature() -> Int {
  Int(math_core_add(2, 3))
}
