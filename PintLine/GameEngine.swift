import SwiftUI

enum PourPhase: Equatable {
    case ready
    case draining
    case settling
    case judged
}

enum GameEvent {
    case drainStart
    case drainStop
    case judged(PourResult)
}

/// CADisplayLink wrapper so the liquid motion runs on the display refresh.
final class FrameDriver: NSObject {
    var onFrame: (Double) -> Void = { _ in }
    private var link: CADisplayLink?
    private var last: CFTimeInterval = -1

    func start() {
        guard link == nil else { return }
        last = -1
        let l = CADisplayLink(target: self, selector: #selector(step(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_ l: CADisplayLink) {
        if last < 0 { last = l.timestamp; return }
        let dt = min(0.05, l.timestamp - last)
        last = l.timestamp
        onFrame(dt)
    }
}

/// The pour state machine. All positions are in logical glass points:
/// y = 0 is the top of the glass, y = glassHeight the bottom. The judged
/// `lineY` is the liquid surface (the foam/beer boundary), which drops as you drink.
/// The game judges the top of the foam head, matching how a real Guinness split
/// is called.
@Observable
final class GameEngine {
    static let glassHeight: Double = 420
    static let glassTopHalfWidth: Double = 125
    static let glassBottomHalfWidth: Double = 100
    static let startLineY: Double = 40
    static let baseFoamHeight: Double = 20

    let level: LevelDefinition
    let tolerances: Tolerances
    var onEvent: (GameEvent) -> Void = { _ in }

    private(set) var phase: PourPhase = .ready
    private(set) var lineY: Double = GameEngine.startLineY
    private(set) var time: Double = 0
    private(set) var result: PourResult?
    private(set) var judgedAt: Double = 0
    private(set) var attempt = 0

    private var equilibrium = 0.0
    private var overshoot = 0.0
    private var settleT = 0.0
    @ObservationIgnored private let driver = FrameDriver()

    var bandCenterY: Double { level.bandFraction * Self.glassHeight }

    /// The head grows slightly as you drink.
    var foamHeight: Double {
        Self.baseFoamHeight + max(0, lineY - Self.startLineY) * 0.05
    }

    /// The highest visible point of the foam head. This—not the foam/beer
    /// boundary—is the reference point for the target band and score.
    var foamTopY: Double { lineY - foamHeight }

    init(level: LevelDefinition, tolerances: Tolerances = .base) {
        self.level = level
        self.tolerances = tolerances
        driver.onFrame = { [weak self] dt in self?.tick(dt) }
    }

    func start() { driver.start() }
    func stop() { driver.stop() }

    /// Zero wind-up: beer starts draining immediately on touch-down.
    func touchDown() {
        guard phase == .ready else { return }
        phase = .draining
        onEvent(.drainStart)
    }

    func touchUp() {
        guard phase == .draining else { return }
        // Momentum carries the surface a couple of px past the cut-off point,
        // then it settles back with damped oscillation.
        overshoot = min(3.0, level.drainSpeed * 0.02)
        equilibrium = lineY + overshoot
        settleT = 0
        phase = .settling
        onEvent(.drainStop)
    }

    func retry() {
        attempt += 1
        result = nil
        settleT = 0
        lineY = Self.startLineY
        phase = .ready
    }

    /// Resolve an in-flight split when the player leaves or backgrounds the
    /// app. This makes pause behave like releasing at that instant, so it
    /// cannot be used to erase a miss before submitting a leaderboard run.
    func resolveForPause() -> PourResult? {
        switch phase {
        case .ready:
            return nil
        case .draining:
            overshoot = min(3.0, level.drainSpeed * 0.02)
            equilibrium = min(Self.glassHeight - 8, lineY + overshoot)
            lineY = equilibrium
            finish(forceOver: lineY >= Self.glassHeight - 8)
        case .settling:
            lineY = equilibrium
            finish()
        case .judged:
            break
        }
        return result
    }

    private func tick(_ dt: Double) {
        time += dt
        switch phase {
        case .ready, .judged:
            break
        case .draining:
            // Micro-texture: a barely-perceptible shimmer in the drain rate.
            let micro = 1 + 0.02 * sin(time * 23) + 0.015 * sin(time * 7.7)
            lineY += level.drainSpeed * micro * dt
            if lineY >= Self.glassHeight - 8 {
                lineY = Self.glassHeight - 8
                finish(forceOver: true)
            }
        case .settling:
            settleT += dt
            let envelope = exp(-6.0 * settleT)
            lineY = equilibrium - overshoot * cos(26 * settleT) * envelope
            if settleT > 0.5 || envelope < 0.03 {
                lineY = equilibrium
                finish()
            }
        }
    }

    private func finish(forceOver: Bool = false) {
        let d = foamTopY - bandCenterY
        let ad = abs(d)
        let t = tolerances
        let stars: Int = forceOver ? 0
            : ad <= t.threeStar ? 3
            : ad <= t.twoStar ? 2
            : ad <= t.oneStar ? 1 : 0
        let score = max(0, 100 - Int((ad * 4).rounded()))
        let perfect = !forceOver && ad <= t.perfect
        let miss: MissDirection? = stars == 0 ? (d < 0 ? .under : .over) : nil
        let r = PourResult(distance: d, score: score, stars: stars, perfect: perfect, miss: miss)
        result = r
        judgedAt = time
        phase = .judged
        onEvent(.judged(r))
    }
}
