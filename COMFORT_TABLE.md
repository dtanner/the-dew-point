# Comfort Descriptor Table

The full mapping from **temperature + dew point** to a **word** and an **icon**.
The icon has two renditions: the color **emoji** shown in the app, and the
**SF Symbol** shown in tinted watch-face complications.

This file is the human-readable companion to the source of truth in code
([`ComfortDescriptor.swift`](Sources/ThermalComfort/ComfortDescriptor.swift) for
the word→icon catalog, [`Describe.swift`](Sources/ThermalComfort/Describe.swift)
for the banding) and the [thermal-comfort spec](thermal-comfort-spec.md). It is
meant to be **updated as we get real-world "felt right / felt off" feedback** —
when a band feels wrong on-device, adjust it here and in code together.

> The complication glyphs below are rendered to PNGs by
> [`Scripts/render-symbols.swift`](Scripts/render-symbols.swift) (`just symbols`).
> They are drawn white on a dark square to mimic a watch face and to read on both
> light and dark themes — the **actual tint varies with the user's watch-face
> settings**, so review the glyph choice, not the exact color.

> Notes on inputs:
> - Dew point is clamped to ≤ temperature.
> - **RH** = relative humidity (Magnus formula); some bands switch on RH rather
>   than raw dew point because the same dew point reads very differently across a
>   temperature range.
> - **Feels** = feels-like (heat index when valid, i.e. temp ≥ 80 °F and RH ≥ 40 %;
>   otherwise the actual temperature).
> - Range below −30 °F and above 130 °F is not handled.

## Bitter / Freezing — temp < 32 °F

| Temp (°F) | Condition | Word | Emoji | Complication symbol |
|---|---|---|---|---|
| < 20 | any | Bitter | 🥶 | <img src="images/symbols/thermometer.snowflake.png" width="40" alt="thermometer.snowflake"><br>`thermometer.snowflake` |
| 20–31 | RH > 85 | Raw | 🌫️ | <img src="images/symbols/cloud.fog.fill.png" width="40" alt="cloud.fog.fill"><br>`cloud.fog.fill` |
| 20–31 | RH ≤ 85 | Freezing | ❄️ | <img src="images/symbols/snowflake.png" width="40" alt="snowflake"><br>`snowflake` |

## Cold — 32–49 °F

| Condition | Word | Emoji | Complication symbol |
|---|---|---|---|
| RH > 85 | Raw | 🌫️ | <img src="images/symbols/cloud.fog.fill.png" width="40" alt="cloud.fog.fill"><br>`cloud.fog.fill` |
| dp < temp − 15 | Crisp | 🍃 | <img src="images/symbols/leaf.fill.png" width="40" alt="leaf.fill"><br>`leaf.fill` |
| otherwise | Cold | 🧥 | <img src="images/symbols/thermometer.low.png" width="40" alt="thermometer.low"><br>`thermometer.low` |

## Cool — 50–64 °F (RH-driven)

| Condition | Word | Emoji | Complication symbol |
|---|---|---|---|
| RH > 88 | Clammy | 🌫️ | <img src="images/symbols/humidity.fill.png" width="40" alt="humidity.fill"><br>`humidity.fill` |
| dp < 38 | Crisp | 🍃 | <img src="images/symbols/leaf.fill.png" width="40" alt="leaf.fill"><br>`leaf.fill` |
| dp < 50 | Brisk | 💨 | <img src="images/symbols/wind.png" width="40" alt="wind"><br>`wind` |
| RH < 80 | Comfortable | 🌤️ | <img src="images/symbols/cloud.sun.fill.png" width="40" alt="cloud.sun.fill"><br>`cloud.sun.fill` |
| otherwise | Damp | 💧 | <img src="images/symbols/cloud.drizzle.fill.png" width="40" alt="cloud.drizzle.fill"><br>`cloud.drizzle.fill` |

## Mild — 65–74 °F (dew-point-driven, capped at Muggy)

| Dew point (°F) | Word | Emoji | Complication symbol |
|---|---|---|---|
| < 50 | Pleasant | ☀️ | <img src="images/symbols/sun.min.fill.png" width="40" alt="sun.min.fill"><br>`sun.min.fill` |
| 50–56 | Comfortable | 🌤️ | <img src="images/symbols/cloud.sun.fill.png" width="40" alt="cloud.sun.fill"><br>`cloud.sun.fill` |
| 57–62 | Sticky | 💦 | <img src="images/symbols/drop.fill.png" width="40" alt="drop.fill"><br>`drop.fill` |
| 63+ | Muggy | 😓 | <img src="images/symbols/cloud.fill.png" width="40" alt="cloud.fill"><br>`cloud.fill` |

## Warm — 75–79 °F (dew-point-driven)

