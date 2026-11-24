import SwiftUI
import ThermalComfort
import WeatherData

/// The Now tab: the comfort (or precipitation) word with the numbers beneath, on
/// the same model the watch uses, plus the word changes still to come today.
struct NowView: View {
    let model: ConditionsModel

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
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
    }
}

/// Colors shared by the iPhone screens, matching the app icon's deep navy.
enum Palette {
    static let background = Color(red: 0.024, green: 0.078, blue: 0.114)
    static let surface = Color(red: 0.047, green: 0.137, blue: 0.192)
}

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
        VStack(spacing: 0) {
            Spacer()
            hero
            Spacer()
            let upcoming = model.upcomingChanges.prefix(4)
            if !upcoming.isEmpty {
                ComingUpCard(changes: Array(upcoming))
                    .padding(.bottom, 16)
            }
            footer
        }
        .padding(.horizontal, 16)
        .multilineTextAlignment(.center)
        .sheet(isPresented: $editing) {
            CustomWordEditor(
                defaultWord: model.defaultWord(for: snapshot),
                initialText: isCustomized ? descriptor.word : "",
                isCustomized: isCustomized,
                onSave: { model.customize($0, for: snapshot) },
                onReset: { model.removeCustomization(for: snapshot) }
            )
            .presentationDetents([.medium])
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Text(descriptor.word)
                .font(.system(size: 88, weight: .bold))
                .tracking(-2)
                // Precipitation words can run long ("Scattered Thunderstorms"):
                // allow a second line and shrink before truncating.
                .lineLimit(2)
                .minimumScaleFactor(0.4)
            Text("\(fahrenheit: snapshot.temperatureF) · dew \(fahrenheit: snapshot.dewpointF)")
                .font(.title3)
                .foregroundStyle(.secondary)
            // Absent (not "—") when there's no reading, as on the watch.
            if let aqi = model.aqi {
                AQIPill(aqi: aqi)
                    .padding(.top, 6)
            }
            if isCustomizable {
                Button(isCustomized ? "Edit word" : "Customize word") { editing = true }
                    .font(.body.weight(.medium))
                    .padding(.top, 14)
            }
        }
    }

    /// Data-source credits. WeatherKit requires the Apple Weather mark and legal
    /// link to be visible; AirNow (EPA, public domain) doesn't, but naming it keeps
    /// both feeds accounted for.
    private var footer: some View {
        VStack(spacing: 6) {
            AttributionView()
            Text("Air quality from EPA AirNow")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 12)
    }
}

/// The next few word changes, so a glance tells you whether to expect better or
/// worse later.
private struct ComingUpCard: View {
    let changes: [WordChange]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coming up")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                ForEach(changes, id: \.date) { change in
                    WordChangeRow(change: change)
                }
            }
        }
        .multilineTextAlignment(.leading)
        .card()
    }
}

/// One word change as a grid row: time, word, numbers. Shared by the Now card and
/// the Today list so both read the same way.
struct WordChangeRow: View {
    let change: WordChange
    var label: String?

    var body: some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(label ?? change.date.formatted(.dateTime.hour()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(change.word)
                .font(.body.weight(.semibold))
                .foregroundStyle(change.isPrecipitation ? Color.accentColor : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(fahrenheit: change.temperatureF) · dew \(fahrenheit: change.dewpointF)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

/// The AQI reading with its EPA severity color on the number and dot; the label
/// stays secondary so the color reads as data, not decoration.
private struct AQIPill: View {
    let aqi: Int

    var body: some View {
        let category = AQICategory(aqi: aqi)
        HStack(spacing: 8) {
            Circle()
                .fill(category.color)
                .frame(width: 8, height: 8)
            Text("AQI \(Text("\(aqi)").foregroundStyle(category.color).fontWeight(.semibold))")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .padding(.horizontal, 14)
        .background(Palette.surface, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// Sheet for entering, editing, or clearing the custom word for the current band.
/// Length is capped live and Save is gated on the same validation the model
/// applies, so a rejected word can't be saved silently.
private struct CustomWordEditor: View {
    let defaultWord: String
    let isCustomized: Bool
    let onSave: (String) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @FocusState private var focused: Bool

    init(defaultWord: String, initialText: String, isCustomized: Bool,
         onSave: @escaping (String) -> Void, onReset: @escaping () -> Void) {
        self.defaultWord = defaultWord
        self.isCustomized = isCustomized
        self.onSave = onSave
        self.onReset = onReset
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(defaultWord, text: $text)
                        .font(.title3.weight(.semibold))
                        .focused($focused)
                        .submitLabel(.done)
                        .onChange(of: text) { _, new in
                            if new.count > ComfortWord.maxLength {
                                text = String(new.prefix(ComfortWord.maxLength))
                            }
                        }
                        .onSubmit(save)
                } header: {
                    Text("Instead of “\(defaultWord)”, say")
                } footer: {
                    Text("Applies whenever conditions fall in this band.")
                }
                if isCustomized {
                    Section {
                        Button("Reset to \(defaultWord)", role: .destructive) {
                            onReset()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Your word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(ComfortWord.validate(text) == nil)
                }
            }
            .onAppear { focused = true }
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
        ContentUnavailableView {
            Label("No conditions", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

/// WeatherKit-required attribution: the Apple Weather combined mark, linked to
/// Apple's legal page. Falls back to a "Weather" text link until the mark loads.
private struct AttributionView: View {
    @State private var info: WeatherAttributionInfo?

    var body: some View {
        Group {
            if let info {
                Link(destination: info.legalPageURL) {
                    AsyncImage(url: info.combinedMarkURL) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        Text("Weather")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(height: 14)
                }
                .accessibilityLabel("Weather data from Apple Weather")
            } else {
                Text("Weather")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        // The app is always dark, so request the light (white) mark.
        .task {
            info = try? await WeatherAttributionInfo.load(darkBackground: true)
        }
    }
}

// Formats a °F temperature as a rounded integer with a degree sign.
extension String.StringInterpolation {
    mutating func appendInterpolation(fahrenheit value: Double) {
        appendLiteral("\(Int(value.rounded()))°")
    }
}

#if DEBUG
#Preview("Muggy") {
    RootView(model: ConditionsModel(
        provider: FakeWeatherProvider(snapshot: WeatherSnapshot(temperatureF: 70, dewpointF: 64, asOf: .now)),
        airQuality: FakeAirQualityProvider(aqi: 42),
        forecast: FakeForecastProvider.sampleDay()
    ))
}

#Preview("Precipitation") {
    let storm = ComfortDescriptor(word: "Scattered Thunderstorms")
    return RootView(model: ConditionsModel(
        provider: FakeWeatherProvider(snapshot: WeatherSnapshot(temperatureF: 75, dewpointF: 69, precipitation: storm, asOf: .now))
    ))
}
#endif
