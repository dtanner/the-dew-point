import SwiftUI
import ThermalComfort
import WeatherData

/// The Words tab: the user's custom words, then every band with its default and
/// custom word. Custom words belong to a band, not a word — Muggy names four
/// bands, and each can read differently — so every row carries its band's range.
struct WordsView: View {
    let model: ConditionsModel

    @State private var editing: BandEdit?

    var body: some View {
        NavigationStack {
            List {
                savedSection
                ForEach(BandLayout.temperatureBands, id: \.temperatureBand) { row in
                    Section("\(row.temperatureBand.name) · \(temperatureLabel(row.temperaturesF))") {
                        ForEach(row.bands, id: \.band) { entry in
                            Button { editing = BandEdit(entry: entry, model: model) } label: {
                                BandRow(entry: entry, row: row, model: model, isCurrent: entry.band == currentBand)
                            }
                            .listRowBackground(Palette.surface)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Your words")
            .bandEditor($editing, model: model)
        }
    }

    private var savedSection: some View {
        // One row per band. Two saved words can share a band after a threshold
        // change; the newest is the one in effect, as the store resolves it.
        var seenBands = Set<ComfortBand>()
        let saved = model.savedCustomizations.reversed().compactMap { custom in
            BandLayout.entry(for: classify(tempF: custom.tempF, dewpointF: custom.dewpointF).band)
                .map { (custom: custom, entry: $0) }
        }
        .filter { seenBands.insert($0.entry.band).inserted }
        .reversed()
        .map { $0 }
        return Section {
            if saved.isEmpty {
                Text("No custom words yet. Tap any band below to give it your own word.")
                    .foregroundStyle(Color.secondary)
                    .listRowBackground(Palette.surface)
            } else {
                ForEach(saved, id: \.entry.band) { item in
                    Button { editing = BandEdit(entry: item.entry, model: model) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.custom.word)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                            Text("Instead of \(item.entry.descriptor.word) · \(item.entry.rangeDescription)")
                                .font(.footnote)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .listRowBackground(Palette.surface)
                }
                .onDelete { offsets in
                    for custom in offsets.map({ saved[$0].custom }) {
                        model.removeCustomization(tempF: custom.tempF, dewpointF: custom.dewpointF)
                    }
                }
            }
        } header: {
            Text("Saved")
        } footer: {
            Text("Custom words sync to your watch and its complications.")
        }
    }

    private var currentBand: ComfortBand? {
        guard case let .loaded(snapshot, _) = model.phase else { return nil }
        return classify(tempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF).band
    }
}

/// One band: its default word and range, and the user's word or "Default".
/// Grey text uses `Color.secondary`, not `.secondary`: inside a list button the
/// hierarchical style is derived from the accent tint.
private struct BandRow: View {
    let entry: BandEntry
    let row: TemperatureBandRow
    let model: ConditionsModel
    let isCurrent: Bool

    var body: some View {
        let custom = model.customWord(for: entry.band)
        let word = custom ?? entry.descriptor.word
        let isCustom = custom != nil
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(entry.descriptor.word)
                        .foregroundStyle(Color.primary)
                    if isCurrent {
                        Text("Now")
                            .font(.caption2.weight(.semibold))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .foregroundStyle(Palette.background)
                            .background(Color.accentColor, in: Capsule())
                    }
                }
                // The section header already gives the temperatures; repeat them only
                // where the band covers part of the section (Brutal starts above 80°).
                Text(entry.temperaturesF == row.temperaturesF ? entry.dewDescription : entry.rangeDescription)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            Text(isCustom ? word : "Default")
                .fontWeight(isCustom ? .semibold : .regular)
                .foregroundStyle(isCustom ? Color.accentColor : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Change this word")
    }
}
