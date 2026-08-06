# The Dew Point

A watchOS app (watchOS 26+) that turns the current temperature and dew point into
a single, glanceable word describing how it feels outside — e.g. _Crisp_,
_Muggy_, _Steamy_. When it's precipitating, the comfort word gives way to
what's falling (_Heavy Rain_, _Scattered Thunderstorms_), taken straight from
WeatherKit's current condition.

Alongside the word there are two numeric complications for the round watch-face
slots: the dew point itself, and the current EPA Air Quality Index. The AQI
comes from [AirNow](https://www.airnow.gov) (WeatherKit carries no air quality
data).

The full temperature/dew-point → word mapping lives in
[COMFORT_TABLE.md](COMFORT_TABLE.md). To explore the bands visually, use the
hosted [comfort band editor](https://dtanner.github.io/the-dew-point/comfort-editor.html).

## Screenshots

The app screen and the watch-face word complication, both showing the same sample
condition (_Muggy_):

<p>
  <img src="https://github.com/dtanner/the-dew-point/releases/download/assets/app.png" width="220" alt="The Dew Point app showing Muggy, 70° / dew 64°">
  &nbsp;&nbsp;
  <img src="https://github.com/dtanner/the-dew-point/releases/download/assets/complications.png" width="240" alt="The Word complication showing Muggy">
</p>

## Contributing

Architecture notes, build instructions, and the AirNow API key setup live in
[CONTRIBUTING.md](CONTRIBUTING.md).
