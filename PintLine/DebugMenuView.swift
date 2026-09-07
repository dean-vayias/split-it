import SwiftUI

/// Tuning menu: every BAC effect individually toggleable, BAC override,
/// pixel-distance readout, seasonal window status.
struct DebugMenuView: View {
    @Environment(DebugSettings.self) private var debug
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var debug = debug
        NavigationStack {
            Form {
                Section("BAC effects") {
                    Toggle("Blur", isOn: $debug.blurEnabled)
                    Toggle("Sway", isOn: $debug.swayEnabled)
                    Toggle("Scene tilt", isOn: $debug.tiltEnabled)
                }
                Section("BAC override") {
                    Toggle("Force BAC", isOn: Binding(
                        get: { debug.forcedBAC != nil },
                        set: { debug.forcedBAC = $0 ? 0.15 : nil }
                    ))
                    if debug.forcedBAC != nil {
                        Slider(value: Binding(
                            get: { debug.forcedBAC ?? 0 },
                            set: { debug.forcedBAC = $0 }
                        ), in: 0...0.35, step: 0.01)
                        Text(String(format: "%.2f", debug.forcedBAC ?? 0))
                            .font(.caption.monospacedDigit())
                    }
                }
                Section("Readouts") {
                    Toggle("Show pixel distance", isOn: $debug.showDistances)
                }
                Section("Seasonal windows") {
                    LabeledContent("Big Game Sunday",
                                   value: SeasonalConfig.bigGameSunday.contains() ? "active" : "inactive")
                    LabeledContent("World Cup",
                                   value: SeasonalConfig.worldCup.contains() ? "active" : "inactive")
                    Text("Override via UserDefaults keys seasonal.biggame.start / .end and seasonal.worldcup.start / .end (\"MM-dd\").")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Debug")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
