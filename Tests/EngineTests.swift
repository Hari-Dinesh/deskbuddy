import Foundation

@main struct Tests {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        func date(_ hour: Int, _ minute: Int = 0, day: Int = 5) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
        }
        var checks = 0
        func check(_ value: Bool, _ label: String) { precondition(value, label); checks += 1; print("PASS \(label)") }
        var p = Preferences(); p.mealsEnabled = false; p.waterMinutes = 5
        var e = ReminderEngine()
        let now = date(10)
        check(e.tick(now: now, elapsed: 3600, active: false, preferences: p) == nil && e.activeSeconds == 0, "Sleep / idle adds no active time")
        for i in 0..<19 { _ = e.tick(now: now.addingTimeInterval(Double(i * 15)), elapsed: 15, active: true, preferences: p) }
        check(e.activeSeconds == 285, "Water uses accumulated active time")
        check(e.tick(now: now.addingTimeInterval(285), elapsed: 15, active: true, preferences: p) == .water, "Water becomes due at configured interval")
        e.snooze(.water, now: now.addingTimeInterval(285))
        check(e.tick(now: now.addingTimeInterval(600), elapsed: 5, active: true, preferences: p) == nil, "Snooze suppresses water")
        check(e.tick(now: now.addingTimeInterval(900), elapsed: 5, active: true, preferences: p) == .water, "Snoozed water returns")
        e.done(.water, now: now.addingTimeInterval(900))
        check(e.activeSeconds == 0 && e.waterCount == 1, "Done records water and resets timer")
        var meal = ReminderEngine(); p.mealsEnabled = true
        check(meal.tick(now: date(9), elapsed: 0, active: true, preferences: p) == .breakfast, "Breakfast starts at scheduled time")
        check(meal.tick(now: date(9), elapsed: 0, active: true, preferences: p) == nil, "Single reminder pacing")
        meal.snooze(.breakfast, now: date(9))
        check(meal.tick(now: date(9, 5), elapsed: 0, active: true, preferences: p) == nil, "Meal snooze honored")
        check(meal.tick(now: date(9, 10), elapsed: 0, active: true, preferences: p) == .breakfast, "Meal snooze expires")
        meal.done(.breakfast, now: date(9, 10))
        check(meal.tick(now: date(9, 20), elapsed: 0, active: true, preferences: p) == nil, "Completed meal stays completed")
        check(meal.tick(now: date(13), elapsed: 0, active: false, preferences: p) == nil, "Meal deferred while inactive")
        check(meal.tick(now: date(13, 5), elapsed: 0, active: true, preferences: p) == .lunch, "Meal offered on return")
        var stale = ReminderEngine()
        check(stale.tick(now: date(16), elapsed: 0, active: true, preferences: p) == nil, "Expired meals never become backlog")
        stale.rollDay(date(10)); stale.completed = [.breakfast]; stale.waterCount = 3
        stale.rollDay(date(10, day: 6))
        check(stale.completed.isEmpty && stale.waterCount == 0, "Daily completion resets")
        var gap = ReminderEngine(); _ = gap.tick(now: now, elapsed: 3600, active: true, preferences: p)
        check(gap.activeSeconds == 15, "Clock gaps capped so sleep never adds hours")
        let data = try JSONEncoder().encode(e)
        let saved = try JSONDecoder().decode(ReminderEngine.self, from: data)
        check(saved.waterCount == 1 && saved.activeSeconds == 0, "State survives encoding")
        print("\(checks) checks passed")
    }
}
