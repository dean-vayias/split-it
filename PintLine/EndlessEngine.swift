import SwiftUI

/// A single continuous night out. Every attempt begins fresh; buzz rises with
/// successful splits, briefly recedes at each hangover, and eventually lives
/// near the cap until the player misses.
@Observable
final class EndlessEngine {
    enum Phase: Equatable {
        case pouring
        case cutOff
    }

    struct VenueArrival: Equatable {
        let kicker: String
        let title: String
        let icon: String
    }

    private(set) var night = 1
    private(set) var pints = 0
    private(set) var bac: Double = 0
    private(set) var peakBAC: Double = 0
    private(set) var phase: Phase = .pouring
    private(set) var current: GameEngine
    private(set) var isCapstone = false
    private(set) var arrival: VenueArrival?

    private struct JourneyStop {
        let venue: VenueID
        let hangover: Bool
        let time: String?
    }

    /// Every stop is one split. Venue changes happen without an interstitial.
    private var stops: [JourneyStop] = []
    private var stopIndex = 0
    private var hangoversClearedThisRun = 0
    private(set) var hasActiveRun = false
    private var runStartUTCDate = LeaderboardService.utcDayKey()
    private var arrivalToken = UUID()

    private static let maximumBuzz = 0.35
    private static let buzzPerSplit = 0.022

    var homeNight: Int { homeDisplayCheckpoint.night }
    var homeVenue: VenueID { homeStop.venue }
    var hasResumableRun: Bool { hasActiveRun || Persistence.shared.data.savedRun != nil }
    var resumableSplits: Int { hasActiveRun ? pints : Persistence.shared.data.savedRun?.splits ?? 0 }
    var homeNextVenue: VenueID? {
        let checkpoint = homeDisplayCheckpoint
        let sequence = Self.makeStops(for: checkpoint.night)
        if sequence[checkpoint.stop].hangover {
            let next = normalizedPersistedCheckpoint
            return Self.makeStops(for: next.night)[next.stop].venue
        }
        if let next = sequence.dropFirst(checkpoint.stop + 1).first(where: { !$0.hangover }) {
            return next.venue
        }
        return Self.makeStops(for: checkpoint.night + 1).first?.venue
    }

    private var homeStop: JourneyStop {
        let checkpoint = homeDisplayCheckpoint
        return Self.makeStops(for: checkpoint.night)[checkpoint.stop]
    }

    private var homeDisplayCheckpoint: (night: Int, stop: Int) {
        if hasActiveRun, stops.indices.contains(stopIndex) {
            return (night, stopIndex)
        }
        if let saved = Persistence.shared.data.savedRun {
            let savedNight = max(1, saved.night)
            let sequence = Self.makeStops(for: savedNight)
            return (savedNight, min(max(0, saved.stopIndex), sequence.count - 1))
        }
        return normalizedPersistedCheckpoint
    }

    /// Hangovers are transient run milestones, never durable journey entry points.
    private var normalizedPersistedCheckpoint: (night: Int, stop: Int) {
        let persistedNight = max(1, Persistence.shared.data.journeyNight)
        let sequence = Self.makeStops(for: persistedNight)
        let persistedStop = min(max(0, Persistence.shared.data.journeyStop), sequence.count - 1)
        return sequence[persistedStop].hangover ? (persistedNight + 1, 0)
                                                 : (persistedNight, persistedStop)
    }

    init() {
        current = GameEngine(level: LevelGenerator.endless(venue: .pub, bac: 0, night: 1, seed: 0, hangover: false))
    }

    func beginRun() {
        Persistence.shared.clearSavedRun()
        SessionStats.shared.reset()
        let checkpoint = normalizedPersistedCheckpoint
        night = checkpoint.night
        pints = 0
        hangoversClearedThisRun = 0
        runStartUTCDate = LeaderboardService.utcDayKey()
        hasActiveRun = true
        buildNight()
        stopIndex = checkpoint.stop
        Persistence.shared.recordJourneyCheckpoint(night: night, stop: stopIndex)
        // A new run is equally approachable for every player, regardless of
        // their personal best or how far they have travelled through venues.
        bac = 0
        peakBAC = 0
        dismissArrival()
        spawn()
    }

