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

- The release manifest declares **no permissions whatsoever**. Verifiable with
  `aapt2 dump permissions` on the uploaded bundle.
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
| App icon | 512 × 512 PNG, 32-bit | `docs/store/icon-512.png` — generated by `tools/generate_icon.py` |
| Feature graphic | 1024 × 500 PNG or JPEG | **Still needed** |
| Phone screenshots | 2–8, min 320px on the short side | **Still needed** |
| Tablet screenshots | Recommended, since the tablet layout is the primary one | **Still needed** |

Good candidates for screenshots, in order:

1. The board itself with a full set of cards — the product in one glance.
2. A card being pressed, showing the highlight.
3. The symbol picker with a search in progress, showing the breadth of the set.
4. The card editor with a photograph attached and the photo/symbol fade slider.
5. Page two of a board, showing the paging arrows.

Take them on the tablet emulator at 2560 × 1600, or on a real device. Avoid
showing any real photograph of a child.

## Release checklist

- [ ] GitHub Pages enabled and the privacy policy URL resolving
- [ ] Upload keystore generated and **backed up somewhere that is not this
      machine** (see `RELEASING.md`)
- [ ] `android/key.properties` created locally, not committed
- [ ] `flutter build appbundle --release` produces a bundle signed with the
      upload key
- [ ] Feature graphic and screenshots produced
- [ ] Data safety, content rating and target audience forms completed
- [ ] Internal testing track used first, on Paul's own devices, before any
      production release
