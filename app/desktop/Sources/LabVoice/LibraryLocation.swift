import Foundation
import Combine
import LocalStore
import Darwin

struct LibraryLocationSnapshot: Codable, Equatable, Sendable {
    let root: URL
    let createIfMissing: Bool
    let revision: UUID
    var unavailableReason: String? = nil
    func open() throws -> LocalStore {
        guard unavailableReason == nil else { throw LibraryLocationError.invalidPreference }
        return try LocalStore(root: root, createIfMissing: createIfMissing)
    }
}
struct LibraryActivity {
    let id: UUID
    let location: LibraryLocationSnapshot
}
actor LibraryLocationInspector {
    func inspect(_ candidate: LibraryLocationSnapshot) throws { _ = try candidate.open().inventory() }
}

@MainActor final class LibraryLocation: ObservableObject {
    static let shared = LibraryLocation()
    static let preferenceKey = "libraryDirectory"
    @Published private(set) var snapshot: LibraryLocationSnapshot
    @Published private(set) var switching = false
    @Published private(set) var error: String?
    @Published private(set) var activities: [UUID: String] = [:]
    private let defaults: UserDefaults
    private let inspect: (LibraryLocationSnapshot) async throws -> Void
    private var admissionObservation: AnyCancellable?
    var displayPath: String { snapshot.unavailableReason ?? snapshot.root.path }
    var canSwitch: Bool { !switching && activities.isEmpty && AudioCaptureAdmission.shared.available }
    init(defaults: UserDefaults = .standard, defaultRoot: URL? = nil,
         inspect: ((LibraryLocationSnapshot) async throws -> Void)? = nil) {
        self.defaults = defaults
        let defaultDirectory = defaultRoot ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Lab Voice/sessions", isDirectory: true)
        if defaults.object(forKey: Self.preferenceKey) != nil {
            if let selected = defaults.string(forKey: Self.preferenceKey), !selected.isEmpty, selected.hasPrefix("/") {
                snapshot = .init(root: URL(fileURLWithPath: selected, isDirectory: true), createIfMissing: false, revision: UUID())
            } else {
                let reason = "Saved library folder is invalid. Choose an existing folder."
                snapshot = .init(root: defaultDirectory, createIfMissing: false, revision: UUID(), unavailableReason: reason)
                error = reason
            }
        } else { snapshot = .init(root: defaultDirectory, createIfMissing: true, revision: UUID()) }
        let inspector = LibraryLocationInspector()
        self.inspect = inspect ?? { try await inspector.inspect($0) }
        admissionObservation = AudioCaptureAdmission.shared.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }
    func begin(_ reason: String) throws -> LibraryActivity {
        guard !switching else { throw LibraryLocationError.busy }
        let activity = LibraryActivity(id: UUID(), location: snapshot)
        activities[activity.id] = reason
        return activity
    }
    func end(_ activity: LibraryActivity) { activities.removeValue(forKey: activity.id) }
    func report(_ failure: Error, location: LibraryLocationSnapshot) {
        guard snapshot.revision == location.revision else { return }
        error = describe(failure)
    }
    func confirmed(_ location: LibraryLocationSnapshot) {
        if snapshot.revision == location.revision { error = nil }
    }
    private func describe(_ error: Error) -> String {
        if case StoreError.io(_, let code) = error {
            if code == ENOENT { return "Selected library folder does not exist. Reconnect it or choose another folder." }
            if code == EACCES || code == EPERM { return "Selected library folder is not accessible. Check its permissions or choose another folder." }
        }
        if case LibraryLocationError.invalidPreference = error { return "Saved library folder is invalid. Choose an existing folder." }
        return "Library folder unavailable: \(error)"
    }
    @discardableResult func choose(_ root: URL) async -> Bool {
        guard canSwitch else { error = "Finish audio, recording, transcription, or library work before changing the folder."; return false }
        guard root.isFileURL, root.path.hasPrefix("/") else { error = "Choose an existing folder on this Mac."; return false }
        switching = true; error = nil
        defer { switching = false }
        let candidate = LibraryLocationSnapshot(root: root.standardizedFileURL, createIfMissing: false, revision: UUID())
        do {
            try await inspect(candidate)
            // Admission remains held throughout inspection, so no operation can bind the old root here.
            defaults.set(candidate.root.path, forKey: Self.preferenceKey)
            snapshot = candidate
            return true
        } catch { self.error = "Folder was not changed. " + describe(error); return false }
    }
}
enum LibraryLocationError: Error { case busy, invalidPreference }
