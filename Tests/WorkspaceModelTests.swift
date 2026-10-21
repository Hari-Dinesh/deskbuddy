import Foundation

@main struct WorkspaceModelTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("deskbuddy-note-model-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let persistence = WorkspacePersistence(url: root.appendingPathComponent("workspace.json"))
        let model = WorkspaceModel(persistence: persistence)
        precondition(!model.saveNote(id: nil, text: "  "))
        precondition(model.saveNote(id: nil, text: "First note"))
        let note = model.data.notes[0]
        precondition(model.saveNote(id: note.id, text: "Edited note"))
        let restored = try persistence.load()
        precondition(restored.notes.count == 1 && restored.notes[0].text == "Edited note")
        precondition(!model.addReminder(title: "past", date: .distantPast))
        precondition(model.addReminder(title: "Call", date: Date().addingTimeInterval(60)))
        let id = model.data.reminders[0].id
        model.snooze(id)
        precondition(model.data.reminders[0].dueAt > Date().addingTimeInterval(590))
        model.complete(id)
        precondition(model.data.reminders[0].completedAt != nil)
        model.deleteReminder(id); model.deleteNote(note.id)
        precondition(model.data.notes.isEmpty && model.data.reminders.isEmpty)
        try Data("broken".utf8).write(to: persistence.url)
        let corrupt = WorkspaceModel(persistence: persistence)
        precondition(!corrupt.error.isEmpty && !corrupt.saveNote(id: nil, text: "Must not overwrite"))
        let retained = try Data(contentsOf: persistence.url)
        precondition(retained == Data("broken".utf8))
        print("PASS note CRUD, quick-reminder validation/actions and corrupt-file write protection")
    }
}
