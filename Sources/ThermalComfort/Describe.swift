/// Maps temperature and dew point (both °F) to a single comfort descriptor.
///
/// The structure mirrors the spec's temperature bands top to bottom; within each
/// band the rules are kept in source order so this reads alongside the spec
/// document. Dew point is clamped to temperature first (it can't physically
/// exceed it). The 80–89°F band is "feels like" driven; the rest key off dew
/// point or relative humidity directly, as noted per band.
public func describe(tempF: Double, dewpointF: Double) -> ComfortDescriptor {
    let dp = min(dewpointF, tempF)
    let rh = Meteorology.relativeHumidity(tempF: tempF, dewpointF: dp)
    let feels = Meteorology.feelsLike(tempF: tempF, relativeHumidity: rh)

    // Bitter / Freezing — temp < 32°F
    if tempF < 20 { return .bitter }
    if tempF < 32 { return rh > 85 ? .raw : .freezing }

    // Cold — 32–49°F
    if tempF < 50 {
        if rh > 85 { return .raw }
        if dp < tempF - 15 { return .crisp }
        return .cold
    }

    // Cool — 50–64°F (RH-driven: the same dew point feels very different at 57°F
    // vs 63°F).
    if tempF < 65 {
        if rh > 88 { return .clammy }
        if dp < 38 { return .crisp }
        if dp < 50 { return .brisk }
        if rh < 80 { return .comfortable }
        return .damp
    }

    // Mild — 65–74°F (dew-point-driven, capped at Muggy).
    if tempF < 75 {
        if dp < 50 { return .pleasant }
        if dp < 57 { return .comfortable }
        if dp < 63 { return .sticky }
        return .muggy
    }

    // Warm — 75–79°F (dew-point-driven; Balmy lives only here).
    if tempF < 80 {
        if dp < 48 { return .balmy }
        if dp < 57 { return .warm }
        if dp < 63 { return .sticky }
        if dp < 70 { return .muggy }
        return .oppressive
    }

    // Hot — 80–89°F (feels-like driven; dry air falls back to actual temp).
    if tempF < 90 {
        if feels < 84 { return .warmBright }
        if feels < 90 {
            if dp < 62 { return .hot }
            if dp < 68 { return .muggy }
            return .oppressive
        }
        if feels < 97 {
            if dp < 60 { return .sweltering }
            if dp < 68 { return .oppressive }
            return .miserable
        }
        return .miserable
    }

    // Very Hot — 90–99°F (dew-point-driven).
    if tempF < 100 {
        if dp < 45 { return .dryHeat }
        if dp < 55 { return .hot }
        if dp < 63 { return .sweltering }
        if dp < 68 { return .miserable }
        return .dangerous
    }

    // Extreme — 100°F+
    if dp < 48 { return .scorching }
    if dp < 60 { return .dangerous }
    return .deadly
}
