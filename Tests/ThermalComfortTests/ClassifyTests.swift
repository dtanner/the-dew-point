import Testing
@testable import ThermalComfort

/// `classify` adds a band identity alongside the descriptor `describe` already
/// returns. These lock the two properties customizations depend on: the descriptor
/// still agrees with `describe`, and band identity tracks the *range*, not the word.
struct ClassifyTests {

    @Test func descriptorMatchesDescribe() {
        for (t, d) in [(70.0, 64.0), (57.0, 55.0), (82.0, 75.0), (-10.0, -20.0), (101.0, 70.0)] {
            #expect(classify(tempF: t, dewpointF: d).descriptor == describe(tempF: t, dewpointF: d))
        }
    }

    // Two readings in the same named range must share a band so a custom word saved
    // at one applies across the whole range.
    @Test func sameRangeSharesABand() {
        #expect(classify(tempF: 70, dewpointF: 64).band == classify(tempF: 73, dewpointF: 66).band)
    }

    // The same word recurs across temperature bands (Muggy lives in Mild, Warm, and
    // Hot). Those are distinct ranges and must be distinct bands, so customizing one
    // doesn't leak into the others.
    @Test func sameWordInDifferentRangesAreDifferentBands() {
        let mild = classify(tempF: 70, dewpointF: 64) // Mild band
        let warm = classify(tempF: 77, dewpointF: 65) // Warm band
        #expect(mild.descriptor == .muggy)
        #expect(warm.descriptor == .muggy)
        #expect(mild.band != warm.band)
    }
}
