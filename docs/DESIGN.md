# Kyle's Voice — Design

## 0. The user

Kyle, age 10. Non-verbal autistic. No current pictorial communication system;
introduction recommended by his speech and language therapy team. Reading: no
sight-word reading currently. Motor: good fine motor control in general, but
**activates targets by slapping with an open palm as often as by pointing**.
The SLT team specifically wants a system mixing **abstract symbols with real
photographs**.

Two consequences dominate this design:

1. **We are building the motor plan from scratch.** Nothing to replicate, so we
   have one chance to lay it out correctly and never move it again.
2. **Palm activation is a first-class input method, not an accessibility
   afterthought.** See section 5.

---

## 1. Principles

1. **Motor planning is sacred.** A card lives in the same grid position forever.
   The grid never reflows, never sorts, never auto-hides, never collapses gaps.
   Users learn the motor path to a word, not the picture. Empty cells stay empty.
2. **Grow into a fixed grid, never grow the grid.** Start with the *target* grid
   dimensions from day one and leave most cells empty. Adding vocabulary later
   fills empty cells; it never resizes or reshuffles existing ones.
3. **Offline-first, always.** No network dependency for any communication
   function, ever.
4. **The child can never get stuck.** Any screen the child can reach, the child
   can leave. Only *editing* is gated.
5. **Fast is a feature.** Tap to audible speech under 100 ms. Latency destroys
   communicative intent.
6. **No ads, no accounts, no in-app purchases, no analytics, no tracking.**
7. **Failure is silent and recoverable, never punishing.** No error sounds, no
   "wrong" feedback, no scoring. This is a voice, not a game.

---

## 2. Core communication

### 2.1 Board structure

