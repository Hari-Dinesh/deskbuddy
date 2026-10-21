import AppKit
import SwiftUI

final class WorkspaceModel: ObservableObject {
    @Published var data: WorkspaceData
    @Published var error = ""
    @Published var confirmation = ""
    @Published var selectedTab = 0
    @Published var calendarStatus = "Not connected"
    @Published var isConnecting = false
    @Published var isSyncing = false
    @Published var signInCode = ""
    @Published var lastSync: Date?
    private let persistence: WorkspacePersistence
    private var writable = true
    private var authTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private var connectionID = UUID()
    private var nextSync = Date.distantPast
    private var retryNotBefore = Date.distantPast
    private let client = MicrosoftCalendarClient()

    init(persistence: WorkspacePersistence = WorkspacePersistence()) {
        self.persistence = persistence
        do { data = try persistence.load() }
        catch { data = WorkspaceData(); writable = false; self.error = "Saved notes could not be read. The original file was preserved. Restore workspace.json from backup before saving new content." }
        if data.microsoft.enabled { calendarStatus = "Saved connection · waiting to sync" }
    }
    @discardableResult func save() -> Bool {
        guard writable else { return false }
        do { try persistence.save(data); return true }
        catch { self.error = "Could not save: \(error.localizedDescription)"; return false }
    }
    func saveNote(id: UUID?, text: String) -> Bool {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, content.count <= 50_000 else { error = "Enter a note between 1 and 50,000 characters."; return false }
        let previous = data
        if let id, let index = data.notes.firstIndex(where: { $0.id == id }) { data.notes[index].text = content; data.notes[index].updatedAt = Date() }
        else { data.notes.insert(QuickNote(text: content), at: 0) }
        guard save() else { data = previous; return false }
        error = ""; confirmation = "Note saved"; return true
    }
    func deleteNote(_ id: UUID) { let previous = data; data.notes.removeAll { $0.id == id }; if !save() { data = previous } }
    func addReminder(title: String, date: Date) -> Bool {
        let content = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, content.count <= 300, date > Date() else { error = "Enter a reminder (up to 300 characters) and choose a future time."; return false }
        let previous = data
        data.reminders.append(ScheduledReminder(title: content, dueAt: date))
        guard save() else { data = previous; return false }
        error = ""; confirmation = "Reminder set for " + date.formatted(date: .abbreviated, time: .shortened); return true
    }
    @discardableResult func complete(_ id: UUID) -> Bool {
        let previous = data; data.complete(id, at: Date())
        guard save() else { data = previous; return false }; return true
    }
    @discardableResult func snooze(_ id: UUID) -> Bool {
        let previous = data; data.snooze(id, at: Date())
        guard save() else { data = previous; return false }; return true
    }
    func deleteReminder(_ id: UUID) { let previous = data; data.reminders.removeAll { $0.id == id }; if !save() { data = previous } }
    func markDelivered(_ id: UUID) { data.delivered(id, at: Date()); _ = save() }
    func open(_ url: URL?) { if let url = GraphCalendarPage.safeLink(url?.absoluteString) { NSWorkspace.shared.open(url) } }
    func connect() {
        guard !isConnecting, !data.microsoft.enabled else { return }
        let settings = data.microsoft
        guard writable, settings.valid else { error = "Enter a valid Microsoft client ID and tenant before connecting."; return }
        connectionID = UUID(); let generation = connectionID
        retryNotBefore = .distantPast
        error = ""; isConnecting = true; calendarStatus = "Requesting Microsoft sign-in code…"
        authTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let code = try await client.startSignIn(settings)
                guard connectionID == generation else { return }
                signInCode = code.user_code
                calendarStatus = "Open microsoft.com/devicelogin and enter this code."
                let tokens = try await client.finishSignIn(settings, code: code)
                try Task.checkCancellation()
                guard connectionID == generation else { return }
                try MicrosoftKeychain.save(tokens, account: settings.credentialAccount)
                data.microsoft.enabled = true
                if !save() { data.microsoft.enabled = false; try? MicrosoftKeychain.remove(account: settings.credentialAccount); throw MicrosoftFailure.message("Connection was not saved. Check local storage permissions.") }
                calendarStatus = "Connected · syncing calendar…"
                signInCode = ""; isConnecting = false
                sync(force: true)
            } catch {
                guard connectionID == generation else { return }
                signInCode = ""; isConnecting = false
                if error is CancellationError { calendarStatus = "Sign-in cancelled" }
                else { calendarStatus = "Not connected"; self.error = error.localizedDescription }
            }
        }
    }
    func cancelSignIn() {
        connectionID = UUID(); authTask?.cancel(); authTask = nil
        isConnecting = false; signInCode = ""; calendarStatus = "Not connected"
    }
    func disconnect() {
        connectionID = UUID(); authTask?.cancel(); syncTask?.cancel()
        isConnecting = false; isSyncing = false; signInCode = ""
        do { try MicrosoftKeychain.remove(account: data.microsoft.credentialAccount) }
        catch { self.error = error.localizedDescription; return }
        data.microsoft.enabled = false; retryNotBefore = .distantPast
        data.reminders.removeAll { $0.kind == .meeting }
        _ = save(); calendarStatus = "Disconnected · local Microsoft tokens removed"; lastSync = nil
    }
    func sync(force: Bool = false) {
        guard data.microsoft.enabled, !isSyncing, !isConnecting, Date() >= retryNotBefore, force || Date() >= nextSync else { return }
        let generation = connectionID
        let settings = data.microsoft
        isSyncing = true; nextSync = Date().addingTimeInterval(60)
        syncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard var tokens = try MicrosoftKeychain.load(account: settings.credentialAccount) else { throw MicrosoftFailure.signedOut }
                if tokens.expiresAt < Date().addingTimeInterval(120) {
                    tokens = try await client.refresh(settings, tokens: tokens)
                    try Task.checkCancellation()
                    guard connectionID == generation else { return }
                    try MicrosoftKeychain.save(tokens, account: settings.credentialAccount)
                }
                let now = Date()
                let meetings = try await client.meetings(token: tokens.accessToken, from: now.addingTimeInterval(-6 * 3600), to: now.addingTimeInterval(24 * 3600))
                try Task.checkCancellation()
                guard connectionID == generation else { return }
                let previous = data
                data.mergeMeetings(meetings, now: now)
                if !save() { data = previous; throw MicrosoftFailure.message("Calendar fetched but could not be saved.") }
                lastSync = now; calendarStatus = "Connected · calendar updated"; error = ""
            } catch {
                guard connectionID == generation else { return }
                if case MicrosoftFailure.signedOut = error {
                    try? MicrosoftKeychain.remove(account: settings.credentialAccount)
                    data.microsoft.enabled = false
                    data.reminders.removeAll { $0.kind == .meeting }
                    _ = save()
                    calendarStatus = "Sign-in required · cached meetings cleared"
                } else if case MicrosoftFailure.rateLimited(let delay) = error {
                    nextSync = Date().addingTimeInterval(delay); retryNotBefore = nextSync
                    calendarStatus = "Rate limited · will retry automatically"
                } else if !(error is CancellationError) {
                    nextSync = Date().addingTimeInterval(300)
                    calendarStatus = "Sync unavailable · showing cached calendar"
                }
                if !(error is CancellationError) { self.error = error.localizedDescription }
            }
            if connectionID == generation { isSyncing = false }
        }
    }
    func updateLeadMinutes() {
        data.microsoft.leadMinutes = min(30, max(1, data.microsoft.leadMinutes))
        _ = save(); if data.microsoft.enabled { sync(force: true) }
    }
}
