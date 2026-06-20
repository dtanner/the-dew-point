import SwiftUI
import ThermalComfort
import WeatherData

/// Top-level screen. Routes between loading, loaded, and failed phases and
/// (re)fetches when it appears.
struct ContentView: View {
    @State private var model: ConditionsModel
    @Environment(\.scenePhase) private var scenePhase

    init(model: ConditionsModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView()
            case let .loaded(snapshot, descriptor):
                ConditionsView(snapshot: snapshot, descriptor: descriptor)
            case let .failed(message):
                FailureView(message: message) {
                    Task { await model.refresh() }
                }
            }
        }
        .task { await model.refresh() }
        // `.task` only runs when the view is first created. watchOS resumes a
        // suspended app without recreating it, so without this a reopen would show
        // the last-rendered (possibly hours-old) reading. Refetch on every return
        // to active; the provider's TTL still gates the actual WeatherKit call.
        // onChange skips the initial `.active`, so cold launch doesn't double-fetch.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
    }
}

/// The hero view: the comfort (or precipitation) word, with the underlying
/// numbers and required weather attribution beneath.
private struct ConditionsView: View {
    let snapshot: WeatherSnapshot
    let descriptor: ComfortDescriptor

    var body: some View {
        VStack(spacing: 2) {
            Text(descriptor.word)
                .font(.title.weight(.semibold))
                // Comfort words are single tokens; precipitation words can be two
                // ("Scattered Thunderstorms"). Allow a second line and scale down
                // before truncating so the longest still fit a 40mm face.
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text("\(fahrenheit: snapshot.temperatureF) · dew \(fahrenheit: snapshot.dewpointF)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            AttributionView()
                .padding(.top, 2)
        }
        .multilineTextAlignment(.center)
    }
}

private struct FailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
            Text(message)
                .font(.caption2)
                .multilineTextAlignment(.center)
            Button("Retry", action: retry)
        }
        .padding(.horizontal)
    }
}

/// WeatherKit-required attribution. Shows the data-source name linked to Apple's
/// legal page. The official Apple Weather mark image (from
/// `WeatherAttribution.combinedMark*URL`) should replace the text before App
/// Store submission.
private struct AttributionView: View {
    @State private var legalURL: URL?

    var body: some View {
        Group {
            if let legalURL {
                // .plain so the link reads as subtle text, not a full-width
                // watchOS button competing with the content.
                Link(destination: legalURL) { Text("Weather") }
                    .buttonStyle(.plain)
            } else {
                Text("Weather")
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .task {
            legalURL = try? await WeatherAttributionInfo.legalPageURL()
        }
    }
}

// Formats a °F temperature as a rounded integer with a degree sign.
private extension String.StringInterpolation {
    mutating func appendInterpolation(fahrenheit value: Double) {
        appendLiteral("\(Int(value.rounded()))°")
    }
}

#if DEBUG
#Preview("Muggy") {
    ConditionsView(
        snapshot: WeatherSnapshot(temperatureF: 70, dewpointF: 64, asOf: .now),
        descriptor: describe(tempF: 70, dewpointF: 64)
    )
}

#Preview("Precipitation") {
    let storm = ComfortDescriptor(word: "Scattered Thunderstorms")
    return ConditionsView(
        snapshot: WeatherSnapshot(temperatureF: 72, dewpointF: 66, precipitation: storm, asOf: .now),
        descriptor: storm
    )
}

#Preview("Failed") {
    FailureView(message: "Location is off. Turn it on in Settings to see conditions.") {}
}
#endif
