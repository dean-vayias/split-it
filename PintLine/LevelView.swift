import SwiftUI

/// Live window top safe-area inset (GeometryReader reports 0 inside ignoresSafeArea).
func currentTopInset() -> CGFloat {
    let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
    return scene?.windows.first { $0.isKeyWindow }?.safeAreaInsets.top
        ?? scene?.windows.first?.safeAreaInsets.top ?? 0
}

// MARK: - Twist timing (all deterministic functions of engine time)

enum TwistTiming {
    /// Shower fog: 7s cycle — fade in, hold, clear.
    static func fogAmount(_ t: Double) -> Double {
        let c = t.truncatingRemainder(dividingBy: 7)
        if c < 2 { return c / 2 }
        if c < 3.5 { return 1 }
        if c < 5 { return 1 - (c - 3.5) / 1.5 }
        return 0
    }

    /// Silhouette crossing (waiter / vendor): progress 0...1 during a crossing, else nil.
    static func crossing(_ t: Double, seed: String, cycle: Double, chance: Double,
                         duration: Double) -> Double? {
        let cycleIndex = Int(floor(t / cycle))
        guard LevelGenerator.unit(seed: "\(seed)-c-\(cycleIndex)") < chance else { return nil }
        let moment = 0.5 + (cycle - duration - 1) * LevelGenerator.unit(seed: "\(seed)-m-\(cycleIndex)")
        let local = t - Double(cycleIndex) * cycle
        guard local >= moment, local < moment + duration else { return nil }
        return (local - moment) / duration
    }

    /// Football crowd wave: rises, covers, falls on a 9s cycle.
    static func waveCover(_ t: Double) -> Double {
        let c = t.truncatingRemainder(dividingBy: 9)
        if c < 1.0 { return c }
        if c < 2.2 { return 1 }
        if c < 3.2 { return 1 - (c - 2.2) }
        return 0
    }

    /// Jumbotron flash: brief white flash at a pseudo-random moment per 6s cycle.
    static func jumbotronFlash(_ t: Double, seed: String) -> Bool {
        let cycleIndex = Int(floor(t / 6))
        let moment = 1 + 4 * LevelGenerator.unit(seed: "\(seed)-j-\(cycleIndex)")
        let local = t - Double(cycleIndex) * 6
        return local >= moment && local < moment + 0.12
    }

    /// Crowd roar surge level 0...1 (audio modulation).
    static func roarSurge(_ t: Double, seed: String) -> Double {
        let cycleIndex = Int(floor(t / 5))
        let surging = LevelGenerator.unit(seed: "\(seed)-r-\(cycleIndex)") < 0.45
        let local = t - Double(cycleIndex) * 5
        guard surging else { return 0 }
        return sin(min(1, local / 5) * .pi) // swell up and back down across the cycle
    }

    /// Bat crack: true only on the trigger frame(s).
    static func batCrackNow(_ t: Double, seed: String) -> Bool {
        let cycleIndex = Int(floor(t / 8))
        guard LevelGenerator.unit(seed: "\(seed)-b-\(cycleIndex)") < 0.5 else { return false }
        let moment = 1.5 + 5 * LevelGenerator.unit(seed: "\(seed)-bm-\(cycleIndex)")
        let local = t - Double(cycleIndex) * 8
        return local >= moment && local < moment + 0.06
    }

    /// Baseball "stretch": once per attempt, spectators stand and block the view.
    static func stretchCover(_ t: Double, seed: String) -> Double {
        let start = 2.5 + 4 * LevelGenerator.unit(seed: seed)
        guard t >= start, t < start + 3.5 else { return 0 }
        let local = t - start
        if local < 0.5 { return local / 0.5 }
        if local < 3.0 { return 1 }
        return 1 - (local - 3.0) / 0.5
    }

    /// Soccer chant pulse 0...1, locked to the chant loop's 2s bar.
    static func chantPulse(_ t: Double) -> Double {
        let local = t.truncatingRemainder(dividingBy: 2)
        var p = 0.0
        for beat in [0.0, 0.5, 1.0, 1.35] where local >= beat {
            p = max(p, exp(-(local - beat) * 4))
        }
        return p
    }

    /// Flags/scarves crossing at "near-goal" moments.
    static func flagsProgress(_ t: Double, seed: String) -> Double? {
        crossing(t, seed: seed + "-flags", cycle: 11, chance: 0.5, duration: 1.6)
    }

