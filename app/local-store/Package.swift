// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocalStore",
    platforms: [.macOS(.v12)],
    products: [.library(name: "LocalStore", targets: ["LocalStore"])],
    targets: [.target(name: "LocalStore"), .testTarget(name: "LocalStoreTests", dependencies: ["LocalStore"])]
)
