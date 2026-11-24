import SwiftUI
import ThermalComfort
import WeatherData

/// The Bands tab: why the current word is the word (where this reading sits among
/// the words at today's temperature), and an overview of every temperature band.
/// Everything here comes from `BandLayout`, which samples the engine, so it always
/// matches what the watch shows.
struct BandsView: View {
    let model: ConditionsModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if case let .loaded(snapshot, _) = model.phase {
                        CurrentBandCard(snapshot: snapshot, model: model)
                            .card()
                    }
                    Text("All bands")
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                    AllBandsList(model: model, current: currentTemperatureBand)
                        .card()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(Palette.background)
            .navigationTitle("Bands")
        }
    }

    private var currentTemperatureBand: TemperatureBand? {
        guard case let .loaded(snapshot, _) = model.phase else { return nil }
        return classify(tempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF).band.temperatureBand
    }
}

/// "Why <word>?": the words a dew-point sweep passes through at the current
/// temperature, with the reading marked. Tapping a word edits that band's word.
private struct CurrentBandCard: View {
    let snapshot: WeatherSnapshot
    let model: ConditionsModel

    @State private var editing: BandEdit?

    var body: some View {
        let current = classify(tempF: snapshot.temperatureF, dewpointF: snapshot.dewpointF)
        let segments = BandLayout.segments(atTempF: snapshot.temperatureF, dewpointsF: dewWindow)
        let words = segments.map { model.word(for: $0.band, default: $0.descriptor) }
        let index = segments.firstIndex { $0.band == current.band }
        let word = model.word(for: current.band, default: current.descriptor)
        let row = BandLayout.temperatureBands.first { $0.temperatureBand == current.band.temperatureBand }

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Why “\(word)”?")
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("At \(fahrenheit: snapshot.temperatureF), the dew point picks the word. Yours is \(fahrenheit: snapshot.dewpointF).")
                    .foregroundStyle(.secondary)
                if let precipitation = snapshot.precipitation {
                    Text("“\(precipitation.word)” shows while it lasts; underneath, it’s \(word).")
                        .foregroundStyle(.secondary)
                }
            }
            if let row {
                Text("\(row.temperatureBand.name) · \(temperatureLabel(row.temperaturesF))")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            SegmentBar(
                segments: segments,
                words: words,
                currentIndex: index,
                currentDewF: snapshot.dewpointF,
                onTap: { edit(segments, at: $0) }
            )
            if let index {
                neighborHint(segments: segments, words: words, index: index)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .bandEditor($editing, model: model)
    }

    // Dew points to sweep: wide enough to show the dry words below the current
    // band (Dry Heat starts under 45° at 90°+) and the muggy ones up to where real
    // dew points top out, always including the reading itself.
    private var dewWindow: ClosedRange<Int> {
        let dew = Int(snapshot.dewpointF.rounded(.down))
        let low = min(Int(snapshot.temperatureF.rounded(.down)) - 30, 35, dew)
        return low...max(80, dew)
    }

    // What the word would be just drier or just more humid than this band.
    @ViewBuilder
    private func neighborHint(segments: [DewPointSegment], words: [String], index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if index > 0 {
                Text("Dew point under \(segments[index].dewpointsF.lowerBound)° would read \(emphasized(words[index - 1])).")
            }
            if index < segments.count - 1 {
                Text("\(segments[index + 1].dewpointsF.lowerBound)° or more would read \(emphasized(words[index + 1])).")
            }
        }
    }

    private func emphasized(_ word: String) -> Text {
        Text(word).foregroundStyle(.primary).fontWeight(.semibold)
    }

    private func edit(_ segments: [DewPointSegment], at index: Int) {
        let segment = segments[index]
        let range = segment.dewpointsF
        let customWord = model.isCustomized(tempF: snapshot.temperatureF, dewpointF: Double(range.lowerBound))
            ? model.word(for: segment.band, default: segment.descriptor)
            : nil
        editing = BandEdit(
            band: segment.band,
            tempF: snapshot.temperatureF,
            // Any dew point in the run classifies into this band; the middle is as
            // good as any and keeps clear of the edges.
            dewpointF: Double(range.lowerBound + range.upperBound) / 2,
            defaultWord: segment.descriptor.word,
            customWord: customWord,
            range: "at \(Int(snapshot.temperatureF.rounded()))°, dew point \(dewLabel(segments, index))"
        )
    }
}

/// The words across the dew-point sweep as one bar, each word's width following
/// how much of the sweep it covers, with a pin over the current reading.
private struct SegmentBar: View {
    let segments: [DewPointSegment]
    let words: [String]
    let currentIndex: Int?
    let currentDewF: Double
    let onTap: (Int) -> Void

    private let gap: CGFloat = 3
    private let pinHeight: CGFloat = 30
    private let barHeight: CGFloat = 44

