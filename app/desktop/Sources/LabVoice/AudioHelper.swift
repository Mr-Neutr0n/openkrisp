import Foundation
import Darwin

struct AudioDirection: Decodable, Sendable { let channels: UInt32 }
struct AudioHardwareDevice: Decodable, Identifiable, Sendable {
    let uid: String
    let name: String
    let alive: UInt32
    let nominalRate: Double
    let input: AudioDirection
    let output: AudioDirection
    var id: String { uid }
    enum CodingKeys: String, CodingKey { case uid, name, alive, input, output; case nominalRate = "nominal_rate" }
}
struct AudioCompanion: Decodable, Sendable { let uid: String; let present: Bool }
struct AudioInventory: Decodable, Sendable {
    let devices: [AudioHardwareDevice]
    let companions: [AudioCompanion]
    let errors: [String]
    enum CodingKeys: String, CodingKey { case devices, errors; case companions = "companion_devices" }
    var driverPresent: Bool {
        ["dev.hari.labvoice.feed", "dev.hari.labvoice.monitor"].allSatisfy { uid in
            companions.contains { $0.uid == uid && $0.present }
        }
    }
}
struct AudioRouteOptions: Equatable, Sendable {
    let inputUID: String
    let outputUID: String
    let microphoneNoise: Bool
    let speakerNoise: Bool
    var installedProvider: InstalledNCConfiguration? = nil
    var installedSpeakerProvider: InstalledNCConfiguration? = nil
    var validProviderRoles: Bool {
        (installedProvider == nil || (microphoneNoise && installedProvider?.modelRole == .outbound)) &&
        (installedSpeakerProvider == nil || (speakerNoise && installedSpeakerProvider?.modelRole == .inbound))
    }
    var arguments: [String] {
        var args = ["--route", "--input", inputUID, "--output", outputUID]
        if microphoneNoise { args.append("--microphone-noise-suppression") }
        if speakerNoise { args.append("--speaker-noise-suppression") }
        if microphoneNoise, let installedProvider { args += installedProvider.arguments }
        if speakerNoise, let installedSpeakerProvider { args += installedSpeakerProvider.arguments(speaker: true) }
        return args
    }
}
struct AudioStartup: Decodable, Sendable {
    let event: String
    let operationID: String?
    let microphone: AudioChannelControl?
    let speaker: AudioChannelControl?
    let inputUID: String
    let outputUID: String
    let microphoneNoise: Bool
    let speakerNoise: Bool
    let microphoneProvider: String?
    let speakerProvider: String?
    let providerModelSHA256: String?
    let providerAddonSHA256: String?
    let providerAdapterSHA256: String?
    let providerNodeSHA256: String?
    let providerDelaySamples: Int?
    let providerMaximumCallbackFrames: Int?
    let speakerProviderModelSHA256: String?
    let speakerProviderAddonSHA256: String?
    let speakerProviderAdapterSHA256: String?
    let speakerProviderNodeSHA256: String?
    let speakerProviderDelaySamples: Int?
    let speakerProviderMaximumCallbackFrames: Int?
    enum CodingKeys: String, CodingKey {
        case speakerProviderModelSHA256 = "speaker_provider_model_sha256", speakerProviderAddonSHA256 = "speaker_provider_addon_sha256"
        case speakerProviderAdapterSHA256 = "speaker_provider_adapter_sha256", speakerProviderNodeSHA256 = "speaker_provider_node_sha256"
        case speakerProviderDelaySamples = "speaker_provider_delay_samples", speakerProviderMaximumCallbackFrames = "speaker_provider_maximum_callback_frames"
        case event, operationID, microphone, speaker
        case microphoneProvider = "microphone_provider", speakerProvider = "speaker_provider"
        case providerModelSHA256 = "provider_model_sha256", providerAddonSHA256 = "provider_addon_sha256"
        case providerAdapterSHA256 = "provider_adapter_sha256", providerNodeSHA256 = "provider_node_sha256"
        case providerDelaySamples = "provider_delay_samples", providerMaximumCallbackFrames = "provider_maximum_callback_frames"
        case inputUID = "input_uid", outputUID = "output_uid"
        case microphoneNoise = "microphone_noise", speakerNoise = "speaker_noise"
    }
    var controls: AudioControlSnapshot? {
        guard let microphone, let speaker else { return nil }
        return AudioControlSnapshot(microphone: microphone, speaker: speaker)
    }
    func matches(_ expected: AudioRouteOptions) -> Bool {
        guard expected.validProviderRoles, inputUID == expected.inputUID, outputUID == expected.outputUID,
              microphoneNoise == expected.microphoneNoise, speakerNoise == expected.speakerNoise else { return false }
        func lane(noise: Bool, configuration: InstalledNCConfiguration?, role: InstalledNCModelRole,
                  name: String?, model: String?, addon: String?, adapter: String?, node: String?, delay: Int?, maximum: Int?) -> Bool {
            if let configuration {
                guard noise, configuration.modelRole == role, name == "installed-krisp", model == role.modelSHA256,
                      addon == InstalledNCConfiguration.addonSHA256, adapter == configuration.adapterSHA256,
                      node == configuration.nodeSHA256, let maximum, (1...4096).contains(maximum),
                      delay == ((maximum + 958) / 480 + 2) * 480 else { return false }
                return true
            }
            return name == (noise ? "rnnoise" : "none") && model == nil && addon == nil && adapter == nil && node == nil && delay == nil && maximum == nil
        }
        return lane(noise: expected.microphoneNoise, configuration: expected.installedProvider, role: .outbound,
                    name: microphoneProvider, model: providerModelSHA256, addon: providerAddonSHA256,
                    adapter: providerAdapterSHA256, node: providerNodeSHA256, delay: providerDelaySamples, maximum: providerMaximumCallbackFrames) &&
            lane(noise: expected.speakerNoise, configuration: expected.installedSpeakerProvider, role: .inbound,
                 name: speakerProvider, model: speakerProviderModelSHA256, addon: speakerProviderAddonSHA256,
                 adapter: speakerProviderAdapterSHA256, node: speakerProviderNodeSHA256,
                 delay: speakerProviderDelaySamples, maximum: speakerProviderMaximumCallbackFrames)
    }
}
struct HelperExit: Sendable { let status: Int32; let output: Data; let diagnostic: String }

