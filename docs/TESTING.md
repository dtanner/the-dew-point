# The Dew Point — Tester Guide

Thanks for testing! The Dew Point is an Apple Watch app that turns the current
temperature + dew point into one glanceable word — "Crisp", "Muggy", "Sticky" —
so you know how it feels outside without decoding numbers. The main way to use
it is as a **complication on your watch face**, not the full-screen app.

## 1. Install and first launch

1. Install the app from **TestFlight on your iPhone**. It will install onto
   your paired Apple Watch (if it doesn't appear, open the **Watch** app on
   your iPhone → **General** → make sure **Automatic App Install** is on, or
   scroll to Available Apps and install The Dew Point).
2. **Open the app on your watch once** and allow **location access** when
   asked ("While Using the App" is fine). You should see a word like "Warm"
   with the temperature and dew point underneath.

That first open matters: it fetches your local conditions and hands them to
the complications. If you add a complication before ever opening the app, it
may show a placeholder word until you do.

## 2. Add the complications to a watch face

There are three complications. **Which ones appear in the picker depends on
the shape of the slot you tapped** — a rectangular slot only offers the
complications that fit a rectangle, so don't worry if you don't see all three
at once:

| Complication | Shows | Fits in |
| --- | --- | --- |
| **Comfort Word** | The feel, in one word (e.g. "Muggy") | Rectangular slots (like the big middle slot on Modular) and inline slots (the line next to the time) |
| **Dew Point** | The dew point as a number (e.g. "64°") | Circular and corner slots |
| **Air Quality** | The EPA air quality index (e.g. "42"; "AQI 42" in rectangular slots) | Circular, corner, and rectangular slots |

### On the watch

1. Touch and hold your watch face, then tap **Edit**.
2. Swipe to the **Complications** screen.
3. Tap the slot you want to change.
4. Scroll the list to **The Dew Point** and pick the complication.
5. Press the Digital Crown to save.

### From the iPhone (often easier)

1. Open the **Watch** app on your iPhone.
2. Under **My Faces**, tap the face you want to edit.
3. In the **Complications** section, tap a slot and choose **The Dew Point**.

**Suggested setup:** the **Modular** face with the Word complication in the
large middle slot, plus the Dew Point number in one of the small slots — the
feel at a glance, with the number behind it.

## 3. Customize the word (optional)

If a word doesn't match how it feels to you — say the app calls it "Muggy"
and you'd call it "Swampy" — you can override it:

1. Open the app on your watch.
2. Tap **Customize** under the word (it says **Edit word** if you've already
   changed it).
3. Enter your word (up to 14 characters) by dictation, Scribble, or keyboard,
   and tap **Save**.

Your word applies to the current *conditions band*, not just this moment — the
app will use it whenever conditions feel like this again, in the app and on
the complication. **Reset to default** in the same screen removes it. During
rain or snow there's nothing to customize (see below), so the button is hidden.

## 4. What to expect

- **Rain/snow override:** during active precipitation the word is replaced by
  the condition itself — "Heavy Rain", "Scattered Thunderstorms". That's
  intentional.
- **Refresh cadence:** complications update roughly every 30 minutes on their
  own (watchOS limits how often, so it can occasionally be longer). Opening
  the app refreshes them immediately.
- **Air quality is US-only:** the AQI comes from the EPA's AirNow network, so
  outside the US (or far from a reporting station) it shows a dash.
- **Stale or odd reading?** Open the app. If it still looks wrong, that's
  exactly the kind of feedback I want.

## 5. What feedback helps most

- Did the word **feel right** for the conditions? "It said Muggy but it felt
  fine" is the most useful report you can send — include roughly where you
  were and the temp/dew numbers from the app screen if you can.
- Any time the complication showed a **placeholder, stale, or missing** value.
- To send feedback: take a screenshot on the watch (press the Digital Crown +
  side button together — it lands in your iPhone photos; if nothing happens,
  turn on iPhone **Watch** app → **General** → **Enable Screenshots**), then in
  **TestFlight on your iPhone** tap The Dew Point → **Send Beta Feedback**.
