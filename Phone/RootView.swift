import SwiftUI

/// The iPhone app's tabs. Owns the model's lifecycle work (fetching, refetching on
/// return to the foreground, custom-word sync) so it runs once for the app rather
/// than once per tab.
struct RootView: View {
    @State private var model: ConditionsModel
    @Environment(\.scenePhase) private var scenePhase

    init(model: ConditionsModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        TabView {
            Tab("Now", systemImage: "drop") {
                NowView(model: model)
            }
            Tab("Today", systemImage: "clock") {
                TodayView(model: model)
            }
        }
        // The app's look is built for dark only, matching the watch, where the
        // AQI colors are tuned for a dark background (see AQICategoryColor).
        .preferredColorScheme(.dark)
        .task { await model.refresh() }
        .task { await model.syncCustomizations() }
        // `.task` runs once per view lifetime, and iOS resumes a backgrounded app
        // without recreating it. Refetch on each return to active so a reopen never
        // shows an hours-old reading; the providers' TTLs still gate the network.
        // onChange skips the initial `.active`, so cold launch doesn't double-fetch.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
    }
}