    /// Campfire illumination 0...1 — the band is readable only in flashes.
    static func firelight(_ t: Double) -> Double {
        clamp01(0.5 + 0.3 * sin(t * 5.1) * sin(t * 2.3) + 0.2 * sin(t * 9.7))
    }
}

// MARK: - Hidden anchor tuner

/// Five rapid taps toggle this session-only control. It deliberately is not
/// linked from the normal UI, but makes it practical to tune the contact point
/// against the real venue art on device. Every nudge is also printed to Xcode.
private struct AnchorTuner: View {
    let venue: VenueID
    let debug: DebugSettings
    private let step = 0.002

    var body: some View {
        let anchor = debug.tunedAnchor(for: venue)
        VStack(spacing: 7) {
            Text("ANCHOR · \(venue.config.name.uppercased())")
                .font(.caption2.weight(.bold))
            Text(String(format: "x %.4f  y %.4f", anchor.x, anchor.baseY))
                .font(.caption2.monospacedDigit())
            HStack(spacing: 12) {
                Button { debug.nudgeAnchor(for: venue, x: -step) } label: {
                    Image(systemName: "arrow.left")
                }
                VStack(spacing: 4) {
                    Button { debug.nudgeAnchor(for: venue, y: -step) } label: {
                        Image(systemName: "arrow.up")
                    }
                    Button { debug.nudgeAnchor(for: venue, y: step) } label: {
                        Image(systemName: "arrow.down")
                    }
                }
                Button { debug.nudgeAnchor(for: venue, x: step) } label: {
                    Image(systemName: "arrow.right")
                }
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.bordered)
        }
        .padding(10)
        .foregroundStyle(.white)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Twist overlays

struct TwistOverlayView: View {
    let twist: TwistKind
    let size: CGSize
    let time: Double
    let seed: String
    @Environment(PlayerSettings.self) private var settings

    var body: some View {
        switch twist {
        case .none:
            EmptyView()

        case .condensation:
            let fog = TwistTiming.fogAmount(time)
            ZStack {
                Color.white.opacity(fog * 0.10)
                RoundedRectangle(cornerRadius: 40)
                    .fill(.white.opacity(fog * 0.45))
                    .frame(width: 340, height: 560)
                    .blur(radius: 36)
            }

        case .candlelight:
            ZStack {
                Color.black.opacity(0.12 + 0.08 * sin(time * 7.3) * sin(time * 2.9))
                if let p = TwistTiming.crossing(time, seed: seed + "-waiter",
                                                cycle: 8, chance: 1, duration: 1.2) {
                    silhouette(height: size.height * 0.58)
                        .position(x: -90 + p * (size.width + 180), y: size.height * 0.55)
                }
            }

        case .crowdWave:
            let cover = TwistTiming.waveCover(time)
            ZStack {
                if !settings.reduceFlashes && TwistTiming.jumbotronFlash(time, seed: seed) {
                    Color.white.opacity(0.7)
                }
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 0) {
                        HStack(spacing: 6) {
                            ForEach(0..<14, id: \.self) { _ in
                                Circle().frame(width: 24, height: 24)
                            }
                        }
                        Rectangle().frame(maxHeight: .infinity)
                    }
                    .foregroundStyle(Color(red: 0.04, green: 0.05, blue: 0.12))
                    .frame(height: max(1, size.height * 0.55 * cover))
                }
            }

        case .vendor:
            ZStack {
                if let p = TwistTiming.crossing(time, seed: seed + "-vendor",
                                                cycle: 7, chance: 0.65, duration: 1.5) {
                    silhouette(height: size.height * 0.5, tray: true)
                        .position(x: -90 + p * (size.width + 180), y: size.height * 0.58)
                }
                let stretch = TwistTiming.stretchCover(time, seed: seed + "-stretch")
                if stretch > 0 {
                    VStack(spacing: 0) {
                        Spacer()
                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                ForEach(0..<9, id: \.self) { i in
                                    Circle().frame(width: 30, height: 30)
                                        .offset(y: i.isMultiple(of: 2) ? -6 : 0)
                                }
                            }
                            Rectangle().frame(maxHeight: .infinity)
                        }
                        .foregroundStyle(Color(red: 0.16, green: 0.20, blue: 0.26))
                        .frame(height: max(1, size.height * 0.62 * stretch))
                    }
                }
            }

