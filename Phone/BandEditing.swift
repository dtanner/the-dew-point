import SwiftUI
import ThermalComfort

/// A band picked for editing from the Bands or Words tab, carrying a reading inside
/// it for the custom word to be saved against.
struct BandEdit: Identifiable {
    let band: ComfortBand
    let tempF: Double
    let dewpointF: Double
    let defaultWord: String
    /// The user's word for the band, or `nil` if it shows the default.
    let customWord: String?
    /// Where the band sits, for the editor's footer.
    let range: String
    var id: ComfortBand { band }

    /// Editing `entry` as the user's word list sees it.
    @MainActor
    init(entry: BandEntry, model: ConditionsModel) {
        let word = model.word(for: entry.band, default: entry.descriptor)
        self.init(
            band: entry.band,
            tempF: Double(entry.sampleTempF),
            dewpointF: Double(entry.sampleDewpointF),
            defaultWord: entry.descriptor.word,
            customWord: word == entry.descriptor.word ? nil : word,
            range: entry.rangeDescription
        )
    }

    init(band: ComfortBand, tempF: Double, dewpointF: Double, defaultWord: String, customWord: String?, range: String) {
        self.band = band
        self.tempF = tempF
        self.dewpointF = dewpointF
        self.defaultWord = defaultWord
        self.customWord = customWord
        self.range = range
    }
}

extension View {
    /// Presents the word editor for `edit`, saving through `model`.
    func bandEditor(_ edit: Binding<BandEdit?>, model: ConditionsModel) -> some View {
        sheet(item: edit) { edit in
            CustomWordEditor(
                defaultWord: edit.defaultWord,
                initialText: edit.customWord ?? "",
                isCustomized: edit.customWord != nil,
                bandRange: edit.range,
                onSave: { model.customize($0, tempF: edit.tempF, dewpointF: edit.dewpointF) },
                onReset: { model.removeCustomization(tempF: edit.tempF, dewpointF: edit.dewpointF) }
            )
            .presentationDetents([.medium])
        }
    }
}

/// Sampled temperatures as a label, e.g. "65–74°". Ranges reaching the sampling
/// grid's edges are open-ended ("Below 20°", "100°+"), since the grid's edges
/// aren't real limits.
func temperatureLabel(_ range: ClosedRange<Int>) -> String {
    let grid = BandLayout.temperatureGrid
    switch (range.lowerBound == grid.lowerBound, range.upperBound == grid.upperBound) {
    case (true, true): return "any temperature"
    case (true, false): return "Below \(range.upperBound + 1)°"
    case (false, true): return "\(range.lowerBound)°+"
    case (false, false): return "\(range.lowerBound)–\(range.upperBound)°"
    }
}

extension BandEntry {
    /// Where the band sits, e.g. "65–74°, dew 63°+". Dew points can't exceed the
    /// temperature, so reaching the band's top temperature reads as open-ended.
    var rangeDescription: String {
        "\(temperatureLabel(temperaturesF)), \(dewDescription)"
    }

    /// Just the dew-point half of `rangeDescription`, e.g. "dew 63°+".
    var dewDescription: String {
        switch (dewpointsF.lowerBound == BandLayout.dewpointFloor, dewpointsF.upperBound == temperaturesF.upperBound) {
        case (true, true): "any dew point"
        case (true, false): "dew up to \(dewpointsF.upperBound)°"
        case (false, true): "dew \(dewpointsF.lowerBound)°+"
        case (false, false): "dew \(dewpointsF.lowerBound)–\(dewpointsF.upperBound)°"
        }
    }
}
