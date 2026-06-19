import Testing
@testable import ThermalComfort

/// Focused, human-readable cases that document intent the bulk parity grid can't:
/// the spec's worked examples, dew-point clamping, and the boundaries of the
/// valid domain.
struct DescribeTests {

    // Each distinct word should own a distinct complication symbol so the icon
    // complication is unambiguous. The two "Warm" bands intentionally share a
    // symbol, which keying on word allows. Guards against a future descriptor
    // silently reusing another's glyph.
    @Test func distinctWordsHaveDistinctSymbols() {
        var symbolByWord: [String: String] = [:]
        for descriptor in ComfortDescriptor.all {
            if let existing = symbolByWord[descriptor.word] {
                #expect(existing == descriptor.symbol)
            } else {
                symbolByWord[descriptor.word] = descriptor.symbol
            }
        }
        let symbols = Array(symbolByWord.values)
        #expect(Set(symbols).count == symbols.count)
    }

    // The two worked examples from the spec's Cool section — same dew point,
    // different temperature, deliberately different result.
    @Test func coolBandExamplesFromSpec() {
        #expect(describe(tempF: 57, dewpointF: 55) == .clammy)
        #expect(describe(tempF: 63, dewpointF: 55) == .comfortable)
    }

    // Dew point above temperature is unphysical; it must clamp to temp and not
    // change the verdict relative to dp == temp.
    @Test func dewpointClampsToTemperature() {
        let clamped = describe(tempF: 70, dewpointF: 95)
        let atTemp = describe(tempF: 70, dewpointF: 70)
        #expect(clamped == atTemp)
    }

    // "Warm" is the one word the spec emits with two different emojis depending
    // on band. Lock both so a future cleanup is a deliberate, visible change.
    @Test func warmHasTwoBandSpecificEmojis() {
        #expect(describe(tempF: 77, dewpointF: 50) == .warm)        // ☀️
        #expect(describe(tempF: 82, dewpointF: 30) == .warmBright)  // 🌞
        #expect(ComfortDescriptor.warm.emoji == "☀️")
        #expect(ComfortDescriptor.warmBright.emoji == "🌞")
    }

    @Test func extremeColdAndHeatEndpoints() {
        #expect(describe(tempF: -30, dewpointF: -40) == .bitter)
        #expect(describe(tempF: 130, dewpointF: 80) == .deadly)
    }
}