@MainActor protocol AudioHelperChild: AnyObject {
    var running: Bool { get }
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws
    func send(_ line: Data) throws
    func terminate()
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool
}

enum AudioHelperError: Error, LocalizedError {
    case missingHelper, inventoryFailed(String), invalidInventory, controlChannelClosed, controlWriteFailed(Int32), invalidControlLine
    var errorDescription: String? {
        switch self {
        case .missingHelper: return "The signed app is missing its audio helper. Rebuild the app bundle."
        case .inventoryFailed(let message): return "Cannot read audio devices. \(message)"
        case .invalidInventory: return "The audio helper returned invalid device information."
        case .controlChannelClosed: return "The audio helper control channel is closed."
        case .controlWriteFailed(let code): return "The audio helper did not accept a control write, OS error \(code)."
        case .invalidControlLine: return "The audio control message exceeds the bounded pipe limit."
        }
    }
}

// Blocking pipe reads stay on utility queues. Main-queue delivery preserves stream order.
// This class never starts a route unless its caller explicitly supplies --route arguments.
@MainActor final class SystemAudioHelperChild: AudioHelperChild {
    private let url: URL
    private var process: Process?
    private var input: FileHandle?
    private var inputLimit = 0
    private var lineCallback: ((String) -> Void)?
    private var exitCallback: ((HelperExit) -> Void)?
    private var stdout = Data(), stderr = Data(), lines = Data()
    private var stdoutClosed = false, stderrClosed = false
    private var exitStatus: Int32?
    private var overflow = false
    var running: Bool { process?.isRunning ?? false }
    init(url: URL) { self.url = url }
    func launch(arguments: [String], line: @escaping (String) -> Void, exit: @escaping (HelperExit) -> Void) throws {
        guard process == nil else { throw AudioHelperError.inventoryFailed("The helper is already running.") }
        let child = Process(), output = Pipe(), error = Pipe(), commands = Pipe()
        child.executableURL = url; child.arguments = arguments
        let writer = commands.fileHandleForWriting
        let fd = writer.fileDescriptor
        let flags = fcntl(fd, F_GETFL)
        let atomicLimit = fpathconf(fd, _PC_PIPE_BUF)
        guard flags >= 0, atomicLimit > 0,
              fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0,
              fcntl(fd, F_SETNOSIGPIPE, 1) == 0,
              fcntl(fd, F_SETFD, FD_CLOEXEC) == 0 else {
            try? writer.close(); try? commands.fileHandleForReading.close()
            throw AudioHelperError.controlWriteFailed(errno)
        }
        inputLimit = min(512, Int(atomicLimit))
        child.standardInput = commands
        child.standardOutput = output; child.standardError = error
        lineCallback = line; exitCallback = exit; process = child
        child.terminationHandler = { [weak self] ended in
            DispatchQueue.main.async { self?.ended(ended.terminationStatus) }
        }
        do { try child.run() }
        catch {
            try? writer.close(); try? commands.fileHandleForReading.close()
            process = nil; lineCallback = nil; exitCallback = nil; throw error
        }
        commands.fileHandleForReading.closeFile(); input = writer
        output.fileHandleForWriting.closeFile(); error.fileHandleForWriting.closeFile()
        read(output.fileHandleForReading, isError: false)
        read(error.fileHandleForReading, isError: true)
    }
    private func read(_ handle: FileHandle, isError: Bool) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            defer { try? handle.close() }
            var bytes = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = bytes.withUnsafeMutableBytes { Darwin.read(handle.fileDescriptor, $0.baseAddress, $0.count) }
                if count < 0 && errno == EINTR { continue }
                if count <= 0 { break }
                let data = Data(bytes.prefix(count))
                DispatchQueue.main.async { self?.receive(data, isError: isError) }
            }
            DispatchQueue.main.async { self?.closed(isError: isError) }
        }
    }
    private func receive(_ data: Data, isError: Bool) {
        if isError {
            if stderr.count + data.count <= 65_536 { stderr.append(data) } else { overflow = true }
        } else {
            if stdout.count + data.count <= 2_097_152 { stdout.append(data) } else { overflow = true }
            if lines.count + data.count <= 65_536 { lines.append(data) }
            else { overflow = true; lines.removeAll(keepingCapacity: true) }
            while let newline = lines.firstIndex(of: 10) {
                let row = lines.prefix(upTo: newline)
                let text = String(decoding: row, as: UTF8.self)
                lines.removeSubrange(...newline)
                lineCallback?(text)
            }
        }
    }
    private func closed(isError: Bool) {
        if isError { stderrClosed = true } else { stdoutClosed = true }
        finishIfReady()
    }
    private func ended(_ status: Int32) { exitStatus = status; finishIfReady() }
    private func finishIfReady() {
        guard let status = exitStatus, stdoutClosed, stderrClosed else { return }
        let callback = exitCallback
        exitCallback = nil; lineCallback = nil
        closeInput()
        var diagnostic = String(decoding: stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if overflow { diagnostic += "\nHelper output exceeded the diagnostic limit." }
        callback?(HelperExit(status: status, output: stdout, diagnostic: diagnostic))
    }
    func send(_ line: Data) throws {
        guard running, let input else { throw AudioHelperError.controlChannelClosed }
        guard !line.isEmpty, line.count <= inputLimit, line.last == 10 else { throw AudioHelperError.invalidControlLine }
        let count = line.withUnsafeBytes { Darwin.write(input.fileDescriptor, $0.baseAddress, line.count) }
        guard count == line.count else { throw AudioHelperError.controlWriteFailed(count < 0 ? errno : EIO) }
    }
    private func closeInput() { try? input?.close(); input = nil }
    func terminate() {
        closeInput()
        if let process, process.isRunning { process.terminate() }
    }
    func waitForExit(timeoutNanoseconds: UInt64) async -> Bool {
        let start = DispatchTime.now().uptimeNanoseconds
        while running || exitStatus == nil || !stdoutClosed || !stderrClosed {
            if DispatchTime.now().uptimeNanoseconds - start >= timeoutNanoseconds { return false }
            do { try await Task.sleep(nanoseconds: 20_000_000) } catch { return false }
        }
        return true
    }
}

