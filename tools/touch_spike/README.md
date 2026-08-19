# Touch geometry spike

A throwaway diagnostic, not part of the product. It answers one question on
real hardware:

> Does the tablet report contact geometry that varies meaningfully between a
> fingertip point and an open-palm slap?

The entire palm-mode design in `docs/DESIGN.md` section 5 depends on the answer
being yes. If it is no, palm mode needs redesigning around multi-touch centroid
and dwell instead, and it is far cheaper to learn that now.

## What it captures

A full-screen `Listener` (not a `GestureDetector` — gesture recognisers
arbitrate and discard raw pointer data) records every pointer event:

position, pointer id, phase, `radiusMajor`, `radiusMinor`, `radiusMin`,
`radiusMax`, `size`, `pressure`, `orientation`, `tilt`, and timings.

It also reads `DisplayMetrics.xdpi` / `ydpi` over a platform channel, because
Flutter's `devicePixelRatio` on Android comes from the *bucketed* density
(`densityDpi / 160`) and cannot convert a radius into millimetres.

Live on screen: the contact ellipse for each active pointer, so you can see
immediately whether a palm draws a bigger ellipse than a fingertip, without
waiting to analyse the CSV.

## Capturing Kyle's data

1. Enable Developer Options and USB debugging on the tablet, connect it, and
   accept the debugging prompt.
2. Install:
   ```
   flutter build apk --debug
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```
3. Open the app. Leave **Verbose logcat off** — it distorts the timings.
4. Pick a session label from the dropdown, then capture. Do these as separate
   sessions, tapping **Clear session** between each:

   | Label | What to do | Roughly how many |
   |---|---|---|
   | `point` | You, deliberate fingertip taps all over the screen | 50 |
   | `slap` | Kyle, using it however he naturally does | 50+ |
   | `mixed` | Kyle, unstructured free play | as long as he'll tolerate |
   | `calibration` | Flat palm held still in each corner and the centre | 5 |

   The `point` session is the control: it establishes what a small contact
   looks like on this specific hardware, so the slap numbers have something to
   be compared against.

5. Tap **Export CSV**, then **Share last export** to email or save it. The file
   also lands in
   `/sdcard/Android/data/dev.kylesvoice.touch_spike/files/`, retrievable with:
   ```
   adb pull /sdcard/Android/data/dev.kylesvoice.touch_spike/files/ ./captures/
   ```

Watch the coloured verdict line at the bottom. Green means the hardware reports
a varying radius and palm mode is viable. Amber means it reports a constant
placeholder. Red means it reports nothing.

## Reading the CSV

Each file starts with a `#` metadata line recording the device, its true DPI,
screen size in pixels and millimetres, and headline counts. Then a header row
and one row per pointer event.

Two millimetre columns are emitted deliberately:

- `radius_major_mm_assuming_logical`
- `radius_major_mm_assuming_physical`

It is not yet established whether the Flutter engine hands us contact radius in
logical or physical pixels on Android. Rather than bake an assumption in at
capture time, both interpretations are recorded and the question gets settled
from the `calibration` session — a flat palm has a known real-world size, so
whichever column produces a plausible figure is the correct interpretation.

## Emulator note

The emulator is only useful for checking the app runs. `adb shell input`
synthesises events with no contact geometry, so the app correctly reports
"no contact radius at all" there. That is the detector working, not a bug.
Real numbers require real hardware and a real hand.

## Tests

```
flutter analyze
flutter test
```

The tests synthesise `PointerEvent`s with explicit contact geometry and run
headlessly with no device attached. This is the pattern the main app's palm
resolver will be built against.
