import AVFoundation

/// All SFX are synthesized foley — no audio assets needed.
/// Glug loop and ambient beds loop on their own player nodes;
/// one-shots are pre-mixed single buffers.
final class AudioManager {
    static let shared = AudioManager()

    private let engine = AVAudioEngine()
    private let glugNode = AVAudioPlayerNode()
    private let fxNode = AVAudioPlayerNode()
    private let ambNode = AVAudioPlayerNode()
    private let roarNode = AVAudioPlayerNode()
    private let chantNode = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var started = false

    private lazy var glugBuffer = makeGlugLoop()
    private lazy var ambBuffer = makeBrownNoise()
    private lazy var clinkBuffer = makeClink()
    private lazy var perfectBuffer = makePerfect()
    private lazy var underBuffer = makeSadTrombone()
    private lazy var overBuffer = makeGulpSlide()
    private lazy var cutOffBuffer = makeCutOff()
    private lazy var roarBuffer = makeRoarLoop()
    private lazy var chantBuffer = makeChantLoop()
    private lazy var batCrackBuffer = makeBatCrack()

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        for node in [glugNode, fxNode, ambNode, roarNode, chantNode] {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
    }

    private func ensureStarted() {
        guard !started else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        engine.prepare()
        do {
            try engine.start()
            started = true
        } catch {
            started = false
        }
    }

    // MARK: - Public API

    /// Glug-glug loop; rate pitch-shifts subtly with drain speed.
    func startGlug(drainSpeed: Double) {
        ensureStarted()
        guard started else { return }
        glugNode.stop()
        glugNode.rate = Float(0.9 + min(1, drainSpeed / 200) * 0.4)
        glugNode.volume = 0.5
        glugNode.scheduleBuffer(glugBuffer, at: nil, options: .loops)
        glugNode.play()
    }

    func stopGlug() {
        glugNode.stop()
    }

    /// Glass-set-down clink on release.
    func playClink() { play(clinkBuffer, volume: 0.6) }

    /// Heavy thump + satisfied "ahhh" for a perfect split.
    func playPerfect() { play(perfectBuffer, volume: 0.8) }

    /// Distinct comedic stings: under-pour vs over-chug.
    func playFail(over: Bool) { play(over ? overBuffer : underBuffer, volume: 0.7) }

    /// Glass-slide + record-scratch-adjacent sting for getting cut off.
    func playCutOff() { play(cutOffBuffer, volume: 0.8) }

    /// Layered ambient bed per venue (synthesized noise, colored per venue config).
    func setAmbience(_ spec: AmbienceSpec, hangover: Bool = false) {
        ensureStarted()
        guard started else { return }
        ambNode.stop()
        if hangover {
            ambNode.rate = 0.45; ambNode.volume = 0.10 // muffled, painful
        } else {
            ambNode.rate = spec.rate; ambNode.volume = spec.volume
        }
        ambNode.scheduleBuffer(ambBuffer, at: nil, options: .loops)
        ambNode.play()
    }

    /// Crowd roar loop for stadiums; modulate with setRoarLevel for surges.
    func startRoar() {
        ensureStarted()
        guard started else { return }
        roarNode.stop()
        roarNode.volume = 0.10
        roarNode.scheduleBuffer(roarBuffer, at: nil, options: .loops)
        roarNode.play()
    }

    func setRoarLevel(_ level: Float) {
        roarNode.volume = level
    }

    func stopRoar() {
        roarNode.stop()
    }

    /// Supporter chant loop with a steady, learnable rhythm.
    func startChant() {
        ensureStarted()
        guard started else { return }
        chantNode.stop()
        chantNode.volume = 0.30
        chantNode.scheduleBuffer(chantBuffer, at: nil, options: .loops)
        chantNode.play()
    }

    func stopChant() {
        chantNode.stop()
    }

    /// Bat-crack jump scare (Baseball Park).
    func playBatCrack() { play(batCrackBuffer, volume: 0.9) }

    func stopAmbience() {
        ambNode.stop()
    }

    // MARK: - One-shot playback

    private func play(_ buffer: AVAudioPCMBuffer, volume: Float) {
        ensureStarted()
        guard started else { return }
        fxNode.scheduleBuffer(buffer, at: nil, options: [])
        fxNode.volume = volume
        if !fxNode.isPlaying { fxNode.play() }
    }

    // MARK: - Synthesis

    private func buffer(seconds: Double, _ render: (Double) -> Float) -> AVAudioPCMBuffer {
        let n = Int(seconds * format.sampleRate)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
        buf.frameLength = AVAudioFrameCount(n)
        let out = buf.floatChannelData![0]
        let sr = format.sampleRate
        for i in 0..<n {
            out[i] = render(Double(i) / sr)
        }
        return buf
    }

    private func srand(_ x: Double) -> Double {
        // deterministic noise source
        let s = sin(x * 127.1 + 311.7) * 43758.5453
        return s - s.rounded(.down)
    }

    /// Burbling glug: decaying noise bursts ~9 per second over a low wobble.
    private func makeGlugLoop() -> AVAudioPCMBuffer {
        buffer(seconds: 0.5) { t in
            var v: Double = 0
            for k in 0..<5 {
                let tk = Double(k) * 0.1
                if t >= tk {
                    let dt = t - tk
                    v += (self.srand(Double(k) * 7.13 + 1) - 0.5) * exp(-dt * 45) * 0.9
                }
            }
            v += sin(2 * .pi * 110 * t) * 0.12
            return Float(v * 0.8)
        }
    }

