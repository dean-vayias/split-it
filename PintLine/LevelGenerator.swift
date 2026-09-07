import Foundation

/// Levels are cheap to manufacture: venue + band position + drain speed + BAC.
/// All randomness is seeded so a given level is identical on every launch.
enum LevelGenerator {

    /// One speed everywhere. Players build a single piece of muscle memory;
    /// modes differ through targets, scoring, venues, and visual conditions.
    static let universalDrainSpeed = 160.0

    static func dailyKey(for date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Deterministic pseudo-random Double in 0..<1 from a string seed (FNV-1a).
    static func unit(seed: String) -> Double {
        var hash: UInt64 = 1469598103934665603
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        // a couple of xorshift rounds for good measure
        hash ^= hash << 13
        hash ^= hash >> 7
        hash ^= hash << 17
        return Double(hash % 1_000_000) / 1_000_000.0
    }

    static func levels(for venue: VenueID) -> [LevelDefinition] {
        let config = venue.config
        let count = config.levelCount
        let range = config.bacRange
        return (0..<count).map { i in
            let t = Double(i) / Double(count - 1)
            let eased = t * t * (3 - 2 * t) // smoothstep: gentle start, firm finish
            let bac = range.lowerBound + (range.upperBound - range.lowerBound) * eased
            let band = 0.38 + 0.30 * unit(seed: "band-\(venue.rawValue)-\(i)")
            return LevelDefinition(venue: venue, index: i, bac: bac,
                                   bandFraction: band, drainSpeed: universalDrainSpeed,
                                   hangover: false)
        }
    }

    static func endless(venue: VenueID, bac: Double, night: Int, seed: Int,
                        hangover: Bool) -> LevelDefinition {
        let s = "endless-\(night)-\(seed)"
        let band = 0.36 + 0.32 * unit(seed: s + "-band")
        return LevelDefinition(venue: venue, index: seed, bac: bac,
                               bandFraction: band, drainSpeed: universalDrainSpeed,
                               hangover: hangover)
    }

    /// The same authored challenge for everyone on a given local calendar day.
    static func daily(for date: Date = Date()) -> LevelDefinition {
        let key = dailyKey(for: date)
        let venues = VenueID.allCases.filter { $0 != .hangover }
        let venueUnit = unit(seed: "daily-\(key)-venue")
        let venue = venues[Int(venueUnit * Double(venues.count)) % venues.count]
        let band = 0.38 + 0.28 * unit(seed: "daily-\(key)-band")
        let index = Int(unit(seed: "daily-\(key)-index") * 10_000)
        return LevelDefinition(venue: venue, index: index, bac: 0.12,
                               bandFraction: band, drainSpeed: universalDrainSpeed,
                               hangover: false)
    }

    /// One shared venue, BAC, and target for every player and all five pours.
    static func dailyFive(day: String = LeaderboardService.utcDayKey()) -> LevelDefinition {
        let venues = VenueID.allCases.filter { $0 != .hangover }
        let venue = venues[Int(unit(seed: "daily-five-\(day)-venue") * Double(venues.count))
                           % venues.count]
        let band = 0.36 + 0.32 * unit(seed: "daily-five-\(day)-band")
        // One shared condition of the day, held constant across all five
        // pours. The glass stays crisp; BAC only changes the room and motion.
        let dailyBAC = [0.07, 0.10, 0.13, 0.16]
        let bac = dailyBAC[Int(unit(seed: "daily-five-\(day)-bac") * Double(dailyBAC.count))
                           % dailyBAC.count]
        let index = Int(unit(seed: "daily-five-\(day)-id") * 1_000_000)
        return LevelDefinition(venue: venue, index: index, bac: bac,
                               bandFraction: band, drainSpeed: universalDrainSpeed,
                               hangover: false)
    }
}
