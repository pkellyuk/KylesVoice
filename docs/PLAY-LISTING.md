# Google Play listing — Kyle's Voice

Everything needed to fill in the Play Console, in the order the Console asks for
it. Character limits are Play's own.

---

## App details

| Field | Value |
|---|---|
| **App name** (30 max) | `Kyle's Voice — Free AAC` |
| **Launcher label** | `Kyle's Voice` (set in the manifest; the store title can be longer than what fits under an icon) |
| **Application ID** | `io.github.pkellyuk.kylesvoice` — **permanent, cannot be changed after the first release** |
| **Default language** | English (United Kingdom) |
| **App or game** | App |
| **Free or paid** | Free, and it must stay free — see the licence and the project's stated purpose |
| **Category** | Medical, or Education. Medical is the better fit for AAC; Education reaches more browsing parents. Either is defensible |
| **Tags** | Accessibility, Communication, Special needs |

## Short description (80 max)

```
Free picture cards that speak. Built for a non-verbal child. No ads, ever.
```

*(74 characters.)*

## Full description (4000 max)

```
Kyle's Voice is a free picture-card communication app with speech output, for
people who cannot speak.

It was built for one ten-year-old boy who is non-verbal and autistic, on the
advice of his speech and language therapy team, and is shared openly for anyone
else who needs it.

There is no cost, no advertising, no subscription, no account, and no feature
held back behind a payment. Communication is not a premium feature.


WHAT IT DOES

• Tap a card, and the device speaks the word or phrase.
• Cards can show a real photograph, a symbol, or both.
• 3,436 built-in symbols from the Mulberry set, searchable by word.
• Add your own photographs straight from the camera — their own cup, their own
  school, their own people.
• Add pages when a board fills up, so you never have to remove a card.
• A simple editor, kept behind a grown-up check so it cannot be opened by
  accident.


BUILT AROUND HOW PEOPLE ACTUALLY TOUCH A SCREEN

Some users press a card with one finger. Others land with a whole open hand.
Kyle's Voice measures the shape and size of the contact rather than testing a
single point, treats a hand landing as one action instead of six, and ignores the
bounce that follows. Every setting behind this was derived from real measurements
on real hardware, not guessed.


A CARD NEVER MOVES

Learning a communication board is learning where the words are — a physical
habit, not a memory of pictures. So the grid never reshuffles, never sorts and
never closes gaps. Empty cells stay exactly where they are, waiting. Vocabulary
grows by filling those gaps and by adding pages, so a word learned today is
still in the same place next year.


FROM PHOTOGRAPH TO SYMBOL

A card can start as a photograph of your child's own cup, and be faded gradually
toward the abstract symbol for "drink" over weeks — so the idea generalises
beyond that one object, without the card ever changing position or its word.


PRIVACY

Kyle's Voice collects nothing and sends nothing. There are no accounts, no
advertising, no analytics and no tracking. The released app does not even ask
Android for permission to use the internet. Boards and photographs stay in the
app's private storage on your own device.

Speech is produced by whichever text-to-speech engine is already installed on
your device.


OPEN SOURCE

The complete source code is public, under the GNU General Public License v3.0,
at github.com/pkellyuk/KylesVoice. Contributions, corrections and board sets are
welcome — particularly from speech and language therapists.

Symbols are the Mulberry Symbol set by Garry Paxton and Steve Lee, used under a
Creative Commons BY-SA 4.0 licence.
```

---

## Data safety declaration

Play asks these directly. The honest answers are the simple ones.

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Not applicable — no data is collected or transmitted |
| Do you provide a way for users to request that their data is deleted? | Not applicable — nothing is collected. Uninstalling removes everything stored locally |

**Supporting facts, should Play query it:**