        case .chants:
            if let p = TwistTiming.flagsProgress(time, seed: seed) {
                ZStack {
                    flag(index: 0, color: Theme.amber, progress: p)
                    flag(index: 1, color: Color(red: 0.8, green: 0.15, blue: 0.12), progress: p)
                    flag(index: 2, color: .white, progress: p)
                }
            }

        case .firelight:
            Color.black.opacity(0.93 - 0.78 * TwistTiming.firelight(time))
        }
    }

    private func flag(index i: Int, color: Color, progress p: Double) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: 90, height: 56)
            .rotationEffect(.degrees(sin(time * 6 + Double(i)) * 10))
            .position(x: -100 + p * (size.width + 200),
                      y: size.height * (0.18 + 0.14 * Double(i)) + sin(time * 6 + Double(i) * 2) * 16)
            .opacity(0.9)
    }

    private func silhouette(height: CGFloat, tray: Bool = false) -> some View {
        VStack(spacing: 0) {
            Circle().frame(width: height * 0.16, height: height * 0.16)
            ZStack(alignment: .top) {
                Capsule().frame(width: height * 0.3, height: height * 0.7)
                if tray {
                    RoundedRectangle(cornerRadius: 3)
                        .frame(width: height * 0.34, height: 8)
                        .offset(x: height * 0.22, y: height * 0.2)
                }
            }
        }
        .foregroundStyle(Color.black.opacity(0.78))
        .frame(height: height)
    }
}

// MARK: - Gameplay scene (shared by story and endless)

struct GamePlayView: View {
    let engine: GameEngine
    let venue: VenueID
    let hangover: Bool
    let hudTitle: String
    let showHint: Bool
    let isNightOut: Bool
    var dailyScoring = false
    let onJudged: (PourResult) -> Void
    let onAdvance: (PourResult) -> Void

    @Environment(DebugSettings.self) private var debug
    @Environment(PlayerSettings.self) private var settings
    @Environment(Persistence.self) private var persistence
    @Environment(SessionStats.self) private var session
    /// Two-state composition: resting pint in the scene vs. raised pint at the lips.
    @State private var raised = false

    private var twists: [TwistKind] {
        if dailyScoring { return [] }
        return venue.config.twist == .none ? [] : [venue.config.twist]
    }

    var body: some View {
        let effects = resolvedEffects
        let t = engine.time
        GeometryReader { geo in
            ZStack {
                scene(effects: effects, size: geo.size, time: t)
                hud(bac: debug.forcedBAC ?? engine.level.bac, topInset: currentTopInset())
                    .frame(width: geo.size.width, height: geo.size.height)
                if !dailyScoring, engine.phase == .judged, let r = engine.result {
                    LevelCompleteView(result: r, streak: session.streak,
                                      isNightOut: isNightOut)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 5).onEnded {
                    debug.tuningVenue = debug.tuningVenue == venue ? nil : venue
                }
            )
            .overlay(alignment: .bottomTrailing) {
                if debug.tuningVenue == venue {
                    AnchorTuner(venue: venue, debug: debug)
                        .padding(.trailing, 16)
                        .padding(.bottom, 36)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in engine.touchDown() }
                    .onEnded { _ in
                        if engine.phase == .judged, let r = engine.result {
                            onAdvance(r)
                        } else {
                            engine.touchUp()
                        }
                    }
            )
        }
        .task(id: ObjectIdentifier(engine)) { wire(engine) }
        .onDisappear { teardown() }
        .onChange(of: engine.phase) { _, newPhase in
            switch newPhase {
            case .draining:
                // Snappy, identical raise every attempt. Drain starts instantly
                // in the engine — this animation is cosmetic only.
                withAnimation(.easeOut(duration: 0.08)) { raised = true }
            case .settling, .judged:
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { raised = false }
            case .ready:
                raised = false
            }
        }
        .onChange(of: batCrackActive) { _, active in
            if active && settings.soundEnabled { AudioManager.shared.playBatCrack() }
        }
        .onChange(of: roarLevel) { _, level in
            if settings.soundEnabled { AudioManager.shared.setRoarLevel(level) }
        }
    }

    private var resolvedEffects: BACEffects {
        var effects = BACEffects.resolve(bac: engine.level.bac, debug: debug)
        if settings.reduceMotion {
            effects.blurRadius = 0
            effects.swayAmplitude = 0
            effects.tiltAmplitude = 0
        }
        return effects
    }

