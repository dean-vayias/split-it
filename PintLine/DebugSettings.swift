import SwiftUI

/// Player-facing comfort and feedback controls. These are deliberately
/// separate from the developer tuning switches below.
@Observable
final class PlayerSettings {
    static let shared = PlayerSettings()

    var soundEnabled: Bool { didSet { save() } }
    var hapticsEnabled: Bool { didSet { save() } }
    var reduceMotion: Bool { didSet { save() } }
    var reduceFlashes: Bool { didSet { save() } }
    var highContrastTarget: Bool { didSet { save() } }

    private let defaults = UserDefaults.standard

    private init() {
        soundEnabled = defaults.object(forKey: "settings.sound") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "settings.haptics") as? Bool ?? true
        reduceMotion = defaults.object(forKey: "settings.reduceMotion") as? Bool ?? false
        reduceFlashes = defaults.object(forKey: "settings.reduceFlashes") as? Bool ?? false
        highContrastTarget = defaults.object(forKey: "settings.highContrastTarget") as? Bool ?? false
    }

    private func save() {
        defaults.set(soundEnabled, forKey: "settings.sound")
        defaults.set(hapticsEnabled, forKey: "settings.haptics")
        defaults.set(reduceMotion, forKey: "settings.reduceMotion")
        defaults.set(reduceFlashes, forKey: "settings.reduceFlashes")
        defaults.set(highContrastTarget, forKey: "settings.highContrastTarget")
    }
}

/// Debug/tuning switches. Every BAC effect is individually toggleable here.
@Observable
final class DebugSettings {
    var blurEnabled = true
    var swayEnabled = true
    var tiltEnabled = true
    /// When set, overrides the level's BAC for effect resolution.
    var forcedBAC: Double? = nil
    var showDistances = false
    /// Session-only offsets used by the hidden five-finger anchor tuner.
    /// Values are normalized screen-coordinate deltas, just like GlassAnchor.
    var anchorNudges: [VenueID: CGSize] = [:]
    var tuningVenue: VenueID? = nil

    func tunedAnchor(for venue: VenueID) -> GlassAnchor {
        let anchor = venue.config.glassAnchor
        let nudge = anchorNudges[venue] ?? .zero
        return GlassAnchor(x: clamp01(anchor.x + nudge.width),
                           baseY: clamp01(anchor.baseY + nudge.height))
    }

    func nudgeAnchor(for venue: VenueID, x: Double = 0, y: Double = 0) {
        let old = anchorNudges[venue] ?? .zero
        let next = CGSize(width: old.width + x, height: old.height + y)
        anchorNudges[venue] = next
        let anchor = tunedAnchor(for: venue)
        print(String(format: "GlassAnchor.%@: x: %.4f, baseY: %.4f",
                     venue.rawValue, anchor.x, anchor.baseY))
    }

    init() {
        #if DEBUG
        // Test hook: `-bac 0.15`
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-bac"), i + 1 < args.count, let v = Double(args[i + 1]) {
            forcedBAC = v
        }
        #endif
    }
}
