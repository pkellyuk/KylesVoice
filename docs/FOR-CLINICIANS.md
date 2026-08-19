# Kyle's Voice — Notes for Speech and Language Therapists

A plain-language summary of what this app is and the clinical assumptions built
into it. Corrections very welcome — several decisions below are our best
reading of good practice, not clinical expertise, and we would rather change
them now than after a child has learned them.

## What it is

A free, open-source picture-communication app with speech output. No cost, no
advertising, no subscription, no account, no data collection, and no feature
held back behind payment.

**Android tablets and phones first.** iPad support is intended but will come
later — it is deliberately deferred so that a working app reaches the child
sooner. If iPad is important for your caseload, please say so, as it would
change the ordering.

It was built for one 10-year-old boy starting his first pictorial system, and
is being shared openly in case it is useful to others. Board sets can be
exported and shared between home and school as a single file, and exported in
Open Board Format so they are not locked into this app.

## Clinical assumptions we have designed around

**1. Motor planning consistency.** Cards never move. The grid does not reflow,
re-sort, or close gaps when vocabulary is added or hidden. Vocabulary is added
by filling empty cells in an already full-size grid, so the motor path to a word
learned in month one is still correct in year three. The editor warns before
moving any populated card.

**2. Photographs first, symbols later.** Because the request was for a mix of
real and abstract images, each card holds *both* a photograph and a symbol, with
a blend control between them. A card can start as a photo of the child's own cup
and be shifted gradually toward an abstract "drink" symbol over weeks, per card
or across the whole board at once, without ever changing position or label.

**3. Text is present but not required.** Labels appear on cards for incidental
exposure to print even for a non-reading child. Size, position and visibility
are all configurable, including off.

**4. Immediate speech at first, sentence building later.** The initial setting
speaks each card as it is touched, for the tightest possible feedback loop.
Multi-word sentence building is a setting, not a different app or a different
board.

**5. Colour coding is available but off by default.** Fitzgerald Key / Goossens
colouring can be switched on when it is being taught.

**6. Nothing punishes error.** No error sounds, no "wrong" feedback, no scores,
no rewards or streaks. It is a voice, not a game.

## The touch handling, and why it is unusual

The child this was built for frequently activates targets with an open-palm
slap rather than a point. Standard apps hit-test a single contact point, so a
slap fires whichever card happens to sit under the reported centre — often the
wrong word.

This app instead measures the **area of contact** and activates the card that the
hand is mostly covering. It also ignores extra fingers landing milliseconds
apart, and blocks repeat activation for a short window afterwards to prevent
double-firing from bounce.

Where two cards are covered near-equally, the behaviour is configurable: fire
the larger overlap anyway (default — biased toward always giving the child a
voice), or do nothing. We would particularly value your view on which default is
right, and on whether "do nothing" risks more frustration than an occasional
wrong word.

Other adjustable settings: hold-to-activate time, gap size between cards,
activate-on-press versus on-release, and repeat-activation lockout.

## What we would value your input on

1. **Initial vocabulary and grid size.** Our starting proposal is a 4 x 3 grid
   with only 4-6 cells filled, so there is room to grow without anything ever
   moving. Is that the right shape and the right starting density?
2. **Ambiguous-touch policy** — fire the best guess, or ignore? (See above.)
3. **The photo-to-symbol blend progression** — is a gradual cross-fade sound
   practice, or is a clean switch at a chosen point better?
4. **Immediate speech vs. sentence building** as a starting mode.
5. **Anything here that contradicts current practice.** We would rather be
   corrected early.
6. **Switch scanning**, planned for a later phase — is it worth building, and if
   so what scanning patterns and switch hardware are actually in use?

## What we will not do

- Charge for it, or for any part of it.
- Collect any data. Optional usage logging (most-used cards, utterances per day)
  is off by default, stays entirely on the device, and exports to a spreadsheet
  only if a parent or therapist chooses to.
- Use proprietary symbol sets we do not have the right to redistribute.