| Dew point (°F) | Word | Emoji | Complication symbol |
|---|---|---|---|
| < 48 | Balmy | 🌞 | <img src="images/symbols/sun.haze.fill.png" width="40" alt="sun.haze.fill"><br>`sun.haze.fill` |
| 48–56 | Warm | ☀️ | <img src="images/symbols/sun.max.fill.png" width="40" alt="sun.max.fill"><br>`sun.max.fill` |
| 57–62 | Sticky | 💦 | <img src="images/symbols/drop.fill.png" width="40" alt="drop.fill"><br>`drop.fill` |
| 63–69 | Muggy | 😓 | <img src="images/symbols/cloud.fill.png" width="40" alt="cloud.fill"><br>`cloud.fill` |
| 70+ | Oppressive | 😰 | <img src="images/symbols/thermometer.high.png" width="40" alt="thermometer.high"><br>`thermometer.high` |

## Hot — 80–89 °F (feels-like-driven)

| Feels (°F) | Dew point (°F) | Word | Emoji | Complication symbol |
|---|---|---|---|---|
| < 84 | any | Warm | 🌞 | <img src="images/symbols/sun.max.fill.png" width="40" alt="sun.max.fill"><br>`sun.max.fill` |
| 84–89 | < 62 | Hot | 🌡️ | <img src="images/symbols/thermometer.medium.png" width="40" alt="thermometer.medium"><br>`thermometer.medium` |
| 84–89 | 62–67 | Muggy | 😓 | <img src="images/symbols/cloud.fill.png" width="40" alt="cloud.fill"><br>`cloud.fill` |
| 84–89 | 68+ | Oppressive | 😰 | <img src="images/symbols/thermometer.high.png" width="40" alt="thermometer.high"><br>`thermometer.high` |
| 90–96 | < 60 | Sweltering | 🔥 | <img src="images/symbols/flame.fill.png" width="40" alt="flame.fill"><br>`flame.fill` |
| 90–96 | 60–67 | Oppressive | 😰 | <img src="images/symbols/thermometer.high.png" width="40" alt="thermometer.high"><br>`thermometer.high` |
| 90–96 | 68+ | Miserable | 😵 | <img src="images/symbols/thermometer.sun.fill.png" width="40" alt="thermometer.sun.fill"><br>`thermometer.sun.fill` |
| 97+ | any | Miserable | 😵 | <img src="images/symbols/thermometer.sun.fill.png" width="40" alt="thermometer.sun.fill"><br>`thermometer.sun.fill` |

## Very Hot — 90–99 °F (dew-point-driven)

| Dew point (°F) | Word | Emoji | Complication symbol |
|---|---|---|---|
| < 45 | Dry Heat | 🌵 | <img src="images/symbols/sun.dust.fill.png" width="40" alt="sun.dust.fill"><br>`sun.dust.fill` |
| 45–54 | Hot | 🌡️ | <img src="images/symbols/thermometer.medium.png" width="40" alt="thermometer.medium"><br>`thermometer.medium` |
| 55–62 | Sweltering | 🔥 | <img src="images/symbols/flame.fill.png" width="40" alt="flame.fill"><br>`flame.fill` |
| 63–67 | Miserable | 😵 | <img src="images/symbols/thermometer.sun.fill.png" width="40" alt="thermometer.sun.fill"><br>`thermometer.sun.fill` |
| 68+ | Dangerous | 🥵 | <img src="images/symbols/exclamationmark.triangle.fill.png" width="40" alt="exclamationmark.triangle.fill"><br>`exclamationmark.triangle.fill` |

## Extreme — 100 °F+ (dew-point-driven)

| Dew point (°F) | Word | Emoji | Complication symbol |
|---|---|---|---|
| < 48 | Scorching | 🏜️ | <img src="images/symbols/sun.max.trianglebadge.exclamationmark.png" width="40" alt="sun.max.trianglebadge.exclamationmark"><br>`sun.max.trianglebadge.exclamationmark` |
| 48–59 | Dangerous | 🥵 | <img src="images/symbols/exclamationmark.triangle.fill.png" width="40" alt="exclamationmark.triangle.fill"><br>`exclamationmark.triangle.fill` |
| 60+ | Deadly | ☠️ | <img src="images/symbols/exclamationmark.octagon.fill.png" width="40" alt="exclamationmark.octagon.fill"><br>`exclamationmark.octagon.fill` |

---

### Known judgment calls

- **Boundary thresholds** (e.g. dp 62 / 68 / 70, the RH cutoffs) were tuned by
  feel, not derived from a single published standard — prime candidates for
  retuning from feedback.
- **"Warm" uses two emoji** — ☀️ in the 75–79 °F band, 🌞 in the 80–89 °F band
  (and Pleasant also uses ☀️). Both share the `sun.max.fill` symbol. Flagged as a
  likely inconsistency to resolve during tuning.
