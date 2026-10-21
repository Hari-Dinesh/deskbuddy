import Foundation

/// Generic boundary for opt-in calendar / meeting providers. Microsoft transport is implemented in MicrosoftCalendar.swift.
struct IntegrationEvent: Equatable, Sendable {
    let providerID: String
    let externalID: String
    let start: Date
    let end: Date
}

protocol ReminderIntegration: Sendable {
    var id: String { get }
    func events(from start: Date, to end: Date) async throws -> [IntegrationEvent]
    func disconnect() async throws
}

enum IntegrationPolicy {
    /// Only enabled providers can request quiet time; malformed events are ignored.
    static func quietUntil(now: Date, events: [IntegrationEvent], enabledProviders: Set<String>) -> Date? {
        events.filter { enabledProviders.contains($0.providerID) && $0.start <= now && $0.end > now && $0.end > $0.start }
            .map(\.end).max()
    }
}
