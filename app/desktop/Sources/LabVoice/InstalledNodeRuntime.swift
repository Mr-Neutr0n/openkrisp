import Foundation

enum InstalledNodeRuntime {
    static let bundledSHA256 = "533bd644c5ae0e0ea3a80e433aad16b817447ccba1e1eea701875eac80cb75d4"
    static let homebrewSHA256 = "1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040"
    static let reviewedSHA256: Set<String> = [bundledSHA256,homebrewSHA256]
    static func packagedURL() -> URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let node = resources.appendingPathComponent("helper/node-runtime/node")
        return FileManager.default.isExecutableFile(atPath: node.path) ? node : nil
    }
}