    /// Loopable smoothed brown-ish noise bed.
    private func makeBrownNoise() -> AVAudioPCMBuffer {
        var last = 0.0
        var x = 0.0
        return buffer(seconds: 2.0) { _ in
            x += 1
            let white = self.srand(x * 0.6180339887) - 0.5
            last = (last + 0.02 * white) / 1.02
            // crossfade loop seam
            return Float(last * 2.4)
        }
    }

    private func makeClink() -> AVAudioPCMBuffer {
        buffer(seconds: 0.25) { t in
            let v = sin(2 * .pi * 2093 * t) * exp(-t * 28)
                + 0.5 * sin(2 * .pi * 2960 * t) * exp(-t * 40)
                + 0.3 * sin(2 * .pi * 3520 * t) * exp(-t * 55)
            return Float(v * 0.7)
        }
    }

    /// thump-thump + a satisfied "ahhh".
    private func makePerfect() -> AVAudioPCMBuffer {
        buffer(seconds: 0.9) { t in
            var v = 0.0
            // two low thumps at 0s and 0.12s
            for start in [0.0, 0.12] where t >= start {
                let dt = t - start
                v += sin(2 * .pi * 85 * dt) * exp(-dt * 16) * 0.9
            }
            // "ahhh": formant-ish stack with vibrato, from 0.2s
            if t >= 0.2 {
                let dt = t - 0.2
                let env = min(1, dt / 0.08) * exp(-max(0, dt - 0.35) * 6)
                let vib = 1 + 0.04 * sin(2 * .pi * 5.5 * dt)
                v += (0.5 * sin(2 * .pi * 620 * vib * dt)
                    + 0.3 * sin(2 * .pi * 930 * vib * dt)
                    + 0.15 * sin(2 * .pi * 1240 * vib * dt)) * env * 0.5
            }
            return Float(v)
        }
    }

    /// Sad-trombone-adjacent descending wah (under-pour).
    private func makeSadTrombone() -> AVAudioPCMBuffer {
        var phase = 0.0
        let sr = 44100.0
        return buffer(seconds: 0.8) { t in
            let freq = 220 - 120 * (t / 0.8)
            phase += 2 * .pi * freq / sr
            let env = min(1, t / 0.05) * (1 - pow(t / 0.8, 3))
            let v = sin(phase) + 0.35 * sin(2 * phase) + 0.15 * sin(3 * phase)
            return Float(v * env * 0.35)
        }
    }

    /// Rising gulp slide (over-chug, "down the hatch").
    private func makeGulpSlide() -> AVAudioPCMBuffer {
        var phase = 0.0
        let sr = 44100.0
        return buffer(seconds: 0.5) { t in
            let freq = 260 + 420 * (t / 0.5)
            phase += 2 * .pi * freq / sr
            let env = min(1, t / 0.04) * (1 - pow(t / 0.5, 2.5))
            let v = sin(phase) + 0.3 * sin(2 * phase)
            return Float(v * env * 0.35)
        }
    }

    /// Decelerating scratch + low thud (cut off).
    private func makeCutOff() -> AVAudioPCMBuffer {
        var x = 0.0
        return buffer(seconds: 0.6) { t in
            x += 1
            let decel = exp(-t * 5)
            let noise = (self.srand(x * 0.773) - 0.5) * decel * 0.8
            let thud = t >= 0.35 ? sin(2 * .pi * 70 * (t - 0.35)) * exp(-(t - 0.35) * 14) : 0
            return Float(noise + thud * 0.8)
        }
    }

    /// Crowd roar bed: layered slow-swelling noise.
    private func makeRoarLoop() -> AVAudioPCMBuffer {
        var x = 0.0
        var last = 0.0
        var last2 = 0.0
        return buffer(seconds: 3.0) { t in
            x += 1
            let white = self.srand(x * 0.4142) - 0.5
            last = (last + 0.06 * white) / 1.06
            last2 = (last2 + 0.015 * white) / 1.015
            let swell = 0.7 + 0.3 * sin(2 * .pi * t / 3.0)
            return Float((last * 1.6 + last2 * 2.2) * swell)
        }
    }

    /// Supporter chant: "oh… oh-oh" pulsed formant bursts on a steady beat.
    /// 2-second bar, pulse on beats 1 and 3.4 — the rhythm is learnable.
    private func makeChantLoop() -> AVAudioPCMBuffer {
        let beats = [0.0, 0.5, 1.0, 1.35]
        return buffer(seconds: 2.0) { t in
            var v = 0.0
            for (i, start) in beats.enumerated() where t >= start {
                let dt = t - start
                let env = min(1, dt / 0.03) * exp(-dt * (i == beats.count - 1 ? 9 : 5))
                // crowd of voices: detuned formant stacks around 180Hz
                for v_idx in 0..<4 {
                    let detune = 1 + (self.srand(Double(v_idx) * 3.7) - 0.5) * 0.08
                    let f = 180 * detune
                    v += (0.5 * sin(2 * .pi * f * dt)
                        + 0.3 * sin(2 * .pi * f * 3 * dt)
                        + 0.2 * sin(2 * .pi * f * 4.5 * dt)) * env * 0.12
                }
            }
            return Float(v)
        }
    }

    /// Sharp wooden crack.
    private func makeBatCrack() -> AVAudioPCMBuffer {
        var x = 0.0
        return buffer(seconds: 0.18) { t in
            x += 1
            let snap = (self.srand(x * 1.319) - 0.5) * exp(-t * 90) * 1.6
            let knock = sin(2 * .pi * 900 * t) * exp(-t * 60) * 0.7
                + sin(2 * .pi * 240 * t) * exp(-t * 35) * 0.5
            return Float(snap + knock)
        }
    }
}
