# Guided tours

The owner asked for pop-up animations that explain the parts of the app and what they do
(2026-10-20). Each main screen has a short guided tour.

## What a member sees

The first time a screen opens, the tour starts by itself, about a second later, once the
screen has loaded:

1. The screen dims.
2. A spotlight glides to one part of the screen, and a ring pulses around it to draw the
   eye.
3. A card springs in beside the part. It has an icon, a title, one or two plain
   sentences, dots showing progress, and **Skip** and **Next** (**Got it** on the last
   step).
4. Tapping anywhere also moves on, and the Back button ends the tour.

Each tour plays **once per phone**. The **?** button in the screen's top bar plays it
again at any time.

| Screen | Steps |
| --- | --- |
| Sign-in | Country, language, phone and SMS code |
| Your chamas | The chama list, Create a chama, Join with a code |
| Chama overview | Welcome (JiraniChama never holds the money), your position, how to pay, shortcuts, fines/meetings/loans, the bottom bar |
| Records | The check on your phone (it turns red if a past record was changed), every record |
| Members | The members (tap for a statement); for officials, Invite a member |
| Rules | The rule book; how a rule is changed (a members' vote) |
| Money out | Approval by officials and members' votes; approving with a fingerprint |

The wording is in English and Kiswahili (`tour…` keys in the ARB files).

## How it is built

- **The engine** is `showTour` in `jirani_ui` (`lib/src/tour.dart`). Each `TourStep`
  names a `GlobalKey` on the part to point at.
  - The engine scrolls that part into view and measures it again on every frame, so the
    spotlight follows a part that loads late or a list that is still settling.
  - A step whose part is not on screen shows its card in the middle instead.
  - The card goes below the spotlight, or above it, or, if neither has room, at the foot
    of the screen.
- **The app side** is `lib/core/tours.dart`.
  - `showTourOnce` starts a screen's tour when it has not been seen. It is called from
    the screen's `build`, and checks only once per app run.
  - `TourButton` is the **?** that replays a tour.
  - What has been seen is kept in the phone's secure storage (`tour_<name>`). If storage
    cannot be read (as in widget tests), no tour starts, so tours never get in the way of
    using the app.
- **Tests:** `test/tours_test.dart` plays the home tour step by step with an in-memory
  store, and checks that it does not repeat and that **?** replays it. The tour's ring
  pulses for ever, so these tests pump time instead of waiting for the screen to settle.
