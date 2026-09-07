import SwiftUI

/// Instant judgment panel: stars, score, streak, celebration or fail jab.
/// One tap retries or advances — the loop stays fast.
struct LevelCompleteView: View {
    let result: PourResult
    let streak: Int
    let isNightOut: Bool

    private var title: String {
        if result.perfect { return "PERFECT SPLIT" }
        switch result.stars {
        case 3: return "DEAD CENTER"
        case 2: return "CLEAN SPLIT"
        case 1: return "JUST INSIDE"
        default:
            if isNightOut { return "THAT’S LAST CALL" }
            return result.miss == .over ? "ONE GULP TOO FAR" : "CALLED IT EARLY"
        }
    }

    private var action: String {
        if isNightOut && result.stars == 0 { return "tap for your night recap" }
        return result.stars > 0 ? "tap for the next pint" : "tap to try again"
    }

    var body: some View {
        VStack(spacing: 10) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(result.perfect ? Theme.amber : .white)
                    .shadow(color: result.perfect ? Theme.amber.opacity(0.8) : .clear, radius: 12)

                if result.stars > 0, isNightOut {
                    Text("\(streak) SPLITS")
                        .font(.headline.bold().monospacedDigit())
                        .foregroundStyle(Theme.amber)
                } else if result.stars > 0 {
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < result.stars ? "star.fill" : "star")
                                .foregroundStyle(i < result.stars ? Theme.amber : .white.opacity(0.4))
                        }
                    }
                    .font(.title3)
                }

                Text(proximityText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.62))

                Text(action)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 2)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .frame(maxWidth: 340)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }

    private var proximityText: String {
        if result.perfect { return "cream split the center" }
        if result.stars == 0 {
            return result.distance < 0 ? "cream stopped above the target"
                                       : "cream passed below the target"
        }
        if isNightOut { return "cream landed inside the target" }
        let amount = String(format: "%.1f", abs(result.distance))
        return result.distance < 0 ? "\(amount) points above center"
                                   : "\(amount) points below center"
    }
}