@MainActor final class AudioHelperServices {
    private var inventoryChild: (any AudioHelperChild)?
    private var inventoryDeadline: Task<Void, Never>?
    static func makeChild() throws -> any AudioHelperChild { SystemAudioHelperChild(url: try packagedURL()) }
    static func packagedURL() throws -> URL {
        guard let resources = Bundle.main.resourceURL else { throw AudioHelperError.missingHelper }
        let url = resources.appendingPathComponent("helper/audio-host")
        guard FileManager.default.isExecutableFile(atPath: url.path) else { throw AudioHelperError.missingHelper }
        return url
    }
    func stopInventory() async -> Bool {
        guard let child = inventoryChild else { return true }
        child.terminate()
        return await child.waitForExit(timeoutNanoseconds: 10_000_000_000)
    }

    func inventory() async throws -> AudioInventory {
        guard inventoryChild == nil else { throw AudioHelperError.inventoryFailed("A refresh is already pending.") }
        let child = SystemAudioHelperChild(url: try Self.packagedURL())
        inventoryChild = child
        inventoryDeadline = Task { [weak child] in
            do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return }
            child?.terminate()
        }
        defer { inventoryDeadline?.cancel(); inventoryDeadline = nil; inventoryChild = nil }
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try child.launch(arguments: ["--list"], line: { _ in }, exit: { event in
                    guard event.status == 0 else {
                        continuation.resume(throwing: AudioHelperError.inventoryFailed(event.diagnostic)); return
                    }
                    do { continuation.resume(returning: try JSONDecoder().decode(AudioInventory.self, from: event.output)) }
                    catch { continuation.resume(throwing: AudioHelperError.invalidInventory) }
                })
            } catch { continuation.resume(throwing: error) }
        }
    }
}
