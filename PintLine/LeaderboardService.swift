import GameKit
import SwiftUI
import UIKit

enum LeaderboardPeriod: String, CaseIterable, Identifiable {
    case dailyFive = "Daily Five"
    case daily = "Today"
    case allTime = "All-Time"

    var id: String { rawValue }

    var leaderboardID: String {
        switch self {
        case .dailyFive: "com.pintline.game.daily_five"
        case .daily: "com.pintline.game.split_streak.daily"
        case .allTime: "com.pintline.game.split_streak.all_time"
        }
    }

    var subtitle: String {
        switch self {
        case .dailyFive: "TODAY’S FIVE-POUR PRECISION"
        case .daily: "BEST STREAK STARTED TODAY"
        case .allTime: "BEST STREAK EVER"
        }
    }

    var unit: String { self == .dailyFive ? "POINTS" : "SPLITS" }

    var footer: String {
        switch self {
        case .dailyFive: "One shared five-pour challenge. Maximum 25 points. Resets daily."
        case .daily: "Longest uninterrupted split streak from a run started today."
        case .allTime: "Longest uninterrupted split streak. Paused nights count."
        }
    }
}

struct LeaderboardStanding: Identifiable, Equatable {
    let id: String
    let rank: Int
    let playerName: String
    let score: Int
    let isLocalPlayer: Bool
}

/// Game Center is the network source of truth. Pending submissions live in
/// Persistence so offline runs are uploaded after the next successful sign-in.
@MainActor @Observable
final class LeaderboardService {
    static let shared = LeaderboardService()

    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    private(set) var entries: [LeaderboardStanding] = []
    private(set) var localStanding: LeaderboardStanding?
    private(set) var message: String?

