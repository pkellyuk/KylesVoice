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
- [ ] Confirm Kyle's actual Android tablet — screen size drives grid sizing, and
      the touch driver drives radius calibration.
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
- [ ] **Palm-mode touch resolution** (contact-area overlap, multi-touch lockout,
      post-activation lockout). This is MVP, not an add-on — without it the app
      does not work for him.
- [ ] Speak-on-tap with platform TTS; voice, rate, pitch selection.
- [ ] Card model with photo, label and independent spoken text.
- [ ] Photo capture from camera into a card.
- [ ] Parent-gated editor: add, edit, position, hide, delete cards.
- [ ] Local persistence (SQLite plus media on disk).
- [ ] Low-stimulation theme; press feedback with haptics.
- [ ] Home/back navigation and folder cards.

**Exit criterion:** Kyle uses it daily for a fortnight and mis-fires are rare
enough that the SLT team is satisfied.

## Phase 2 — The clinical features

Goal: what the SLT team needs to actually run a programme with it.

- [ ] Dual-image cards: symbol library, `both` and `blend` modes.
- [ ] Board-wide blend slider for staged symbol transition.
- [ ] Bundled symbol set with search and attribution tracking.
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
- [ ] Play Store and App Store release: privacy policy, Data Safety, Families
      policy compliance, content rating.

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