    private var batCrackActive: Bool {
        twists.contains(.vendor) && TwistTiming.batCrackNow(engine.time, seed: engine.level.id)
    }

    private var roarLevel: Float {
        guard twists.contains(.crowdWave) else { return 0.10 }
        return Float(0.10 + 0.30 * TwistTiming.roarSurge(engine.time, seed: engine.level.id))
    }

    // MARK: Scene

    private func scene(effects: BACEffects, size: CGSize, time t: Double) -> some View {
        let swayX = effects.swayAmplitude * sin(t * 2 * .pi / effects.swayPeriod)
        let tilt = effects.tiltAmplitude * sin(t * 2 * .pi / effects.tiltPeriod)
        let chantScale = twists.contains(.chants) && !settings.reduceMotion
            ? 0.025 * TwistTiming.chantPulse(t) : 0
        let hangoverPulse = hangover && !settings.reduceMotion ? 0.02 * sin(t * 2.6) : 0

        // Two-state layout: small resting pint anchored to its surface in the
        // art, or raised to the lips.
        let restH = size.height * 0.21
        let drinkH = size.height * 0.62
        let pintH = raised ? drinkH : restH
        let anchor = debug.tunedAnchor(for: venue)
        let restingPoint = aspectFillPoint(anchor, in: size)
        // GlassAnchor is the exact contact point of the base and the depicted
        // surface. PintView's drawable canvas includes 60pt of vertical
        // breathing room, so its visible base is not at the frame's midpoint.
        let baseContactFraction = (GameEngine.glassHeight / 2 + 2)
            / (GameEngine.glassHeight + 60)
        let py = raised ? size.height * 0.52
                        : restingPoint.y - restH * baseContactFraction

        // Grounding geometry, derived from the glass's logical dimensions so
        // the contact shadows track the glass base at any size.
        let canvasH = GameEngine.glassHeight + 60
        let baseW = pintH * (2 * GameEngine.glassBottomHalfWidth) / canvasH
        let contactY = py + pintH * (GameEngine.glassHeight / 2 + 2) / canvasH
        let grounded = raised ? 0.0 : 1.0

        return ZStack {
            Group {
                VenueBackground(venue: venue)
                AmbientOverlayView(venue: venue, time: t)
            }
            // Camera push-in while drinking.
            .scaleEffect(raised && !settings.reduceMotion ? 1.05 : 1)
            .blur(radius: effects.blurRadius + (hangover ? 4 : 0))

            // Contact shadow: a soft elliptical pool beneath the glass base,
            // plus a tighter, darker seam exactly where glass meets surface.
            // Both fade out while the pint is raised to the lips.
            Ellipse()
                .fill(.black.opacity(0.35))
                .frame(width: baseW * 1.25, height: baseW * 0.24)
                .blur(radius: 7)
                .frame(width: size.width, height: size.height)
                .offset(y: contactY + 2 - size.height / 2)
                .opacity(grounded)
            Ellipse()
                .fill(.black.opacity(0.45))
                .frame(width: baseW * 0.92, height: baseW * 0.07)
                .blur(radius: 2)
                .frame(width: size.width, height: size.height)
                .offset(y: contactY - size.height / 2)
                .opacity(grounded)

            // Pint above the world. Frame animation (not scaleEffect) so the
            // line and band redraw crisply at every size during the raise.
            PintView(engine: engine, skin: persistence.skin(for: venue),
                     dailyScoring: dailyScoring)
                .frame(width: pintH * 0.62, height: pintH)
                // Daily BAC deliberately softens the precision instrument.
                // It is capped below the room blur so the scoring colors stay
                // legible while the exact center becomes harder to judge.
                .blur(radius: dailyScoring ? effects.blurRadius * 0.38 : 0)
                .frame(width: size.width, height: size.height)
                .offset(y: py - size.height / 2)

            // Twist overlays stay in front: the waiter, the wave, the fog and
            // the darkness must all be able to block the glass mid-drink.
            Group {
                ForEach(Array(twists.enumerated()), id: \.offset) { _, twist in
                    TwistOverlayView(twist: twist, size: size, time: t, seed: engine.level.id)
                }
                if hangover {
                    Color.gray.opacity(0.30)
                }
            }
            .scaleEffect(raised && !settings.reduceMotion ? 1.05 : 1)
            .blur(radius: effects.blurRadius + (hangover ? 4 : 0))
        }
        .saturation(hangover ? 0.5 : 1)
        .offset(x: swayX)
        .rotationEffect(.degrees(tilt))
        .scaleEffect(1 + chantScale + hangoverPulse)
        // Blur and rotation can otherwise reveal the hosting view at the
        // extreme corners. Keep those edges dark and intentional.
        .background(Color.black)
    }

