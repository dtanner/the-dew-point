import Foundation
import Testing
@testable import ThermalComfort

/// Replays every vector in `parity.csv` — the full integer grid of the spec's
/// valid domain (−30…130°F × −40…temp dew point) — and asserts the Swift port
/// produces the exact same word as the original reference. This is the safety net
/// that lets the thresholds be retuned later with confidence: regen the fixture,
/// watch the diff. (The fixture still carries the spec's original emoji column,
/// now unused — the app no longer shows glyphs.)
struct ParityTests {

    struct Vector {
        let tempF: Double
        let dewpointF: Double
        let word: String
    }

    static func loadVectors() throws -> [Vector] {
        let url = try #require(
            Bundle.module.url(forResource: "parity", withExtension: "csv"),
            "parity.csv resource missing from test bundle"
        )
        let text = try String(contentsOf: url, encoding: .utf8)
        // Split on any newline so the CSV writer's CRLF terminators don't leave a
        // stray carriage return on the last field.
        return text
            .split(whereSeparator: \.isNewline)
            .dropFirst() // header
            .map { line in
                let f = line.split(separator: ",", omittingEmptySubsequences: false)
                return Vector(
                    tempF: Double(f[0])!,
                    dewpointF: Double(f[1])!,
                    word: String(f[2])
                )
            }
    }

    @Test func everyVectorMatchesReference() throws {
        let vectors = try Self.loadVectors()
        #expect(vectors.count > 14_000, "fixture looks truncated: \(vectors.count) rows")

        var mismatches: [String] = []
        for v in vectors {
            let got = describe(tempF: v.tempF, dewpointF: v.dewpointF)
            if got.word != v.word {
                mismatches.append(
                    "temp=\(v.tempF) dp=\(v.dewpointF): expected \(v.word), got \(got.word)"
                )
            }
        }
        let preview = mismatches.prefix(20).joined(separator: "\n")
        #expect(mismatches.isEmpty, "\(mismatches.count) mismatches:\n\(preview)")
    }
}