    var body: some View {
        GeometryReader { geometry in
            let widths = Self.widths(
                spans: segments.map { CGFloat($0.dewpointsF.count) },
                total: geometry.size.width - gap * CGFloat(segments.count - 1)
            )
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    if let x = pinX(widths: widths) {
                        pin.position(x: x, y: pinHeight / 2)
                    }
                }
                .frame(height: pinHeight)
                HStack(spacing: gap) {
                    ForEach(segments.indices, id: \.self) { index in
                        segmentButton(index, width: widths[index])
                    }
                }
                HStack(spacing: gap) {
                    ForEach(segments.indices, id: \.self) { index in
                        Text(dewLabel(segments, index))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: widths[index], alignment: .leading)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .accessibilityHidden(true)
            }
        }
        .frame(height: pinHeight + barHeight + 22)
    }

    private func segmentButton(_ index: Int, width: CGFloat) -> some View {
        let isCurrent = index == currentIndex
        return Button { onTap(index) } label: {
            Text(words[index])
                .font(.footnote.weight(isCurrent ? .bold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
                .frame(width: width, height: barHeight)
                .foregroundStyle(isCurrent ? Palette.background : Color.primary)
                .background(fill(index), in: shape(index))
                .contentShape(shape(index))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(words[index]), dew point \(dewLabel(segments, index))")
        .accessibilityHint("Change this word")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private var pin: some View {
        VStack(spacing: 2) {
            Text("\(fahrenheit: currentDewF)")
                .font(.caption.weight(.semibold))
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .foregroundStyle(Palette.background)
                .background(Color.primary, in: Capsule())
            Rectangle()
                .fill(Color.primary)
                .frame(width: 2, height: 6)
        }
        .accessibilityHidden(true)
    }

    // The pin sits over the reading inside its own segment, so it lines up with the
    // highlighted word even where segments were widened to fit their labels.
    private func pinX(widths: [CGFloat]) -> CGFloat? {
        guard let currentIndex else { return nil }
        let segment = segments[currentIndex].dewpointsF
        let start = widths[..<currentIndex].reduce(0, +) + gap * CGFloat(currentIndex)
        let fraction = (currentDewF - Double(segment.lowerBound) + 0.5) / Double(segment.count)
        return start + widths[currentIndex] * CGFloat(min(1, max(0, fraction)))
    }

    private func fill(_ index: Int) -> Color {
        if index == currentIndex { return .accentColor }
        let step = segments.count > 1 ? Double(index) / Double(segments.count - 1) : 0
        return Color.accentColor.opacity(0.18 + 0.22 * step)
    }

    private func shape(_ index: Int) -> UnevenRoundedRectangle {
        let outer: CGFloat = 10, inner: CGFloat = 4
        let first = index == 0, last = index == segments.count - 1
        return UnevenRoundedRectangle(
            topLeadingRadius: first ? outer : inner,
            bottomLeadingRadius: first ? outer : inner,
            bottomTrailingRadius: last ? outer : inner,
            topTrailingRadius: last ? outer : inner
        )
    }

    /// Splits `total` across segments in proportion to `spans`, but never narrower
    /// than a word can be read at: segments under the minimum get it, and the rest
    /// share what's left in proportion.
    static func widths(spans: [CGFloat], total: CGFloat) -> [CGFloat] {
        guard !spans.isEmpty, total > 0 else { return spans.map { _ in 0 } }
        let minimum = min(56, total / CGFloat(spans.count))
        var pinned = Set<Int>()
        while true {
            let free = spans.indices.filter { !pinned.contains($0) }
            let freeTotal = total - minimum * CGFloat(pinned.count)
            let freeSpan = free.reduce(0) { $0 + spans[$1] }
            let widths = spans.indices.map { index in
                pinned.contains(index) ? minimum : freeTotal * spans[index] / freeSpan
            }
            let tooNarrow = free.filter { widths[$0] < minimum }
            if tooNarrow.isEmpty { return widths }
            pinned.formUnion(tooNarrow)
        }
    }
}

/// Every temperature band and its words, the current one highlighted.
private struct AllBandsList: View {
    let model: ConditionsModel
    let current: TemperatureBand?

    var body: some View {
        let rows = BandLayout.temperatureBands
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(rows.indices, id: \.self) { index in
                if index > 0 {
                    Divider().gridCellUnsizedAxes(.horizontal)
                }
                let row = rows[index]
                let isCurrent = row.temperatureBand == current
                GridRow {
                    Text(temperatureLabel(row.temperaturesF))
                        .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                        .monospacedDigit()
                    // A no-break space before each dot keeps it on the word's line,
                    // so a wrapped list never starts a line with "·".
                    Text(words(in: row).joined(separator: "\u{00A0}· "))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                .accessibilityElement(children: .combine)
            }
        }
    }

    // A word can name two bands in one row (Stifling, in the 80s); list it once.
    private func words(in row: TemperatureBandRow) -> [String] {
        var seen = Set<String>()
        return row.bands
            .map { model.word(for: $0.band, default: $0.descriptor) }
            .filter { seen.insert($0).inserted }
    }
}

/// A segment's dew points, e.g. "50–56°"; the driest and most humid are
/// open-ended, since the sweep's edges aren't real limits.
private func dewLabel(_ segments: [DewPointSegment], _ index: Int) -> String {
    let range = segments[index].dewpointsF
    if segments.count == 1 { return "any" }
    if index == 0 { return "under \(range.upperBound + 1)°" }
    if index == segments.count - 1 { return "\(range.lowerBound)°+" }
    return "\(range.lowerBound)–\(range.upperBound)°"
}
