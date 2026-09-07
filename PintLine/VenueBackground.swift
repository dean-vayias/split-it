import SwiftUI

/// Venue scenes are IMAGES. Never draw venue backgrounds with shapes or
/// gradients — the code is a compositor: the illustrated JPG scaled cover,
/// cheap ambient overlays on top, and the procedural pint above that.
struct VenueBackground: View {
    let venue: VenueID

    var body: some View {
        Image(venue.config.artImage)
            .resizable()
            .scaledToFill()
            .allowsHitTesting(false)
    }
}

// MARK: - Ambient life

/// Constant-60fps, GPU-cheap overlay animations drawn on top of the static
/// art: steam wisps, ember particles, water droplets, light flicker.
/// Part of the composited scene, so BAC blur/sway affects it too.
struct AmbientOverlayView: View {
    let venue: VenueID
    let time: Double
    @Environment(PlayerSettings.self) private var settings

    var body: some View {
        let kinds = venue.config.ambient
        if !kinds.isEmpty {
            Canvas { ctx, size in
                for kind in kinds {
                    switch kind {
                    case .steamWisps: steam(ctx: ctx, size: size)
                    case .embers: embers(ctx: ctx, size: size)
                    case .droplets: droplets(ctx: ctx, size: size)
                    case .lightFlicker: flicker(ctx: ctx, size: size)
                    case .strobe:
                        if !settings.reduceFlashes { disco(ctx: ctx, size: size) }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func glow(ctx: GraphicsContext, at point: CGPoint, radius: CGFloat,
                      color: Color, alpha: Double) {
        let rect = CGRect(x: point.x - radius, y: point.y - radius,
                          width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [color.opacity(alpha), color.opacity(0)]),
            center: point, startRadius: 2, endRadius: radius))
    }

    /// Soft steam blobs drifting over the tile.
    private func steam(ctx: GraphicsContext, size: CGSize) {
        for i in 0..<3 {
            let fi = Double(i)
            let sx = size.width * (0.25 + 0.25 * fi) + sin(time * 0.35 + fi * 2.2) * 50
            let sy = size.height * (0.3 + 0.2 * fi) + cos(time * 0.28 + fi * 1.7) * 40
            glow(ctx: ctx, at: CGPoint(x: sx, y: sy), radius: 130 + fi * 30,
                 color: .white, alpha: 0.10)
        }
    }

    /// Embers rising off the fire, fading as they climb.
    private func embers(ctx: GraphicsContext, size: CGSize) {
        for i in 0..<10 {
            let fi = Double(i)
            let seed = "ember-\(i)"
            let ex = size.width * (0.35 + 0.3 * LevelGenerator.unit(seed: seed + "x"))
                + sin(time * (0.8 + fi * 0.13) + fi) * 26
            let rise = (time * (14 + 10 * LevelGenerator.unit(seed: seed + "s")) + fi * 90)
                .truncatingRemainder(dividingBy: size.height * 0.55)
            let ey = size.height * 0.62 - rise
            let fade = max(0, 1 - rise / (size.height * 0.55))
            ctx.fill(Path(ellipseIn: CGRect(x: ex - 2, y: ey - 2, width: 4, height: 4)),
                     with: .color(Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.8 * fade)))
        }
    }

    /// Thin droplet streaks falling down the frame.
    private func droplets(ctx: GraphicsContext, size: CGSize) {
        for i in 0..<12 {
            let seed = "drip-\(i)"
            let dx = size.width * LevelGenerator.unit(seed: seed + "x")
            let speed = 120 + 160 * LevelGenerator.unit(seed: seed + "s")
            let fall = (time * speed + 700 * LevelGenerator.unit(seed: seed + "o"))
                .truncatingRemainder(dividingBy: size.height + 80)
            let dy = fall - 40
            let len = 10 + 14 * LevelGenerator.unit(seed: seed + "l")
            var streak = Path()
            streak.move(to: CGPoint(x: dx, y: dy))
            streak.addLine(to: CGPoint(x: dx, y: dy + len))
            ctx.stroke(streak, with: .color(.white.opacity(0.28)), lineWidth: 1.5)
        }
    }

    /// Karaoke disco: neon spots slowly sweeping the room over a soft
    /// strobe wash — gentle pulses, never a hard flash.
    private func disco(ctx: GraphicsContext, size: CGSize) {
        let colors: [Color] = [
            Color(red: 0.75, green: 0.35, blue: 1.0),   // neon purple
            Color(red: 1.0, green: 0.35, blue: 0.75),   // hot pink
            Color(red: 0.30, green: 0.65, blue: 1.0)    // electric blue
        ]
        for i in 0..<3 {
            let fi = Double(i)
            let gx = size.width * (0.5 + 0.38 * sin(time * 0.9 + fi * 2.1))
            let gy = size.height * (0.22 + 0.10 * sin(time * 0.6 + fi * 1.3))
            glow(ctx: ctx, at: CGPoint(x: gx, y: gy), radius: 150,
                 color: colors[i], alpha: 0.16 + 0.06 * sin(time * 2.2 + fi * 3.0))
        }
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .color(Color(red: 0.7, green: 0.5, blue: 1.0)
                    .opacity(0.05 + 0.04 * sin(time * 6.0))))
    }

    /// Warm light breathing over the art — pub bulbs up top, fire glow below.
    private func flicker(ctx: GraphicsContext, size: CGSize) {
        switch venue {
        case .pub:
            // Mains hum on the hanging Edison bulbs.
            let hum1 = 0.20 + 0.03 * sin(time * 2.6) + 0.015 * sin(time * 9.1)
            let hum2 = 0.16 + 0.03 * sin(time * 3.4 + 1.7)
            glow(ctx: ctx, at: CGPoint(x: size.width * 0.10, y: size.height * 0.14),
                 radius: 170, color: Theme.amber, alpha: hum1)
            glow(ctx: ctx, at: CGPoint(x: size.width * 0.38, y: size.height * 0.15),
                 radius: 150, color: Theme.amber, alpha: hum2)
            glow(ctx: ctx, at: CGPoint(x: size.width * 0.88, y: size.height * 0.16),
                 radius: 140, color: Theme.amber, alpha: hum1 * 0.8)
        case .campfire:
            // Fire glow from the hearth, breathing irregularly.
            let breath = 0.6 + 0.25 * sin(time * 5.1) * sin(time * 2.3) + 0.15 * sin(time * 9.7)
            glow(ctx: ctx, at: CGPoint(x: size.width * 0.5, y: size.height * 0.56),
                 radius: 260, color: Color(red: 1.0, green: 0.55, blue: 0.15), alpha: 0.30 * breath)
        default:
            break
        }
    }
}
