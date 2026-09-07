import SwiftUI

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(Persistence.self) private var persistence
    @State private var previewEngine = GameEngine(level: LevelGenerator.levels(for: .pub)[0])

    var body: some View {
        GeometryReader { geo in
            let glassHeight = geo.size.height * 0.25
            let anchor = aspectFillPoint(currentVenue.config.glassAnchor, in: geo.size)
            let baseFraction = (GameEngine.glassHeight / 2 + 2) / (GameEngine.glassHeight + 60)
            let glassCenterY = anchor.y - glassHeight * baseFraction
            let topInset = currentTopInset()
            let bottomInset = 28.0

            ZStack {
                VenueBackground(venue: currentVenue)
                LinearGradient(colors: [.black.opacity(0.30), .clear, .black.opacity(0.62)],
                               startPoint: .top, endPoint: .bottom)

                PintView(engine: previewEngine, skin: persistence.skin(for: currentVenue))
                    .frame(width: glassHeight * 0.62, height: glassHeight)
                    // Center against the phone viewport, not the background
                    // image's aspect-fill coordinate space.
                    .frame(width: geo.size.width, height: geo.size.height)
                    .offset(y: glassCenterY - geo.size.height / 2)

                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        Text("SPLIT IT")
                            .font(.system(.title3, design: .rounded).weight(.black))
                            .tracking(3)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.65), radius: 6)

                        Spacer()

                        Button { router.screen = .daily } label: {
                            VStack(alignment: .center, spacing: 1) {
                                Text("DAILY FIVE")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(1)
                                if let score = dailyFiveScore {
                                    Text("\(score) / 25")
                                        .font(.caption.bold().monospacedDigit())
                                } else if dailyFiveAttempts > 0 {
                                    Text("\(dailyFiveAttempts) / 5 PLAYED")
                                        .font(.system(size: 8, weight: .bold).monospacedDigit())
                                        .opacity(0.64)
                                }
                            }
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 13)
                            .padding(.vertical, dailyFiveScore == nil && dailyFiveAttempts == 0 ? 10 : 7)
                            .background(Theme.amber, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(dailyFiveScore.map { "Daily Five score, \($0) out of 25" }
                                            ?? "Play Daily Five")
                    }

                    Spacer()

                    VStack(spacing: 0) {
                        HStack(alignment: .center, spacing: 18) {
                            Text(currentVenue.config.displayName().uppercased())
                                .font(.system(.title2, design: .rounded).weight(.black))
                                .tracking(1.8)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Spacer(minLength: 4)

                            if let nextVenue {
                                nextStopPreview(nextVenue)
                            }
                        }

                        Button(action: startLevel) {
                            VStack(spacing: 2) {
                                Text(journey.hasResumableRun ? "RESUME NIGHT" : "PLAY")
                                    .font(.callout.bold())
                                    .tracking(0.8)

                                if journey.hasResumableRun {
                                    Text("CURRENT STREAK: \(journey.resumableSplits) \(journey.resumableSplits == 1 ? "SPLIT" : "SPLITS")")
                                        .font(.system(size: 9, weight: .bold))
                                        .tracking(0.8)
                                        .opacity(0.68)
                                }
                            }
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 18)
                            .padding(.vertical, journey.hasResumableRun ? 12 : 15)
                            .frame(maxWidth: .infinity)
                            .background(Theme.amber, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 18)

                        if !journey.hasResumableRun {
                            Text("STOP THE FOAM TOP BETWEEN THE LINES")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.7)
                                .foregroundStyle(.white.opacity(0.72))
                                .padding(.top, 8)
                        }
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 7)

                    HStack(spacing: 7) {
                        utilityButton("Stats", icon: "chart.bar.fill", screen: .stats)
                        Spacer(minLength: 0)
                        utilityButton("Leaders", icon: "trophy.fill", screen: .leaderboard)
                        Spacer(minLength: 0)
                        utilityButton("Settings", icon: "slider.horizontal.3", screen: .settings)
                    }
                    .padding(.top, 20)
                }
                .frame(width: geo.size.width - 36,
                       height: geo.size.height - topInset - bottomInset)
                .offset(y: (topInset - bottomInset) / 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            previewEngine = GameEngine(level: previewLevel)
        }
    }

    private var journey: EndlessEngine { router.endless }

    private var currentVenue: VenueID {
        journey.homeVenue
    }

    private var previewLevel: LevelDefinition {
        LevelGenerator.endless(venue: currentVenue, bac: 0, night: journey.homeNight,
                               seed: journey.homeNight * 31, hangover: currentVenue == .hangover)
    }

    private var nextVenue: VenueID? {
        journey.homeNextVenue
    }

    private var dailyFiveDay: String { LeaderboardService.utcDayKey() }

    private var dailyFiveScore: Int? {
        persistence.dailyFiveResult(for: dailyFiveDay)
    }

    private var dailyFiveAttempts: Int {
        persistence.dailyFiveScores(for: dailyFiveDay).count
    }

    private func startLevel() {
        router.screen = .endless
    }

    private func utilityButton(_ title: String, icon: String, screen: Screen) -> some View {
        Button { router.screen = screen } label: {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(.black.opacity(0.48), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func nextStopPreview(_ venue: VenueID) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("UP NEXT")
                .font(.system(size: 8, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.62))
            HStack(spacing: 5) {
                Circle()
                    .fill(Theme.amber)
                    .frame(width: 6, height: 6)
                Capsule()
                    .fill(.white.opacity(0.38))
                    .frame(width: 20, height: 2)
                Image(systemName: venue.routeIcon)
                    .font(.caption2.bold())
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.16), in: Circle())
            }
            Text(venue.config.displayName())
                .font(.caption2.bold())
        }
        .foregroundStyle(.white)
    }

    private func aspectFillPoint(_ anchor: GlassAnchor, in size: CGSize) -> CGPoint {
        let sourceAspect = 1440.0 / 2493.0
        let viewAspect = size.width / max(1, size.height)
        if viewAspect > sourceAspect {
            let imageHeight = size.width / sourceAspect
            return CGPoint(x: anchor.x * size.width,
                           y: anchor.baseY * imageHeight - (imageHeight - size.height) / 2)
        }
        let imageWidth = size.height * sourceAspect
        return CGPoint(x: anchor.x * imageWidth - (imageWidth - size.width) / 2,
                       y: anchor.baseY * size.height)
    }
}

