import XCTest

final class AppTests: XCTestCase {
  // References SharedStub (which lives in App's buildable folder) to prove
  // the cross-target sources: glob is genuinely needed for AppTests to build.
  func test_sharedStub_defaultValue() {
    XCTAssertEqual(SharedStub().value, "stub")
  }
}
