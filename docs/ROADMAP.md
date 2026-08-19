# Kyle's Voice — Roadmap

Phases are ordered so that **Kyle has a working voice as early as possible**,
and everything after that is generalisation for other users.

---

## Platform priority

**Android first, exclusively.** iOS is kept structurally possible (see
`DESIGN.md` 11.2) and compile-checked in CI, but is not built out, tested or
shipped until Kyle has a working Android app. Deferring iOS also defers the
Apple Developer Program fee and the macOS build dependency.

---

## Phase 0 — Decisions and de-risking, before app code

- [x] Stack: Flutter, Android-first, pure-Dart core package.
- [x] Code licence: GPL-3.0, confirmed.
- [ ] Confirm bundled symbol set and verify its licence terms directly with the
      source (Mulberry proposed; ARASAAC's NC clause reviewed).
- [x] Target devices confirmed: Amazon Fire HD 8 (primary, Play Store
      sideloaded) plus two rugged Android phones. See `DESIGN.md` section 13.
- [ ] Settle the grid dimensions from spike data. Provisionally 3 x 2, revised
      down from 4 x 3 because of the 8-inch screen. Fixed forever once chosen.
- [ ] Answer the phone question in `DESIGN.md` 13.2: same board at reduced
      accuracy, or parent-held backup voice?
- [x] **Touch-geometry spike built** — `tools/touch_spike`. Logs every pointer
      event's position, radius, pressure and timing to CSV, reads true physical
      DPI over a platform channel, visualises the contact ellipse live, and
      exports via share sheet or `adb pull`. Verified on emulator; see
      `tools/touch_spike/README.md`.
- [ ] **Touch-geometry spike run on real hardware.** Install on Kyle's tablet,
      capture the `point`, `slap`, `mixed` and `calibration` sessions described
      in the spike README, and use the data to:
      - confirm the tablet reports usable contact radius at all;
      - derive the device-specific units-to-pixels calibration constant;
      - measure realistic contact sizes, to size the grid and set the ambiguity
        threshold from evidence rather than guesswork;
      - measure slap bounce intervals, to set the post-activation lockout.

      If contact radius turns out to be unusable on his hardware, palm mode
      needs a different design (multi-touch centroid plus dwell) and it is far
      cheaper to learn that now.
- [ ] SLT team review of `DESIGN.md` section 12 (Kyle's starting profile) and
      initial vocabulary selection.

## Phase 1 — Kyle's MVP

Goal: Kyle taps a card and it speaks, reliably, with his own photographs.

- [ ] Fixed grid renderer with position-as-identity and preserved empty cells.
- [x] **Palm-mode touch resolution** — `packages/kylesvoice_core`. Exact
      ellipse-versus-cell overlap, contact coalescing into composite hand
      landings, area-weighted scoring, ambiguity detection, post-activation
      lockout and dwell. 77 tests, including replay of the real captures in
      `docs/captures/`. Calibration constants still to be set from Kyle's own
      data.
- [x] Wire the resolver into a Flutter widget layer and verify on device —
      `app/`. Renders the fixed grid with empty cells preserved, feeds real
      pointer geometry through the coalescer and resolver, speaks through the
      platform engine, and carries a parent-gated diagnostics overlay.
      Confirmed working on a Galaxy S24 and a tablet emulator.
- [ ] Settle `lockoutMillis` from Kyle's data. The captures show the default
      800 ms merges deliberately repeated slaps into one activation — correct
      for a rebounding hand, wrong for a child repeating a word on purpose.
- [ ] Speak-on-tap with platform TTS; voice, rate, pitch selection.
- [ ] Card model with photo, label and independent spoken text.
- [x] Photo capture from camera or gallery into a card, downscaled at
      capture, filed atomically beside the board. Verified on device: captured,
      saved, restarted, still there.
- [x] Parent-gated editor: add, edit and remove cards, change grid size with
      an explicit warning naming what would be lost, one-level undo.
- [x] Local persistence — atomic JSON writes with an automatic backup and
      salvaging decode. Supersedes the SQLite sketch; see `DATA-MODEL.md`.
      Verified on device: a card added in the editor survives a force-stop.
- [ ] Low-stimulation theme; press feedback with haptics.
- [x] Multiple pages per board, reached by fixed arrows in reserved strips.
      Adding a page moves nothing already placed, so a full grid never forces
      a resize. Swipe paging available but off by default.
- [ ] Home/back navigation and folder cards.

**Exit criterion:** Kyle uses it daily for a fortnight and mis-fires are rare
enough that the SLT team is satisfied.

## Phase 2 — The clinical features

Goal: what the SLT team needs to actually run a programme with it.

- [x] Dual-image cards: `photo`, `symbol`, `both` and `blend` modes with a
      per-card cross-fade slider, so a card can start on the child's own cup
      and move gradually to an abstract symbol without ever changing position.
- [x] Bundled symbol library — the full Mulberry set, 3,436 symbols under
      CC BY-SA 4.0, imported reproducibly by `tools/import_symbols.dart` with
      a searchable picker. Emoji retained as a fallback for the core words
      Mulberry lacks.
- [ ] Cover the core vocabulary Mulberry is missing (yes, no, stop, again,
      please, thank you, hurt, mum, dad, like). Awaiting the SLT team's steer;
      see `FOR-CLINICIANS.md`.
- [ ] Board-wide blend slider for staged symbol transition.
- [x] Bundled symbol set with search and attribution tracking.
- [ ] Recorded per-card audio.
- [ ] Sentence bar and build-then-speak mode.
- [ ] Export/import `.kvz` — home-to-school transfer.
- [ ] Undo and pre-edit snapshots.
- [ ] Touch tuning UI (dwell, lockout, ambiguity policy, gutters) with a
      practice/diagnostic screen showing how each touch resolved.
- [ ] Opt-in local usage logging with CSV export.

## Phase 3 — Generalisation for other users

Goal: useful to the rest of the SLT team's caseload, not just Kyle.

- [ ] Multiple user profiles on one device.
- [ ] Switch scanning (row/column and linear, auto and step).
- [ ] Colour coding schemes.
- [ ] OBF/OBZ import and export.
- [ ] Starter board set templates.
- [ ] Backup to the user's own cloud drive.
- [ ] **Distribution.** Play Store alone is insufficient: the primary target is
      a Fire tablet, and stock Fire OS has no Play Store. Ship through several
      channels, in this order:
      - Direct APK on GitHub Releases — works on any Android or Fire device,
        available immediately, no gatekeeper.
      - Amazon Appstore — reaches stock Fire tablets, which is what other
        families in the SLT team's caseload will have.
      - Google Play — reaches ordinary Android devices and Kyle's tablet, which
        has Play sideloaded. Requires privacy policy, Data Safety declaration,
        Families policy compliance and a content rating.
      - F-Droid — natural home for a GPL-3.0 app with no proprietary
        dependencies, and reaches users who avoid app stores entirely.
- [ ] Verify the app runs on stock Fire OS with no Google Play Services present.

## Phase 4 — Growth

- [ ] Keyboard page with word prediction, for emerging literacy.
- [ ] Core vocabulary strip persistent across pages.
- [ ] App UI localisation and RTL.
- [ ] Bilingual board sets.
- [ ] Community board-set library (static repo, no server).
- [ ] Scheduled automatic blend progression.

---

## Explicit non-goals

- No cloud accounts, no server infrastructure, no telemetry.
- No gamification, rewards, scores or streaks.
- No AI-generated symbols or speech in the core communication path — it must
  work offline, instantly, and identically every time.
- No proprietary symbol sets.
- No paid tier, ever.