- **Board set** — the whole vocabulary for one user (Kyle's board set).
- **Page** — one screen of cells. Every page in a board set shares the same grid
  dimensions.
- **Cell** — a fixed position on the grid. May be empty.
- **Card** — the thing in a cell: image(s), label, spoken text, colour.

### 2.2 Card behaviour

- **Speak card** — speaks its phrase; optionally appends to the sentence bar.
- **Navigation card** — opens another page. Rendered with a folded-corner
  affordance and, optionally, a preview montage of its contents.
- **Action card** — backspace, clear, speak sentence, home. Fixed positions.

### 2.3 Utterance modes

Configurable per profile:

- **Immediate** (default for Kyle initially) — tap speaks the card straight away.
  Correct starting point for a first system; the feedback loop must be tight and
  obvious.
- **Build-then-speak** — taps queue into the sentence bar; tapping the bar
  speaks the whole utterance. This is the growth path toward multi-word
  requesting and should be one setting away, not a different app.
- **Hybrid** — speaks each card as tapped *and* accumulates into the bar.
  Often the best bridge between the two.

### 2.4 Sentence bar

- Horizontal strip across the top showing queued cards as thumbnails.
- Tap the bar to speak the full utterance. Tap again to repeat.
- Single backspace button; long-press to clear all.
- Hideable entirely (Kyle's initial profile hides it).
- Auto-clear after speaking: on/off.

### 2.5 Navigation

- **Home** button in a fixed corner, present on every page, never moves.
- **Back** returns one level.
- Optional **auto-return home** after an utterance.
- Breadcrumb trail is off by default — visual noise, and he cannot read it.

---

## 3. Images: mixing photographs and symbols

An explicit requirement from the SLT team, and a genuine differentiator.

### 3.1 Dual-image cards

Every card can hold **two images**: a real photograph and an abstract symbol.
The board set has a global display mode, overridable per card:

| Mode | Rendering |
|---|---|
| `photo` | Photograph only |
| `symbol` | Symbol only |
| `both` | Split card — photo and symbol side by side or stacked |
| `blend` | Cross-fade between photo and symbol at a per-card opacity |

### 3.2 Symbol transition (image fading)

`blend` mode exists to support a deliberate clinical progression: begin with a
photo of *Kyle's actual cup*, and over weeks shift the blend toward the abstract
symbol for "drink", so the concept generalises beyond that one object.

- Per-card blend value, 0 (pure photo) to 1 (pure symbol).
- A **board-wide blend slider** so a therapist or parent can advance the whole
  set gradually.
- A **schedule** option (later phase): advance blend by N% per week automatically.

This must be reversible, and must never change the card's position or label.

### 3.3 Photograph capture

Personal photographs matter more than stock symbols for a first system — *his*
cup, *his* school, *his* people.

- Camera capture directly into a card, from the editor, in two taps.
- Automatic background removal is **not** planned: unreliable, and a cluttered
  real background is sometimes exactly the point. Instead offer crop, rotate,
  and a simple square/circle mask.
- Photos stored at a sane resolution (longest edge around 1024 px) to keep
  board sets shareable by email or messaging.

### 3.4 Symbol sets and licensing

To confirm before any code ships:

- **Mulberry Symbols** — CC BY-SA. Recommended bundled default: no
  non-commercial restriction, which keeps the licensing story clean.
- **ARASAAC** — very large and multilingual, but **CC BY-NC-SA**. The
  non-commercial clause is compatible with this app being free, but it
  complicates redistribution and downstream reuse. Candidate for an optional
  in-app download rather than a bundled default.
- **Sclera** — high-contrast pictographs; useful alternative for some users.
- **PCS / SymbolStix / Widgit** — proprietary. Not usable. Do not import.

Verify current licence terms directly with each source before shipping, and
record attributions in `THIRD-PARTY-ASSETS.md`. Asset licences are tracked
separately from the code licence.

---

## 4. Voice and speech

- **Platform TTS**: Android `TextToSpeech`, iOS `AVSpeechSynthesizer`. Free,
  offline-capable, no licensing cost.
- **Voice picker** with rate and pitch control, auditioned live in the editor.
  Note that genuine child voices are scarce on both platforms — surface whatever
  is installed and let the parent choose.
- **Recorded speech per card** overrides TTS when present. Recording a sibling or
  a similar-aged child saying the word is often far more motivating than
  synthetic speech, and side-steps the missing-child-voice problem entirely.
- **Pronunciation override** — a separate "speaks as" field per card, for names,
  local place names, and anything TTS mangles. Label and spoken text are always
  independent fields (label "toilet", speaks "I need the toilet").
- **Audio session**: AAC speech is an accessibility function and should play even
  when the iOS silent switch is on; duck and resume other media rather than
  stopping it.
- **Output gain / volume boost**, because this gets used in noisy classrooms.
- **Never queue-and-drop**: a new activation interrupts the previous utterance
  immediately rather than queueing behind it.

---

## 5. Touch input: point mode and palm mode

Kyle slaps as often as he points. A naive "which cell contains this point?" hit
test will fire the wrong card — and firing the wrong word is worse than firing
nothing, because it teaches him the system lies.

### 5.1 Contact-area resolution ("palm mode")

Resolve the **contact patch**, not a single point:

- Both platforms expose touch geometry; in Flutter, `Listener` provides
  `PointerEvent.radiusMajor`, `radiusMinor`, `size` and `pressure`.
- Model the contact as an ellipse at the touch centroid.
- Compute the **overlap area between that ellipse and each cell's rectangle**.
- Activate the cell with the greatest overlap.

**What this does and does not buy, stated precisely.** An earlier draft of this
document claimed area resolution makes a slap land on the card the palm mostly
covers "rather than whichever card sits under the reported centre point". That
is not true in general, and the distinction matters enough to correct.

A contact ellipse is symmetric about its centre. Across two equal, adjoining
cells, the majority of its area therefore *always* falls on the side its centre
is on. On a uniform grid with no gutters, area resolution and a naive centre
hit-test select the same cell, always. Area resolution cannot by itself rescue a
slap whose reported centroid already landed on the wrong card.

What it genuinely provides:

1. **No dead zones.** Point mode cannot resolve a centre that lands in a gutter,
   and returns nothing. A contact spanning the gutter still overlaps the cells
   either side, so area resolution always has an answer. On a board with
   generous gutters — which is what we want, to reduce edge mis-hits — this is
   the everyday case, not a corner case.
2. **Correct behaviour at screen edges**, where part of the contact falls
   outside the grid and the balance between cells is no longer symmetric about
   the reported centre.
3. **Correct behaviour across cells of unequal size**, once spans are in use. A
   contact centred just inside a small cell may genuinely cover more of an
   adjacent 2x2 card, and area resolution gets that right.
4. **Ambiguity detection.** This is arguably the most valuable of the four. Area
   resolution knows *how close* the call was, which a point hit-test cannot. That
   is what makes the `ignore` policy in 5.2 possible at all, and what lets usage
   logging measure how often Kyle's activations were near-ties.

Contact size is also what makes `auto` mode in 5.6 possible, and what tells us
whether to trust a given touch at all.

Two caveats to validate on real hardware, both handled by the calibration spike
in `ROADMAP.md` Phase 0:

- **Units.** Android's `MotionEvent.getTouchMajor()` is widely supported, but on
  a significant number of devices reports in *device-specific units rather than
  pixels*, depending on how the touchscreen driver is configured. A per-device
  calibration constant, derived empirically from real touch data, is therefore
  part of the resolver rather than an afterthought.
- **Availability.** Where radius is unreported or implausible, palm mode degrades
  to a fixed assumed contact radius (configurable, default around 25 mm) centred
  on the reported point. iOS fidelity in particular is unknown and unverified;
  note that finger `force` is not available on iPad at all (Apple Pencil and
  legacy 3D Touch only), so contact radius is the only signal there.

The resolver consumes a normalised contact-ellipse struct, never raw platform
fields, so calibration and platform differences are contained in one adapter.

### 5.2 Ambiguity handling

If the top two candidate cells' overlap areas are within a configurable
threshold (default 15%), the activation is **ambiguous**. Configurable response:

- `nearest` (default) — activate the larger anyway. Biased toward always giving
  him a voice; occasionally wrong.
- `ignore` — do nothing, with a soft neutral pulse across both cells. Safer, but
  risks frustration.

Start Kyle on `nearest`, and revisit with the SLT team after observation.

### 5.3 Multi-touch lockout

A slap frequently registers several pointers within milliseconds.

- Take the **first** pointer down as authoritative.
- Ignore additional pointers until all pointers are released.
- Apply a **post-activation lockout** after each activation (default 800 ms)
  during which no further activation can occur, killing bounce and double-fire.

### 5.4 Activation timing

- **Dwell / hold-to-activate**: require contact held for N ms before the target
  arms. Default 0 for Kyle, whose fine motor control is good.
- **Activate on release** within the same resolved cell, with hysteresis so a
  slight slide during release does not cancel.
- **Release-anywhere option**: activate the cell armed on press regardless of
  where the hand lifts. Useful for a dragging or sliding hand.

### 5.5 Gutters

A **dead gutter** between cells (configurable, default 8 dp) belonging to no
cell. In point mode this reduces mis-hits on card edges; in palm mode gutters
contribute no overlap area to any cell and so simply reduce noise.

### 5.6 Mode selection

`point` / `palm` / `auto` is a **profile setting, not a runtime toggle** — it
must not change under him mid-session. `auto` infers from reported contact size
per touch and is the intended default once validated on real devices; until
then Kyle's profile is set explicitly to `palm`.

---

## 6. UI, layout and visual design

- **Large touch targets** and generous spacing. Tablet is the primary form
  factor; phone is supported but with a smaller target grid.
- **No gestures required for core use.** No swipe, no pinch, no long-press in
  child-facing mode. Gestures exist only in the editor.
- **Text labels are shown** even though Kyle cannot read. Incidental exposure to
  the written word alongside the image is standard practice and costs nothing.
  Label size, position (below / above / overlay) and visibility are configurable
  per board set.
- **Colour coding** — optional Fitzgerald Key / Goossens scheme (people yellow,
  verbs green, nouns orange, descriptors blue, social pink). Off by default for
  Kyle; it is meaningless until taught, and some children find it distracting.
- **Themes**: light, dark, high contrast, and **low stimulation** (desaturated
  chrome so the cards are the only salient elements on screen).
- **Press feedback**: immediate border glow and scale, plus optional haptic,
  firing *before* audio starts so the tap is acknowledged instantly.
- **Minimal animation.** No page-transition flourishes. Honour the platform
  "reduce motion" setting.
- **Both orientations supported**, with an orientation lock option. Critically,
  grid positions are preserved across rotation: the same card sits in the same
  relative cell in portrait and landscape, even though the cells reshape.

---

## 7. Accessibility beyond touch

- **Switch scanning** — row/column and linear, auto and step modes, configurable
  scan rate and highlight style, external Bluetooth switch support. Not needed
  for Kyle, but it is what makes this app useful to the rest of the SLT team's
  caseload. The activation pipeline is therefore architected so scanning drives
  the same "activate cell" entry point that touch does.
- **Screen reader support in the editor**, since a blind or low-vision parent may
  be the one configuring the board.
- **Guided Access (iOS) / App Pinning (Android)** — in-app guidance on locking
  the device to the app so he cannot wander into other apps.

---

## 8. Editing and parent/therapist mode

- **Parent gate**: press and hold a corner for 3 seconds, then a simple
  arithmetic challenge. Not a typed password he can watch and learn.
- **Card editor**: photo, symbol, blend, label, spoken text, recorded audio,
  colour, cell span (1x1, 2x1, 2x2), visibility (**hidden but space preserved**).
- **Board editor**: grid dimensions, page management, drag to reposition — with
  an explicit warning every time a populated cell moves, explaining the motor
  planning cost.
- **Undo**, and an automatic snapshot before any destructive edit. A parent
  deleting three months of tuning at 9 pm is a real and foreseeable failure.
- **Export / import board sets** as a single file. See `DATA-MODEL.md`. This is
  how home and school stay in sync without anyone running a server.

---

## 9. Data, backup and privacy

- **Local SQLite** plus media files on disk. Everything works with zero network.
- **Manual export/import** first; optional automatic backup to the *user's own*
  cloud drive (Google Drive / iCloud Drive / Files) later. Never to our servers,
  because there are no servers.
- **Usage logging: local only, off by default, explicit opt-in.** Most-used
  cards, utterances per day, time of day, navigation dead-ends. Genuinely useful
  in SLT review and for spotting words he reaches for and cannot find.
  Exportable as CSV, deletable in one action.
- **Play Data Safety / Apple Privacy labels**: "no data collected", and true.
- **Google Play Families policy** applies if we target children: no ad SDKs, no
  analytics SDKs, content rating, hosted privacy policy. A zero-SDK app makes
  this straightforward.
- Camera and microphone permissions requested only at point of use.

---

## 10. Language and localisation

- Externalise every UI string from the first commit; retrofitting is miserable.
- **Board content language is independent of app UI language** — a bilingual
  household may want an English interface and a different board language.
- **RTL support** affects grid fill order and sentence bar direction.
- English first. Additional languages are then largely a matter of symbol-set
  label translations plus available TTS voices.

---

## 11. Technology

**Android first. iOS capable eventually.** Android is the sole target for
initial delivery; iOS support is kept structurally open but is not built,
tested, or shipped until Android is working for Kyle.

**Flutter** is the stack:

- One codebase, with full pixel control over a custom grid — which matters,
  because the core UI is a bespoke grid, not platform widgets.
- `Listener` exposes the raw pointer geometry that palm mode in section 5
  depends on.
- Mature packages for the rest: `flutter_tts`, `just_audio`, `drift`/`sqflite`,
  `image_picker`, `archive`.

### 11.1 Structure

- **`kylesvoice_core`** — a pure Dart package with no Flutter dependency: touch
  resolution, board model, blend logic, OBF codec, persistence schema. Fully
  unit-testable headlessly on a development machine with no device attached.
  The hardest and most novel logic lives here deliberately.
- **`kylesvoice_app`** — a thin Flutter UI over the core. Widget tests and
  golden-image tests.

### 11.2 Keeping iOS open

Four disciplines, applied from the first commit:

1. No Android-only plugin is added without a verified iOS equivalent.
2. Platform-specific behaviour (audio session control, TTS, file paths) sits
   behind an interface, with Android implementations and iOS stubs that fail
   loudly rather than silently.
3. The touch resolver consumes a normalised contact-ellipse struct, never raw
   Android `MotionEvent` fields, so an iOS adapter can supply
   `UITouch.majorRadius` or fall back to an assumed radius.
4. An iOS build job runs in CI from day one — free on GitHub Actions for public
   repositories — purely to catch compile breakage. It never gates anything.

### 11.3 Test and automation strategy

Chosen substantially because it maximises what can be verified automatically:

| Layer | Mechanism |
|---|---|
| Core logic | `flutter test` / `dart test`, headless, no device |
| Touch resolution | Synthesised `PointerEvent`s with arbitrary `radiusMajor`, `radiusMinor` and `pressure` — hundreds of simulated slap geometries, headless |
| Layout | Golden-image tests, diffable in CI |
| On-device | `adb` install, `adb shell input` for interaction, `adb exec-out screencap` for visual verification, `adb logcat` for the entry/exit logging |
| End-to-end flows | Maestro (YAML flows, CLI-driven, Android from any host OS) |

Real-device behaviour with Kyle — touch fidelity, TTS voice quality, audio
latency — cannot be automated by anyone and remains human work.

Known trade-offs: switch access and some deep platform accessibility integration
are more awkward in Flutter than in native code, and platform channels will
likely be needed for audio session category control and for TTS edge cases.
Both are manageable.

---

## 12. Kyle's starting profile

A concrete first configuration, for review by the SLT team:

| Setting | Value | Rationale |
|---|---|---|
| Grid | 3 x 2 (6 cells), landscape — **provisional, see section 13** | Constrained by an 8-inch screen and palm-sized contacts |
| Populated at start | 3-4 cells | Room to grow without ever moving anything |
| Utterance mode | Immediate | Tightest possible feedback loop for a first system |
| Sentence bar | Hidden | Not yet meaningful; enable at multi-word stage |
| Labels | Shown, small, below image | Incidental literacy exposure |
| Colour coding | Off | Meaningless until taught |
| Touch mode | Palm | Contact-area resolution, `nearest` on ambiguity |
| Post-activation lockout | 800 ms | Slap bounce suppression |
| Dwell | 0 ms | Fine motor control is good |
| Images | `photo`, progressing to `blend` | Real objects first, generalise later |
| Theme | Low stimulation | Cards are the only salient elements |

Initial vocabulary selection is for the SLT team to determine, not for us. The
structure above is built to accept whatever they recommend.

---

## 13. Target devices

Kyle's actual hardware, which constrains several decisions above:

| Device | Role | Notes |
|---|---|---|
| Amazon Fire HD 8 | Primary | 8-inch, 1280x800. Fire OS, with Google Play Store sideloaded |
| Two rugged Android phones | Secondary, used in rotation | One charges while the other is in use |

None are high-end, because he sometimes throws them. That is a design input,
not an aside.

### 13.1 The screen size problem

An 8-inch 16:10 panel is roughly 172 x 108 mm of active area. If a palm contact
is 40-50 mm across, the number of cells that can be reliably distinguished by
contact-area resolution is small:

- 172 / 50 gives about **3 columns**
- 108 / 50 gives about **2 rows**

Hence the revision from 4 x 3 down to **3 x 2** in section 12. Since grid
dimensions are fixed forever (principle 2), getting this wrong is expensive, and
a 12-cell grid on this hardware would mean cells barely larger than his hand.

These figures are estimates. The touch spike reports the panel's true physical
size in millimetres and measures his actual contact sizes, so the final grid is
set from measurement, not from this arithmetic.

### 13.2 The same board across different screen sizes

The phones are far smaller than the tablet. This creates a real tension:

- **Rows and columns must never change across devices.** Motor planning is
  substantially spatial and relative; keeping the same 3 x 2 arrangement means
  "drink is bottom-left" holds true on every device he uses.
- **But physical cell size does change**, and on a phone a 3 x 2 grid gives
  cells smaller than his palm, at which point contact-area resolution cannot
  disambiguate anything.

The resolution adopted: grid dimensions are a property of the **board set**, not
of the device. Cells scale to fit whatever screen is present. On the phones,
palm mode degrades gracefully toward "largest overlap wins" with a wider
ambiguity threshold, and accuracy will genuinely be worse.

**Open question for the SLT team:** is it better for the phones to carry the
same 3 x 2 board at reduced accuracy, or to be treated as a parent-held backup
voice rather than something Kyle operates independently? We have not assumed an
answer.

### 13.3 Fire OS

Fire OS is a fork of Android, and differs in ways that matter:

- **No Google Play Services or Play Store by default.** Kyle's tablet has the
  Play Store sideloaded, so Google's TTS engine and Play distribution both work
  *for him*. Stock Fire tablets, which is what other families will have, do not.
- **Sideloaded Play Services can break on a Fire OS update.** The app must
  therefore never depend on Play Services being present. It does not: TTS goes
  through the standard Android `TextToSpeech` API, which works with whichever
  engine is installed, and there are no Google SDKs in the project.
- **Distribution cannot be Play Store alone.** See `ROADMAP.md`.
- Speech capability is measured rather than assumed: the touch spike includes a
  speech probe that enumerates the installed engines and voices on whatever
  device it is run on.

### 13.4 Durability

He sometimes throws the devices. Beyond choosing rugged hardware, which is
already done, the app must assume it can be killed abruptly at any moment:

- **Board edits are committed immediately**, never held in memory pending a
  "save" the parent might never reach.
- **Process death must lose nothing** beyond the in-progress utterance.
- **No modal state that survives a restart.** The app always reopens on the home
  board, ready to speak.
- Backups matter more than usual, because a device may simply stop existing.
  This raises the priority of export/import: it is not only home-to-school
  transfer, it is disaster recovery.
