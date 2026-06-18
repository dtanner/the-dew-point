import Foundation

/// Pure meteorological calculations backing the comfort descriptor.
///
/// All values are in °F and plain `Double`s (not `Measurement`) to match the
/// reference implementation bit-for-bit — running these through unit conversions
/// would introduce float drift that could flip a borderline threshold.
public enum Meteorology {

    /// Relative humidity (%) from temperature and dew point via the Magnus formula.
    /// Clamped to 0...100.
    public static func relativeHumidity(tempF: Double, dewpointF: Double) -> Double {
        let t = (tempF - 32) * 5 / 9
        let d = (dewpointF - 32) * 5 / 9
        let rh = 100 * exp(17.625 * d / (243.04 + d)) / exp(17.625 * t / (243.04 + t))
        return min(100, max(0, rh))
    }

    /// Heat index (°F) via the Rothfusz regression. Only defined when it is both
    /// hot and humid enough (`tempF >= 80` and `rh >= 40`); returns `nil`
    /// otherwise, signaling that dry/cool air should fall back to actual temp.
    public static func heatIndex(tempF: Double, relativeHumidity rh: Double) -> Double? {
        guard tempF >= 80, rh >= 40 else { return nil }
        let t = tempF, r = rh
        var hi = -42.379
            + 2.04901523 * t
            + 10.14333127 * r
            - 0.22475541 * t * r
            - 0.00683783 * t * t
            - 0.05391553 * r * r
            + 0.00122874 * t * t * r
            + 0.00085282 * t * r * r
            - 0.00000199 * t * t * r * r

        // Low-humidity adjustment.
        if r < 13, (80...112).contains(t) {
            hi -= ((13 - r) / 4) * ((17 - abs(t - 95)) / 17).squareRoot()
        // High-humidity adjustment.
        } else if r > 85, (80...87).contains(t) {
            hi += ((r - 85) / 10) * ((87 - t) / 5)
        }
        return hi
    }

    /// "Feels like" temperature (°F): the heat index when it applies, otherwise
    /// the actual temperature. Never reads cooler than actual.
    public static func feelsLike(tempF: Double, relativeHumidity rh: Double) -> Double {
        if let hi = heatIndex(tempF: tempF, relativeHumidity: rh) {
            return max(tempF, hi)
        }
        return tempF
    }
}