struct VenueProgressView: View {
    let venue: VenueID
    @Environment(AppRouter.self) private var router
    @Environment(Persistence.self) private var persistence
    private let columns = Array(repeating: GridItem(.flexible()), count: 5)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ScreenHeader(title: venue.config.displayName()) { router.screen = .home }

                VStack(spacing: 8) {
                    Image(systemName: venue.routeIcon)
                        .font(.system(size: 42, weight: .bold))
                    Text(venue.config.tagline)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(LinearGradient(colors: venue.config.displayPalette(),
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 24))
                .foregroundStyle(.white)

                let routeDone = persistence.isRouteComplete(venue)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(routeDone ? "LEVELS CLEARED" : "NEXT STOP PROGRESS")
                            .font(.subheadline.bold()).tracking(1)
                        Spacer()
                        Text("First \(Persistence.routeRounds) rounds")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(0..<Persistence.routeRounds, id: \.self) { levelButton($0) }
                    }
                }

                Button {
                    router.screen = .level(venue, persistence.firstIncomplete(in: venue))
                } label: {
                    Label(routeDone ? "Replay levels" : "Continue", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.ink)

                VStack(alignment: .leading, spacing: 12) {
                    Text("MASTERY ROUNDS")
                        .font(.subheadline.bold()).tracking(1)
                    Text("Optional rounds for stars, perfect splits, and bragging rights.")
                        .font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Persistence.routeRounds..<venue.config.levelCount, id: \.self) { levelButton($0) }
                    }
                }
            }
            .padding(18)
        }
        .background(Theme.cream.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
    }

    private func levelButton(_ index: Int) -> some View {
        let level = LevelGenerator.levels(for: venue)[index]
        let stars = persistence.stars(for: level)
        return Button { router.screen = .level(venue, index) } label: {
            VStack(spacing: 3) {
                Text("\(index + 1)").font(.subheadline.bold().monospacedDigit())
                Text(stars == 0 ? "· · ·" : String(repeating: "★", count: stars))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.amber)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(stars > 0 ? Theme.ink.opacity(0.08) : .white.opacity(0.48),
                        in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }
}

struct SettingsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(PlayerSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 18) {
            ScreenHeader(title: "Settings") { router.screen = .home }
            Form {
                Section("FEEDBACK") {
                    Toggle("Sound", isOn: $settings.soundEnabled)
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                }
                Section("COMFORT") {
                    Toggle("Reduce motion", isOn: $settings.reduceMotion)
                    Toggle("Reduce flashes", isOn: $settings.reduceFlashes)
                    Toggle("High-contrast target", isOn: $settings.highContrastTarget)
                }
                Section {
                    Text("Split It is a fictional timing game. It does not estimate real intoxication or provide guidance about alcohol consumption.")
                        .font(.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .environment(\.colorScheme, .light)
            .tint(Theme.amber)
        }
        .padding(.horizontal, 18)
        .background(Theme.cream.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .environment(\.colorScheme, .light)
    }
}

struct StatsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(Persistence.self) private var persistence

    var body: some View {
        VStack(spacing: 20) {
            ScreenHeader(title: "Stats") { router.screen = .home }
            HStack(spacing: 12) {
                stat("Splits", persistence.data.successfulSplits)
                stat("Perfect", persistence.data.perfectSplits)
                stat("Attempts", persistence.data.totalAttempts)
            }
            VStack(spacing: 8) {
                Text("BEST SPLIT STREAK").font(.caption.bold()).tracking(1.5)
                Text("\(persistence.data.bestSplitStreak)")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                Text("SPLITS IN ONE RUN")
                    .font(.callout).foregroundStyle(Theme.ink.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 22))
            Spacer()
        }
        .padding(18)
        .background(Theme.cream.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 5) {
            Text("\(value)").font(.title2.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(Theme.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 18)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 17))
    }
}

struct ScreenHeader: View {
    let title: String
    let back: () -> Void

    var body: some View {
        HStack {
            Button(action: back) {
                Image(systemName: "chevron.left").font(.headline).frame(width: 44, height: 44)
            }
            Spacer()
            Text(title.uppercased()).font(.headline).tracking(2)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(Theme.ink)
    }
}

extension VenueID {
    var routeIcon: String {
        switch self {
        case .pub: "mug.fill"
        case .shower: "shower.fill"
        case .dinner: "fork.knife"
        case .beach: "beach.umbrella.fill"
        case .rooftop: "building.2.fill"
        case .karaoke: "music.mic"
        case .tailgate: "truck.pickup.side.fill"
        case .wedding: "heart.fill"
        case .football: "football.fill"
        case .baseball: "baseball.fill"
        case .soccer: "soccerball"
        case .campfire: "flame.fill"
        case .hangover: "sun.haze.fill"
        }
    }
}
