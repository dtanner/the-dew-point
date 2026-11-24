/// The temperature bands `classify` is organized into — the spec's top-level
/// sections. Each `ComfortBand` belongs to exactly one.
///
/// Only the grouping lives here, not the boundaries: `BandLayout` finds each band's
/// temperature range by sampling `classify`, so retuning a threshold there can't
/// leave a stale range on screen.
public enum TemperatureBand: CaseIterable, Hashable, Sendable {
    case bitter, subfreezing, cold, cool, mild, warm, hot, veryHot, extreme

    /// The spec's name for the band, e.g. "Mild".
    public var name: String {
        switch self {
        case .bitter: "Bitter"
        case .subfreezing: "Freezing"
        case .cold: "Cold"
        case .cool: "Cool"
        case .mild: "Mild"
        case .warm: "Warm"
        case .hot: "Hot"
        case .veryHot: "Very Hot"
        case .extreme: "Extreme"
        }
    }
}

public extension ComfortBand {
    /// The temperature band this range sits in.
    var temperatureBand: TemperatureBand {
        switch self {
        case .bitter:
            .bitter
        case .subfreezingRaw, .subfreezingFreezing:
            .subfreezing
        case .coldRaw, .coldCrisp, .cold:
            .cold
        case .coolClammy, .coolCrisp, .coolBrisk, .coolComfy, .coolDamp:
            .cool
        case .mildPleasant, .mildComfy, .mildSticky, .mildMuggy:
            .mild
        case .warmBalmy, .warmWarm, .warmSticky, .warmMuggy, .warmStifling:
            .warm
        case .hotWarm, .hotHot, .hotMuggy, .hotStifling,
             .hotSteamy, .hotStiflingHigh, .hotBrutal, .hotBrutalExtreme:
            .hot
        case .veryHotDryHeat, .veryHotHot, .veryHotSteamy, .veryHotBrutal, .veryHotDanger:
            .veryHot
        case .extremeSearing, .extremeDanger, .extremeDeadly:
            .extreme
        }
    }
}

/// A run of whole-degree dew points that all land in one band at a given
/// temperature.
public struct DewPointSegment: Equatable, Sendable {
    public let band: ComfortBand
    public let descriptor: ComfortDescriptor
    /// The sampled dew points (°F) in this run, inclusive.
    public let dewpointsF: ClosedRange<Int>
}

/// One temperature band and the comfort bands inside it, for a "how the words are
/// laid out" overview.
public struct TemperatureBandRow: Equatable, Sendable {
    public let temperatureBand: TemperatureBand
    /// The sampled temperatures (°F) in this band, inclusive. The first and last
    /// rows are open-ended in reality; their outer bound is just the sampling edge.
    public let temperaturesF: ClosedRange<Int>
    /// The comfort bands reachable in this temperature band, driest first (ordered
    /// by the mean dew point at which each occurs).
    public let bands: [(band: ComfortBand, descriptor: ComfortDescriptor)]

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.temperatureBand == rhs.temperatureBand
            && lhs.temperaturesF == rhs.temperaturesF
            && lhs.bands.map(\.band) == rhs.bands.map(\.band)
    }
}

/// Display data describing how `classify` divides up conditions, derived by
/// sampling it on a whole-degree grid rather than restating its thresholds, so it
/// can't drift from the engine.
///
/// Whole degrees are enough here: the readings these explain are shown rounded,
/// and the few non-integer (humidity and feels-like) boundaries land within a
/// degree of where the grid puts them.
public enum BandLayout {
    /// The bands a dew-point sweep at `tempF` passes through, in dew-point order.
    /// Dew points above `tempF` are left out: `classify` clamps them to `tempF`, so
    /// they'd only repeat the top band.
    public static func segments(atTempF tempF: Double, dewpointsF: ClosedRange<Int>) -> [DewPointSegment] {
        let top = min(dewpointsF.upperBound, Int(tempF.rounded(.down)))
        // Colder than the whole window: every dew point in it clamps to `tempF`.
        let bottom = min(dewpointsF.lowerBound, top)
        var segments: [DewPointSegment] = []
        var start = bottom
        var current = classify(tempF: tempF, dewpointF: Double(start))
        for dew in stride(from: bottom + 1, through: top, by: 1) {
            let next = classify(tempF: tempF, dewpointF: Double(dew))
            if next.band != current.band {
                segments.append(DewPointSegment(band: current.band, descriptor: current.descriptor, dewpointsF: start...(dew - 1)))
                start = dew
                current = next
            }
        }
        segments.append(DewPointSegment(band: current.band, descriptor: current.descriptor, dewpointsF: start...top))
        return segments
    }

    /// Every temperature band, coldest first, with the comfort bands inside it.
    public static let temperatureBands: [TemperatureBandRow] = sampleTemperatureBands()

    // The grid spans every band with room to spare: Bitter starts below 20°F and
    // Extreme at 100°F, and dew points this low read the same as any lower ones.
    static let temperatureGrid = -20...120
    static let dewpointFloor = -40

    private static func sampleTemperatureBands() -> [TemperatureBandRow] {
        // Per comfort band: its word and the running dew-point sum/count for ordering.
        struct BandStats {
            let descriptor: ComfortDescriptor
            var dewTotal = 0
            var count = 0
            var meanDew: Double { Double(dewTotal) / Double(count) }
        }
        struct Row {
            let temperatureBand: TemperatureBand
            var temps: ClosedRange<Int>
            var stats: [ComfortBand: BandStats] = [:]
        }

        // Temperature bands are contiguous, so a new row starts whenever the
        // sampled temperature crosses into a different one.
        var rows: [Row] = []
        for temp in temperatureGrid {
            for dew in dewpointFloor...temp {
                let result = classify(tempF: Double(temp), dewpointF: Double(dew))
                if rows.last?.temperatureBand != result.band.temperatureBand {
                    rows.append(Row(temperatureBand: result.band.temperatureBand, temps: temp...temp))
                }
                let last = rows.count - 1
                rows[last].temps = rows[last].temps.lowerBound...temp
                rows[last].stats[result.band, default: BandStats(descriptor: result.descriptor)].dewTotal += dew
                rows[last].stats[result.band]?.count += 1
            }
        }
        return rows.map { row in
            TemperatureBandRow(
                temperatureBand: row.temperatureBand,
                temperaturesF: row.temps,
                bands: row.stats
                    .sorted { $0.value.meanDew < $1.value.meanDew }
                    .map { ($0.key, $0.value.descriptor) }
            )
        }
    }
}
