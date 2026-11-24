import Testing
@testable import ThermalComfort

/// `BandLayout` explains `classify` on screen, so these check it against
/// `classify` itself and against the spec's ranges.
struct BandLayoutTests {

    @Test func mildSegmentsMatchTheSpec() {
        let segments = BandLayout.segments(atTempF: 70, dewpointsF: 35...80)
        #expect(segments.map(\.band) == [.mildPleasant, .mildComfy, .mildSticky, .mildMuggy])
        #expect(segments.map(\.dewpointsF) == [35...49, 50...56, 57...62, 63...70])
    }

    // Every sampled dew point lands in the segment `classify` puts it in, and the
    // segments tile the window with no gaps or overlaps.
    @Test func segmentsAgreeWithClassifyEverywhere() {
        for temp in stride(from: -15.0, through: 115.0, by: 2.5) {
            let segments = BandLayout.segments(atTempF: temp, dewpointsF: -20...90)
            let top = min(90, Int(temp.rounded(.down)))
            #expect(segments.first?.dewpointsF.lowerBound == min(-20, top))
            #expect(segments.last?.dewpointsF.upperBound == top)
            for (previous, next) in zip(segments, segments.dropFirst()) {
                #expect(previous.dewpointsF.upperBound + 1 == next.dewpointsF.lowerBound)
                #expect(previous.band != next.band)
            }
            for segment in segments {
                for dew in segment.dewpointsF {
                    #expect(classify(tempF: temp, dewpointF: Double(dew)).band == segment.band, "\(temp)° / dew \(dew)°")
                }
            }
        }
    }

    @Test func temperatureColderThanTheWindowIsOneSegment() {
        let segments = BandLayout.segments(atTempF: 10, dewpointsF: 35...80)
        #expect(segments.map(\.band) == [.bitter])
        #expect(segments.map(\.dewpointsF) == [10...10])
    }

    @Test func temperatureBandsMatchTheSpecRanges() {
        let rows = BandLayout.temperatureBands
        #expect(rows.map(\.temperatureBand) == TemperatureBand.allCases)
        // Outer bounds are the sampling grid's edges.
        #expect(rows.map(\.temperaturesF) == [
            -20...19, 20...31, 32...49, 50...64, 65...74, 75...79, 80...89, 90...99, 100...120,
        ])
    }

    @Test func bandsAreOrderedDriestFirst() {
        let mild = BandLayout.temperatureBands.first { $0.temperatureBand == .mild }
        #expect(mild?.bands.map(\.descriptor) == [.pleasant, .comfy, .sticky, .muggy])
        let veryHot = BandLayout.temperatureBands.first { $0.temperatureBand == .veryHot }
        #expect(veryHot?.bands.map(\.descriptor) == [.dryHeat, .hot, .steamy, .brutal, .danger])
    }

    // Each reachable comfort band shows up in exactly one row, the one its
    // `temperatureBand` names — so nothing is missing from the overview.
    //
    // `hotSteamy` is the one band no reading reaches: in the 80–89°F band,
    // feels-like only rises above the actual temperature at 40%+ humidity, which
    // there needs a dew point of roughly 54–62°F, so "feels 90–96 with dew point
    // under 60" has no real readings. If that rule is retuned to be reachable,
    // this fails and the exemption can go.
    @Test func everyReachableBandAppearsOnceInItsOwnRow() {
        var seen: [ComfortBand] = []
        for row in BandLayout.temperatureBands {
            for entry in row.bands {
                #expect(entry.band.temperatureBand == row.temperatureBand)
                seen.append(entry.band)
            }
        }
        #expect(seen.count == Set(seen).count)
        #expect(!seen.contains(.hotSteamy))
        #expect(seen.count == 35)
    }
}
