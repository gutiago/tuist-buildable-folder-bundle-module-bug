// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "ReproDeps",
  dependencies: [
    .package(path: "../Vendor"),
  ]
)
