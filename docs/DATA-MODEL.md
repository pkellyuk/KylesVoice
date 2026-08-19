# Kyle's Voice — Data Model

## Design constraints

1. **Cell position is identity.** A card's grid position is durable data, not a
   rendering detail. Nothing in this schema permits implicit reordering.
2. **Empty cells are real.** A page stores its full grid; absent cards leave
   holes that persist.
3. **Portable.** A board set must survive export, transfer by email, and import
   on a different device with different screen dimensions.
4. **Interchangeable.** Export to Open Board Format (OBF/OBZ) so board sets work
   with the wider open AAC ecosystem, and so the SLT team is not locked in to
   this app.

---

## Entities

### BoardSet

The complete vocabulary for one user.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `name` | text | "Kyle" |
| `schemaVersion` | int | For migrations |
| `gridRows` | int | Fixed for all pages in the set |
| `gridCols` | int | Fixed for all pages in the set |
| `rootPageId` | uuid | Home page |
| `locale` | tag | Board content language, independent of app UI language |
| `settings` | json | See `BoardSettings` below |
| `createdAt` / `updatedAt` | timestamp | |

Changing `gridRows` / `gridCols` on an existing set is a destructive migration
and must be gated behind an explicit warning about motor planning.

### BoardSettings (embedded json)

| Field | Type | Default |
|---|---|---|
| `utteranceMode` | `immediate` \| `build` \| `hybrid` | `immediate` |
| `showSentenceBar` | bool | `false` |
| `autoClearAfterSpeak` | bool | `true` |
| `autoReturnHome` | bool | `false` |
| `showLabels` | bool | `true` |
| `labelPosition` | `below` \| `above` \| `overlay` | `below` |
| `labelScale` | float | `1.0` |
| `imageMode` | `photo` \| `symbol` \| `both` \| `blend` | `photo` |
| `globalBlend` | float 0..1 | `0.0` — board-wide symbol transition |
| `colourCoding` | bool | `false` |
| `theme` | `light` \| `dark` \| `highContrast` \| `lowStim` | `lowStim` |
| `touchMode` | `point` \| `palm` \| `auto` | `palm` |
| `ambiguityPolicy` | `nearest` \| `ignore` | `nearest` |
| `ambiguityThreshold` | float | `0.15` |
| `dwellMs` | int | `0` |
| `lockoutMs` | int | `800` |
| `assumedContactRadiusMm` | float | `25.0` |
| `gutterDp` | float | `8.0` |
| `releaseAnywhere` | bool | `false` |
| `voiceId` | text | Platform voice identifier |
| `speechRate` / `speechPitch` | float | |
| `outputGain` | float | `1.0` |

### Page

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `boardSetId` | uuid | |
| `name` | text | Editor-facing only |
| `isRoot` | bool | |

A page has no card list of its own; cards reference their page and position.

### Cell / Card

Cards are stored keyed by position. There is no ordering column, because there
is no ordering — only coordinates.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `pageId` | uuid | |
| `row` | int | 0-based, from top |
| `col` | int | 0-based, from left in LTR; mirrored for RTL at render time |
| `rowSpan` | int | Default 1 |
| `colSpan` | int | Default 1 |
| `kind` | `speak` \| `navigate` \| `action` | |
| `label` | text | Displayed text |
| `speechText` | text | Spoken text; falls back to `label` if empty |
| `photoMediaId` | uuid? | Real photograph |
| `symbolMediaId` | uuid? | Abstract symbol |
| `imageMode` | enum? | Overrides `BoardSettings.imageMode` when set |
| `blend` | float? 0..1 | Overrides `globalBlend` when set |
| `audioMediaId` | uuid? | Recorded speech; overrides TTS when present |
| `colour` | argb? | |
| `hidden` | bool | Hidden, but the cell stays occupied and empty |
| `targetPageId` | uuid? | For `kind = navigate` |
| `actionType` | enum? | `backspace`, `clear`, `speak`, `home` |

Unique constraint on `(pageId, row, col)`. Spans are validated not to overlap.

### Media

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `boardSetId` | uuid | |
| `kind` | `photo` \| `symbol` \| `audio` | |
| `path` | text | Relative to the board set's media directory |
| `sourceAttribution` | text? | Symbol set name and licence, carried through export |
| `checksum` | text | Deduplication on import |

Attribution travels with the asset. It is not optional metadata — it is what
keeps CC BY-SA compliance intact when board sets are shared onward.

### UsageEvent (opt-in, local only)

| Field | Type |
|---|---|
| `id` | int |
| `timestamp` | timestamp |
| `cardId` | uuid |
| `pageId` | uuid |
| `resolvedBy` | `point` \| `palmOverlap` \| `scan` |
| `wasAmbiguous` | bool |

`resolvedBy` and `wasAmbiguous` are deliberately included: they let us measure
whether palm mode is actually working for Kyle rather than guessing.

---

## Interchange format

### Native export: `.kvz`

A zip archive:

```
boardset.json      the full board set, pages and cards
media/             photos, symbols, audio
attributions.json  per-asset licence and source
manifest.json      schema version, app version, export timestamp
```

Self-contained and lossless. This is the home-to-school transfer unit.

### Open Board Format export: `.obz`

OBF represents boards as a grid with an explicit `grid.order` array of button
IDs including nulls for empty cells, which maps cleanly onto our
position-as-identity model.

Expected lossy edges on OBF export, to be documented in the exporter:

- Dual-image cards (photo + symbol + blend) have no OBF equivalent. Export the
  currently-displayed composite as a single image, and preserve the originals in
  an extension field so a round-trip through our own app is lossless.
- Palm-mode touch settings are app-specific and go in extension fields.

Import should accept `.obz` from other AAC tools, mapping unknown extensions to
defaults rather than failing.
