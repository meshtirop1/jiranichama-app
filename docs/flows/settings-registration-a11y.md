# Home tabs, Settings, registering a chama, and "Easy to read" (2026-10-20)

The owner asked for:

- the logo to spin fast while pages load;
- a Settings tab with the profile, the ID-check (KYC) status and more;
- clear arrows for money in, money out and fines;
- a simple way to register a chama with the government, with every law and document
  explained and the papers prepared from what the app knows, plus an occasional prompt;
- an accessibility button for older members and people who do not see well.

## Home has three tabs

The bottom bar has three tabs: **Chamas**, **Register** and **Settings**. A tab is built
the first time it is opened, so opening the app does not load all three.

## Loading

Every page that loads shows `BrandLoader`: the JiraniChama mark, with the gold dots (the
members) spinning around the pot once every 0.65 s, a gold trail behind the leading dot,
and the ring gently pulsing. With "Less movement" on (ours, or the phone's own setting) it
turns slowly, once every 2.4 s. The splash screen uses a large one.

## Money arrows

On the Records tab every record that moves money gets a `FlowArrow`. The three kinds
differ in colour **and** shape, so they still read for someone who cannot tell red from
green:

| | Colour | Shape | Amount |
|---|---|---|---|
| Money in (contributions, repayments, interest, income) | green | round, arrow coming down into a dot (bottom-left) | `+ KES 1,000` |
| Money out (payments, loans paid out, bank charges, unapproved withdrawals) | red | round, arrow leaving up and away (top-right) | `− KES 1,000` |
| Fines (raised, paid, waived) | amber | square, gavel | `KES 200` |

Above the list, three totals show money in, money out and fines raised. Tapping one shows
only those records; tap it again, or the chip, to show everything.

## Easy to read

Every main screen has the person-in-a-circle button in its top bar: sign-in, home, inside
a chama, and Settings. It opens a sheet with:

- **Text size:** seven steps from 90 % to 200 %, with big A−/A+ buttons and a slider. A
  sample line shows the result at once.
- **Bold text**, **High contrast** (black on white or white on black, real borders, no
  grey text), **Bigger buttons** (taller buttons and rows), **Less movement**.
- **Light, dark or the phone's setting.**
- A note on TalkBack for people who prefer to listen.
- **Back to normal.**

The choices apply to the whole app at once (`A11ySettings.apply` on the app's
`MediaQuery`, plus `JiraniTheme.light/dark(highContrast:, largeTargets:)`), and are kept on
the phone (`prefs.dart`). The phone's own text size and bold settings still count:
whichever asks for more wins. A dot on the button shows that something is changed. The
chosen language is now remembered the same way.

## Settings

- **Profile:** the person's name (with a pencil to change it), phone hint, country, and
  the date they joined.
- **ID check:**
  - their status (`kyc_status` from `/auth/me/`: not yet, being checked, checked, not
    passed);
  - how it works (national ID and a selfie through Smile ID, once);
  - that the chama pays;
  - why it matters (officials before money moves; one person, one member);
  - that others see only a tick.

  The button says "coming soon" until the check is switched on.
- **Language and display:** language (EN/SW, saved on the phone and the server), country,
  and "Easy to read".
- **This phone:** whether the signing key is set up, and "Show the guided tours again".
- **Your money and your privacy:** what others see, that JiraniChama never holds money,
  and that the records are sealed.
- **About** and **Sign out**.

## Register

The Register tab (also opened from a chama's overview) shows:

1. A header: "Make your chama official. We fill your papers, you bring the IDs and
   signatures."
2. With more than one chama, a chip for each.
3. **Progress:** "3 of 10 ready" with a bar. Officials tick things off, and every member
   sees how far they are.
4. **Ways to register** in the chama's country. Officials pick one (community group, bank
   account, SACCO or company), and the choice is shared.
5. The chosen way: where to go, the law, the fee, how long it takes, and renewal.
6. **Papers you need.** Each one is marked "We prepare this" or "You bring this". "Make
   PDF" fetches the filled-in paper from the server and opens the share sheet, to print
   it or send it on WhatsApp.
7. **Step by step,** with a tick for each step.
8. **Your certificate** (officials): typing its number marks the chama registered and
   stops the reminders.
9. The guide's "not legal advice" line.

Without a chama, the tab shows the guide for a country the person picks, and a note that
creating the chama fills the papers in.

## The reminder

On an active chama's overview, until the chama is registered (`chama.registered`), a card
says "Register your chama with the government". It has **Prepare the papers** and
**Later**. "Later" hides it on this phone for 14 days, so it comes back now and then
without nagging.

## The ID check, switched on (2026-10-20)

Once the server has Smile ID set up, the Settings card's button reads **Check my ID**. It
opens a short form:

- the kind of ID (the country's options);
- the ID number;
- the names as written on the ID;
- which of the member's chamas pays.

The card then shows "Checked" and "ID ending 1234 checked". Members' lists show a green
tick next to everyone who passed. Only the tick is shared, never the ID. See
`docs/flows/identity.md` in the API repository.