- The release manifest requests **no Android platform permission at all** — in
  particular no `INTERNET`, so the app has no means of transmitting anything.
  The manifest does contain one `uses-permission` line, for
  `io.github.pkellyuk.kylesvoice.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.
  That is a permission the app defines on itself at `protectionLevel="signature"`,
  added automatically by AndroidX Core so that an app's own dynamic broadcast
  receivers cannot be reached by other apps. It grants the app nothing, is never
  shown to a user, and has no bearing on Data safety.
  (`android.permission.DUMP` also appears, but as the guard *on* AndroidX's
  ProfileInstallReceiver — the app demands it of callers rather than holding it.)
  Verifiable on the merged manifest, or with `aapt2 dump permissions` on the
  uploaded bundle.
- No analytics, advertising, crash-reporting or attribution SDK is present. The
  full dependency list is four packages: `flutter_tts`, `image_picker`,
  `path_provider`, `flutter_svg`, plus `flutter_svg`'s own dependencies.
- Photographs are written to app-private storage via `path_provider`, never to
  shared storage.

## Privacy policy URL

```
https://pkellyuk.github.io/KylesVoice/privacy-policy.html
```

**This needs GitHub Pages turned on before it will resolve.** In the repository:
Settings → Pages → Source: *Deploy from a branch* → Branch: `main`, folder
`/docs` → Save. Give it a minute, then check the URL loads before pasting it
into the Console.

## Content rating

Complete the IARC questionnaire. Truthful answers for this app:

- No violence, sexual content, profanity, gambling, or drug references.
- No user-generated content shared between users.
- No in-app purchases.
- No advertising.
- Does the app share the user's location? **No.**
- Does the app allow users to interact or exchange information? **No.**
- Is the app primarily a news or educational product? **No.**

The last one is worth explaining, because it looks arguable. IARC asks it to
decide whether otherwise-ratable content should be read in a news or teaching
context — a news report on a drug raid is not rated like the same thing shown
for entertainment. Kyle's Voice carries no news, and it is not an educational
product: it does not teach, it lets someone speak. The only content in it is
whatever words a parent put on the cards. Nothing in the app needs
contextualising, so answering yes would buy nothing and invite a reviewer to
ask what, exactly, it teaches.

This is a different field from the store **category**, where Education remains a
defensible choice.

Expected outcome: rated suitable for all ages in every region.

## Target audience and content

This is the question that decides whether Play's **Families policy** applies.

The app is genuinely intended for children *and* adults — AAC users span all
ages. Selecting a child age band brings the Families programme requirements,
which this app already satisfies: no ads, no analytics SDKs, no data collection,
and a privacy policy.

**Recommended:** declare a mixed audience including under-13s, and be ready to
confirm the app is designed for children. Nothing in the build needs to change
either way.

## Ads

Declare **"No, my app does not contain ads."** This is true and must remain true.

## Screenshots and graphics

Play requires, at minimum:

| Asset | Requirement | Status |
|---|---|---|
| App icon | 512 x 512 PNG | `docs/store/icon-512.png` |
| Feature graphic | 1024 x 500 | `docs/store/feature-graphic-1024x500.png` |
| Tablet screenshots | 2-8 | Six, at 2560 x 1600, in `docs/store/` |
| Phone screenshots | 2-8 | Six, at 2400 x 1263, in `docs/store/` |

The six tablet screenshots, in the order worth uploading them:

| File | Shows |
|---|---|
| `shot-1-board.png` | The board itself — the product in one glance |
| `shot-6-symbols.png` | The symbol picker mid-search, showing the breadth of the set |
| `shot-4-card-editor.png` | The card editor: photograph, symbol and colour together |
| `shot-3-editor.png` | The board editor with an empty cell waiting |
| `shot-5-pages.png` | Page two, showing the paging arrows |
| `shot-2-parent-gate.png` | The grown-up check that keeps the editor out of reach |

All are generated reproducibly: `tools/make_demo_board.py` builds the demo
vocabulary, and the images come from the tablet emulator. No real photograph of
a child appears in any of them.

### Phone screenshots

Play asks for phone screenshots separately from tablet ones, and the app is
available on phones. The app is landscape-locked, so these are landscape too.

| File | Shows |
|---|---|
| `shot-phone-1-board.png` | The board itself |
| `shot-phone-2-symbols.png` | The symbol picker mid-search |
| `shot-phone-3-card-editor.png` | The card editor: photograph and symbol together |
| `shot-phone-4-editor.png` | The board editor with an empty cell waiting |
| `shot-phone-5-pages.png` | Page two, showing the paging arrows |
| `shot-phone-6-parent-gate.png` | The grown-up check |

Captured from a Pixel 6 emulator (`kv_phone_api33`) running a debug build with
the demo board pushed onto it, exactly as the tablet shots were.

**They are padded, and they have to be.** Play rejects a screenshot whose long
edge is more than twice its short edge. A Pixel 6 in landscape is 2400 x 1080,
which is 2.22:1, so a screenshot straight off the device is refused even though
it is precisely what the user sees. `tools/pad_screenshots.py` pads the short
edge with the app's own background colour — no cropping, nothing hidden — to
2400 x 1263, or 1.9:1. It also converts to 24-bit RGB, which Play requires and
`screencap` does not produce.

```bat
adb -s <device> exec-out screencap -p > shot.png
python3 tools/pad_screenshots.py shot-phone-1-board=shot.png
```

## Release checklist

- [x] GitHub Pages enabled and the privacy policy URL resolving
- [x] Upload keystore generated (backing it up somewhere that is not this
      machine remains yours to do — see `RELEASING.md`)
- [x] `android/key.properties` created locally, not committed
- [x] `flutter build appbundle --release` produces a bundle signed with the
      upload key (verified: owner `CN=Paul Kelly`, not `CN=Android Debug`)
- [x] Feature graphic and tablet screenshots produced
- [x] Phone screenshots produced
- [ ] Data safety, content rating and target audience forms completed
- [ ] Internal testing track used first, on Paul's own devices, before any
      production release
