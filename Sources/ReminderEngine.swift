import Foundation

enum ReminderKind: String, Codable, CaseIterable {
    case water, breakfast, lunch, dinner
    var title: String { rawValue.capitalized }
    var symbol: String { self == .water ? "drop.fill" : "fork.knife" }
    var message: String {
        switch self {
        case .water: return "Time for a water break."
        case .breakfast: return "Take a moment for breakfast."
        case .lunch: return "Step away and enjoy lunch."
        case .dinner: return "Wrap up for a dinner break."
        }
    }
}

struct Preferences: Codable {
    var waterMinutes = 45
    var idleMinutes = 5
    var breakfast = 9 * 60
    var lunch = 13 * 60
    var dinner = 20 * 60
    var mealsEnabled = true
    var sound = false
    var name = "My buddy"
    var photo: Data? = nil
    func time(for kind: ReminderKind) -> Int {
        switch kind { case .breakfast: return breakfast; case .lunch: return lunch; case .dinner: return dinner; case .water: return 0 }
    }
}

struct ReminderEngine: Codable {
    var activeSeconds: Double = 0
    var day = ""
    var completed: Set<ReminderKind> = []
    var snoozes: [ReminderKind: Date] = [:]
    var waterCount = 0
    var lastPresented: Date? = nil

    mutating func rollDay(_ now: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        let key = "\(c.year!)-\(c.month!)-\(c.day!)"
        if day != key { day = key; completed = []; snoozes = [:]; waterCount = 0 }
    }
    mutating func tick(now: Date, elapsed: Double, active: Bool, preferences: Preferences, calendar: Calendar = .current) -> ReminderKind? {
        rollDay(now, calendar: calendar)
        guard active else { return nil }
        activeSeconds += max(0, min(elapsed, 15))
        if let lastPresented, now.timeIntervalSince(lastPresented) < 60 { return nil }
        let c = calendar.dateComponents([.hour, .minute], from: now)
        let minute = c.hour! * 60 + c.minute!
        if preferences.mealsEnabled {
            for kind in [ReminderKind.breakfast, .lunch, .dinner] {
                let scheduled = preferences.time(for: kind)
                // Only offer a meal within its two-hour window; never dump stale meals after wake.
                if minute >= scheduled && minute < min(scheduled + 120, 1440) && !completed.contains(kind) && (snoozes[kind] ?? .distantPast) <= now {
                    lastPresented = now
                    return kind
                }
            }
        }
        if activeSeconds >= Double(preferences.waterMinutes * 60) && (snoozes[.water] ?? .distantPast) <= now {
            lastPresented = now
            return .water
        }
        return nil
    }
    mutating func done(_ kind: ReminderKind, now: Date) {
        rollDay(now)
        if kind == .water { activeSeconds = 0; waterCount += 1 } else { completed.insert(kind) }
        snoozes.removeValue(forKey: kind)
        lastPresented = now
    }
    mutating func snooze(_ kind: ReminderKind, now: Date) {
        snoozes[kind] = now.addingTimeInterval(600)
        lastPresented = now
    }
}