    /// Converts an anchor authored against the 1440×2493 source art through
    /// the same aspect-fill crop used by VenueBackground.
    private func aspectFillPoint(_ anchor: GlassAnchor, in size: CGSize) -> CGPoint {
        let sourceAspect = 1440.0 / 2493.0
        let viewAspect = size.width / max(1, size.height)
        if viewAspect > sourceAspect {
            let imageHeight = size.width / sourceAspect
            let cropY = (imageHeight - size.height) / 2
            return CGPoint(x: anchor.x * size.width,
                           y: anchor.baseY * imageHeight - cropY)
        } else {
            let imageWidth = size.height * sourceAspect
            let cropX = (imageWidth - size.width) / 2
            return CGPoint(x: anchor.x * imageWidth - cropX,
                           y: anchor.baseY * size.height)
        }
    }

    // MARK: HUD

    private func hud(bac: Double, topInset: CGFloat) -> some View {
        VStack {
            if isNightOut {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        VStack(spacing: 3) {
                            HStack(spacing: 8) {
                                Text("SPLITS")
                                    .font(.system(size: 8, weight: .bold))
                                    .tracking(0.6)
                                Spacer(minLength: 0)
                                Text(hudTitle)
                                    .font(.caption.bold().monospacedDigit())
                            }
                            .foregroundStyle(.white)

                            HStack(spacing: 8) {
                                Text("BEST")
                                    .font(.system(size: 8, weight: .bold))
                                    .tracking(0.6)
                                Spacer(minLength: 0)
                                Text("\(max(persistence.data.bestSplitStreak, session.streak))")
                                    .font(.caption.bold().monospacedDigit())
                            }
                            .foregroundStyle(.white.opacity(0.60))
                        }
                        .frame(width: 74)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        }

                        HStack(spacing: 6) {
                            Text("BUZZ METER")
                                .font(.system(size: 7, weight: .bold))
                                .tracking(0.55)
                                .foregroundStyle(.white.opacity(0.62))
                            BuzzMeter(value: bac)
                                .frame(width: 44)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.56), in: Capsule())
                        .overlay {
                            Capsule().stroke(.white.opacity(0.12), lineWidth: 1)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, topInset + 8)
            } else {
                Text(hudTitle)
                    .font(.caption.bold())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.42), in: Capsule())
                    .padding(.top, topInset + 8)
            }
            Spacer()
            if showHint && engine.phase == .ready {
                VStack(spacing: 7) {
                    Image(systemName: "hand.tap.fill")
                        .font(.title2)
                    Text(dailyScoring ? "FIVE POURS · SAME TARGET" : "HOLD TO DRINK · RELEASE TO STOP")
                        .font(.caption.bold()).tracking(1)
                    Text(dailyScoring
                         ? "Green scores 5. Yellow scores 3. Red scores 1."
                         : "Put the very top of the cream inside the two lines.")
                        .font(.caption)
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 44)
            }
            if debug.showDistances, let r = engine.result {
                Text(String(format: "Δ %.1fpx", r.distance))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 8)
            }
        }
        .foregroundStyle(.white.opacity(0.9))
        .allowsHitTesting(false)
    }

    // MARK: Wiring

    private func wire(_ engine: GameEngine) {
        engine.onEvent = { event in
            let audio = AudioManager.shared
            let haptics = HapticsManager.shared
            switch event {
            case .drainStart:
                if settings.soundEnabled { audio.startGlug(drainSpeed: engine.level.drainSpeed) }
                if settings.hapticsEnabled { haptics.startRumble() }
            case .drainStop:
                audio.stopGlug()
                if settings.soundEnabled { audio.playClink() }
                haptics.stopRumble()
                if settings.hapticsEnabled { haptics.releaseClick() }
            case .judged(let r):
                audio.stopGlug()
                haptics.stopRumble()
                // The engine event is the authoritative completion signal.
                // Using it avoids SwiftUI coalescing a short phase transition
                // before a host has had a chance to persist the attempt.
                onJudged(r)
                if r.perfect {
                    if settings.soundEnabled { audio.playPerfect() }
                    if settings.hapticsEnabled { haptics.perfectThump() }
                } else if r.stars == 0 {
                    if settings.soundEnabled { audio.playFail(over: r.miss == .over) }
                    if settings.hapticsEnabled { haptics.failBuzz() }
                }
            }
        }
        engine.start()
        let audio = AudioManager.shared
        if settings.soundEnabled {
            audio.setAmbience(venue.config.ambience, hangover: hangover)
            if twists.contains(.crowdWave) { audio.startRoar() } else { audio.stopRoar() }
            if twists.contains(.chants) { audio.startChant() } else { audio.stopChant() }
        }
        #if DEBUG
        // Test hook: `-autodrink [holdMs]` pours then releases for screenshots.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-autodrink") {
            let holdMs = (i + 1 < args.count ? Double(args[i + 1]) : nil) ?? 1200
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                engine.touchDown()
                try? await Task.sleep(for: .milliseconds(Int(holdMs)))
                engine.touchUp()
            }
        }
        #endif
    }

    private func teardown() {
        engine.stop()
        let audio = AudioManager.shared
        audio.stopGlug()
        audio.stopAmbience()
        audio.stopRoar()
        audio.stopChant()
        HapticsManager.shared.stopRumble()
    }
}

