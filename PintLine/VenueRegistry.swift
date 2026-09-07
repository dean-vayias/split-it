import SwiftUI

// MARK: - Venue configuration (data-driven venue registry)

/// Signature mechanical twist layered under the BAC effects.
enum TwistKind {
    case none           // teaches the loop / pure ambience
    case condensation   // The Shower: steam fogs the lens on a cycle
    case candlelight    // Fancy Dinner / Wedding: flicker + waiter crossings
    case crowdWave      // Football Stadium: wave blocks view, jumbotron flashes, roar surges
    case vendor         // Baseball Park: vendor crossings, bat-crack jump scare, the stretch
    case chants         // Soccer Stadium: rhythmic chant pulse, flags & scarves
    case firelight      // Campfire: band readable only in firelight flashes
}

/// Cheap code-drawn ambient life layered over the illustrated background.
enum AmbientKind {
    case steamWisps     // drifting soft steam (The Shower)
    case embers         // rising ember particles (Campfire)
    case droplets       // falling water droplets (The Shower, The Beach)
    case lightFlicker   // warm glow with mains-hum flicker (Pub bulbs, campfire glow)
    case strobe         // sweeping disco spots + soft strobe wash (Karaoke Bar)
}

/// Cosmetic glass presentation per venue.
struct GlassSkin {
    var outlineColor: Color
    var glassTint: Color
    var foamColor: Color
    var showCondensation: Bool
    /// Color temperature of the rim highlights and reflections — warm amber
    /// in the Pub, cool teal in the Shower, neon purple at Karaoke, etc.
    var rimTint: Color = .white

    static let classic = GlassSkin(outlineColor: Theme.wood, glassTint: .white,
                                   foamColor: Theme.foam, showCondensation: false,
                                   rimTint: Color(red: 1.0, green: 0.80, blue: 0.55))
}

/// Ambient loop playback spec (synthesized noise bed: rate = color, volume = level).
struct AmbienceSpec {
    var rate: Float
    var volume: Float
}

/// Where the base of the glass rests on the illustrated background, in
/// normalized screen coordinates (x = fraction of width, baseY = fraction of
/// height). Tunable per venue — eyeball against the art so the glass sits
/// naturally on its surface (bar counter, caddy shelf, cupholder, log).
struct GlassAnchor {
    var x: Double
    var baseY: Double
}

/// A time-gated cosmetic reskin of a venue. Generic framing only —
/// no league/federation trademarks, team names, or logos.
struct SeasonalReskin {
    var displayName: String
    var accent: Color
    var window: SeasonalWindow
}

/// Date window (month/day, inclusive, wraps across year end).
/// Defaults live here; runtime overrides can be pushed via UserDefaults
/// ("seasonal.<key>.start" / ".end", "MM-dd" strings) so windows can move
/// without a new build.
struct SeasonalWindow {
    var startMonth: Int
    var startDay: Int
    var endMonth: Int
    var endDay: Int

    func contains(_ date: Date = Date()) -> Bool {
        let cal = Calendar.current
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let today = m * 100 + d
        let start = startMonth * 100 + startDay
        let end = endMonth * 100 + endDay
        return start <= end ? (today >= start && today <= end)
                            : (today >= start || today <= end)
    }
}

enum SeasonalConfig {
    static func window(key: String, fallback: SeasonalWindow) -> SeasonalWindow {
        let defaults = UserDefaults.standard
        func parse(_ s: String?) -> (Int, Int)? {
            guard let s, let m = Int(s.prefix(2)), let d = Int(s.suffix(2)) else { return nil }
            return (m, d)
        }
        guard let (sm, sd) = parse(defaults.string(forKey: "seasonal.\(key).start")),
              let (em, ed) = parse(defaults.string(forKey: "seasonal.\(key).end")) else {
            return fallback
        }
        return SeasonalWindow(startMonth: sm, startDay: sd, endMonth: em, endDay: ed)
    }

    /// "Big Game Sunday" — reskin of Football Stadium. Default: the week
    /// around the big February game. Override keys: seasonal.biggame.*
    static var bigGameSunday: SeasonalWindow {
        window(key: "biggame", fallback: SeasonalWindow(startMonth: 2, startDay: 6,
                                                        endMonth: 2, endDay: 13))
    }

    /// "World Cup" — reskin of Soccer Stadium. Default: mid-June to mid-July.
    /// Override keys: seasonal.worldcup.*
    static var worldCup: SeasonalWindow {
        window(key: "worldcup", fallback: SeasonalWindow(startMonth: 6, startDay: 11,
                                                         endMonth: 7, endDay: 19))
    }
}

