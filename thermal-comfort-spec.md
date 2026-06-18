# Thermal Comfort Descriptor — App Spec

## Overview

Given **temperature (°F)** and **dew point (°F)**, output a **single word descriptor** and **emoji icon** describing how the conditions feel.

---

## Inputs

| Input | Type | Constraint |
|---|---|---|
| `temp_f` | float | –30 to 130°F |
| `dewpoint_f` | float | ≤ `temp_f` (physics; clamp if needed) |

---

## Supporting Calculations

### Clamp dewpoint
```
dp = min(dewpoint_f, temp_f)
```

### Relative Humidity (Magnus formula)
```
t_c = (temp_f - 32) * 5/9
d_c = (dp - 32) * 5/9
rh  = 100 * exp(17.625 * d_c / (243.04 + d_c))
          / exp(17.625 * t_c / (243.04 + t_c))
rh  = clamp(rh, 0, 100)
```

### Heat Index (Rothfusz regression)
Only valid when `temp_f >= 80` **and** `rh >= 40`. Otherwise `hi = None`.

```
hi = -42.379
   + 2.04901523  * T
   + 10.14333127 * R
   - 0.22475541  * T * R
   - 0.00683783  * T²
   - 0.05391553  * R²
   + 0.00122874  * T² * R
   + 0.00085282  * T  * R²
   - 0.00000199  * T² * R²

# Low-humidity adjustment
if R < 13 and 80 ≤ T ≤ 112:
    hi -= ((13 - R) / 4) * sqrt((17 - |T - 95|) / 17)

# High-humidity adjustment
if R > 85 and 80 ≤ T ≤ 87:
    hi += ((R - 85) / 10) * ((87 - T) / 5)
```

### Feels Like
```
feels = max(temp_f, hi)   # if hi is valid
feels = temp_f            # if hi is None (dry or cool air)
```

---

## Decision Logic

### Bitter / Freezing (temp < 32°F)
| Condition | Word | Icon |
|---|---|---|
| temp < 20 | Bitter | 🥶 |
| temp 20–31, rh > 85 | Raw | 🌫️ |
| temp 20–31, rh ≤ 85 | Freezing | ❄️ |

### Cold (32–49°F)
| Condition | Word | Icon |
|---|---|---|
| rh > 85 | Raw | 🌫️ |
| dp < temp – 15 | Crisp | 🍃 |
| otherwise | Cold | 🧥 |

### Cool (50–64°F)
Uses **RH** thresholds, not raw dewpoint — same dp reads very differently at 57°F vs 63°F.

| Condition | Word | Icon |
|---|---|---|
| rh > 88 | Clammy | 🌫️ |
| dp < 38 | Crisp | 🍃 |
| dp < 50 | Brisk | 💨 |
| rh < 80 | Comfortable | 🌤️ |
| otherwise | Damp | 💧 |

> Example: dp=55 at 57°F → rh=92% → **Clammy**; dp=55 at 63°F → rh=75% → **Comfortable**

### Mild (65–74°F)
Dewpoint-driven. Capped at Muggy — never Oppressive or worse.

| dp | Word | Icon |
|---|---|---|
| < 50 | Pleasant | ☀️ |
| 50–56 | Comfortable | 🌤️ |
| 57–62 | Sticky | 💦 |
| 63+ | Muggy | 😓 |

### Warm (75–79°F)
Dewpoint-driven. Balmy lives here and only here.

| dp | Word | Icon |
|---|---|---|
| < 48 | Balmy | 🌞 |
| 48–56 | Warm | ☀️ |
| 57–62 | Sticky | 💦 |
| 63–69 | Muggy | 😓 |
| 70+ | Oppressive | 😰 |

### Hot (80–89°F)
**Feels-like driven** (heat index + actual temp). Dry air (rh < 40) → `feels = actual`.

| feels | dp | Word | Icon |
|---|---|---|---|
| < 84 | any | Warm | 🌞 |
| 84–89 | < 62 | Hot | 🌡️ |
| 84–89 | 62–67 | Muggy | 😓 |
| 84–89 | 68+ | Oppressive | 😰 |
| 90–96 | < 60 | Sweltering | 🔥 |
| 90–96 | 60–67 | Oppressive | 😰 |
| 90–96 | 68+ | Miserable | 😵 |
| 97+ | any | Miserable | 😵 |