// MARK: - LevelView: story + endless hosts

struct BuzzMeter: View {
    let value: Double

    private var progress: Double { clamp01(value / 0.35) }
    private let labels = ["FRESH", "BUZZING", "WOBBLY", "MESSY", "LAST CALL"]

    private var stage: Int {
        min(labels.count - 1, Int(progress * Double(labels.count)))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.white.opacity(0.16))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(LinearGradient(colors: [Color.green, Theme.amber, Color.orange, Color.red],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(5, geo.size.width * progress))
            }
        }
        .frame(height: 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Buzz meter, \(labels[stage].lowercased())")
    }
}

struct LevelView: View {
    enum Mode: Equatable {
        case story(VenueID, Int)
        case endless
        case daily
    }

    let mode: Mode

    var body: some View {
        switch mode {
        case .story(let venue, let index):
            StoryLevelHost(venue: venue, index: index)
        case .endless:
            EndlessHost()
        case .daily:
            DailyHost()
        }
    }
}

struct StoryLevelHost: View {
    let venue: VenueID
    let index: Int
    @State private var engine: GameEngine

    @Environment(AppRouter.self) private var router
    @Environment(Persistence.self) private var persistence
    @Environment(SessionStats.self) private var session

    init(venue: VenueID, index: Int) {
        self.venue = venue
        self.index = index
        _engine = State(initialValue: GameEngine(level: LevelGenerator.levels(for: venue)[index]))
    }

    var body: some View {
        GamePlayView(
            engine: engine,
            venue: venue,
            hangover: false,
            hudTitle: index < Persistence.routeRounds
                ? "\(venue.config.displayName()) · level \(index + 1)/\(Persistence.routeRounds)"
                : "\(venue.config.displayName()) · mastery \(index + 1 - Persistence.routeRounds)/\(venue.config.levelCount - Persistence.routeRounds)",
            showHint: venue == .pub && index == 0 && engine.attempt == 0,
            isNightOut: false,
            onJudged: { r in
                persistence.record(level: engine.level, stars: r.stars)
                persistence.recordOutcome(r)
                session.apply(r)
            },
            onAdvance: { r in
                if r.stars > 0 {
                    if index + 1 == Persistence.routeRounds {
                        router.screen = .home
                    } else if index + 1 < venue.config.levelCount {
                        router.screen = .level(venue, index + 1)
                    } else {
                        router.screen = .home
                    }
                } else {
                    engine.retry()
                }
            }
        )
    }
}

struct EndlessHost: View {
    @Environment(AppRouter.self) private var router
    @Environment(SessionStats.self) private var session

    private var endless: EndlessEngine { router.endless }

