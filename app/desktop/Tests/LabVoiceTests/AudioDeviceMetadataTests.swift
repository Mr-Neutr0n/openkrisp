import XCTest
@testable import LabVoice

final class AudioDeviceMetadataTests: XCTestCase {
    private func device(_ metadata: [String: Any] = [:]) throws -> AudioHardwareDevice {
        var value: [String: Any] = ["uid": "own-uid", "name": "Display name only", "alive": 1, "nominal_rate": 48000,
            "input": ["channels": 1], "output": ["channels": 0]]
        for (key, field) in metadata { value[key] = field }
        return try JSONDecoder().decode(AudioHardwareDevice.self, from: JSONSerialization.data(withJSONObject: value))
    }
    func testOldInventoryDoesNotInventInterfaceMetadataFromDisplayName() throws {
        let value = try device()
        XCTAssertNil(value.interfaceName); XCTAssertNil(value.manufacturer); XCTAssertNil(value.modelId); XCTAssertNil(value.metadataReadErrors)
        XCTAssertEqual(value.localHeadsetPolicyDevice.interfaceName, .missing)
        let lists = LocalHeadsetLists(allowed: [.init(name: .string("Display"))])
        XCTAssertEqual(LocalHeadsetPolicy.evaluate(device: value.localHeadsetPolicyDevice, lists: lists, mode: .auto), .unknown("Device interfaceName is missing or malformed."))
        // Defaulted fields preserve existing memberwise construction.
        let constructed = AudioHardwareDevice(uid: "uid", name: "Display", alive: 1, nominalRate: 48000, input: .init(channels: 1), output: .init(channels: 0))
        XCTAssertNil(constructed.interfaceName)
    }
    func testNewMetadataDecodesExactFieldsAndConvertsWithoutDerivation() throws {
        let value = try device(["interface_name": "Global Poly Headset", "manufacturer": "ACME", "model_id": "Model-123", "metadata_read_errors": []])
        XCTAssertEqual(value.interfaceName, "Global Poly Headset"); XCTAssertEqual(value.manufacturer, "ACME"); XCTAssertEqual(value.modelId, "Model-123")
        XCTAssertEqual(value.metadataReadErrors, [])
        let lists = LocalHeadsetLists(allowed: [.init(manufacturer: .string("acme"), modelUID: .string("123"))])
        XCTAssertEqual(LocalHeadsetPolicy.evaluate(device: value.localHeadsetPolicyDevice, lists: lists, mode: .auto), .allowed)
    }
    func testMissingNullEmptyAndFailedOptionalReadsStayDistinct() throws {
        let empty = try device(["interface_name": "", "manufacturer": "", "model_id": "", "metadata_read_errors": []])
        XCTAssertEqual(empty.localHeadsetPolicyDevice.interfaceName, .string(""))
        XCTAssertEqual(LocalHeadsetPolicy.evaluate(device: empty.localHeadsetPolicyDevice, lists: .init(), mode: .auto), .userChoiceRequired)
        let null = try device(["interface_name": NSNull(), "manufacturer": NSNull(), "model_id": NSNull()])
        XCTAssertNil(null.interfaceName); XCTAssertEqual(null.localHeadsetPolicyDevice.manufacturer, .missing)
        let failed = try device(["interface_name": "Global Poly", "manufacturer": "", "model_id": "", "metadata_read_errors": ["manufacturer: property read OSStatus=-1"]])
        XCTAssertEqual(failed.manufacturer, ""); XCTAssertEqual(failed.metadataReadErrors?.count, 1)
        XCTAssertEqual(LocalHeadsetPolicy.evaluate(device: failed.localHeadsetPolicyDevice, lists: .init(allowed: [.init(name: .string("poly"))]), mode: .auto), .allowed)
    }
    func testMalformedMetadataTypesRejectInventoryRatherThanCoerce() throws {
        for (key, value) in [("interface_name", 7 as Any), ("manufacturer", false as Any), ("model_id", [] as Any), ("metadata_read_errors", "failure" as Any), ("metadata_read_errors", [7] as Any)] {
            XCTAssertThrowsError(try device([key: value]))
        }
    }
}
