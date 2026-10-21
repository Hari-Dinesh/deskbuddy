import SwiftUI
import AppKit

struct WorkspaceView: View {
    @ObservedObject var model: WorkspaceModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your work, close at hand.").font(.title2.bold())
            TabView(selection: $model.selectedTab) {
                QuickNotesView(model: model).tabItem { Label("Quick notes", systemImage: "note.text") }.tag(0)
                QuickRemindersView(model: model).tabItem { Label("Reminders", systemImage: "bell") }.tag(1)
                MicrosoftCalendarView(model: model).tabItem { Label("Calendar / Teams", systemImage: "calendar") }.tag(2)
            }
            if !model.confirmation.isEmpty && model.error.isEmpty { Text(model.confirmation).font(.caption).foregroundStyle(.secondary) }
            if !model.error.isEmpty { Text(model.error).font(.callout).foregroundStyle(.orange).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
            Text("Notes and quick reminders stay on this Mac. Only the calendar tab contacts Microsoft when connected.").font(.caption).foregroundStyle(.secondary)
        }.padding(22).frame(minWidth: 650, minHeight: 610)
    }
}

struct QuickNotesView: View {
    @ObservedObject var model: WorkspaceModel
    @State private var selected: UUID?
    @State private var draft = ""
    private var edited: Bool { draft != (model.data.notes.first(where: { $0.id == selected })?.text ?? "") }
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading) {
                Button("New note", systemImage: "plus") { selected = nil; draft = "" }.disabled(edited)
                List(model.data.notes.sorted { $0.updatedAt > $1.updatedAt }) { note in
                    Button { selected = note.id; draft = note.text } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(note.text.prefix(60))).lineLimit(2)
                            Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                    }.buttonStyle(.plain).disabled(edited)
                }
            }.frame(width: 210)
            VStack(alignment: .leading, spacing: 10) {
                Text(selected == nil ? "New note" : "Edit note").font(.headline)
                TextEditor(text: $draft).font(.body).padding(6).overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                HStack {
                    Button("Save note") { if model.saveNote(id: selected, text: draft) { if selected == nil { selected = model.data.notes.first?.id }; draft = model.data.notes.first(where: { $0.id == selected })?.text ?? draft } }.keyboardShortcut("s", modifiers: .command)
                    Button("Discard changes") { draft = model.data.notes.first(where: { $0.id == selected })?.text ?? "" }.disabled(!edited)
                    Button("Remind in 10 min") { _ = model.addReminder(title: String(draft.prefix(300)), date: Date().addingTimeInterval(600)) }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Spacer()
                    if let selected { Button("Delete", role: .destructive) { model.deleteNote(selected); self.selected = nil; draft = "" } }
                }
                Text(edited ? "Unsaved changes · save or discard before switching notes" : "Saved locally").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(14)
    }
}

struct QuickRemindersView: View {
    @ObservedObject var model: WorkspaceModel
    @State private var title = ""
    @State private var due = Date().addingTimeInterval(600)
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("What should I remind you about?", text: $title).textFieldStyle(.roundedBorder)
            HStack {
                DatePicker("When", selection: $due, displayedComponents: [.date, .hourAndMinute])
                Button("In 5 min") { due = Date().addingTimeInterval(300) }
                Button("In 30 min") { due = Date().addingTimeInterval(1800) }
                Button("Add") { if model.addReminder(title: title, date: due) { title = ""; due = Date().addingTimeInterval(600) } }.buttonStyle(.borderedProminent).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            List {
                ForEach(model.data.reminders.filter { $0.kind == .quick }.sorted { $0.dueAt < $1.dueAt }) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).strikethrough(item.completedAt != nil)
                            Text(item.dueAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if item.completedAt == nil { Button("Done") { model.complete(item.id) } }
                        Button("Delete", role: .destructive) { model.deleteReminder(item.id) }
                    }.padding(.vertical, 4)
                }
            }
            Text("Due reminders appear through your avatar while DeskBuddy is running. Overdue quick reminders return after wake; Quiet for one hour defers them.").font(.caption).foregroundStyle(.secondary)
        }.padding(14)
    }
}

struct MicrosoftCalendarView: View {
    @ObservedObject var model: WorkspaceModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Microsoft 365 calendar & Teams meetings").font(.headline)
                Text("Read upcoming calendar events, show reminders before meetings and open their Teams or Outlook link. No chat or calendar writes.").foregroundStyle(.secondary)
                TextField("Application (client) ID", text: $model.data.microsoft.clientID).textFieldStyle(.roundedBorder).disabled(model.data.microsoft.enabled || model.isConnecting)
                TextField("Tenant ID, organizations, or common", text: $model.data.microsoft.tenant).textFieldStyle(.roundedBorder).disabled(model.data.microsoft.enabled || model.isConnecting)
                Text("An Entra public-client app registration is required. Enable device-code/public-client sign-in and delegated Calendars.ReadBasic permission. Your organization may require administrator approval.").font(.caption).foregroundStyle(.secondary)
                Link("Setup guide", destination: URL(string: "https://github.com/Hari-Dinesh/deskbuddy/blob/main/docs/INTEGRATIONS.md")!)
                HStack {
                    if model.isConnecting { Button("Cancel sign-in") { model.cancelSignIn() } }
                    else if model.data.microsoft.enabled {
                        Button("Sync now") { model.sync(force: true) }.disabled(model.isSyncing)
                        Button("Disconnect") { model.disconnect() }
                    } else {
                        Button("Connect Microsoft calendar") { model.connect() }.disabled(!model.data.microsoft.valid)
                    }
                    if model.isConnecting || model.isSyncing { ProgressView().controlSize(.small) }
                }
                Text(model.calendarStatus).font(.callout).textSelection(.enabled)
                if !model.signInCode.isEmpty {
                    HStack {
                        Text(model.signInCode).font(.title.monospaced().bold()).textSelection(.enabled)
                        Button("Copy code") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.signInCode, forType: .string) }
                        Link("Open Microsoft sign-in", destination: URL(string: "https://microsoft.com/devicelogin")!)
                    }
                    Text("Enter this code only on Microsoft's sign-in page, then return here. DeskBuddy will finish connecting automatically.").font(.caption)
                }
                Stepper("Remind \(model.data.microsoft.leadMinutes) minutes before meetings", value: $model.data.microsoft.leadMinutes, in: 1...30)
                    .onChange(of: model.data.microsoft.leadMinutes) { _ in model.updateLeadMinutes() }
                Toggle("Pause water and meal prompts during scheduled meetings", isOn: $model.data.microsoft.quietDuringMeetings).onChange(of: model.data.microsoft.quietDuringMeetings) { _ in _ = model.save() }
                if let last = model.lastSync { Text("Last synced \(last.formatted(date: .abbreviated, time: .shortened)) · times shown locally").font(.caption).foregroundStyle(.secondary) }
                Divider()
                Text("Upcoming · next 24 hours").font(.headline)
                ForEach(model.data.reminders.filter { $0.kind == .meeting && ($0.expiresAt ?? .distantPast) > Date() }.sorted { $0.dueAt < $1.dueAt }) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                            if let start = item.meetingStart { Text(start.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if item.joinURL != nil { Button("Open meeting") { model.open(item.joinURL) } }
                    }.padding(.vertical, 4)
                }
                Text("Calendar sync runs about once a minute while awake. Offline data is labeled as cached; scheduled meetings do not prove that you are in a live Teams call. Disconnect removes local tokens and cached meetings; Microsoft consent can be revoked in your account settings.").font(.caption).foregroundStyle(.secondary)
            }.padding(14)
        }
    }
}
