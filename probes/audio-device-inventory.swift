import Foundation
import CoreAudio

// Read-only CoreAudio declarations. No IOProc, stream start, property write or recording.
func address(_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}
func bytes(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> (OSStatus, Data) {
    var a = address(selector, scope)
    var size: UInt32 = 0
    let status = AudioObjectGetPropertyDataSize(object, &a, 0, nil, &size)
    guard status == noErr, size <= 1_048_576 else { return (status == noErr ? -1 : status, Data()) }
    var data = Data(count: Int(size))
    if size == 0 { return (noErr, data) }
    let read = data.withUnsafeMutableBytes { AudioObjectGetPropertyData(object, &a, 0, nil, &size, $0.baseAddress!) }
    guard read == noErr else { return (read, Data()) }
    data.count = Int(size)
    return (read, data)
}
func values<T>(_ data: Data, _: T.Type) -> [T] {
    guard data.count % MemoryLayout<T>.stride == 0 else { return [] }
    return stride(from: 0, to: data.count, by: MemoryLayout<T>.stride).map { offset in
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
    }
}
func scalar<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _: T.Type, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> [String: Any] {
    let (status, data) = bytes(object, selector, scope)
    guard status == noErr, data.count == MemoryLayout<T>.size, let value = values(data, T.self).first else {
        return ["status": status, "state": "unavailable", "bytes": data.count]
    }
    return ["status": status, "value": value]
}
func text(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [String: Any] {
    var a = address(selector)
    var result: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    let status = AudioObjectGetPropertyData(object, &a, 0, nil, &size, &result)
    guard status == noErr, let result else { return ["status": status, "state": "unavailable"] }
    return ["status": status, "value": result.takeRetainedValue() as String]
}
func ranges(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [String: Any] {
    let (status, data) = bytes(object, selector)
    return ["status": status, "ranges": values(data, AudioValueRange.self).map { ["min": $0.mMinimum, "max": $0.mMaximum] }]
}
func format(_ f: AudioStreamBasicDescription) -> [String: Any] {
    ["sample_rate": f.mSampleRate, "format_id": f.mFormatID, "flags": f.mFormatFlags,
     "bytes_per_packet": f.mBytesPerPacket, "frames_per_packet": f.mFramesPerPacket,
     "bytes_per_frame": f.mBytesPerFrame, "channels": f.mChannelsPerFrame, "bits_per_channel": f.mBitsPerChannel]
}
func streams(_ device: AudioObjectID, _ scope: AudioObjectPropertyScope) -> [String: Any] {
    let (status, data) = bytes(device, kAudioDevicePropertyStreams, scope)
    let items = values(data, AudioStreamID.self).map { stream -> [String: Any] in
        var item: [String: Any] = ["object_id": stream,
            "latency_frames": scalar(stream, kAudioStreamPropertyLatency, UInt32.self),
            "starting_channel": scalar(stream, kAudioStreamPropertyStartingChannel, UInt32.self)]
        for (key, selector) in [("virtual", kAudioStreamPropertyVirtualFormat), ("physical", kAudioStreamPropertyPhysicalFormat)] {
            let (s, b) = bytes(stream, selector)
            item[key + "_format"] = ["status": s, "formats": values(b, AudioStreamBasicDescription.self).map(format)]
        }
        for (key, selector) in [("virtual", kAudioStreamPropertyAvailableVirtualFormats), ("physical", kAudioStreamPropertyAvailablePhysicalFormats)] {
            let (s, b) = bytes(stream, selector)
            item[key + "_available_formats"] = ["status": s, "formats": values(b, AudioStreamRangedDescription.self).map {
                ["format": format($0.mFormat), "rate_min": $0.mSampleRateRange.mMinimum, "rate_max": $0.mSampleRateRange.mMaximum] as [String: Any]
            }]
        }
        return item
    }
    return ["status": status, "streams": items,
        "device_latency_frames": scalar(device, kAudioDevicePropertyLatency, UInt32.self, scope),
        "safety_offset_frames": scalar(device, kAudioDevicePropertySafetyOffset, UInt32.self, scope)]
}

let (status, deviceData) = bytes(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDevices)
var selected: [[String: Any]] = []
for device in values(deviceData, AudioDeviceID.self) {
    let name = text(device, kAudioObjectPropertyName)
    let uid = text(device, kAudioDevicePropertyDeviceUID)
    let identity = ((name["value"] as? String ?? "") + " " + (uid["value"] as? String ?? "")).lowercased()
    guard identity.contains("krisp") else { continue }
    selected.append([
        "object_id": device, "name": name, "uid": uid,
        "manufacturer": text(device, kAudioObjectPropertyManufacturer),
        "model_uid": text(device, kAudioDevicePropertyModelUID),
        "transport_type": scalar(device, kAudioDevicePropertyTransportType, UInt32.self),
        "alive": scalar(device, kAudioDevicePropertyDeviceIsAlive, UInt32.self),
        "running_somewhere": scalar(device, kAudioDevicePropertyDeviceIsRunningSomewhere, UInt32.self),
        "nominal_sample_rate": scalar(device, kAudioDevicePropertyNominalSampleRate, Float64.self),
        "available_nominal_sample_rates": ranges(device, kAudioDevicePropertyAvailableNominalSampleRates),
        "buffer_frames": scalar(device, kAudioDevicePropertyBufferFrameSize, UInt32.self),
        "buffer_frame_range": ranges(device, kAudioDevicePropertyBufferFrameSizeRange),
        "input": streams(device, kAudioObjectPropertyScopeInput),
        "output": streams(device, kAudioObjectPropertyScopeOutput)
    ])
}
let output: [String: Any] = ["schema_version": 1, "device_list_status": status,
    "selection": "device name or UID contains krisp, case-insensitive", "devices": selected,
    "limitations": ["Read-only device declarations at one instant; no audio was captured or processed.",
        "Names and UIDs select devices but do not authenticate the loaded driver binary.",
        "Declared latency is not measured end-to-end latency.", "Hidden devices may not appear in the public device list."]]
let json = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: json, as: UTF8.self))
if status != noErr { exit(1) }
