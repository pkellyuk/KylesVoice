---
layout: default
title: Privacy policy — Kyle's Voice
---

# Privacy policy — Kyle's Voice

**Last updated:** 19 August 2026

Kyle's Voice is a free, open-source communication app. It is built for people
who cannot speak, including children. This policy is written plainly because the
people who need to read it are parents, carers and therapists, not lawyers.

## The short version

**Kyle's Voice collects nothing, sends nothing, and has no way to.** There are no
accounts, no advertising, no analytics, and no tracking of any kind. The release
build does not even ask Android for permission to use the internet.

## What the app stores, and where

Everything the app keeps is stored **only on your own device**, in the app's own
private storage area that other apps cannot read:

| What | Where |
|---|---|
| Your board: cards, words, spoken phrases, colours, layout | A file in the app's private storage |
| Photographs you add to cards | The app's private storage |
| Which symbols you chose | Part of the board file |

Uninstalling the app deletes all of it. Nothing is copied anywhere else unless
you deliberately export or share it yourself.

## The camera and your photos

When you add a photograph to a card, the app opens your device's normal camera
app or photo picker. The app does not declare the camera permission and has no
independent access to your camera or your photo library. It receives only the
single picture you choose, and stores a copy of it in its own private storage.

## Speech

Spoken words are produced by the text-to-speech engine already installed on your
device — Google's, Samsung's, Amazon's, or whichever you have chosen in your
Android settings. Kyle's Voice passes the card's phrase to that engine.

**One thing worth knowing:** the speech engine is a separate app with its own
permissions and its own privacy policy. Some engines offer higher-quality
"network" voices that send the text to be processed on a server. Kyle's Voice
cannot control this and does not know which kind of voice you have selected. If
this matters to you, choose an offline or "installed" voice in your device's
text-to-speech settings, or install offline voice data. Kyle's Voice itself
sends nothing anywhere.

## Children

This app is intended to be used by children as well as adults. It is designed so
that there is nothing to collect: no sign-up, no profile, no identifiers, no
advertising, no third-party analytics SDKs, and no content from the internet.

## Optional usage logging

A future version may offer optional logging of which cards are used, to help
therapists review progress. If it is ever added it will be **off by default**,
will stay **entirely on the device**, will be exportable only by you, and will
be deletable in one action. It will never be transmitted anywhere. This policy
will be updated before any such feature ships.

## Permissions

The released app declares **no Android permissions at all**. Development builds
declare internet access purely so the developer tools can attach to a running
app; that permission is not present in any version distributed to users.

## Open source

The complete source code is public at
<https://github.com/pkellyuk/KylesVoice>, so every claim here can be checked
rather than taken on trust.

## Contact

Questions, or anything in this policy that looks wrong, to
**paulj.kellyuk@gmail.com**, or raise an issue at
<https://github.com/pkellyuk/KylesVoice/issues>.
