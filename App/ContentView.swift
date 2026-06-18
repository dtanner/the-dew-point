import SwiftUI
import ThermalComfort
import WeatherData

/// Top-level screen. Routes between loading, loaded, and failed phases and
/// (re)fetches when it appears.
struct ContentView: View {
    @State private var model: ConditionsModel

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
    }
}

/// The hero view: the comfort word and its color emoji, with the underlying
/// numbers and required weather attribution beneath.
private struct ConditionsView: View {
    let snapshot: WeatherSnapshot
    let descriptor: ComfortDescriptor

    var body: some View {
        VStack(spacing: 2) {
            Text(descriptor.emoji)
                .font(.system(size: 40))
            Text(descriptor.word)
                .font(.title3.weight(.semibold))
                .minimumScaleFactor(0.7)
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
                Link("Weather", destination: legalURL)
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
        snapshot: WeatherSnapshot(temperatureF: 86, dewpointF: 72, asOf: .now),
        descriptor: describe(tempF: 86, dewpointF: 72)
    )
}

#Preview("Failed") {
    FailureView(message: "Location is off. Turn it on in Settings to see conditions.") {}
}
#endif
