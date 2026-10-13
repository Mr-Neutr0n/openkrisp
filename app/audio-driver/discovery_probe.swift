// Read-only discovery probe. It never registers an IOProc or opens audio.
import CoreAudio
import Foundation

func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
}
func translate(_ selector: AudioObjectPropertySelector, _ text: String) -> [String: Any] {
    var property = address(selector)
    var qualifier = text as CFString
    var object: AudioObjectID = 0
    var bytes = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = withUnsafePointer(to: &qualifier) {
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &property,
                                   UInt32(MemoryLayout<CFString>.size), $0, &bytes, &object)
    }
    return ["status": status, "id": object, "bytes": bytes]
}
func objects(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [String: Any] {
    var property = address(selector)
    var bytes: UInt32 = 0
    let sizeStatus = AudioObjectGetPropertyDataSize(object, &property, 0, nil, &bytes)
    guard sizeStatus == 0, bytes <= 4096, bytes % 4 == 0 else {
        return ["sizeStatus": sizeStatus, "bytes": bytes, "error": "unsupported_property_size"]
    }
    if bytes == 0 { return ["sizeStatus": sizeStatus, "bytes": 0, "objects": [UInt32]()] }
    var values = [AudioObjectID](repeating: 0, count: Int(bytes) / 4)
    let status = values.withUnsafeMutableBytes {
        AudioObjectGetPropertyData(object, &property, 0, nil, &bytes, $0.baseAddress!)
    }
    guard status == 0, bytes % 4 == 0, Int(bytes) / 4 <= values.count else {
        return ["sizeStatus": sizeStatus, "status": status, "bytes": bytes,
                "error": "invalid_property_result"]
    }
    return ["sizeStatus": sizeStatus, "status": status, "bytes": bytes,
            "objects": Array(values.prefix(Int(bytes) / 4))]
}
let bundle = "dev.hari.labvoice.audio"
let plugin = translate(kAudioHardwarePropertyTranslateBundleIDToPlugIn, bundle)
var result: [String: Any] = ["mode": "read-only-discovery-probe", "bundle": bundle, "plugin": plugin]
if let object = plugin["id"] as? AudioObjectID, object != 0 {
    result["deviceList"] = objects(object, kAudioPlugInPropertyDeviceList)
    result["ownedObjects"] = objects(object, kAudioObjectPropertyOwnedObjects)
}
result["devices"] = ["dev.hari.labvoice.microphone", "dev.hari.labvoice.speaker",
                     "dev.hari.labvoice.feed", "dev.hari.labvoice.monitor"].map {
    ["uid": $0, "translation": translate(kAudioHardwarePropertyTranslateUIDToDevice, $0)] as [String: Any]
}
let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data([10]))
