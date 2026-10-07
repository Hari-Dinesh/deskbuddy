import Foundation

@main struct SceneTests {
    static func main() {
        var count = 0
        func check(_ value: Bool, _ message: String) {
            precondition(value, message); count += 1; print("PASS \(message)")
        }
        check(CompanionPhase.entering.next(water: true) == .drinking, "Water entry leads to drinking")
        check(CompanionPhase.entering.next(water: false) == .waiting, "Meal entry skips drinking")
        check(CompanionPhase.drinking.next(water: true) == .waiting, "Drinking settles into response wait")
        check(CompanionPhase.celebrating.next(water: true) == .runningRight, "Yes exits right")
        check(CompanionPhase.reacting.next(water: true) == .leavingLeft, "Not yet exits left")
        check(!CompanionPhase.entering.interactive && !CompanionPhase.runningRight.interactive, "Travel cannot receive answers")
        check(CompanionPhase.waiting.interactive && CompanionPhase.drinking.interactive, "Waiting and drinking allow answers")
        check(CompanionPhase.idle.duration == 0 && CompanionPhase.waiting.duration == 0, "Idle and waiting need no animation timer")
        check(CompanionPhase.runningRight.duration < CompanionPhase.leavingLeft.duration, "Confirmed break runs faster")
        check(CompanionPhase.entering.sprite(elapsed: 0, water: true) == 0 && CompanionPhase.entering.sprite(elapsed: 0.15, water: true) == 1, "Walking advances poses")
        check(CompanionPhase.drinking.sprite(elapsed: 0, water: true) == 4 && CompanionPhase.drinking.sprite(elapsed: 0.65, water: true) == 5, "Drinking alternates glass poses")
        check(CompanionPhase.celebrating.sprite(elapsed: 0, water: true) == 6 && CompanionPhase.reacting.sprite(elapsed: 0, water: true) == 7, "Answer chooses matching reaction")
        for phase in [CompanionPhase.entering, .drinking, .waiting, .celebrating, .reacting, .runningRight, .leavingLeft] {
            for time in [0.0, 0.08, 0.14, 1.1, 2.4, 100] {
                if let sprite = phase.sprite(elapsed: time, water: true) { check((0..<8).contains(sprite), "Sprite index in atlas bounds") }
            }
        }
        print("\(count) scene checks passed")
    }
}