    var body: some View {
        ZStack {
            switch endless.phase {
            case .pouring:
                GamePlayView(
                    engine: endless.current,
                    venue: endless.current.level.venue,
                    hangover: endless.isCapstone,
                    hudTitle: "\(endless.pints)",
                    showHint: endless.pints == 0,
                    isNightOut: true,
                    onJudged: { r in
                        Persistence.shared.recordOutcome(r)
                        session.apply(r)
                    },
                    onAdvance: { r in endless.handle(r) }
                )
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.24), value: ObjectIdentifier(endless.current))
            case .cutOff:
                CutOffView(endless: endless)
            }
        }
        .overlay(alignment: .top) {
            if let arrival = endless.arrival, case .pouring = endless.phase {
                VenueArrivalBanner(arrival: arrival)
                    .padding(.top, currentTopInset() + 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: endless.arrival)
        .overlay(alignment: .topLeading) {
            if case .pouring = endless.phase {
                Button {
                    endless.pauseRun()
                    router.screen = .home
                } label: {
                    Image(systemName: "house.fill")
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.56), in: Circle())
                        .overlay {
                            Circle().stroke(.white.opacity(0.14), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go home")
                .padding(.leading, 12)
                .padding(.top, currentTopInset() + 8)
            }
        }
        .onAppear {
            endless.resumeOrBeginRun()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-show-cutoff") {
                endless.handle(PourResult(distance: -100, score: 0, stars: 0,
                                          perfect: false, miss: .under))
            }
            if ProcessInfo.processInfo.arguments.contains("-show-arrival") {
                endless.previewArrival()
            }
            #endif
        }
    }
}

