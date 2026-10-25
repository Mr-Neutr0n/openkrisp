import XCTest
@testable import LabVoice

final class LocalHeadsetCompatibilityTests: XCTestCase {
    private var device: LocalHeadsetDevice {
        .init(interfaceName: .string("USB Poly Headset"), manufacturer: .string("Acme Corp"), modelId: .string("Model-123"), sampleRate: 48000)
    }
    private func name(_ value: String) -> LocalHeadsetEntry { .init(name: .string(value)) }
    private func evaluate(_ lists: LocalHeadsetLists, device: LocalHeadsetDevice? = nil, mode: LocalHeadsetMode = .auto) -> LocalHeadsetCompatibility {
        LocalHeadsetPolicy.evaluate(device: device ?? self.device, lists: lists, mode: mode)
    }
    func testLocalPrecedenceAndManualChoice() {
        let match = name("pOLy")
        XCTAssertEqual(evaluate(.init()), .userChoiceRequired)
        XCTAssertEqual(evaluate(.init(manual: [match])), .manualAllowed)
        XCTAssertEqual(evaluate(.init(allowed: [match], manual: [match])), .allowed)
        XCTAssertEqual(evaluate(.init(allowed: [match], blocked: [match], manual: [match])), .blocked)
        XCTAssertTrue(LocalHeadsetCompatibility.allowed.compatible)
        XCTAssertTrue(LocalHeadsetCompatibility.manualAllowed.compatible)
        for result in [LocalHeadsetCompatibility.blocked, .lowRate, .alwaysOff, .userChoiceRequired, .unknown("missing")] { XCTAssertFalse(result.compatible) }
    }
    func testNamePrecedesPairWithoutWhitespaceTrimmingOrRegex() {
        let pair = LocalHeadsetEntry(manufacturer: .string("ACME"), modelUID: .string("DEL-1"))
        XCTAssertEqual(evaluate(.init(allowed: [pair])), .allowed)
        var mixed = pair; mixed.name = .string("other")
        XCTAssertEqual(evaluate(.init(allowed: [mixed])), .userChoiceRequired)
        mixed.name = .string(""); XCTAssertEqual(evaluate(.init(allowed: [mixed])), .allowed)
        mixed.name = .unsupported(truthy: false); XCTAssertEqual(evaluate(.init(allowed: [mixed])), .allowed)
        XCTAssertEqual(evaluate(.init(allowed: [name(" poly ")])), .allowed)
        XCTAssertEqual(evaluate(.init(allowed: [name("  poly  ")])), .userChoiceRequired)
        XCTAssertEqual(evaluate(.init(allowed: [name("poly.*")])), .userChoiceRequired)
        var missingPair = pair; missingPair.modelUID = .missing
        XCTAssertEqual(evaluate(.init(allowed: [missingPair, .init(modelUID: .string("model"))])), .userChoiceRequired)
        missingPair.modelUID = .string("")
        XCTAssertEqual(evaluate(.init(allowed: [missingPair])), .userChoiceRequired)
    }
    func testMalformedFieldsFollowOnlyReachedBranches() {
        let malformed = LocalHeadsetEntry(name: .unsupported(truthy: true))
        XCTAssertEqual(evaluate(.init(allowed: [name("poly")], blocked: [malformed])), .unknown("Malformed blocked entry 0 field name."))
        XCTAssertEqual(evaluate(.init(allowed: [name("poly"), malformed])), .allowed)
        XCTAssertEqual(evaluate(.init(allowed: [malformed], blocked: [name("poly")])), .blocked)
        var pair = LocalHeadsetEntry(manufacturer: .unsupported(truthy: true))
        XCTAssertEqual(evaluate(.init(allowed: [pair])), .userChoiceRequired) // Missing model UID short-circuits first.
        pair.modelUID = .string("model")
        XCTAssertEqual(evaluate(.init(allowed: [pair])), .unknown("Malformed allowed entry 0 field manufacturer."))
        pair.manufacturer = .string("other"); pair.modelUID = .unsupported(truthy: true)
        XCTAssertEqual(evaluate(.init(allowed: [pair])), .userChoiceRequired)
        pair.manufacturer = .string("acme")
        XCTAssertEqual(evaluate(.init(manual: [pair])), .unknown("Malformed manual entry 0 field model_uid."))
    }
    func testEarlyGatesAndRequiredDeviceFields() {
        var bad = device; bad.interfaceName = .missing; bad.manufacturer = .missing; bad.modelId = .missing; bad.sampleRate = nil
        XCTAssertEqual(evaluate(.init(), device: bad, mode: .alwaysOff), .alwaysOff)
        XCTAssertEqual(evaluate(.init(), device: bad), .unknown("Device sample rate is missing or malformed."))
        bad.sampleRate = 15999; XCTAssertEqual(evaluate(.init(), device: bad), .lowRate)
        bad.sampleRate = 16000; XCTAssertEqual(evaluate(.init(), device: bad), .unknown("Device interfaceName is missing or malformed."))
        bad = device; bad.manufacturer = .unsupported(truthy: false)
        XCTAssertEqual(evaluate(.init(allowed: [name("poly")])), .allowed)
        XCTAssertEqual(evaluate(.init(allowed: [name("poly")]), device: bad), .unknown("Device manufacturer is missing or malformed."))
        bad = device; bad.modelId = .missing
        XCTAssertEqual(evaluate(.init(allowed: [name("poly")]), device: bad), .unknown("Device modelId is missing or malformed."))
        bad = device; bad.interfaceName = .string(""); bad.manufacturer = .string(""); bad.modelId = .string("")
        XCTAssertEqual(evaluate(.init(allowed: [name("poly"), .init(manufacturer: .string("acme"), modelUID: .string("model"))]), device: bad), .userChoiceRequired)
        bad.sampleRate = -1; XCTAssertEqual(evaluate(.init(), device: bad), .lowRate)
        for rate in [Double.nan, .infinity] { bad.sampleRate = rate; XCTAssertEqual(evaluate(.init(), device: bad), .unknown("Device sample rate is missing or malformed.")) }
    }
    func testUTF16SubstringAndExactManualRemovalAvoidCanonicalEquivalence() {
        var item = device; item.interfaceName = .string("USB Caf\u{00e9}")
        XCTAssertEqual(evaluate(.init(allowed: [name("cafe\u{0301}")]), device: item), .userChoiceRequired)
        XCTAssertEqual(evaluate(.init(allowed: [name("CAF\u{00c9}")]), device: item), .allowed)
        item.interfaceName = .string("USB 👩‍💻 headset")
        XCTAssertEqual(evaluate(.init(allowed: [name("💻")]), device: item), .allowed)
        var lists = LocalHeadsetLists(manual: [name("Poly"), name("poly"), name("caf\u{00e9}"), name("cafe\u{0301}")])
        lists.addManual(name: "Poly"); lists.addManual(name: "")
        lists.removeManual(exactName: ""); XCTAssertEqual(lists.manual.count, 5)
        lists.removeManual(exactName: "Poly"); XCTAssertEqual(lists.manual.count, 3)
        lists.removeManual(exactName: "caf\u{00e9}"); XCTAssertEqual(lists.manual.count, 2)
        XCTAssertEqual(lists.manual[1].name, .string("cafe\u{0301}"))
    }
    func testReviewerStaticFixtureLocalSubset() throws {
        // Expectations come from retained static source, not original execution.
        let url = try XCTUnwrap(Bundle.module.url(forResource: "LocalHeadsetMatcherCases", withExtension: "json", subdirectory: "Fixtures"))
        let fixture = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let base = try XCTUnwrap(fixture["defaultDevice"] as? [String: Any])
        let cases = try XCTUnwrap(fixture["cases"] as? [[String: Any]])
        XCTAssertEqual(cases.count, 43)
        var checked = 0, excluded = 0
        for item in cases {
            // Team/account policy is deliberately outside this local subset.
            if item["team"] != nil || (item["allowed"] as? Bool) == false { excluded += 1; continue }
            let id = try XCTUnwrap(item["id"] as? String)
            var identity = base
            for (key, value) in (item["device"] as? [String: Any]) ?? [:] { identity[key] = value }
            if let omitted = item["omit"] as? String { identity.removeValue(forKey: omitted) }
            let device = LocalHeadsetDevice(interfaceName: .parse(identity["interfaceName"]), manufacturer: .parse(identity["manufacturer"]), modelId: .parse(identity["modelId"]), sampleRate: (identity["fmt"] as? [String: Any])?["sampleRate"] as? Double)
            let lists = (item["lists"] as? [String: Any]) ?? [:]
            let cache: [String: Any] = ["allow_list": lists["allowed"] ?? [], "block_list": lists["blocked"] ?? []]
            let loaded = LocalHeadsetPolicy.loadCache(try JSONSerialization.data(withJSONObject: cache), preserving: .init())
            XCTAssertTrue(loaded.loaded, id)
            // Use the same production entry parser for the independent manual list.
            let manualCache: [String: Any] = ["allow_list": lists["userChoice"] ?? [], "block_list": []]
            let manual = LocalHeadsetPolicy.loadCache(try JSONSerialization.data(withJSONObject: manualCache), preserving: .init())
            var combined = loaded.lists; combined.manual = manual.lists.allowed
            let result = LocalHeadsetPolicy.evaluate(device: device, lists: combined, mode: item["mode"] as? String == "OFF" ? .alwaysOff : .auto)
            let expected = try XCTUnwrap(item["expected"] as? String)
            switch expected {
            case "ALLOWED": XCTAssertEqual(result, .allowed, id)
            case "BLOCKED": XCTAssertEqual(result, .blocked, id)
            case "USER_CHOICE_ALLOWED": XCTAssertEqual(result, .manualAllowed, id)
            case "NOT_DEDICATED": XCTAssertEqual(result, .userChoiceRequired, id)
            case "LOW_RATE": XCTAssertEqual(result, .lowRate, id)
            case "MODE_OPTION_SET_TO_ALWAYS_OFF": XCTAssertEqual(result, .alwaysOff, id)
            case "THROW": if case .unknown = result {} else { XCTFail("Expected explicit unknown for original thrown condition: " + id) }
            default: XCTFail("Unhandled fixture expectation " + expected)
            }
            checked += 1
        }
        XCTAssertEqual(checked, 35); XCTAssertEqual(excluded, 8)
    }
    func testNullBlockedCacheEntryDoesNotPreemptAllowedMatch() throws {
        let cache = Data("{\"allow_list\":[{\"name\":\"poly\"}],\"block_list\":[null]}".utf8)
        let loaded = LocalHeadsetPolicy.loadCache(cache, preserving: .init())
        XCTAssertTrue(loaded.loaded); XCTAssertEqual(evaluate(loaded.lists), .allowed)
    }
    func testBoundedCacheLoadPreservesPriorListsOnEveryFailure() throws {
        let previous = LocalHeadsetLists(allowed: [name("keep")], blocked: [name("block")], manual: [name("manual")])
        let invalid = [nil, Data(), Data("{".utf8), Data("[]".utf8), Data("{\"allow_list\":[],\"block_list\":null}".utf8), Data("{\"allow_list\":{},\"block_list\":[]}".utf8), Data([0xff]), Data(repeating: 0x20, count: 1_048_577)] as [Data?]
        for data in invalid {
            let loaded = LocalHeadsetPolicy.loadCache(data, preserving: previous)
            XCTAssertFalse(loaded.loaded); XCTAssertNotNil(loaded.failure); XCTAssertEqual(loaded.lists, previous)
        }
        let input: [String: Any] = ["allow_list": [["name": "poly", "manufacturer": "ignored"], ["manufacturer": "acme", "model_uid": "model"], NSNull(), 42, ["name": false]], "block_list": [["model_uid": "unused"]]]
        let loaded = LocalHeadsetPolicy.loadCache(try JSONSerialization.data(withJSONObject: input), preserving: previous)
        XCTAssertTrue(loaded.loaded); XCTAssertNil(loaded.failure); XCTAssertEqual(loaded.lists.manual, previous.manual)
        XCTAssertEqual(loaded.lists.allowed.count, 5); XCTAssertEqual(evaluate(loaded.lists), .allowed)
        let malformed: [String: Any] = ["allow_list": [["name": 1]], "block_list": []]
        let accepted = LocalHeadsetPolicy.loadCache(try JSONSerialization.data(withJSONObject: malformed), preserving: previous)
        XCTAssertTrue(accepted.loaded) // Original loader checks arrays, not entry fields.
        XCTAssertEqual(evaluate(accepted.lists), .unknown("Malformed allowed entry 0 field name."))
        let empty = LocalHeadsetPolicy.loadCache(Data("{\"allow_list\":[],\"block_list\":[]}".utf8), preserving: previous)
        XCTAssertTrue(empty.loaded); XCTAssertTrue(empty.lists.allowed.isEmpty); XCTAssertTrue(empty.lists.blocked.isEmpty); XCTAssertEqual(empty.lists.manual, previous.manual)
    }
}
