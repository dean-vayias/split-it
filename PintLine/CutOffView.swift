import SwiftUI

/// Endless game over and shareable run summary.
struct CutOffView: View {
    let endless: EndlessEngine

    @Environment(AppRouter.self) private var router
    @State private var shareImage: Image?

    var body: some View {
        Color(red: 0.05, green: 0.03, blue: 0.02)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 22) {
                    Text("YOU GOT CUT OFF")
                        .font(.system(.title, design: .rounded).bold())
                        .tracking(2)
                        .foregroundStyle(Theme.cream)

                    RecapCard(splits: endless.pints,
                              best: max(Persistence.shared.data.bestSplitStreak, endless.pints))

                    Button("ANOTHER NIGHT") { endless.beginRun() }
                        .font(.headline.bold())
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.amber, in: RoundedRectangle(cornerRadius: 16))

                    Button("GO HOME") { router.screen = .home }
                        .font(.headline.bold())
                        .foregroundStyle(Theme.cream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.cream.opacity(0.30), lineWidth: 1)
                        }

                    if let shareImage {
                        ShareLink(item: shareImage,
                                  preview: SharePreview("Split It — my night out", image: shareImage)) {
                            Label("Share the night", systemImage: "square.and.arrow.up")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Theme.cream)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .task { renderCard() }
    }

    private func renderCard() {
        let renderer = ImageRenderer(content:
            RecapCard(splits: endless.pints,
                      best: max(Persistence.shared.data.bestSplitStreak, endless.pints))
                .frame(width: 340, height: 240)
        )
        renderer.scale = 3
        if let ui = renderer.uiImage {
            shareImage = Image(uiImage: ui)
        }
    }
}

/// The recap card — the viral loop. Must look good enough to post.
struct RecapCard: View {
    let splits: Int
    let best: Int

    var body: some View {
        VStack(spacing: 14) {
            Text("SPLIT IT")
                .font(.caption.weight(.bold))
                .tracking(4)
                .foregroundStyle(Theme.ink.opacity(0.6))

            VStack(spacing: 2) {
                Text("\(splits)")
                    .font(.system(size: 58, weight: .black, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                Text("SPLITS")
                    .font(.caption.bold())
                    .tracking(2)
                    .foregroundStyle(Theme.ink.opacity(0.5))
            }
                .foregroundStyle(Theme.ink)

            Divider().overlay(Theme.ink.opacity(0.15))
            stat(value: best, label: "PERSONAL BEST")
        }
        .padding(28)
        .background(Theme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.amber, lineWidth: 3)
        )
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption2.bold())
                .tracking(1.5)
                .foregroundStyle(Theme.ink.opacity(0.52))
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
    }
}
