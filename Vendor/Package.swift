// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "Vendor",
  platforms: [.iOS(.v16)],
  products: [.library(name: "MathCore", targets: ["MathCore"])],
  targets: [
    // A STATIC C xcframework whose module map references a header (`math_core.h`)
    // whose name does NOT match the xcframework basename (`MathCore`).
    .binaryTarget(name: "MathCore", path: "../Fixtures/MathCore.xcframework"),
  ]
)
