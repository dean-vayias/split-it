import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 18) {
            // A tulip-shaped pint mark matching the hero glass.
            VStack(spacing: 0) {
                Capsule()
                    .fill(Theme.foam)
                    .frame(width: 62, height: 13)
                UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 20,
                                       bottomTrailingRadius: 20, topTrailingRadius: 8)
                    .fill(Theme.stout)
                    .frame(width: 66, height: 88)
                    .overlay(
                        UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 20,
                                               bottomTrailingRadius: 20, topTrailingRadius: 8)
                            .stroke(Theme.wood, lineWidth: 4)
                    )
            }
            Text("SPLIT IT")
                .font(.system(.largeTitle, design: .rounded).bold())
                .tracking(3)
                .foregroundStyle(Theme.ink)
            Text("please pour responsibly.")
                .font(.callout)
                .italic()
                .foregroundStyle(Theme.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cream.ignoresSafeArea())
    }
}
