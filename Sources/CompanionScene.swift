import Foundation

enum CompanionPhase: Equatable {
    case idle, entering, drinking, waiting, celebrating, reacting, runningRight, leavingLeft
    var moving: Bool { self == .entering || self == .runningRight || self == .leavingLeft }
    var departing: Bool { self == .runningRight || self == .leavingLeft }
    var interactive: Bool { self == .waiting || self == .drinking }
    var duration: Double {
        switch self {
        case .entering: return 2.6
        case .drinking: return 2.4
        case .celebrating, .reacting: return 1.0
        case .runningRight: return 1.35
        case .leavingLeft: return 2.6
        case .idle, .waiting: return 0
        }
    }
    static func easedProgress(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }
    func next(water: Bool) -> CompanionPhase {
        switch self {
        case .entering: return water ? .drinking : .waiting
        case .drinking: return .waiting
        case .celebrating: return .runningRight
        case .reacting: return .leavingLeft
        default: return .idle
        }
    }
    func sprite(elapsed: Double, water: Bool) -> Int? {
        switch self {
        case .idle: return nil
        case .entering, .leavingLeft: return Int(max(0, elapsed) / 0.14) % 4
        case .runningRight: return Int(max(0, elapsed) / 0.08) % 4
        case .drinking: return Int(max(0, elapsed) / 0.6) % 2 + 4
        case .waiting: return water ? 4 : nil
        case .celebrating: return 6
        case .reacting: return 7
        }
    }
}