    private var isSubmitting = false
    private var requestedPeriod: LeaderboardPeriod?
    private var isMocking: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-mock-leaderboard")
        #else
        false
        #endif
    }

    private init() {}

    func authenticate() {
        if isMocking {
            isAuthenticated = true
            message = nil
            return
        }
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let controller {
                    self.present(controller)
                    return
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                self.message = error == nil ? nil : "Game Center sign-in is unavailable right now."
                if self.isAuthenticated {
                    self.message = nil
                    self.flushPendingScores()
                    if let requested = self.requestedPeriod { self.load(requested) }
                }
            }
        }
    }

    func submit(streak: Int, dailyRunStartedUTC: String?) {
        guard streak > 0 else { return }
        let today = Self.utcDayKey()
        let eligibleDay = dailyRunStartedUTC == today ? today : nil
        Persistence.shared.queueLeaderboard(streak: streak, dailyUTC: eligibleDay)
        guard isAuthenticated else { return }
        flushPendingScores()
    }

    func submitDailyFive(score: Int, day: String) {
        guard day == Self.utcDayKey() else { return }
        Persistence.shared.queueDailyFiveLeaderboard(score: score, utc: day)
        guard isAuthenticated else { return }
        flushPendingScores()
    }

    func load(_ period: LeaderboardPeriod) {
        requestedPeriod = period
        if isMocking {
            loadMock(period)
            return
        }
        guard isAuthenticated else {
            entries = []
            localStanding = nil
            message = "Sign in to Game Center to see the leaderboard."
            return
        }

        isLoading = true
        message = nil
        GKLeaderboard.loadLeaderboards(IDs: [period.leaderboardID]) { [weak self] boards, error in
            guard let board = boards?.first, error == nil else {
                DispatchQueue.main.async {
                    guard self?.requestedPeriod == period else { return }
                    self?.finishLoading(error: error, fallback: "Leaderboard isn’t available yet.")
                }
                return
            }
            board.loadEntries(for: .global, timeScope: .allTime,
                              range: NSRange(location: 1, length: 50)) {
                [weak self] local, results, _, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard self.requestedPeriod == period else { return }
                    if let error {
                        self.finishLoading(error: error, fallback: "Couldn’t load scores.")
                        return
                    }
                    self.entries = (results ?? []).map(self.standing(from:))
                    self.localStanding = local.map(self.standing(from:))
                    self.isLoading = false
                    self.message = self.entries.isEmpty
                        ? (period == .dailyFive ? "No Daily Five scores yet. Be the first."
                                                 : "No nights on the board yet. Be the first.")
                        : nil
                }
            }
        }
    }

    private func flushPendingScores() {
        guard isAuthenticated, !isSubmitting else { return }
        let persistence = Persistence.shared
        let today = Self.utcDayKey()
        persistence.discardExpiredDailyLeaderboardScore(currentUTC: today)
        persistence.discardExpiredDailyFiveScore(currentUTC: today)

        if persistence.data.pendingAllTimeStreak > 0 {
            let score = persistence.data.pendingAllTimeStreak
            submit(score: score, to: LeaderboardPeriod.allTime.leaderboardID) { [weak self] succeeded in
                if succeeded { Persistence.shared.clearPendingAllTime(upTo: score) }
                self?.finishSubmission(continueQueue: succeeded)
            }
            return
        }

        if persistence.data.pendingDailyStreak > 0,
           persistence.data.pendingDailyUTC == today {
            let score = persistence.data.pendingDailyStreak
            submit(score: score, to: LeaderboardPeriod.daily.leaderboardID) { [weak self] succeeded in
                if succeeded { Persistence.shared.clearPendingDaily(upTo: score, utc: today) }
                self?.finishSubmission(continueQueue: succeeded)
            }
            return
        }

        if let score = persistence.data.pendingDailyFiveScore,
           persistence.data.pendingDailyFiveUTC == today {
            submit(score: score, to: LeaderboardPeriod.dailyFive.leaderboardID) { [weak self] succeeded in
                if succeeded { Persistence.shared.clearPendingDailyFive(score: score, utc: today) }
                self?.finishSubmission(continueQueue: succeeded)
            }
        }
    }

    private func submit(score: Int, to id: String, completion: @escaping (Bool) -> Void) {
        isSubmitting = true
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [id]) { error in
            DispatchQueue.main.async { completion(error == nil) }
        }
    }

    private func finishSubmission(continueQueue: Bool) {
        isSubmitting = false
        if continueQueue { flushPendingScores() }
    }

    private func standing(from entry: GKLeaderboard.Entry) -> LeaderboardStanding {
        LeaderboardStanding(id: entry.player.gamePlayerID,
                            rank: entry.rank,
                            playerName: entry.player.displayName,
                            score: entry.score,
                            isLocalPlayer: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID)
    }

    private func finishLoading(error: Error?, fallback: String) {
        entries = []
        localStanding = nil
        isLoading = false
        message = fallback
    }

    private func present(_ controller: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var presenter = root
        while let shown = presenter.presentedViewController { presenter = shown }
        presenter.present(controller, animated: true)
    }

    private func loadMock(_ period: LeaderboardPeriod) {
        isAuthenticated = true
        isLoading = false
        message = nil
        let names = ["foamfinder", "LastCallLeo", "You", "SplitDecision", "CreamTop"]
        let scores: [Int]
        switch period {
        case .dailyFive: scores = [25, 23, 21, 19, 17]
        case .daily: scores = [31, 27, 22, 19, 17]
        case .allTime: scores = [146, 121, 94, 88, 76]
        }
        entries = zip(names.indices, zip(names, scores)).map { index, value in
            LeaderboardStanding(id: "mock-\(index)", rank: index + 1,
                                playerName: value.0, score: value.1,
                                isLocalPlayer: value.0 == "You")
        }
        localStanding = entries.first(where: \.isLocalPlayer)
    }

    nonisolated static func utcDayKey(_ date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

struct LeaderboardView: View {
    @Environment(AppRouter.self) private var router
    @Environment(LeaderboardService.self) private var service
    @State private var period: LeaderboardPeriod = .dailyFive

    var body: some View {
        VStack(spacing: 16) {
            ScreenHeader(title: "Leaderboard") { router.screen = .home }

            Picker("Leaderboard", selection: $period) {
                ForEach(LeaderboardPeriod.allCases) { board in
                    Text(board.rawValue).tag(board)
                }
            }
            .pickerStyle(.segmented)

            Text(period.subtitle)
                .font(.caption.bold())
                .tracking(1.5)
                .foregroundStyle(Theme.ink.opacity(0.52))

            if service.isLoading {
                Spacer()
                ProgressView().tint(Theme.amber)
                Spacer()
            } else if !service.isAuthenticated {
                emptyState(icon: "person.crop.circle.badge.exclamationmark",
                           message: service.message ?? "Sign in to Game Center to compete.",
                           button: "SIGN IN") {
                    service.authenticate()
                }
            } else if service.entries.isEmpty {
                emptyState(icon: "trophy", message: service.message ?? "No scores yet.",
                           button: "REFRESH") { service.load(period) }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(service.entries) { standing in
                            leaderboardRow(standing)
                        }
                    }
                }

                if let local = service.localStanding,
                   !service.entries.contains(where: { $0.id == local.id }) {
                    Divider()
                    leaderboardRow(local)
                }
            }

            Text(period.footer)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink.opacity(0.46))
                .padding(.horizontal, 24)
        }
        .padding(18)
        .background(Theme.cream.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .environment(\.colorScheme, .light)
        .task(id: period) { service.load(period) }
    }

    private func leaderboardRow(_ standing: LeaderboardStanding) -> some View {
        HStack(spacing: 14) {
            Text("\(standing.rank)")
                .font(.headline.bold().monospacedDigit())
                .frame(width: 34, alignment: .leading)
                .foregroundStyle(standing.rank <= 3 ? Theme.amber : Theme.ink.opacity(0.48))
            Text(standing.playerName)
                .font(.body.weight(standing.isLocalPlayer ? .bold : .medium))
                .lineLimit(1)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(standing.score)")
                    .font(.title3.bold().monospacedDigit())
                Text(period.unit)
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.ink.opacity(0.45))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(standing.isLocalPlayer ? Theme.amber.opacity(0.20) : .white.opacity(0.58),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func emptyState(icon: String, message: String, button: String,
                            action: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Theme.amber)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink.opacity(0.62))
            Button(button, action: action)
                .font(.callout.bold())
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .background(Theme.ink, in: Capsule())
                .foregroundStyle(Theme.cream)
            Spacer()
        }
    }
}
