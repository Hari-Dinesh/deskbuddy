import Foundation

struct QuickNote: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var updatedAt = Date()
}

struct ScheduledReminder: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case quick, meeting }
    var id = UUID()
    var title: String
    var dueAt: Date
    var kind: Kind = .quick
    var sourceID: String? = nil
    var meetingStart: Date? = nil
    var expiresAt: Date? = nil
    var joinURL: URL? = nil
    var completedAt: Date? = nil
    var deliveredAt: Date? = nil
}

struct MicrosoftSettings: Codable, Equatable {
    var clientID = Bundle.main.object(forInfoDictionaryKey: "DeskBuddyMicrosoftClientID") as? String ?? ""
    var tenant = "organizations"
    var enabled = false
    var leadMinutes = 5
    var quietDuringMeetings = true
    var credentialAccount: String { tenant.lowercased() + ":" + clientID.lowercased() }
    var valid: Bool { UUID(uuidString: clientID) != nil && (tenant == "organizations" || tenant == "common" || UUID(uuidString: tenant) != nil) }
}

struct CalendarMeeting: Equatable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let joinURL: URL?
    var reminderKey: String { id + ":" + String(start.timeIntervalSince1970) }
}

struct WorkspaceData: Codable {
    var notes: [QuickNote] = []
    var reminders: [ScheduledReminder] = []
    var microsoft = MicrosoftSettings()

    mutating func mergeMeetings(_ meetings: [CalendarMeeting], now: Date) {
        let existing = Dictionary(reminders.filter { $0.kind == .meeting }.compactMap { item in item.sourceID.map { ($0, item) } }, uniquingKeysWith: { first, _ in first })
        reminders.removeAll { $0.kind == .meeting }
        for meeting in meetings where meeting.end > now {
            var item = existing[meeting.reminderKey] ?? ScheduledReminder(title: meeting.title, dueAt: meeting.start, kind: .meeting)
            item.title = meeting.title; item.sourceID = meeting.reminderKey
            item.dueAt = meeting.start.addingTimeInterval(-Double(microsoft.leadMinutes * 60))
            item.meetingStart = meeting.start; item.expiresAt = meeting.end; item.joinURL = meeting.joinURL
            reminders.append(item)
        }
    }
    func nextDue(now: Date) -> ScheduledReminder? {
        reminders.filter { item in
            item.completedAt == nil && item.dueAt <= now && (item.expiresAt ?? .distantFuture) > now &&
            (item.kind != .meeting || microsoft.enabled) &&
            (item.deliveredAt.map { now.timeIntervalSince($0) >= 600 } ?? true)
        }.sorted { left, right in
            if left.kind != right.kind { return left.kind == .meeting }
            return left.dueAt < right.dueAt
        }.first
    }
    mutating func delivered(_ id: UUID, at now: Date) {
        if let index = reminders.firstIndex(where: { $0.id == id }) { reminders[index].deliveredAt = now }
    }
    mutating func complete(_ id: UUID, at now: Date) {
        if let index = reminders.firstIndex(where: { $0.id == id }) { reminders[index].completedAt = now }
    }
    mutating func snooze(_ id: UUID, at now: Date) {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[index].dueAt = now.addingTimeInterval(reminders[index].kind == .meeting ? 60 : 600)
        reminders[index].deliveredAt = nil
    }
    func meetingQuietUntil(now: Date) -> Date? {
        guard microsoft.enabled, microsoft.quietDuringMeetings else { return nil }
        return reminders.filter { $0.kind == .meeting && ($0.meetingStart ?? .distantFuture) <= now && ($0.expiresAt ?? .distantPast) > now }
            .compactMap(\.expiresAt).max()
    }
}

struct WorkspacePersistence {
    static let defaultURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DeskBuddy/workspace.json")
    let url: URL
    init(url: URL = defaultURL) { self.url = url }
    func load() throws -> WorkspaceData {
        guard FileManager.default.fileExists(atPath: url.path) else { return WorkspaceData() }
        return try JSONDecoder().decode(WorkspaceData.self, from: Data(contentsOf: url))
    }
    func save(_ value: WorkspaceData) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
