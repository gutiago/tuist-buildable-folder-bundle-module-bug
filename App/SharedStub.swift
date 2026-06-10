import Foundation

// Lives inside the App target's buildable folder, but also needs to compile
// into AppTests (cross-target membership). See Issue B in README.md.
struct SharedStub {
  let value: String

  init(value: String = "stub") {
    self.value = value
  }
}