struct VenueConfig: Identifiable {
    let id: VenueID
    let name: String
    let tagline: String
    let bacRange: ClosedRange<Double>
    let palette: [Color]
    /// Illustrated background asset name in Assets.xcassets. Venue scenes are
    /// IMAGES — never draw venue backgrounds with shapes or gradients.
    let artImage: String
    let glassSkin: GlassSkin
    let twist: TwistKind
    let ambience: AmbienceSpec
    let glassAnchor: GlassAnchor
    let ambient: [AmbientKind]
    let reskin: SeasonalReskin?

    /// Five rounds reveal the next stop; the remaining rounds are optional mastery.
    var levelCount: Int { 25 }

    /// Display name with the seasonal reskin applied when its window is active.
    func displayName(at date: Date = Date()) -> String {
        if let reskin, reskin.window.contains(date) { return reskin.displayName }
        return name
    }

    /// Palette with the seasonal accent mixed in when active.
    func displayPalette(at date: Date = Date()) -> [Color] {
        if let reskin, reskin.window.contains(date) {
            return [reskin.accent, palette.last ?? palette[0]]
        }
        return palette
    }

    func isReskinned(at date: Date = Date()) -> Bool {
        reskin?.window.contains(date) ?? false
    }
}

enum VenueRegistry {
    static let all: [VenueConfig] = [
        VenueConfig(
            id: .pub,
            name: "The Pub",
            tagline: "Warm wood, amber light. Learn the pour.",
            bacRange: 0.00...0.05,
            palette: [Color(red: 0.42, green: 0.26, blue: 0.14), Color(red: 0.16, green: 0.09, blue: 0.05)],
            artImage: "pub_bg",
            glassSkin: .classic,
            twist: .none,
            ambience: AmbienceSpec(rate: 0.8, volume: 0.12),
            glassAnchor: GlassAnchor(x: 0.50, baseY: 0.66),   // bar counter top
            ambient: [.lightFlicker],
            reskin: nil
        ),
        VenueConfig(
            id: .shower,
            name: "The Shower",
            tagline: "Steam on the lens. Read the line through the fog.",
            bacRange: 0.05...0.09,
            palette: [Color(red: 0.24, green: 0.48, blue: 0.56), Color(red: 0.08, green: 0.18, blue: 0.23)],
            artImage: "shower_bg",
            glassSkin: GlassSkin(outlineColor: Color(red: 0.55, green: 0.65, blue: 0.68),
                                 glassTint: Color(red: 0.94, green: 0.98, blue: 1.0),
                                 foamColor: Theme.foam, showCondensation: true,
                                 rimTint: Color(red: 0.60, green: 0.88, blue: 0.94)),
            twist: .condensation,
            ambience: AmbienceSpec(rate: 1.5, volume: 0.20),
            glassAnchor: GlassAnchor(x: 0.50, baseY: 0.84),   // chrome caddy shelf
            ambient: [.steamWisps, .droplets],
            reskin: nil
        ),
        VenueConfig(
            id: .dinner,
            name: "Fancy Dinner",
            tagline: "Candlelight flicker. Mind the waiter.",
            bacRange: 0.09...0.13,
            palette: [Color(red: 0.20, green: 0.10, blue: 0.17), Color(red: 0.06, green: 0.03, blue: 0.07)],
            artImage: "fancy_dinner_bg",
            glassSkin: GlassSkin(outlineColor: Color(red: 0.45, green: 0.35, blue: 0.28),
                                 glassTint: Color(red: 1.0, green: 0.97, blue: 0.92),
                                 foamColor: Color(red: 0.97, green: 0.90, blue: 0.76),
                                 showCondensation: false,
                                 rimTint: Color(red: 1.0, green: 0.86, blue: 0.62)),
            twist: .candlelight,
            ambience: AmbienceSpec(rate: 0.6, volume: 0.07),
            glassAnchor: GlassAnchor(x: 0.50, baseY: 0.76),   // tablecloth between the candles
            ambient: [],
            reskin: nil
        ),
        VenueConfig(
            id: .beach,
            name: "The Beach",
            tagline: "Salt air, hot sand. Don't let the spray throw you off.",
            bacRange: 0.13...0.16,
            palette: [Color(red: 0.30, green: 0.72, blue: 0.78), Color(red: 0.90, green: 0.76, blue: 0.52)],
            artImage: "beach_bg",
            glassSkin: GlassSkin(outlineColor: Color(red: 0.45, green: 0.60, blue: 0.62),
                                 glassTint: Color(red: 0.96, green: 0.99, blue: 1.0),
                                 foamColor: Theme.foam, showCondensation: true,
                                 rimTint: Color(red: 0.82, green: 0.95, blue: 1.0)),
            twist: .none,
            ambience: AmbienceSpec(rate: 0.7, volume: 0.15),
            glassAnchor: GlassAnchor(x: 0.55, baseY: 0.70),   // flat sand
            ambient: [.droplets],
            reskin: nil
        ),
        VenueConfig(
            id: .rooftop,
            name: "Rooftop Bar",
            tagline: "Golden hour above the city. Watch your step.",
            bacRange: 0.16...0.19,
            palette: [Color(red: 0.42, green: 0.24, blue: 0.52), Color(red: 0.95, green: 0.48, blue: 0.28)],
            artImage: "rooftop_bg",
            glassSkin: GlassSkin(outlineColor: Color(red: 0.50, green: 0.40, blue: 0.48),
                                 glassTint: Color(red: 1.0, green: 0.96, blue: 0.94),
                                 foamColor: Theme.foam, showCondensation: true,
                                 rimTint: Color(red: 1.0, green: 0.78, blue: 0.60)),
            twist: .none,
            ambience: AmbienceSpec(rate: 1.0, volume: 0.09),
            glassAnchor: GlassAnchor(x: 0.50, baseY: 0.72),   // parapet ledge
            ambient: [],
            reskin: nil
        ),
        VenueConfig(
            id: .karaoke,
            name: "Karaoke Bar",
            tagline: "Neon haze, off-key anthems. Your song is next.",
            bacRange: 0.17...0.20,
            palette: [Color(red: 0.45, green: 0.18, blue: 0.62), Color(red: 0.10, green: 0.04, blue: 0.18)],
            artImage: "karaoke_bg",
            glassSkin: GlassSkin(outlineColor: Color(red: 0.55, green: 0.42, blue: 0.62),
                                 glassTint: Color(red: 0.96, green: 0.94, blue: 1.0),
                                 foamColor: Theme.foam, showCondensation: true,
                                 rimTint: Color(red: 0.85, green: 0.55, blue: 1.0)),
            twist: .none,
            ambience: AmbienceSpec(rate: 1.2, volume: 0.14),
            glassAnchor: GlassAnchor(x: 0.50, baseY: 0.70),   // center of high-top table surface
            ambient: [.strobe],
            reskin: nil
        ),
        VenueConfig(
            id: .tailgate,
            name: "The Tailgate",
            tagline: "Truck bed, grill smoke, kickoff soon.",
            bacRange: 0.19...0.22,
            palette: [Color(red: 0.25, green: 0.45, blue: 0.75), Color(red: 0.85, green: 0.30, blue: 0.18)],
            artImage: "tailgate_bg",
            glassSkin: GlassSkin(outlineColor: Color(red: 0.42, green: 0.44, blue: 0.48),
                                 glassTint: Color(red: 0.97, green: 0.98, blue: 1.0),
                                 foamColor: Theme.foam, showCondensation: true,
                                 rimTint: Color(red: 0.92, green: 0.95, blue: 1.0)),
            twist: .none,
            ambience: AmbienceSpec(rate: 1.0, volume: 0.13),
            glassAnchor: GlassAnchor(x: 0.50, baseY: 0.74),   // truck bed floor
            ambient: [],
            reskin: nil
        ),
        VenueConfig(
            id: .wedding,
            name: "The Wedding",
            tagline: "Open bar, golden hour. Don't cry at the toast.",
            bacRange: 0.22...0.25,
            palette: [Color(red: 0.94, green: 0.68, blue: 0.62), Color(red: 0.62, green: 0.38, blue: 0.34)],
            artImage: "wedding_bg",
            glassSkin: GlassSkin(outlineColor: Color(red: 0.55, green: 0.42, blue: 0.36),
                                 glassTint: Color(red: 1.0, green: 0.97, blue: 0.93),
                                 foamColor: Color(red: 0.97, green: 0.91, blue: 0.78),
                                 showCondensation: false,
                                 rimTint: Color(red: 1.0, green: 0.85, blue: 0.68)),
            twist: .candlelight,
            ambience: AmbienceSpec(rate: 0.65, volume: 0.08),
            glassAnchor: GlassAnchor(x: 0.55, baseY: 0.66),   // reception table
            ambient: [],
            reskin: nil
        ),
        VenueConfig(
            id: .football,
            name: "Football Stadium",
            tagline: "Night game. The wave is coming around.",
            bacRange: 0.25...0.28,
            palette: [Color(red: 0.10, green: 0.14, blue: 0.30), Color(red: 0.03, green: 0.05, blue: 0.12)],
            artImage: "football_stadium_bg",
            glassSkin: GlassSkin(outlineColor: Color(red: 0.30, green: 0.32, blue: 0.38),
                                 glassTint: Color(red: 0.96, green: 0.96, blue: 1.0),
                                 foamColor: Theme.foam, showCondensation: true,
                                 rimTint: Color(red: 0.84, green: 0.90, blue: 1.0)),
            twist: .crowdWave,
            ambience: AmbienceSpec(rate: 1.0, volume: 0.16),
            glassAnchor: GlassAnchor(x: 0.42, baseY: 0.84),   // seat-back cupholder ring
            ambient: [],
            reskin: SeasonalReskin(displayName: "Big Game Sunday",
                                   accent: Color(red: 0.16, green: 0.20, blue: 0.44),
                                   window: SeasonalConfig.bigGameSunday)
        ),
        VenueConfig(
            id: .baseball,
            name: "Baseball Park",
            tagline: "Day game, easy pace. Watch for the vendor.",
            bacRange: 0.28...0.30,
            palette: [Color(red: 0.36, green: 0.56, blue: 0.72), Color(red: 0.16, green: 0.30, blue: 0.20)],
            artImage: "baseball_park_bg",
            glassSkin: GlassSkin(outlineColor: Color(red: 0.40, green: 0.44, blue: 0.50),
                                 glassTint: Color(red: 0.97, green: 0.99, blue: 1.0),
                                 foamColor: Theme.foam, showCondensation: true,
                                 rimTint: Color(red: 0.94, green: 0.97, blue: 1.0)),
            twist: .vendor,
            ambience: AmbienceSpec(rate: 0.9, volume: 0.12),
            glassAnchor: GlassAnchor(x: 0.55, baseY: 0.78),   // dugout ledge
            ambient: [],
            reskin: nil
        ),
        VenueConfig(
            id: .soccer,
            name: "Soccer Stadium",
            tagline: "Ninety thousand people chanting. Find the rhythm.",
            bacRange: 0.30...0.32,
            palette: [Color(red: 0.14, green: 0.34, blue: 0.20), Color(red: 0.05, green: 0.14, blue: 0.09)],
            artImage: "soccer_stadium_bg",
            glassSkin: GlassSkin(outlineColor: Color(red: 0.34, green: 0.36, blue: 0.34),
                                 glassTint: .white, foamColor: Theme.foam,
                                 showCondensation: false,
                                 rimTint: Color(red: 0.84, green: 0.95, blue: 0.88)),
            twist: .chants,
            ambience: AmbienceSpec(rate: 1.1, volume: 0.15),
            glassAnchor: GlassAnchor(x: 0.50, baseY: 0.80),   // railing top
            ambient: [],
            reskin: SeasonalReskin(displayName: "World Cup",
                                   accent: Color(red: 0.18, green: 0.44, blue: 0.24),
                                   window: SeasonalConfig.worldCup)
        ),
        VenueConfig(
            id: .campfire,
            name: "Campfire",
            tagline: "Pitch dark. Read the band by firelight.",
            bacRange: 0.32...0.34,
            palette: [Color(red: 0.14, green: 0.07, blue: 0.04), Color(red: 0.02, green: 0.01, blue: 0.01)],
            artImage: "campfire_bg",
            glassSkin: GlassSkin(outlineColor: Color(red: 0.50, green: 0.30, blue: 0.18),
                                 glassTint: Color(red: 1.0, green: 0.94, blue: 0.85),
                                 foamColor: Color(red: 0.96, green: 0.86, blue: 0.66),
                                 showCondensation: false,
                                 rimTint: Color(red: 1.0, green: 0.70, blue: 0.42)),
            twist: .firelight,
            ambience: AmbienceSpec(rate: 0.55, volume: 0.14),
            glassAnchor: GlassAnchor(x: 0.50, baseY: 0.74),   // center of flat log top
            ambient: [.embers, .lightFlicker],
            reskin: nil
        ),
        VenueConfig(
            id: .hangover,
            name: "The Hangover",
            tagline: "Morning after. Water first. Then this.",
            bacRange: 0.34...0.36,
            palette: [Color(red: 0.35, green: 0.38, blue: 0.44), Color(red: 0.14, green: 0.16, blue: 0.20)],
            artImage: "hangover_bg",
            glassSkin: GlassSkin(outlineColor: Color(red: 0.40, green: 0.42, blue: 0.46),
                                 glassTint: Color(red: 0.95, green: 0.97, blue: 1.0),
                                 foamColor: Theme.foam, showCondensation: false,
                                 rimTint: Color(red: 0.88, green: 0.90, blue: 0.94)),
            twist: .none,
            ambience: AmbienceSpec(rate: 0.45, volume: 0.05),
            glassAnchor: GlassAnchor(x: 0.55, baseY: 0.70),   // dresser top
            ambient: [],
            reskin: nil
        ),
    ]

    static func config(for id: VenueID) -> VenueConfig {
        all.first { $0.id == id } ?? all[0]
    }
}