struct VenueArrivalBanner: View {
    let arrival: EndlessEngine.VenueArrival

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: arrival.icon)
                .font(.caption2.bold())
                .foregroundStyle(Theme.ink)
                .frame(width: 27, height: 27)
                .background(Theme.amber, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(arrival.kicker)
                    .font(.system(size: 7, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(Theme.amber)
                Text(arrival.title.uppercased())
                    .font(.caption2.bold())
                    .tracking(0.75)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 14)
        .padding(.vertical, 7)
        .background(.black.opacity(0.72), in: Capsule())
        .overlay {
            Capsule().stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .frame(maxWidth: 148)
        .shadow(color: .black.opacity(0.34), radius: 9, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Arrived at \(arrival.title)")
    }
}

struct DailyHost: View {
    @Environment(AppRouter.self) private var router
    @Environment(Persistence.self) private var persistence
    @Environment(LeaderboardService.self) private var leaderboards
    @Environment(\.scenePhase) private var scenePhase

    private let day: String
    private let level: LevelDefinition
    private let tolerances: Tolerances
    @State private var engine: GameEngine
    @State private var scores: [Int]
    @State private var latestPoints: Int?
    @State private var showingSummary: Bool

    init() {
        let day = LeaderboardService.utcDayKey()
        let level = LevelGenerator.dailyFive(day: day)
        let scores = Persistence.shared.dailyFiveScores(for: day)
        self.day = day
        self.level = level
        self.tolerances = DailyFiveScoring.tolerances
        _engine = State(initialValue: GameEngine(level: level,
                                                 tolerances: DailyFiveScoring.tolerances))
        _scores = State(initialValue: scores)
        _latestPoints = State(initialValue: nil)
        _showingSummary = State(initialValue: scores.count >= DailyFiveScoring.attemptCount)
    }

    var body: some View {
        ZStack {
            if showingSummary {
                DailyFiveSummaryView(level: level, scores: scores,
                                     leaderboard: { router.screen = .leaderboard },
                                     home: { router.screen = .home })
            } else {
                GamePlayView(
                    engine: engine,
                    venue: level.venue,
                    hangover: false,
                    hudTitle: "DAILY FIVE · \(min(scores.count + 1, DailyFiveScoring.attemptCount))/5",
                    showHint: scores.isEmpty,
                    isNightOut: false,
                    dailyScoring: true,
                    onJudged: record,
                    onAdvance: { result in
                        record(result)
                        advance()
                    }
                )

                if engine.phase == .judged, let result = engine.result {
                    let points = latestPoints
                        ?? DailyFiveScoring.points(distance: result.distance,
                                                   tolerances: tolerances)
                    let visibleScores = latestPoints == nil && scores.count < DailyFiveScoring.attemptCount
                        ? scores + [points] : scores
                    DailyAttemptResultView(points: points, scores: visibleScores)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if !showingSummary {
                Button(action: goHome) {
                    Image(systemName: "house.fill")
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.56), in: Circle())
                        .overlay { Circle().stroke(.white.opacity(0.14), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go home")
                .padding(.leading, 12)
                .padding(.top, currentTopInset() + 8)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !showingSummary {
                engine.start()
            } else if !showingSummary {
                finishInFlightAttempt()
            }
        }
    }

    private func record(_ result: PourResult) {
        guard latestPoints == nil, scores.count < DailyFiveScoring.attemptCount else { return }
        let points = DailyFiveScoring.points(distance: result.distance, tolerances: tolerances)
        latestPoints = points
        scores = persistence.recordDailyFiveAttempt(day: day, points: points)
        persistence.recordOutcome(result)
    }

    private func advance() {
        guard latestPoints != nil else { return }
        if scores.count >= DailyFiveScoring.attemptCount {
            let total = scores.reduce(0, +)
            leaderboards.submitDailyFive(score: total, day: day)
            engine.stop()
            withAnimation(.easeInOut(duration: 0.24)) { showingSummary = true }
            return
        }
        engine.stop()
        latestPoints = nil
        engine = GameEngine(level: level, tolerances: tolerances)
    }

    private func finishInFlightAttempt() {
        engine.stop()
        guard latestPoints == nil, let result = engine.resolveForPause() else { return }
        record(result)
    }

    private func goHome() {
        finishInFlightAttempt()
        router.screen = .home
    }
}

struct DailyAttemptResultView: View {
    let points: Int
    let scores: [Int]

    var body: some View {
        VStack(spacing: 10) {
            Text(points == 5 ? "BULLSEYE" : points == 0 ? "MISS" : "NICE SPLIT")
                .font(.caption.bold())
                .tracking(1.8)
                .foregroundStyle(points == 5 ? Theme.amber : .white.opacity(0.72))

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(points)")
                    .font(.system(size: 48, weight: .black, design: .rounded).monospacedDigit())
                Text(points == 1 ? "POINT" : "POINTS")
                    .font(.caption.bold())
                    .tracking(1)
            }
            .foregroundStyle(.white)

            DailyFiveScoreRow(scores: scores)

            Text("TOTAL \(scores.reduce(0, +)) / 25")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(.white.opacity(0.68))

            Text(scores.count == DailyFiveScoring.attemptCount
                 ? "tap for results"
                 : "tap for pour \(scores.count + 1)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.52))
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.36), radius: 16, y: 8)
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }
}

struct DailyFiveScoreRow: View {
    let scores: [Int]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<DailyFiveScoring.attemptCount, id: \.self) { index in
                Text(index < scores.count ? "\(scores[index])" : "–")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(index < scores.count ? Theme.ink : .white.opacity(0.36))
                    .frame(width: 28, height: 28)
                    .background(index < scores.count ? Theme.amber : .white.opacity(0.10),
                                in: Circle())
            }
        }
    }
}

struct DailyFiveSummaryView: View {
    let level: LevelDefinition
    let scores: [Int]
    let leaderboard: () -> Void
    let home: () -> Void

    var body: some View {
        ZStack {
            VenueBackground(venue: level.venue)
            LinearGradient(colors: [.black.opacity(0.46), .black.opacity(0.82)],
                           startPoint: .top, endPoint: .bottom)

            VStack(spacing: 18) {
                Spacer()

                Text("DAILY FIVE")
                    .font(.caption.bold())
                    .tracking(3)
                    .foregroundStyle(Theme.amber)

                VStack(spacing: 15) {
                    DailyFiveScoreRow(scores: scores)

                    VStack(spacing: 0) {
                        Text("\(scores.reduce(0, +))")
                            .font(.system(size: 72, weight: .black, design: .rounded).monospacedDigit())
                        Text("OUT OF 25")
                            .font(.caption.bold())
                            .tracking(1.8)
                            .foregroundStyle(Theme.ink.opacity(0.52))
                    }

                    Text("\(level.venue.config.displayName().uppercased()) · TODAY")
                        .font(.caption2.bold())
                        .tracking(1.2)
                        .foregroundStyle(Theme.ink.opacity(0.46))
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 28)
                .padding(.vertical, 26)
                .background(Theme.cream, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Theme.amber, lineWidth: 2)
                }

                Button("VIEW DAILY LEADERBOARD", action: leaderboard)
                    .font(.callout.bold())
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.amber, in: Capsule())

                Button("GO HOME", action: home)
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.white.opacity(0.12), in: Capsule())
                    .overlay { Capsule().stroke(.white.opacity(0.18), lineWidth: 1) }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
    }
}
