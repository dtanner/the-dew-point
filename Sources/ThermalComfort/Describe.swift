/// A stable-within-a-build identifier for one leaf of `classify`'s decision tree —
/// i.e. one named temperature/dew-point range. Two readings that land on the same
/// case fall in the same range, which is how a user's custom word saved at one
/// reading applies across the whole range it belongs to.
///
/// Deliberately **not** persisted. Customizations store the raw (temp, dew) sample
/// and re-derive the band on every read, so retuning the thresholds below simply
/// reclassifies a saved sample into whatever range now contains it — nothing to
/// migrate, and these case names are free to change. Cases are named
/// `<tempBand><descriptor>` so they read against the branches that return them;
/// the same descriptor recurs across temp bands (e.g. Muggy) precisely because
/// those are distinct ranges that happen to share a word.
public enum ComfortBand: Hashable, Sendable {
    case bitter
    case subfreezingRaw, subfreezingFreezing
    case coldRaw, coldCrisp, cold
    case coolClammy, coolCrisp, coolBrisk, coolComfy, coolDamp
    case mildPleasant, mildComfy, mildSticky, mildMuggy
    case warmBalmy, warmWarm, warmSticky, warmMuggy, warmStifling
    case hotWarm, hotHot, hotMuggy, hotStifling
    case hotSteamy, hotStiflingHigh, hotBrutal, hotBrutalExtreme
    case veryHotDryHeat, veryHotHot, veryHotSteamy, veryHotBrutal, veryHotDanger
    case extremeSearing, extremeDanger, extremeDeadly
}

/// Maps temperature and dew point (both °F) to the comfort band they fall in and
/// that band's default descriptor.
///
/// The structure mirrors the spec's temperature bands top to bottom; within each
/// band the rules are kept in source order so this reads alongside the spec
/// document. Dew point is clamped to temperature first (it can't physically
/// exceed it). The 80–89°F band is "feels like" driven; the rest key off dew
/// point or relative humidity directly, as noted per band.
public func classify(tempF: Double, dewpointF: Double) -> (band: ComfortBand, descriptor: ComfortDescriptor) {
    let dp = min(dewpointF, tempF)
    let rh = Meteorology.relativeHumidity(tempF: tempF, dewpointF: dp)
    let feels = Meteorology.feelsLike(tempF: tempF, relativeHumidity: rh)

    // Bitter / Freezing — temp < 32°F
    if tempF < 20 { return (.bitter, .bitter) }
    if tempF < 32 { return rh > 85 ? (.subfreezingRaw, .raw) : (.subfreezingFreezing, .freezing) }

    // Cold — 32–49°F
    if tempF < 50 {
        if rh > 85 { return (.coldRaw, .raw) }
        if dp < tempF - 15 { return (.coldCrisp, .crisp) }
        return (.cold, .cold)
    }

    // Cool — 50–64°F (RH-driven: the same dew point feels very different at 57°F
    // vs 63°F).
    if tempF < 65 {
        if rh > 88 { return (.coolClammy, .clammy) }
        if dp < 38 { return (.coolCrisp, .crisp) }
        if dp < 50 { return (.coolBrisk, .brisk) }
        if rh < 80 { return (.coolComfy, .comfy) }
        return (.coolDamp, .damp)
    }

    // Mild — 65–74°F (dew-point-driven, capped at Muggy).
    if tempF < 75 {
        if dp < 50 { return (.mildPleasant, .pleasant) }
        if dp < 57 { return (.mildComfy, .comfy) }
        if dp < 63 { return (.mildSticky, .sticky) }
        return (.mildMuggy, .muggy)
    }

    // Warm — 75–79°F (dew-point-driven; Balmy lives only here).
    if tempF < 80 {
        if dp < 48 { return (.warmBalmy, .balmy) }
        if dp < 57 { return (.warmWarm, .warm) }
        if dp < 63 { return (.warmSticky, .sticky) }
        if dp < 70 { return (.warmMuggy, .muggy) }
        return (.warmStifling, .stifling)
    }

    // Hot — 80–89°F (feels-like driven; dry air falls back to actual temp).
    if tempF < 90 {
        if feels < 84 { return (.hotWarm, .warm) }
        if feels < 90 {
            if dp < 62 { return (.hotHot, .hot) }
            if dp < 68 { return (.hotMuggy, .muggy) }
            return (.hotStifling, .stifling)
        }
        if feels < 97 {
            if dp < 60 { return (.hotSteamy, .steamy) }
            if dp < 68 { return (.hotStiflingHigh, .stifling) }
            return (.hotBrutal, .brutal)
        }
        return (.hotBrutalExtreme, .brutal)
    }

    // Very Hot — 90–99°F (dew-point-driven).
    if tempF < 100 {
        if dp < 45 { return (.veryHotDryHeat, .dryHeat) }
        if dp < 55 { return (.veryHotHot, .hot) }
        if dp < 63 { return (.veryHotSteamy, .steamy) }
        if dp < 68 { return (.veryHotBrutal, .brutal) }
        return (.veryHotDanger, .danger)
    }

    // Extreme — 100°F+
    if dp < 48 { return (.extremeSearing, .searing) }
    if dp < 60 { return (.extremeDanger, .danger) }
    return (.extremeDeadly, .deadly)
}

/// The comfort descriptor for these conditions — `classify` without the band.
public func describe(tempF: Double, dewpointF: Double) -> ComfortDescriptor {
    classify(tempF: tempF, dewpointF: dewpointF).descriptor
}
