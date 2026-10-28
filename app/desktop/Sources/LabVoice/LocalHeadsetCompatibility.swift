import Foundation

// Local subset of retained BvcService matching used by AudioRouteController.
// Static native mapping binds interfaceName to the global
// device name, manufacturer to Manufacturer and modelId to ModelUID. Runtime
// metadata and automatic-selection acceptance remain unverified.
// No account, entitlement, team, cloud or automatic device-type policy runs here.
// Valid finite numeric rates cover the recovered contract. Malformed rates return
// unknown instead of inventing JavaScript coercion behavior. Lowercasing uses the
// host Unicode tables; parity across JavaScript/OS Unicode versions is unverified.
enum LocalHeadsetField: Equatable {
    case missing
    case string(String)
    case unsupported(truthy: Bool)
    var truthy: Bool {
        switch self {
        case .missing: return false
        case .string(let value): return !value.isEmpty
        case .unsupported(let truthy): return truthy
        }
    }
    static func parse(_ value: Any?) -> Self {
        guard let value, !(value is NSNull) else { return .missing }
        if let string = value as? String { return .string(string) }
        if let number = value as? NSNumber { return .unsupported(truthy: number.doubleValue != 0) }
        return .unsupported(truthy: true) // JSON arrays and objects are truthy in JavaScript.
    }
}
struct LocalHeadsetDevice {
    var interfaceName: LocalHeadsetField
    var manufacturer: LocalHeadsetField
    var modelId: LocalHeadsetField
    var sampleRate: Double?
}
struct LocalHeadsetEntry: Equatable {
    var name: LocalHeadsetField = .missing
    var manufacturer: LocalHeadsetField = .missing
    var modelUID: LocalHeadsetField = .missing
    fileprivate static func parse(_ value: Any) -> Self {
        guard let fields = value as? [String: Any] else { return .init() }
        return .init(name: .parse(fields["name"]), manufacturer: .parse(fields["manufacturer"]), modelUID: .parse(fields["model_uid"]))
    }
}
struct LocalHeadsetLists: Equatable {
    var allowed: [LocalHeadsetEntry] = []
    var blocked: [LocalHeadsetEntry] = []
    var manual: [LocalHeadsetEntry] = []
    mutating func addManual(name: String) { manual.append(.init(name: .string(name))) }
    mutating func removeManual(exactName: String) {
        manual.removeAll {
            guard case .string(let name) = $0.name else { return false }
            return name.utf16.elementsEqual(exactName.utf16)
        }
    }
}
enum LocalHeadsetMode { case auto, alwaysOff }
enum LocalHeadsetCompatibility: Equatable {
    case alwaysOff, lowRate, blocked, allowed, manualAllowed, userChoiceRequired
    case unknown(String)
    var compatible: Bool { self == .allowed || self == .manualAllowed }
}
struct LocalHeadsetCacheLoad {
    let lists: LocalHeadsetLists
    let loaded: Bool
    let failure: String?
}
enum LocalHeadsetPolicy {
    // Bounds are independent import limits. Failed loads preserve all previous
    // lists, like observed loadLists. A successful cache load keeps manual names.
    static func loadCache(_ data: Data?, preserving previous: LocalHeadsetLists) -> LocalHeadsetCacheLoad {
        func failed(_ reason: String) -> LocalHeadsetCacheLoad { .init(lists: previous, loaded: false, failure: reason) }
        guard let data, !data.isEmpty else { return failed("Cache is missing or empty.") }
        guard data.count <= 1_048_576 else { return failed("Cache exceeds the local import limit.") }
        guard String(data: data, encoding: .utf8) != nil,
              let object = try? JSONSerialization.jsonObject(with: data), let fields = object as? [String: Any] else { return failed("Cache must be a UTF-8 JSON object.") }
        guard let allowed = fields["allow_list"] as? [Any], let blocked = fields["block_list"] as? [Any] else { return failed("Cache allow_list and block_list must be arrays.") }
        guard allowed.count <= 10_000, blocked.count <= 10_000 else { return failed("Cache lists exceed the local import limit.") }
        return .init(lists: .init(allowed: allowed.map(LocalHeadsetEntry.parse), blocked: blocked.map(LocalHeadsetEntry.parse), manual: previous.manual), loaded: true, failure: nil)
    }
    static func evaluate(device: LocalHeadsetDevice, lists: LocalHeadsetLists, mode: LocalHeadsetMode) -> LocalHeadsetCompatibility {
        if mode == .alwaysOff { return .alwaysOff }
        guard let rate = device.sampleRate, rate.isFinite else { return .unknown("Device sample rate is missing or malformed.") }
        if rate < 16_000 { return .lowRate }
        // Original conversion is unconditional, even for a name-only match.
        guard case .string(let interfaceName) = device.interfaceName else { return .unknown("Device interfaceName is missing or malformed.") }
        guard case .string(let manufacturer) = device.manufacturer else { return .unknown("Device manufacturer is missing or malformed.") }
        guard case .string(let modelId) = device.modelId else { return .unknown("Device modelId is missing or malformed.") }
        let identity = (interfaceName.lowercased(), manufacturer.lowercased(), modelId.lowercased())
        for (name, entries, result) in [("blocked", lists.blocked, LocalHeadsetCompatibility.blocked), ("allowed", lists.allowed, .allowed), ("manual", lists.manual, .manualAllowed)] {
            for (index, entry) in entries.enumerated() {
                switch matches(entry, identity: identity) {
                case .match: return result
                case .noMatch: continue
                case .malformed(let field): return .unknown("Malformed \(name) entry \(index) field \(field).")
                }
            }
        }
        return .userChoiceRequired
    }
    private enum Match { case match, noMatch, malformed(String) }
    private static func matches(_ entry: LocalHeadsetEntry, identity: (String, String, String)) -> Match {
        if entry.name.truthy {
            guard case .string(let name) = entry.name else { return .malformed("name") }
            return includes(identity.0, name.lowercased()) ? .match : .noMatch
        }
        guard entry.manufacturer.truthy, entry.modelUID.truthy else { return .noMatch }
        guard case .string(let manufacturer) = entry.manufacturer else { return .malformed("manufacturer") }
        guard includes(identity.1, manufacturer.lowercased()) else { return .noMatch }
        guard case .string(let modelUID) = entry.modelUID else { return .malformed("model_uid") }
        return includes(identity.2, modelUID.lowercased()) ? .match : .noMatch
    }
    // JavaScript includes compares UTF-16 code units, without canonical equivalence.
    private static func includes(_ source: String, _ needle: String) -> Bool {
        let source = Array(source.utf16), needle = Array(needle.utf16)
        if needle.isEmpty { return true }
        guard source.count >= needle.count else { return false }
        return (0...(source.count - needle.count)).contains { source[$0..<($0 + needle.count)].elementsEqual(needle) }
    }
}
