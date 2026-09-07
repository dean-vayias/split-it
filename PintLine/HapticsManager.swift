import CoreHaptics
import UIKit

final class HapticsManager {
    static let shared = HapticsManager()

    private var engine: CHHapticEngine?
    private var rumblePlayer: CHHapticPatternPlayer?
    private let fallbackTap = UIImpactFeedbackGenerator(style: .medium)
    private let fallbackNotify = UINotificationFeedbackGenerator()

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        engine?.stoppedHandler = { _ in }
        try? engine?.start()
    }

    /// Soft rumble while holding. Intensity scales with drain speed.
    func startRumble(intensity: Float = 0.35) {
        guard let engine else { return }
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)
        ], relativeTime: 0, duration: 60)
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []),
              let player = try? engine.makePlayer(with: pattern) else { return }
        rumblePlayer = player
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    func stopRumble() {
        try? rumblePlayer?.stop(atTime: CHHapticTimeImmediate)
        rumblePlayer = nil
    }

    /// Clean click on release.
    func releaseClick() {
        transient(intensity: 0.6, sharpness: 0.8)
        fallbackTap.impactOccurred(intensity: 0.6)
    }

    /// Heavy double-thump for a perfect split.
    func perfectThump() {
        guard let engine else {
            fallbackNotify.notificationOccurred(.success)
            return
        }
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
            ], relativeTime: 0.12)
        ]
        if let pattern = try? CHHapticPattern(events: events, parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: CHHapticTimeImmediate)
        }
    }

    /// Sad little buzz on a fail.
    func failBuzz() {
        guard let engine else {
            fallbackNotify.notificationOccurred(.error)
            return
        }
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
        ], relativeTime: 0, duration: 0.3)
        if let pattern = try? CHHapticPattern(events: [event], parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: CHHapticTimeImmediate)
        }
    }

    private func transient(intensity: Float, sharpness: Float) {
        guard let engine else { return }
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: 0)
        if let pattern = try? CHHapticPattern(events: [event], parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: CHHapticTimeImmediate)
        }
    }
}
