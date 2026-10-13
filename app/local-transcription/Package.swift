// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "LocalTranscription", platforms: [.macOS(.v12)],
    products: [.library(name: "LocalTranscription", targets: ["LocalTranscription"])],
    targets: [.target(name: "LocalTranscription"),
              .testTarget(name: "LocalTranscriptionTests", dependencies: ["LocalTranscription"])])
