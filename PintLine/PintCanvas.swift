import SwiftUI

/// The hero object: generic stout pint in a transparent glass with an etched
/// horizontal target band. Drawn in logical "glass space" (420pt tall),
/// scaled to fit the available size. The glass itself is rendered as
/// transparency, rim highlights, and refraction hints — never an opaque
/// white outline. The liquid line is the game's crosshair: razor crisp.
struct PintView: View {
    let engine: GameEngine
    let skin: GlassSkin
    let dailyScoring: Bool
    @Environment(PlayerSettings.self) private var settings

    init(engine: GameEngine, skin: GlassSkin, dailyScoring: Bool = false) {
        self.engine = engine
        self.skin = skin
        self.dailyScoring = dailyScoring
    }

    /// Golden shimmer progress (0...1) during a perfect-split celebration.
    private var shimmer: Double? {
        guard engine.result?.perfect == true else { return nil }
        return clamp01((engine.time - engine.judgedAt) / 0.8)
    }

    var body: some View {
        Canvas { ctx, size in
            let scale = size.height / (GameEngine.glassHeight + 60)
            var root = ctx
            root.translateBy(x: size.width / 2, y: size.height / 2)
            root.scaleBy(x: scale, y: scale)
            self.draw(into: &root)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Geometry

    private func py(_ lineY: Double) -> Double {
        lineY - GameEngine.glassHeight / 2
    }

    /// Glass half-width interpolated down the taper; y in logical glass points.
    private func halfWidth(atLineY y: Double) -> Double {
        let t = clamp01(y / GameEngine.glassHeight)
        if t < 0.18 {
            return 116 + (126 - 116) * (t / 0.18)
        }
        if t < 0.58 {
            return 126 + (108 - 126) * ((t - 0.18) / 0.40)
        }
        return 108 + (96 - 108) * ((t - 0.58) / 0.42)
    }

    private func outerGlassPath() -> Path {
        let top = -GameEngine.glassHeight / 2
        let bottom = GameEngine.glassHeight / 2
        var p = Path()
        // Pint-tulip silhouette: narrow lip, proud shoulder, tapered foot.
        p.move(to: CGPoint(x: -116, y: top))
        p.addLine(to: CGPoint(x: 116, y: top))
        p.addQuadCurve(to: CGPoint(x: 126, y: top + 76),
                       control: CGPoint(x: 127, y: top + 34))
        p.addCurve(to: CGPoint(x: 96, y: bottom - 14),
                   control1: CGPoint(x: 124, y: top + 150),
                   control2: CGPoint(x: 101, y: bottom - 92))
        p.addQuadCurve(to: CGPoint(x: -96, y: bottom - 14),
                       control: CGPoint(x: 0, y: bottom + 16))
        p.addCurve(to: CGPoint(x: -126, y: top + 76),
                   control1: CGPoint(x: -101, y: bottom - 92),
                   control2: CGPoint(x: -124, y: top + 150))
        p.addQuadCurve(to: CGPoint(x: -116, y: top),
                       control: CGPoint(x: -127, y: top + 34))
        p.closeSubpath()
        return p
    }

    private func innerGlassPath() -> Path {
        let top = -GameEngine.glassHeight / 2 + 8
        let bottom = GameEngine.glassHeight / 2 - 10
        let topHW = 107.0
        let bottomHW = 87.0
        var p = Path()
        p.move(to: CGPoint(x: -topHW, y: top))
        p.addLine(to: CGPoint(x: topHW, y: top))
        p.addQuadCurve(to: CGPoint(x: 117, y: top + 72),
                       control: CGPoint(x: 118, y: top + 32))
        p.addCurve(to: CGPoint(x: bottomHW, y: bottom - 12),
                   control1: CGPoint(x: 115, y: top + 145),
                   control2: CGPoint(x: 92, y: bottom - 86))
        p.addQuadCurve(to: CGPoint(x: -bottomHW, y: bottom - 12),
                       control: CGPoint(x: 0, y: bottom + 12))
        p.addCurve(to: CGPoint(x: -117, y: top + 72),
                   control1: CGPoint(x: -92, y: bottom - 86),
                   control2: CGPoint(x: -115, y: top + 145))
        p.addQuadCurve(to: CGPoint(x: -topHW, y: top),
                       control: CGPoint(x: -118, y: top + 32))
        p.closeSubpath()
        return p
    }

    // MARK: - Drawing

    private func draw(into ctx: inout GraphicsContext) {
        let time = engine.time
        let surfaceY = py(engine.lineY)
        let foamH = engine.foamHeight
        let bandY = py(engine.bandCenterY)
        let fullWidth = GameEngine.glassTopHalfWidth * 2 + 20
        let top = -GameEngine.glassHeight / 2
        let bottom = GameEngine.glassHeight / 2

        // MARK: Contents (clipped to the inner glass)

        var contents = ctx
        contents.clip(to: innerGlassPath())

        // Dark stout body below the surface line: deep brown-black, richer
        // toward the top where light passes through less liquid.
        let liquidRect = CGRect(x: -fullWidth / 2, y: surfaceY,
                                width: fullWidth, height: GameEngine.glassHeight)
        contents.fill(Path(liquidRect), with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.16, green: 0.08, blue: 0.04),
                Theme.stout,
                Color(red: 0.07, green: 0.035, blue: 0.02)
            ]),
            startPoint: CGPoint(x: 0, y: surfaceY),
            endPoint: CGPoint(x: 0, y: surfaceY + GameEngine.glassHeight)))

        // Depth: soft light streak down the left of the liquid, darkening at
        // the right edge — fakes the cylindrical refraction of the glass.
        contents.fill(Path(CGRect(x: -GameEngine.glassTopHalfWidth + 20, y: surfaceY,
                                  width: 24, height: GameEngine.glassHeight)),
                      with: .color(Color(red: 0.9, green: 0.75, blue: 0.5).opacity(0.08)))
        contents.fill(Path(CGRect(x: GameEngine.glassTopHalfWidth - 40, y: surfaceY,
                                  width: 22, height: GameEngine.glassHeight)),
                      with: .color(.black.opacity(0.25)))

        // Foam head: cream with a soft vertical falloff, wavy bottom edge,
        // seeded bubbles and faint shadow pockets for texture.
        var foamPath = Path()
        foamPath.move(to: CGPoint(x: -fullWidth / 2, y: surfaceY - foamH))
        foamPath.addLine(to: CGPoint(x: fullWidth / 2, y: surfaceY - foamH))
        foamPath.addLine(to: CGPoint(x: fullWidth / 2, y: surfaceY))
        var x = fullWidth / 2
        while x > -fullWidth / 2 {
            let wave = sin(x * 0.09 + time * 2.2) * 1.6 + sin(x * 0.031 - time * 1.3) * 1.1
            foamPath.addLine(to: CGPoint(x: x - 6, y: surfaceY + wave))
            x -= 6
        }
        foamPath.closeSubpath()
        contents.fill(foamPath, with: .linearGradient(
            Gradient(colors: [skin.foamColor, skin.foamColor.opacity(0.85)]),
            startPoint: CGPoint(x: 0, y: surfaceY - foamH),
            endPoint: CGPoint(x: 0, y: surfaceY + 4)))

        for i in 0..<14 {
            let fi = Double(i)
            let bx = (LevelGenerator.unit(seed: "bub-x-\(i)") - 0.5) * fullWidth * 0.8
            let by = surfaceY - foamH * (0.25 + 0.6 * LevelGenerator.unit(seed: "bub-y-\(i)"))
            let r = 1.2 + 2.2 * LevelGenerator.unit(seed: "bub-r-\(i)")
            let wobble = sin(time * 1.8 + fi * 2.1) * 1.5
            contents.fill(Path(ellipseIn: CGRect(x: bx + wobble - r, y: by - r, width: r * 2, height: r * 2)),
                          with: .color(Theme.foamShadow.opacity(0.4)))
        }

        // The liquid line: straight, hard-edged, high contrast. It is the
        // crosshair of the game and must stay razor crisp at all times.
        let lineHW = halfWidth(atLineY: engine.lineY) - 8
        var crispLine = Path()
        crispLine.move(to: CGPoint(x: -lineHW, y: surfaceY))
        crispLine.addLine(to: CGPoint(x: lineHW, y: surfaceY))
        contents.stroke(crispLine, with: .color(skin.foamColor), lineWidth: 2.5)
        var lineGlint = Path()
        lineGlint.move(to: CGPoint(x: -lineHW, y: surfaceY - 1.8))
        lineGlint.addLine(to: CGPoint(x: lineHW, y: surfaceY - 1.8))
        contents.stroke(lineGlint, with: .color(.white.opacity(0.55)), lineWidth: 1)

        // Perfect split: golden shimmer sweeping the band, golden foam
        if let p = shimmer {
            let glow = 1 - p
            contents.fill(Path(ellipseIn: CGRect(x: -130, y: bandY - 60, width: 260, height: 120)),
                          with: .radialGradient(
                            Gradient(colors: [Theme.amber.opacity(0.8 * glow), Theme.amber.opacity(0)]),
                            center: CGPoint(x: 0, y: bandY), startRadius: 4, endRadius: 130))
            contents.fill(foamPath, with: .color(Theme.amber.opacity(0.35 * glow)))
        }

        // MARK: Glass body (transparent: sheen, refraction, etched band)

        var glass = ctx
        glass.clip(to: outerGlassPath())

        // Faint vertical sheen so the empty part of the glass reads as glass
        // against the illustrated background — transparent, never opaque.
        glass.fill(Path(CGRect(x: -GameEngine.glassTopHalfWidth, y: top,
                               width: GameEngine.glassTopHalfWidth * 2, height: GameEngine.glassHeight)),
                   with: .linearGradient(
                    Gradient(colors: [skin.glassTint.opacity(0.13),
                                      skin.glassTint.opacity(0.05),
                                      skin.glassTint.opacity(0.10)]),
                    startPoint: CGPoint(x: 0, y: top),
                    endPoint: CGPoint(x: 0, y: bottom)))
        // Curvature: bright left streak, shadowed right edge.
        glass.fill(Path(CGRect(x: -GameEngine.glassTopHalfWidth + 12, y: top,
                               width: 18, height: GameEngine.glassHeight)),
                   with: .color(skin.rimTint.opacity(0.16)))
        glass.fill(Path(CGRect(x: GameEngine.glassTopHalfWidth - 26, y: top,
                               width: 14, height: GameEngine.glassHeight)),
                   with: .color(.black.opacity(0.08)))
        // Thick base: a heavier lens of glass at the bottom.
        glass.fill(Path(ellipseIn: CGRect(x: -GameEngine.glassBottomHalfWidth, y: bottom - 34,
                                          width: GameEngine.glassBottomHalfWidth * 2, height: 40)),
                   with: .color(.white.opacity(0.10)))

        // Etched target band: frosted lines — a soft wide halo under a thin
        // bright core, following the taper so it reads as cut into the glass.
        let bandHW = halfWidth(atLineY: engine.bandCenterY) - 4
        let bandHalfHeight = engine.tolerances.oneStar
        let targetCore = settings.highContrastTarget ? Color.white : Color.white.opacity(0.6)

        if dailyScoring {
            let radii = DailyFiveScoring.radii(tolerances: engine.tolerances)
            let fills: [Color] = [
                Color.red.opacity(0.58),
                Color.yellow.opacity(0.62),
                Color(red: 0.10, green: 0.78, blue: 0.34).opacity(0.82)
            ]
            for index in radii.indices {
                let outer = radii[index]
                let inner = index + 1 < radii.count ? radii[index + 1] : 0
                if inner == 0 {
                    glass.fill(Path(CGRect(x: -bandHW, y: bandY - outer,
                                           width: bandHW * 2, height: outer * 2)),
                               with: .color(fills[index]))
                } else {
                    glass.fill(Path(CGRect(x: -bandHW, y: bandY - outer,
                                           width: bandHW * 2, height: outer - inner)),
                               with: .color(fills[index]))
                    glass.fill(Path(CGRect(x: -bandHW, y: bandY + inner,
                                           width: bandHW * 2, height: outer - inner)),
                               with: .color(fills[index]))
                }
            }
        }

        if !dailyScoring {
            var bandPath = Path()
            bandPath.move(to: CGPoint(x: -bandHW, y: bandY - bandHalfHeight))
            bandPath.addLine(to: CGPoint(x: bandHW, y: bandY - bandHalfHeight))
            bandPath.move(to: CGPoint(x: -bandHW, y: bandY + bandHalfHeight))
            bandPath.addLine(to: CGPoint(x: bandHW, y: bandY + bandHalfHeight))
            glass.stroke(bandPath,
                         with: .color(.white.opacity(settings.highContrastTarget ? 0.38 : 0.18)),
                         lineWidth: 5)
            glass.stroke(bandPath, with: .color(targetCore),
                         style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            // Etched end ticks tying the two lines together.
            var capPath = Path()
            for side in [-1.0, 1.0] {
                let cxp = side * (bandHW - 4)
                capPath.move(to: CGPoint(x: cxp, y: bandY - bandHalfHeight))
                capPath.addLine(to: CGPoint(x: cxp, y: bandY + bandHalfHeight))
            }
            glass.stroke(capPath, with: .color(.white.opacity(0.4)),
                         style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }

        // Judgment moment: soft glow on the band + tick where the line stopped,
        // so the player sees exactly how far off they were.
        if engine.phase == .settling || engine.phase == .judged {
            let judged = ctx
            judged.fill(Path(ellipseIn: CGRect(x: -fullWidth / 2, y: bandY - 26,
                                               width: fullWidth, height: 52)),
                        with: .radialGradient(
                            Gradient(colors: [.white.opacity(0.25), .white.opacity(0)]),
                            center: CGPoint(x: 0, y: bandY),
                            startRadius: 4, endRadius: fullWidth / 2))
            // The marker uses the exact point that scoring uses: the very top
            // of the cream, never the beer/foam boundary below it.
            let foamTopCanvasY = py(engine.foamTopY)
            let hw = halfWidth(atLineY: engine.foamTopY)
            let tickColor: GraphicsContext.Shading = engine.result?.perfect == true
                ? .color(Theme.amber) : .color(.white.opacity(0.9))
            var tick = Path()
            tick.move(to: CGPoint(x: hw + 10, y: foamTopCanvasY - 7))
            tick.addLine(to: CGPoint(x: hw + 24, y: foamTopCanvasY))
            tick.addLine(to: CGPoint(x: hw + 10, y: foamTopCanvasY + 7))
            judged.stroke(tick, with: tickColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            judged.fill(Path(CGRect(x: hw - 4, y: foamTopCanvasY - 1.5, width: 14, height: 3)),
                        with: tickColor)
        }

        // Condensation droplets on the glass where venue-appropriate
        if skin.showCondensation {
            let drops = ctx
            for i in 0..<14 {
                let rx = LevelGenerator.unit(seed: "drop-x-\(i)")
                let ry = LevelGenerator.unit(seed: "drop-y-\(i)")
                let speed = 4 + 6 * LevelGenerator.unit(seed: "drop-s-\(i)")
                let dx = (rx - 0.5) * fullWidth * 0.85
                let dy = (ry * GameEngine.glassHeight + time * speed)
                    .truncatingRemainder(dividingBy: GameEngine.glassHeight)
                let r = 1.6 + 2.4 * LevelGenerator.unit(seed: "drop-r-\(i)")
                drops.fill(Path(ellipseIn: CGRect(x: dx - r, y: py(dy) - r, width: r * 2, height: r * 2)),
                           with: .color(.white.opacity(0.22)))
            }
        }

        // MARK: Rim highlights (what actually sells the glass)
        //
        // Highlights are tinted to the venue's color temperature
        // (skin.rimTint) so the glass reads as lit BY the scene.

        // Barely-there full outline for definition against dark art.
        ctx.stroke(outerGlassPath(), with: .color(skin.rimTint.opacity(0.16)), lineWidth: 1.5)

        // Left rim catches the light; right rim is a whisper.
        var leftRim = Path()
        leftRim.move(to: CGPoint(x: -GameEngine.glassTopHalfWidth, y: top + 4))
        leftRim.addLine(to: CGPoint(x: -GameEngine.glassBottomHalfWidth, y: bottom - 16))
        ctx.stroke(leftRim, with: .color(skin.rimTint.opacity(0.14)), lineWidth: 6)
        ctx.stroke(leftRim, with: .color(skin.rimTint.opacity(0.55)), lineWidth: 2.5)
        var rightRim = Path()
        rightRim.move(to: CGPoint(x: GameEngine.glassTopHalfWidth, y: top + 4))
        rightRim.addLine(to: CGPoint(x: GameEngine.glassBottomHalfWidth, y: bottom - 16))
        ctx.stroke(rightRim, with: .color(skin.rimTint.opacity(0.22)), lineWidth: 2)

        // Top lip and the heavy base arc.
        var lip = Path()
        lip.move(to: CGPoint(x: -GameEngine.glassTopHalfWidth, y: top + 1))
        lip.addLine(to: CGPoint(x: GameEngine.glassTopHalfWidth, y: top + 1))
        ctx.stroke(lip, with: .color(skin.rimTint.opacity(0.45)), lineWidth: 2.5)
        var baseArc = Path()
        baseArc.move(to: CGPoint(x: -GameEngine.glassBottomHalfWidth, y: bottom - 14))
        baseArc.addQuadCurve(to: CGPoint(x: GameEngine.glassBottomHalfWidth, y: bottom - 14),
                             control: CGPoint(x: 0, y: bottom + 16))
        ctx.stroke(baseArc, with: .color(skin.rimTint.opacity(0.35)), lineWidth: 3)
    }
}
