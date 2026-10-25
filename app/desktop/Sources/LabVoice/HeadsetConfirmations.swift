import Foundation

struct HeadsetConfirmation: Codable, Equatable, Identifiable {
    let uid: String
    let name: String
    var id: String { uid }
}

// Own local policy. Names are labels; only an exact device UID grants confirmation.
@MainActor final class HeadsetConfirmationStore {
    static let preferenceKey = "headsetConfirmations.v1"
    private struct Record: Codable { let schemaVersion: Int; let entries: [HeadsetConfirmation] }
    private let defaults: UserDefaults
    private(set) var entries: [HeadsetConfirmation]
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.preferenceKey), data.count <= 1_048_576,
           let record = try? JSONDecoder().decode(Record.self, from: data), record.schemaVersion == 1,
           record.entries.count <= 256, record.entries.allSatisfy(Self.valid),
           Set(record.entries.map(\.uid)).count == record.entries.count {
            entries = record.entries
        } else { entries = [] }
    }
    private static func valid(_ entry: HeadsetConfirmation) -> Bool {
        [entry.uid, entry.name].allSatisfy {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 4096 && !$0.contains("\0")
        }
    }
    @discardableResult func confirm(uid: String, name: String) -> Bool {
        let entry = HeadsetConfirmation(uid: uid, name: name)
        guard Self.valid(entry) else { return false }
        var next = entries.filter { $0.uid != uid }
        guard next.count < 256 else { return false }
        next.append(entry)
        return save(next)
    }
    @discardableResult func remove(uid: String) -> Bool { save(entries.filter { $0.uid != uid }) }
    @discardableResult func reset() -> Bool { save([]) }
    private func save(_ next: [HeadsetConfirmation]) -> Bool {
        guard let data = try? JSONEncoder().encode(Record(schemaVersion: 1, entries: next)), data.count <= 1_048_576 else { return false }
        defaults.set(data, forKey: Self.preferenceKey)
        entries = next
        return true
    }
}
