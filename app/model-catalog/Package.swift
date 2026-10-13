// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ModelCatalog", platforms: [.macOS(.v12)],
    products: [.library(name: "ModelCatalog", targets: ["ModelCatalog"])],
    targets: [.target(name: "ModelCatalog", resources: [.process("Resources")]),
              .testTarget(name: "ModelCatalogTests", dependencies: ["ModelCatalog"])])