    func resumeOrBeginRun() {
        if hasActiveRun {
            SessionStats.shared.streak = pints
            return
        }
        guard let saved = Persistence.shared.data.savedRun else {
            beginRun()
            return
        }
        night = max(1, saved.night)
        pints = max(0, saved.splits)
        bac = min(Self.maximumBuzz, max(0, saved.buzz))
        peakBAC = max(bac, saved.peakBuzz)
        hangoversClearedThisRun = max(0, saved.hangoversCleared)
        runStartUTCDate = saved.startedUTCDate ?? LeaderboardService.utcDayKey()
        buildNight()
        stopIndex = min(max(0, saved.stopIndex), max(0, stops.count - 1))
        hasActiveRun = true
        SessionStats.shared.streak = pints
        dismissArrival()
        spawn()
    }

    /// Save at the start of the current split. If the app backgrounds during
    /// an active pour, that one split restarts cleanly instead of draining
    /// unseen or throwing away the whole run.
    func pauseRun() {
        guard hasActiveRun, phase != .cutOff else { return }
        current.stop()
        dismissArrival()
        if let result = current.resolveForPause() {
            handle(result)
            if phase == .cutOff { return }
        }
        phase = .pouring
        persistRun()
        submitCurrentRun()
    }

    func resumeInPlace() {
        guard hasActiveRun, phase == .pouring else { return }
        current.start()
    }

    func abandonRun() {
        guard hasResumableRun else { return }
        let saved = Persistence.shared.data.savedRun
        let splits = resumableSplits
        let started = hasActiveRun ? runStartUTCDate : saved?.startedUTCDate
        Persistence.shared.recordRun(splits: splits, peakBuzz: peakBAC)
        submitToLeaderboards(streak: splits, startedUTC: started)
        current.stop()
        hasActiveRun = false
        Persistence.shared.clearSavedRun()
        SessionStats.shared.reset()
    }

    /// Called when the player taps through a judged pint.
    func handle(_ result: PourResult) {
        guard result.stars > 0 else {
            // Fail is the only way a run ends.
            if isCapstone {
                // The next run begins at the normal venue already waiting
                // beyond this milestone, never back on the hangover itself.
                let next = normalizedPersistedCheckpoint
                Persistence.shared.recordJourneyCheckpoint(night: next.night, stop: next.stop)
            }
            phase = .cutOff
            hasActiveRun = false
            Persistence.shared.clearSavedRun()
            Persistence.shared.recordRun(splits: pints, peakBuzz: peakBAC)
            submitCurrentRun()
            if PlayerSettings.shared.soundEnabled { AudioManager.shared.playCutOff() }
            if PlayerSettings.shared.hapticsEnabled { HapticsManager.shared.failBuzz() }
            return
        }
        pints += 1
        bac = min(Self.maximumBuzz, bac + Self.buzzPerSplit)
        peakBAC = max(peakBAC, bac)
        Persistence.shared.recordRun(splits: pints, peakBuzz: peakBAC)

        if isCapstone {
            // Hangovers create diminishing relief. Early in a long run they
            // provide a real reset; later they only pull the player briefly
            // below maximum buzz before the endurance phase resumes.
            let recovery = max(0.025, 0.06 * pow(0.70, Double(hangoversClearedThisRun)))
            bac = max(0, bac - recovery)
            hangoversClearedThisRun += 1
            let next = normalizedPersistedCheckpoint
            night = next.night
            buildNight()
            stopIndex = next.stop
            Persistence.shared.recordJourneyCheckpoint(night: night, stop: stopIndex)
            let stop = stops[stopIndex]
            spawn()
            showArrival(for: stop)
        } else {
            let next = nextNormalCheckpoint()
            Persistence.shared.recordJourneyCheckpoint(night: next.night, stop: next.stop)

            let normalSplits = pints - hangoversClearedThisRun
            let hangoverDue = normalSplits > 0 && normalSplits.isMultiple(of: 5)
            night = next.night
            buildNight()
            stopIndex = hangoverDue ? (stops.firstIndex(where: \.hangover) ?? next.stop)
                                    : next.stop
            let stop = stops[stopIndex]
            spawn()
            showArrival(for: stop)
        }
    }

