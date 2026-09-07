import SwiftUI

struct SavedRun: Codable {
    let night: Int
    let stopIndex: Int
    let splits: Int
    let buzz: Double
    let peakBuzz: Double
    let hangoversCleared: Int
    let startedUTCDate: String?
}

struct DailyFiveRun: Codable {
    let day: String
    var points: [Int]
}

struct ProgressData: Codable {
    var stars: [String: Int] = [:]
    /// Highest unlocked venue order index. 0 = only The Pub.
    var unlockedVenue: Int = 0
    var bestNights: Int = 0
    var bestPints: Int = 0
    var bestPeakBAC: Double = 0
    var bestRunScore: Int = 0
    var bestRunNight: Int = 1
    var bestRunPints: Int = 0
    /// North Star: most consecutive successful splits in one uninterrupted run.
    var bestSplitStreak: Int = 0
    /// Separates the new streak record from legacy score-era local values.
    var splitStreakVersion: Int = 0
    var savedRun: SavedRun? = nil
    var pendingAllTimeStreak: Int = 0
    var pendingDailyStreak: Int = 0
    var pendingDailyUTC: String? = nil
    var dailyFiveRun: DailyFiveRun? = nil
    var dailyFiveResults: [String: Int] = [:]
    var pendingDailyFiveScore: Int? = nil
    var pendingDailyFiveUTC: String? = nil
    var selectedSkinVenue: String? = nil
    var dailyBest: [String: Int] = [:]
    var totalAttempts: Int = 0
    var successfulSplits: Int = 0
    var perfectSplits: Int = 0
    /// Unified journey checkpoint. Progress saves at venue boundaries so a
    /// failed run restarts the current stop rather than the entire game.
    var journeyNight: Int = 1
    var journeyStop: Int = 0

    private enum CodingKeys: String, CodingKey {
        case stars, unlockedVenue, bestNights, bestPints, bestPeakBAC
        case bestRunScore, bestRunNight, bestRunPints, bestSplitStreak, splitStreakVersion
        case savedRun, pendingAllTimeStreak, pendingDailyStreak, pendingDailyUTC
        case dailyFiveRun, dailyFiveResults, pendingDailyFiveScore, pendingDailyFiveUTC
        case selectedSkinVenue
        case dailyBest, totalAttempts, successfulSplits, perfectSplits
        case journeyNight, journeyStop
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stars = try c.decodeIfPresent([String: Int].self, forKey: .stars) ?? [:]
        unlockedVenue = try c.decodeIfPresent(Int.self, forKey: .unlockedVenue) ?? 0
        bestNights = try c.decodeIfPresent(Int.self, forKey: .bestNights) ?? 0
        bestPints = try c.decodeIfPresent(Int.self, forKey: .bestPints) ?? 0
        bestPeakBAC = try c.decodeIfPresent(Double.self, forKey: .bestPeakBAC) ?? 0
        bestRunScore = try c.decodeIfPresent(Int.self, forKey: .bestRunScore) ?? 0
        bestRunNight = try c.decodeIfPresent(Int.self, forKey: .bestRunNight) ?? max(1, bestNights)
        bestRunPints = try c.decodeIfPresent(Int.self, forKey: .bestRunPints) ?? bestPints
        bestSplitStreak = try c.decodeIfPresent(Int.self, forKey: .bestSplitStreak) ?? 0
        splitStreakVersion = try c.decodeIfPresent(Int.self, forKey: .splitStreakVersion) ?? 0
        savedRun = try c.decodeIfPresent(SavedRun.self, forKey: .savedRun)
        pendingAllTimeStreak = try c.decodeIfPresent(Int.self, forKey: .pendingAllTimeStreak) ?? 0
        pendingDailyStreak = try c.decodeIfPresent(Int.self, forKey: .pendingDailyStreak) ?? 0
        pendingDailyUTC = try c.decodeIfPresent(String.self, forKey: .pendingDailyUTC)
        dailyFiveRun = try c.decodeIfPresent(DailyFiveRun.self, forKey: .dailyFiveRun)
        dailyFiveResults = try c.decodeIfPresent([String: Int].self, forKey: .dailyFiveResults) ?? [:]
        pendingDailyFiveScore = try c.decodeIfPresent(Int.self, forKey: .pendingDailyFiveScore)
        pendingDailyFiveUTC = try c.decodeIfPresent(String.self, forKey: .pendingDailyFiveUTC)
        selectedSkinVenue = try c.decodeIfPresent(String.self, forKey: .selectedSkinVenue)
        dailyBest = try c.decodeIfPresent([String: Int].self, forKey: .dailyBest) ?? [:]
        totalAttempts = try c.decodeIfPresent(Int.self, forKey: .totalAttempts) ?? 0
        successfulSplits = try c.decodeIfPresent(Int.self, forKey: .successfulSplits) ?? 0
        perfectSplits = try c.decodeIfPresent(Int.self, forKey: .perfectSplits) ?? 0
        journeyNight = try c.decodeIfPresent(Int.self, forKey: .journeyNight) ?? 1
        journeyStop = try c.decodeIfPresent(Int.self, forKey: .journeyStop) ?? 0
    }
}

