// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "LabVoiceDesktop",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "LabVoice", targets: ["LabVoice"])],
    dependencies: [.package(path: "../local-store"), .package(path: "../model-catalog"), .package(path: "../local-transcription")],
    targets: [.executableTarget(name: "LabVoice", dependencies: [.product(name: "LocalStore", package: "local-store"), .product(name: "ModelCatalog", package: "model-catalog"), .product(name: "LocalTranscription", package: "local-transcription")]),
              .testTarget(name: "LabVoiceTests", dependencies: ["LabVoice"])],
    swiftLanguageModes: [.v5]
)
