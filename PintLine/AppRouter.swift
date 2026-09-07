import SwiftUI

enum Screen: Hashable {
    case home
    case venue(VenueID)
    case level(VenueID, Int)
    case endless
    case daily
    case settings
    case stats
    case leaderboard
}

@Observable
final class AppRouter {
    var screen: Screen = .home
    let endless = EndlessEngine()

    init() {
        #if DEBUG
        // Test hook: `-screen home|endless|level:<venue>:<index>`
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-screen"), i + 1 < args.count {
            let value = args[i + 1]
            switch value {
            case "home": screen = .home
            case "endless": screen = .endless
            case "daily": screen = .daily
            case "settings": screen = .settings
            case "stats": screen = .stats
            case "leaderboard": screen = .leaderboard
            case let s where s.hasPrefix("level:"):
                let parts = s.split(separator: ":")
                if parts.count == 3,
                   let venue = VenueID(rawValue: String(parts[1])),
                   let index = Int(parts[2]) {
                    screen = .level(venue, index)
                }
            default: break
            }
        }
        #endif
    }
}

/// Session-only count of consecutive successful splits in the current run.
@Observable
final class SessionStats {
    static let shared = SessionStats()
    var streak = 0

    func apply(_ result: PourResult) {
        streak = result.stars > 0 ? streak + 1 : 0
    }

    func reset() {
        streak = 0
    }
}