@Observable
final class Persistence {
    static let shared = Persistence()
    static let routeRounds = 5

    private(set) var data = ProgressData()
    private let key = "pintline.progress.v1"

    private init() {
        if let raw = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ProgressData.self, from: raw) {
            data = decoded
        }
        // The old UI stored a different "best run" concept. Start the new
        // North Star clean instead of presenting that legacy value as a streak.
        if data.splitStreakVersion < 1 {
            data.bestSplitStreak = 0
            data.splitStreakVersion = 1
            save()
        }
        // Existing installs used to require all 25 rounds. Honor any first-five
        // progress immediately under the faster route model.
        var routeIndex = data.unlockedVenue
        while routeIndex < VenueID.allCases.count - 1 {
            let venue = VenueID.allCases[routeIndex]
            let cleared = LevelGenerator.levels(for: venue).prefix(Self.routeRounds)
                .allSatisfy { (data.stars[$0.id] ?? 0) >= 1 }
            guard cleared else { break }
            routeIndex += 1
        }
        if routeIndex != data.unlockedVenue {
            data.unlockedVenue = routeIndex
            save()
        }
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(raw, forKey: key)
        }
    }

    // MARK: Story progress

    func stars(for level: LevelDefinition) -> Int {
        data.stars[level.id] ?? 0
    }

    func record(level: LevelDefinition, stars: Int) {
        let existing = data.stars[level.id] ?? 0
        var changed = false
        if stars > existing {
            data.stars[level.id] = stars
            changed = true
        }
        // The first five rounds advance the route. The remaining twenty are
        // optional mastery rather than a progression wall.
        let venue = level.venue
        if venue.order == data.unlockedVenue, isRouteComplete(venue) {
            data.unlockedVenue = min(VenueID.allCases.count - 1, venue.order + 1)
            changed = true
        }
        if changed { save() }
    }

    func recordOutcome(_ result: PourResult) {
        data.totalAttempts += 1
        if result.stars > 0 { data.successfulSplits += 1 }
        if result.perfect { data.perfectSplits += 1 }
        save()
    }

    func isRouteComplete(_ venue: VenueID) -> Bool {
        LevelGenerator.levels(for: venue).prefix(Self.routeRounds)
            .allSatisfy { (data.stars[$0.id] ?? 0) >= 1 }
    }

    func isComplete(_ venue: VenueID) -> Bool {
        LevelGenerator.levels(for: venue).allSatisfy { (data.stars[$0.id] ?? 0) >= 1 }
    }

    func isUnlocked(_ venue: VenueID) -> Bool {
        venue.order <= data.unlockedVenue
    }

    func totalStars(for venue: VenueID) -> Int {
        LevelGenerator.levels(for: venue).reduce(0) { $0 + (data.stars[$1.id] ?? 0) }
    }

    /// First level index without a star, or 0.
    func firstIncomplete(in venue: VenueID) -> Int {
        for level in LevelGenerator.levels(for: venue).prefix(Self.routeRounds)
            where (data.stars[level.id] ?? 0) == 0 {
            return level.index
        }
        return 0
    }

    var selectedSkin: VenueID? {
        data.selectedSkinVenue.flatMap { VenueID(rawValue: $0) }
    }

    func selectSkin(_ venue: VenueID) {
        guard isUnlocked(venue) else { return }
        data.selectedSkinVenue = venue.rawValue
        save()
    }

    func skin(for fallback: VenueID) -> GlassSkin {
        (selectedSkin ?? fallback).config.glassSkin
    }

    // MARK: Run bests

    func recordRun(splits: Int, peakBuzz: Double) {
        data.bestSplitStreak = max(data.bestSplitStreak, splits)
        // Continue populating legacy fields so existing local data remains
        // forwards/backwards compatible while score and numbered nights leave UI.
        data.bestPints = max(data.bestPints, splits)
        data.bestRunPints = max(data.bestRunPints, splits)
        data.bestPeakBAC = max(data.bestPeakBAC, peakBuzz)
        save()
    }

    func saveRun(_ run: SavedRun) {
        data.savedRun = run
        save()
    }

    func clearSavedRun() {
        guard data.savedRun != nil else { return }
        data.savedRun = nil
        save()
    }

    func queueLeaderboard(streak: Int, dailyUTC: String?) {
        data.pendingAllTimeStreak = max(data.pendingAllTimeStreak, streak)
        if let dailyUTC {
            if data.pendingDailyUTC != dailyUTC {
                data.pendingDailyUTC = dailyUTC
                data.pendingDailyStreak = 0
            }
            data.pendingDailyStreak = max(data.pendingDailyStreak, streak)
        }
        save()
    }

    func discardExpiredDailyLeaderboardScore(currentUTC: String) {
        guard let queuedDay = data.pendingDailyUTC, queuedDay != currentUTC else { return }
        data.pendingDailyUTC = nil
        data.pendingDailyStreak = 0
        save()
    }

    func clearPendingAllTime(upTo score: Int) {
        guard data.pendingAllTimeStreak <= score else { return }
        data.pendingAllTimeStreak = 0
        save()
    }

    func clearPendingDaily(upTo score: Int, utc: String) {
        guard data.pendingDailyUTC == utc, data.pendingDailyStreak <= score else { return }
        data.pendingDailyUTC = nil
        data.pendingDailyStreak = 0
        save()
    }

    func dailyFiveScores(for day: String) -> [Int] {
        guard data.dailyFiveRun?.day == day else { return [] }
        return Array((data.dailyFiveRun?.points ?? []).prefix(DailyFiveScoring.attemptCount))
    }

    func dailyFiveResult(for day: String) -> Int? {
        data.dailyFiveResults[day]
    }

    @discardableResult
    func recordDailyFiveAttempt(day: String, points: Int) -> [Int] {
        var run = data.dailyFiveRun?.day == day
            ? data.dailyFiveRun!
            : DailyFiveRun(day: day, points: [])
        guard run.points.count < DailyFiveScoring.attemptCount else { return run.points }
        run.points.append(min(5, max(0, points)))
        data.dailyFiveRun = run
        if run.points.count == DailyFiveScoring.attemptCount {
            data.dailyFiveResults[day] = run.points.reduce(0, +)
            // Keep the lightweight history bounded while preserving enough
            // completed days for a future Stats calendar.
            if data.dailyFiveResults.count > 90 {
                for key in data.dailyFiveResults.keys.sorted().dropLast(90) {
                    data.dailyFiveResults.removeValue(forKey: key)
                }
            }
        }
        save()
        return run.points
    }

    func queueDailyFiveLeaderboard(score: Int, utc: String) {
        data.pendingDailyFiveScore = min(DailyFiveScoring.maximumPoints, max(0, score))
        data.pendingDailyFiveUTC = utc
        save()
    }

    func discardExpiredDailyFiveScore(currentUTC: String) {
        guard let queued = data.pendingDailyFiveUTC, queued != currentUTC else { return }
        data.pendingDailyFiveScore = nil
        data.pendingDailyFiveUTC = nil
        save()
    }

    func clearPendingDailyFive(score: Int, utc: String) {
        guard data.pendingDailyFiveUTC == utc,
              data.pendingDailyFiveScore == score else { return }
        data.pendingDailyFiveScore = nil
        data.pendingDailyFiveUTC = nil
        save()
    }

    func recordDaily(key: String, score: Int) {
        data.dailyBest[key] = max(data.dailyBest[key] ?? 0, score)
        save()
    }

    func recordJourneyCheckpoint(night: Int, stop: Int) {
        data.journeyNight = max(1, night)
        data.journeyStop = max(0, stop)
        save()
    }

    func unlockJourneyVenue(_ venue: VenueID) {
        guard venue.order > data.unlockedVenue else { return }
        data.unlockedVenue = venue.order
        save()
    }
}
