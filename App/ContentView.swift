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
                ConditionsView(snapshot: snapshot, descriptor: descriptor, model: model)
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
    let model: ConditionsModel

    @State private var editing = false

    // No comfort band is on screen while precipitation is showing, so there's
    // nothing to customize then.
    private var isCustomizable: Bool { snapshot.precipitation == nil }
    private var isCustomized: Bool { model.isCustomized(snapshot) }

    var body: some View {
        VStack(spacing: 2) {
            wordLabel
            Text("\(fahrenheit: snapshot.temperatureF) · dew \(fahrenheit: snapshot.dewpointF)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            AttributionView()
                .padding(.top, 2)
        }
        .multilineTextAlignment(.center)
        .sheet(isPresented: $editing) {
            CustomWordEditor(
                initialText: isCustomized ? descriptor.word : "",
                isCustomized: isCustomized,
                onSave: { model.customize($0, for: snapshot) },
                onReset: { model.removeCustomization(for: snapshot) }
            )
        }
    }

    // Tap the word to customize it. watchOS has no Force Touch, so the old long-press
    // context menu is out; a tap opens the editor sheet, which also offers reset.
    // While precipitation is showing there's no comfort band, so the word is inert.
    @ViewBuilder private var wordLabel: some View {
        if isCustomizable {
            Button { editing = true } label: { styledWord }
                .buttonStyle(.plain)
        } else {
            styledWord
        }
    }

    private var styledWord: some View {
        Text(descriptor.word)
            .font(.title.weight(.semibold))
            // Comfort words are single tokens; precipitation words can be two
            // ("Scattered Thunderstorms"). Allow a second line and scale down before
            // truncating so the longest still fit a 40mm face.
            .lineLimit(2)
            .minimumScaleFactor(0.6)
    }
}

/// Sheet for entering, editing, or clearing the custom comfort word. Tapping the
/// watchOS text field brings up dictation, Scribble, and the keyboard; we take
/// whatever string it returns. Length is capped live and Save is gated on the same
/// validation the model applies, so a rejected word can't be saved silently.
private struct CustomWordEditor: View {
    let isCustomized: Bool
    let onSave: (String) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(initialText: String, isCustomized: Bool, onSave: @escaping (String) -> Void, onReset: @escaping () -> Void) {
        self.isCustomized = isCustomized
        self.onSave = onSave
        self.onReset = onReset
        _text = State(initialValue: initialText)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                TextField("Your word", text: $text)
                    .onChange(of: text) { _, new in
                        if new.count > ComfortWord.maxLength {
                            text = String(new.prefix(ComfortWord.maxLength))
                        }
                    }
                    .onSubmit(save)
                Button("Save", action: save)
                    .disabled(ComfortWord.validate(text) == nil)
                if isCustomized {
                    Button("Reset to default", role: .destructive) {
                        onReset()
                        dismiss()
                    }
                }
            }
            .padding()
        }
    }

    private func save() {
        guard ComfortWord.validate(text) != nil else { return }
        onSave(text)
        dismiss()
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
    let snapshot = WeatherSnapshot(temperatureF: 70, dewpointF: 64, asOf: .now)
    return ConditionsView(
        snapshot: snapshot,
        descriptor: describe(tempF: 70, dewpointF: 64),
        model: ConditionsModel(provider: FakeWeatherProvider(snapshot: snapshot))
    )
}

#Preview("Precipitation") {
    let storm = ComfortDescriptor(word: "Scattered Thunderstorms")
    let snapshot = WeatherSnapshot(temperatureF: 72, dewpointF: 66, precipitation: storm, asOf: .now)
    return ConditionsView(
        snapshot: snapshot,
        descriptor: storm,
        model: ConditionsModel(provider: FakeWeatherProvider(snapshot: snapshot))
    )
}

#Preview("Failed") {
    FailureView(message: "Location is off. Turn it on in Settings to see conditions.") {}
}
#endif
