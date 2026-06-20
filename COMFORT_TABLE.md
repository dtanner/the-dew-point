# Comfort Descriptor Table

The full mapping from **temperature + dew point** to a single glanceable **word**.

This file is the human-readable companion to the source of truth in code
([`ComfortDescriptor.swift`](Sources/ThermalComfort/ComfortDescriptor.swift) for
the word catalog, [`Describe.swift`](Sources/ThermalComfort/Describe.swift)
for the banding) and the [thermal-comfort spec](thermal-comfort-spec.md). It is
meant to be **updated as we get real-world "felt right / felt off" feedback** —
when a band feels wrong on-device, adjust it here and in code together.

> **Precipitation override:** when something's falling, the comfort word below is
> replaced outright by the precipitation — what's coming down matters more to the
> glance than how the air feels. That word comes straight from WeatherKit's current
> condition (`condition.description`, e.g. "Heavy Rain" or "Scattered
> Thunderstorms"), so it isn't a fixed catalog and isn't part of the
> temperature/dew-point grid below; see
> [`WeatherKitProvider`](Sources/WeatherData/WeatherKitProvider.swift).

> Notes on inputs:
> - Dew point is clamped to ≤ temperature.
> - **RH** = relative humidity (Magnus formula); some bands switch on RH rather
>   than raw dew point because the same dew point reads very differently across a
>   temperature range.
> - **Feels** = feels-like (heat index when valid, i.e. temp ≥ 80 °F and RH ≥ 40 %;
>   otherwise the actual temperature).
> - Range below −30 °F and above 130 °F is not handled.

## Bitter / Freezing — temp < 32 °F

| Temp (°F) | Condition | Word |
|---|---|---|
| < 20 | any | Bitter |
| 20–31 | RH > 85 | Raw |
| 20–31 | RH ≤ 85 | Freezing |

## Cold — 32–49 °F

| Condition | Word |
|---|---|
| RH > 85 | Raw |
| dp < temp − 15 | Crisp |
| otherwise | Cold |

## Cool — 50–64 °F (RH-driven)

| Condition | Word |
|---|---|
| RH > 88 | Clammy |
| dp < 38 | Crisp |
| dp < 50 | Brisk |
| RH < 80 | Comfortable |
| otherwise | Damp |

## Mild — 65–74 °F (dew-point-driven, capped at Muggy)

| Dew point (°F) | Word |
|---|---|
| < 50 | Pleasant |
| 50–56 | Comfortable |
| 57–62 | Sticky |
| 63+ | Muggy |

## Warm — 75–79 °F (dew-point-driven)

| Dew point (°F) | Word |
|---|---|
| < 48 | Balmy |
| 48–56 | Warm |
| 57–62 | Sticky |
| 63–69 | Muggy |
| 70+ | Oppressive |

## Hot — 80–89 °F (feels-like-driven)

| Feels (°F) | Dew point (°F) | Word |
|---|---|---|
| < 84 | any | Warm |
| 84–89 | < 62 | Hot |
| 84–89 | 62–67 | Muggy |
| 84–89 | 68+ | Oppressive |
| 90–96 | < 60 | Sweltering |
| 90–96 | 60–67 | Oppressive |
| 90–96 | 68+ | Miserable |
| 97+ | any | Miserable |

## Very Hot — 90–99 °F (dew-point-driven)

| Dew point (°F) | Word |
|---|---|
| < 45 | Dry Heat |
| 45–54 | Hot |
| 55–62 | Sweltering |
| 63–67 | Miserable |
| 68+ | Dangerous |

## Extreme — 100 °F+ (dew-point-driven)

| Dew point (°F) | Word |
|---|---|
| < 48 | Scorching |
| 48–59 | Dangerous |
| 60+ | Deadly |

---

### Known judgment calls

- **Boundary thresholds** (e.g. dp 62 / 68 / 70, the RH cutoffs) were tuned by
  feel, not derived from a single published standard — prime candidates for
  retuning from feedback.
- **"Warm" spans two bands** (the 75–79 °F dew-point band and the 80–89 °F
  feels-like band). The spec once distinguished them by emoji; now that the app
  shows words only, they're one descriptor.
