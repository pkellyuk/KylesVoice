# Touch capture findings

First real measurements, and they overturn a central assumption in the original
palm-mode design. Recording them here because the conclusion is unintuitive and
future contributors will otherwise re-derive the wrong model.

## Source data

Captured 19 August 2026 on a **Samsung Galaxy S24 (SM-S921B)**, Android 16,
release build. Raw files are committed in `docs/captures/`.

| Session | Downs | Max concurrent pointers |
|---|---|---|
| `point` (adult fingertip taps) | 58 | 1 |
| `point` (second run) | 46 | 3 |
| `slap` (adult flat-palm slaps) | 18 | 6 |

Device: 1080 x 2340 px, true **xdpi 415.6 / ydpi 418.6**, devicePixelRatio 3.0,
panel 66 x 142 mm.

**Caveats.** These are an adult hand, not Kyle's; a 10-year-old's contact will be
roughly 75-85% of these figures. And a flagship Samsung is a best case — the
Fire HD 8's touch controller is likely to be worse, not better.

---

## Finding 1: a slap is not one large contact, it is a constellation

This is the important one. The design assumed a palm slap produces a single
large contact ellipse, and that resolving it by area overlap would identify the
intended cell.

It does not. Every slap in the capture registered as **six separate simultaneous
contacts**, scattered across a large area:

| Slap | Contacts | Footprint | Largest radius | First contact was largest? |
|---|---|---|---|---|
| 1 | 6 | 42.1 x 51.2 mm | 3.90 | **no** |
| 2 | 6 | 41.5 x 46.3 mm | 5.15 | yes |
| 3 | 6 | 49.2 x 41.0 mm | 2.78 | **no** |

The fingers, knuckles and heel of the hand each land as their own pointer. There
is no single ellipse to measure.

### Consequences

- **Per-contact radius is a weak discriminator.** Within a single slap, radii
  ranged from 0.56 to 5.15. Half the contacts in a slap are indistinguishable
  from a deliberate fingertip tap, because they *are* fingertips.
- **Concurrent pointer count is a strong discriminator.** Six contacts inside
  16 ms is unambiguously a slap. Deliberate tapping produced one.
- **The "first pointer wins" multi-touch lockout in `DESIGN.md` 5.3 is wrong.**
  In two of three slaps the first contact to register was *not* the largest, so
  first-pointer-wins selects an arbitrary fingertip rather than the heel of the
  hand. It suppresses double-firing correctly but picks the wrong target.

### Recommended design change

Treat contacts arriving within a short window as **one composite contact**
rather than as competing individual pointers:

1. Gather all pointers down within a coalescing window (~50 ms).
2. Resolve the composite against the grid, weighting each contact by its area,
   or take the largest single contact as the intended point.
3. Apply the existing lockout to the composite, not to each pointer.

The existing exact ellipse-overlap arithmetic is still correct and still needed
— it just needs to be applied to a weighted set of contacts rather than to one.

---

## Finding 2: a slap covers 42-51 mm, which sets the grid

Measured footprint is consistently around **42 x 46 mm** for an adult hand.
Scaling to a 10-year-old gives roughly **32 x 38 mm**.

Against the target devices:

| Device | Usable area | Cells that fit a child's slap |
|---|---|---|
| Fire HD 8 | 172 x 108 mm | about 5 x 2 |
| Galaxy S24 (landscape) | 142 x 66 mm | about 4 x 1 |

This supports the provisional **3 x 2** grid in `DESIGN.md` section 12 with
comfortable margin, and suggests 4 x 2 would also be defensible on the tablet.
It confirms that a phone cannot carry the same board at the same reliability,
which is the open question in `DESIGN.md` 13.2.

---

## Finding 3: reported contact size is quantised and in device-specific units

Radius values are exact integer multiples of **0.1392 logical pixels**. A
fingertip should be around 22 logical pixels of radius on this panel; the device
reports 1.25. The values are therefore roughly **15-20x smaller than logical
pixels**, in some device-specific unit.

This is exactly the case `DESIGN.md` 5.1 anticipated, and is why
`ResolverConfig.calibrationScale` exists. The constant has not yet been pinned,
because that needs a `calibration` session: a flat palm of known real size held
still.

Quantisation also limits resolution: fingertip taps occupied only nine distinct
levels.

---

## Finding 4: pressure is unusable

All 58 down events in the first point session reported `pressure` of exactly
**1.0000**. The device reports no finger force at all.

Combined with the fact that iPad exposes no finger force either (Apple Pencil
and legacy 3D Touch only), the conclusion is firm: **nothing in this app may
depend on pressure.** It currently does not, and must not start.

---

## Finding 5: `size` may be a better signal than radius

`MotionEvent.getSize()` produced eleven distinct levels against radius's nine,
and is normalised 0..1, so it sidesteps the device-specific units problem
entirely. Worth evaluating as the primary contact-size signal before committing
to radius.

---

## Still open

- A `calibration` session, to pin `calibrationScale` to real millimetres.
- The same four sessions captured on the **Fire HD 8**, which is the actual
  target and probably has a poorer touch controller.
- The same on a rugged phone, to quantify how badly small screens degrade.
- Kyle's own contact sizes, which are the ones that actually matter.
