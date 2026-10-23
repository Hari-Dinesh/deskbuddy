import Foundation

@main struct WorkspaceTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("deskbuddy-workspace-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let persistence = WorkspacePersistence(url: root.appendingPathComponent("workspace.json"))
        var data = try persistence.load()
        precondition(data.notes.isEmpty && data.reminders.isEmpty && !data.microsoft.enabled)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let quick = ScheduledReminder(title: "Call back", dueAt: now.addingTimeInterval(-3600))
        data.notes.append(QuickNote(text: "A local note")); data.reminders.append(quick)
        try persistence.save(data)
        let restored = try persistence.load()
        precondition(restored.notes[0].text == "A local note" && restored.reminders[0].id == quick.id)
        precondition(data.nextDue(now: now)?.id == quick.id, "Overdue quick reminders survive idle/sleep")
        data.delivered(quick.id, at: now)
        precondition(data.nextDue(now: now) == nil, "No duplicate while an alert is delivered")
        precondition(data.nextDue(now: now.addingTimeInterval(601))?.id == quick.id)
        data.snooze(quick.id, at: now)
        precondition(data.nextDue(now: now.addingTimeInterval(599)) == nil)
        precondition(data.nextDue(now: now.addingTimeInterval(600))?.id == quick.id)
        data.complete(quick.id, at: now)
        precondition(data.nextDue(now: now.addingTimeInterval(3600)) == nil)
        print("PASS local persistence, overdue recovery, duplicate suppression, snooze and completion")

        let meeting = CalendarMeeting(id: "event", title: "Standup", start: now.addingTimeInterval(300), end: now.addingTimeInterval(1800), joinURL: nil)
        data.microsoft.enabled = true
        data.mergeMeetings([meeting], now: now)
        let original = data.reminders.first { $0.kind == .meeting }!
        precondition(data.nextDue(now: now)?.id == original.id)
        data.complete(original.id, at: now)
        data.mergeMeetings([meeting], now: now)
        precondition(data.reminders.first { $0.kind == .meeting }!.completedAt == now, "Sync preserves dismissed occurrence")
        let moved = CalendarMeeting(id: "event", title: "Moved standup", start: now.addingTimeInterval(900), end: now.addingTimeInterval(2400), joinURL: nil)
        data.mergeMeetings([moved], now: now)
        precondition(data.reminders.first { $0.kind == .meeting }!.completedAt == nil, "Rescheduled occurrence can notify again")
        precondition(data.meetingQuietUntil(now: now) == nil)
        precondition(data.meetingQuietUntil(now: now.addingTimeInterval(1000)) == moved.end)
        data.microsoft.enabled = false
        precondition(data.meetingQuietUntil(now: now.addingTimeInterval(1000)) == nil)
        precondition(data.nextDue(now: now.addingTimeInterval(1000)) == nil)
        data.mergeMeetings([], now: now)
        precondition(data.reminders.allSatisfy { $0.kind != .meeting }, "Cancelled or removed meetings are removed on successful full sync")
        precondition(data.reminders.contains { $0.id == quick.id }, "Sync never removes local reminders")
        print("PASS calendar merge, reschedule, cancellation, quiet windows and disconnect gating")

        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(data)) as! [String: Any]
        object.removeValue(forKey: "schemaVersion"); object.removeValue(forKey: "microsoft")
        let legacyWorkspace = try JSONDecoder().decode(WorkspaceData.self, from: JSONSerialization.data(withJSONObject: object))
        precondition(legacyWorkspace.notes.count == 1 && legacyWorkspace.notes[0].text == "A local note")
        object["schemaVersion"] = 99
        do { _ = try JSONDecoder().decode(WorkspaceData.self, from: JSONSerialization.data(withJSONObject: object)); preconditionFailure("Future schema must be preserved, not downgraded") } catch { }
        print("PASS legacy workspace defaults and future-schema protection")
        try Data("not JSON".utf8).write(to: persistence.url)
        do { _ = try persistence.load(); preconditionFailure("Corruption should be surfaced") } catch { }
        let retained = try Data(contentsOf: persistence.url)
        precondition(retained == Data("not JSON".utf8))
        print("PASS corrupt storage preserved for recovery")
    }
}
