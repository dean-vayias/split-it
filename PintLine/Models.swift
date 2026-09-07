import SwiftUI

// MARK: - Theme

enum Theme {
    static let cream = Color(red: 0.96, green: 0.93, blue: 0.87)
    static let stout = Color(red: 0.13, green: 0.07, blue: 0.04)
    static let stoutLight = Color(red: 0.24, green: 0.13, blue: 0.07)
    static let foam = Color(red: 0.95, green: 0.88, blue: 0.72)
    static let foamShadow = Color(red: 0.82, green: 0.72, blue: 0.52)
    static let wood = Color(red: 0.35, green: 0.25, blue: 0.18)
    static let amber = Color(red: 0.92, green: 0.63, blue: 0.29)
    static let ink = Color(red: 0.16, green: 0.11, blue: 0.08)
}

// MARK: - Venues

/// Identity only. Everything about a venue — name, art palette, glass skin,
/// twist mechanic, ambience, BAC range, seasonal reskin — lives in the
/// data-driven `VenueRegistry`.
enum VenueID: String, Codable, CaseIterable, Identifiable {
    case pub, shower, dinner
    case beach, rooftop, karaoke, tailgate, wedding
    case football, baseball, soccer
    case campfire, hangover

    var id: String { rawValue }

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    var config: VenueConfig { VenueRegistry.config(for: self) }
}

// MARK: - Levels

struct LevelDefinition: Identifiable {
    let venue: VenueID
    let index: Int           // 0-based within venue (story) or seed (endless)
    let bac: Double
    let bandFraction: Double // 0 = top of glass, 1 = bottom
    let drainSpeed: Double   // logical points per second
    let hangover: Bool

    var id: String { "\(venue.rawValue)-\(index)-\(hangover ? "hg" : "st")" }

    init(venue: VenueID, index: Int, bac: Double, bandFraction: Double,
         drainSpeed: Double, hangover: Bool) {
        self.venue = venue
        self.index = index
        self.bac = bac
        self.bandFraction = bandFraction
        self.drainSpeed = drainSpeed
        self.hangover = hangover
    }
}

struct Tolerances {
    var oneStar: Double
    var twoStar: Double
    var threeStar: Double
    var perfect: Double

    static let base = Tolerances(oneStar: 15, twoStar: 8, threeStar: 3, perfect: 2)
    /// Main-run tuning: a readable starting band that tightens to roughly
    /// +/-9.4pt at maximum buzz without becoming a hidden pixel hunt.
    static let nightOut = Tolerances(oneStar: 13, twoStar: 7, threeStar: 3, perfect: 1.5)

    func scaled(_ f: Double) -> Tolerances {
        Tolerances(oneStar: oneStar * f, twoStar: twoStar * f,
                   threeStar: threeStar * f, perfect: perfect * f)
    }

    static func nightOut(at bac: Double) -> Tolerances {
        let progress = clamp01(bac / 0.35)
        return nightOut.scaled(max(0.72, 1 - 0.28 * progress))
    }
}

enum DailyFiveScoring {
    static let attemptCount = 5
    static let maximumPoints = 25
    static let tolerances = Tolerances(oneStar: 40, twoStar: 18,
                                       threeStar: 2, perfect: 2)

    /// Three fixed scoring bands. The daily BAC changes the shared visual
    /// conditions, not the measurement, so every player gets the same test.
    static func points(distance: Double, tolerances: Tolerances) -> Int {
        let scale = tolerances.oneStar / Self.tolerances.oneStar
        let distance = abs(distance)
        if distance <= 2.0 * scale { return 5 }
        if distance <= 18.0 * scale { return 3 }
        if distance <= 40.0 * scale { return 1 }
        return 0
    }

    static func radii(tolerances: Tolerances) -> [Double] {
        let scale = tolerances.oneStar / Self.tolerances.oneStar
        return [40.0, 18.0, 2.0].map { $0 * scale }
    }
}

// MARK: - Results

enum MissDirection {
    case under  // stopped short of the target
    case over   // passed below the target
}

struct PourResult {
    /// Signed distance in logical px from the foam's top to the band center.
    /// Positive = the foam top settled below the band center (over).
    let distance: Double
    let score: Int
    let stars: Int          // 0...3
    let perfect: Bool
    let miss: MissDirection? // nil when the level was passed
}

// MARK: - BAC effects (blur, sway, scene tilt)
//
// The ladder: blur at 0.05, sway at 0.08, tilt at 0.12. Difficulty never
// attacks readability of the glass itself — effects move the whole scene.

struct BACEffects {
    var blurRadius: Double = 0
    var swayAmplitude: Double = 0
    var swayPeriod: Double = 7
    var tiltAmplitude: Double = 0 // degrees of roll, side to side
    var tiltPeriod: Double = 4

    static func resolve(bac raw: Double, debug: DebugSettings) -> BACEffects {
        let bac = debug.forcedBAC ?? raw
        var e = BACEffects()
        if debug.blurEnabled {
            // 0.05 -> 0 ... 0.12+ -> 6pt
            e.blurRadius = 6 * clamp01((bac - 0.05) / 0.07)
        }
        if debug.swayEnabled {
            let t = clamp01((bac - 0.08) / 0.08)
            e.swayAmplitude = 14 * t
            e.swayPeriod = 7 - 3 * t
        }
        if debug.tiltEnabled {
            // 0.12 -> 0 ... 0.16+ -> 3.5°, a slow 4s roll: listing on the stool.
            e.tiltAmplitude = 3.5 * clamp01((bac - 0.12) / 0.04)
        }
        return e
    }
}

func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
