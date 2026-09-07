import SwiftUI

@main
struct PintLineApp: App {
    @State private var router = AppRouter()
    @State private var debug = DebugSettings()
    @State private var settings = PlayerSettings.shared
    @State private var leaderboards = LeaderboardService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(Persistence.shared)
                .environment(SessionStats.shared)
                .environment(debug)
                .environment(settings)
                .environment(leaderboards)
                .preferredColorScheme(.dark)
                .task { leaderboards.authenticate() }
        }
    }
}

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            switch router.screen {
            case .home:
                HomeView()
            case .venue(let venue):
                VenueProgressView(venue: venue)
            case .level(let venue, let index):
                LevelView(mode: .story(venue, index))
                    .ignoresSafeArea()
            case .endless:
                LevelView(mode: .endless)
                    .ignoresSafeArea()
            case .daily:
                LevelView(mode: .daily)
                    .ignoresSafeArea()
            case .settings:
                SettingsView()
            case .stats:
                StatsView()
            case .leaderboard:
                LeaderboardView()
            }
        }
        .id(router.screen)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: router.screen)
        .onChange(of: scenePhase) { _, newPhase in
            guard router.screen == .endless else { return }
            if newPhase == .active {
                router.endless.resumeInPlace()
            } else {
                router.endless.pauseRun()
            }
        }
    }
}