    private func nextNormalCheckpoint() -> (night: Int, stop: Int) {
        if let next = stops.indices.dropFirst(stopIndex + 1).first(where: { !stops[$0].hangover }) {
            return (night, next)
        }
        return (night + 1, 0)
    }

    private func showArrival(for stop: JourneyStop) {
        let token = UUID()
        arrivalToken = token
        arrival = VenueArrival(
            kicker: stop.hangover ? "SUNRISE" : (stop.time?.uppercased() ?? "NEXT STOP"),
            title: stop.venue.config.displayName(),
            icon: stop.venue.routeIcon
        )
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.35))
            guard let self, self.arrivalToken == token else { return }
            self.arrival = nil
        }
    }

    private func dismissArrival() {
        arrivalToken = UUID()
        arrival = nil
    }

    #if DEBUG
    func previewArrival() {
        guard stops.indices.contains(stopIndex) else { return }
        let stop = stops[stopIndex]
        arrivalToken = UUID()
        arrival = VenueArrival(
            kicker: stop.hangover ? "SUNRISE" : (stop.time?.uppercased() ?? "NEXT STOP"),
            title: stop.venue.config.displayName(),
            icon: stop.venue.routeIcon
        )
    }
    #endif

    private func spawn() {
        current.stop() // halt the previous engine's frame driver before replacing it
        let stop = stops[stopIndex]
        isCapstone = stop.hangover
        // Difficulty is driven only by buzz in this live run—not by player
        // history, best streak, or persistent venue progress.
        let tol = Tolerances.nightOut(at: bac)
        let level = LevelGenerator.endless(venue: stop.venue, bac: bac, night: night,
                                           seed: pints * 31 + night * 7,
                                           hangover: stop.hangover)
        // Hangovers keep the same universal speed and visible target rules;
        // their challenge comes from the scene treatment.
        current = GameEngine(level: level, tolerances: tol)
        Persistence.shared.unlockJourneyVenue(stop.venue)
        phase = .pouring
        persistRun()
    }

    private func persistRun() {
        guard hasActiveRun else { return }
        Persistence.shared.saveRun(SavedRun(night: night, stopIndex: stopIndex,
                                            splits: pints, buzz: bac, peakBuzz: peakBAC,
                                            hangoversCleared: hangoversClearedThisRun,
                                            startedUTCDate: runStartUTCDate))
    }

    private func submitCurrentRun() {
        submitToLeaderboards(streak: pints, startedUTC: runStartUTCDate)
    }

    private func submitToLeaderboards(streak: Int, startedUTC: String?) {
        Task { @MainActor in
            LeaderboardService.shared.submit(streak: streak, dailyRunStartedUTC: startedUTC)
        }
    }

    private func buildNight() {
        stops = Self.makeStops(for: night)
    }

    private static func makeStops(for night: Int) -> [JourneyStop] {
        var result: [JourneyStop] = []

        func add(_ venue: VenueID, time: String?) {
            result.append(JourneyStop(venue: venue, hangover: false, time: time))
        }

        if night == 1 {
            add(.pub, time: "6 PM")
            add(.dinner, time: "8 PM")
            add(.rooftop, time: "10 PM")
            add(.karaoke, time: "midnight")
            add(.campfire, time: "2 AM")
        } else if night == 2 {
            add(.shower, time: "9 AM")
            add(.beach, time: "noon")
            add(.tailgate, time: "3 PM")
            add(.football, time: "6 PM")
            add(.wedding, time: "10 PM")
        } else {
            let sports: Set<VenueID> = [.football, .baseball, .soccer]
            var remaining = VenueID.allCases
                .filter { $0 != .hangover }
                .sorted {
                    LevelGenerator.unit(seed: "night-\(night)-\($0.rawValue)")
                    < LevelGenerator.unit(seed: "night-\(night)-\($1.rawValue)")
                }
            var selected: [VenueID] = []
            while selected.count < 5, !remaining.isEmpty {
                let candidateIndex = remaining.firstIndex { candidate in
                    guard let last = selected.last else { return true }
                    return !(sports.contains(last) && sports.contains(candidate))
                } ?? 0
                selected.append(remaining.remove(at: candidateIndex))
            }
            for venue in selected {
                add(venue, time: nil)
            }
        }

        result.append(JourneyStop(venue: .hangover, hangover: true, time: "sunrise"))
        return result
    }
}