### Very Hot (90–99°F)
| dp | Word | Icon |
|---|---|---|
| < 45 | Dry Heat | 🌵 |
| 45–54 | Hot | 🌡️ |
| 55–62 | Sweltering | 🔥 |
| 63–67 | Miserable | 😵 |
| 68+ | Dangerous | 🥵 |

### Extreme (100°F+)
| dp | Word | Icon |
|---|---|---|
| < 48 | Scorching | 🏜️ |
| 48–59 | Dangerous | 🥵 |
| 60+ | Deadly | ☠️ |

---

## Complete Python Reference Implementation

```python
from math import exp, sqrt

def _rh(temp_f: float, dp_f: float) -> float:
    t, d = (temp_f - 32) * 5/9, (dp_f - 32) * 5/9
    return min(100.0, max(0.0,
        100 * exp(17.625*d / (243.04+d)) / exp(17.625*t / (243.04+t))
    ))

def _hi(temp_f: float, rh: float) -> float | None:
    if temp_f < 80 or rh < 40:
        return None
    T, R = temp_f, rh
    hi = (-42.379 + 2.04901523*T + 10.14333127*R - 0.22475541*T*R
          - 0.00683783*T**2 - 0.05391553*R**2 + 0.00122874*T**2*R
          + 0.00085282*T*R**2 - 0.00000199*T**2*R**2)
    if R < 13 and 80 <= T <= 112:
        hi -= ((13 - R) / 4) * sqrt((17 - abs(T - 95)) / 17)
    elif R > 85 and 80 <= T <= 87:
        hi += ((R - 85) / 10) * ((87 - T) / 5)
    return hi

def describe(temp_f: float, dewpoint_f: float) -> tuple[str, str]:
    dp    = min(dewpoint_f, temp_f)
    rh    = _rh(temp_f, dp)
    hi    = _hi(temp_f, rh)
    feels = max(temp_f, hi) if hi is not None else temp_f

    if temp_f < 20:  return "Bitter",   "🥶"
    if temp_f < 32:  return ("Raw", "🌫️") if rh > 85 else ("Freezing", "❄️")

    if temp_f < 50:
        if rh > 85:           return "Raw",   "🌫️"
        if dp < temp_f - 15:  return "Crisp", "🍃"
        return                       "Cold",  "🧥"

    if temp_f < 65:
        if rh > 88:  return "Clammy",      "🌫️"
        if dp < 38:  return "Crisp",       "🍃"
        if dp < 50:  return "Brisk",       "💨"
        if rh < 80:  return "Comfortable", "🌤️"
        return               "Damp",       "💧"

    if temp_f < 75:
        if dp < 50:  return "Pleasant",    "☀️"
        if dp < 57:  return "Comfortable", "🌤️"
        if dp < 63:  return "Sticky",      "💦"
        return               "Muggy",      "😓"

    if temp_f < 80:
        if dp < 48:  return "Balmy",       "🌞"
        if dp < 57:  return "Warm",        "☀️"
        if dp < 63:  return "Sticky",      "💦"
        if dp < 70:  return "Muggy",       "😓"
        return               "Oppressive", "😰"

    if temp_f < 90:
        if feels < 84:       return "Warm",        "🌞"
        if feels < 90:
            if dp < 62:      return "Hot",          "🌡️"
            if dp < 68:      return "Muggy",        "😓"
            return                   "Oppressive",  "😰"
        if feels < 97:
            if dp < 60:      return "Sweltering",   "🔥"
            if dp < 68:      return "Oppressive",   "😰"
            return                   "Miserable",   "😵"
        return "Miserable", "😵"

    if temp_f < 100:
        if dp < 45:  return "Dry Heat",    "🌵"
        if dp < 55:  return "Hot",         "🌡️"
        if dp < 63:  return "Sweltering",  "🔥"
        if dp < 68:  return "Miserable",   "😵"
        return               "Dangerous",  "🥵"

    if dp < 48:  return "Scorching",  "🏜️"
    if dp < 60:  return "Dangerous",  "🥵"
    return               "Deadly",    "☠️"
```

---

## Known Limitations

- **Boundary thresholds** — the dp cutoffs (e.g. 62, 68, 70) are judgment calls tuned during this session, not derived from a single published standard; may need user testing
- **Below –30°F and above 130°F** not handled
