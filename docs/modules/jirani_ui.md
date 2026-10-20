# jirani_ui

The design system. Screens use its tokens and widgets, never raw colours or sizes, so the
look changes in one place.

## Why it looks like this

The owner said on 2026-10-20 that the first styling was too plain. It was Material 3
generated from one seed colour, with outlined buttons stacked on the overview. The
redesign follows the money apps people in Kenya already trust:

- **One headline card.** Your position (what you have contributed, plus arrears, fines
  and the next amount due) sits on a deep green card at the top.
- **Shortcuts, not a list of buttons.** A three-column grid.
- **Calm surfaces.** White cards (a lifted grey in dark mode) with a hairline border and
  no shadows. Colour is kept for meaning: green for money in and good results, amber for
  waiting, red for problems.
- **Its own font.** Plus Jakarta Sans is bundled, so it works offline and looks the same
  on every phone.

## Pieces

| Piece | Use |
| --- | --- |
| `JiraniTheme.light()` / `.dark()` | A hand-set palette for each mode, not generated from a seed, so the greens stay deep and amounts read clearly. Themes every component: app bar, cards, fields, buttons, tabs, the bottom navigation bar, sheets, dialogs, snack bars and switches |
| `JiraniColors`, `JiraniSpace`, `JiraniRadius` | Tokens. The brand green `#1B6B4A` is final (owner, 2026-10-19). Gold `#C8962E` is the accent |
| `JiraniStatus` (theme extension) | Good, info and warning colours (each with a soft container), the card surface and the hero gradient, for light and dark. Read with `JiraniStatus.of(context)` |
| `JiraniTone` | How something reads: neutral, brand, good, info, warning or critical |
| `HeroCard`, `HeroFigure` | The green headline card and the figures inside it |
| `QuickActions`, `QuickAction` | The shortcut grid: three to a row, four on wide screens |
| `NavTile` | A row that leads to a screen: tinted icon, title, one-line summary, chevron |
| `SurfaceCard` | A plain card (tappable if given `onTap`) |
| `SectionHeader` | The heading over a group |
| `StatusPill` | A short status on a soft pill ("Active", "Chairperson") |
| `InfoRow` | A label and a figure in a card |
| `ToneIcon` | An icon on a tinted rounded square |
| `Avatar` | Initials on a colour picked from the name, so the same person always looks the same |
| `EmptyState` | What a screen shows when there is nothing yet |
| `BrandMark` | The mark (members around the pot) used on sign-in, the splash and the home bar |
| `ActionBar` | Pins a screen's main action to the bottom (`Scaffold.bottomNavigationBar`) |
| `PrimaryButton` | The one main action on a screen; shows a spinner while busy |
| `DigitsField` | Codes and PINs: digits only, centred, fixed length, one-time-code autofill |
| `MoneyText` | Amounts with even-width digits, read out as "Kenya shillings" by screen readers |
| `Notice` | In-screen messages: info, good, warning or critical. Pass `onTap` to make it a link to the screen that deals with it. Announced to screen readers |

Text sizes must work up to 200%; tap targets are at least 48 points. The font's licence
(SIL Open Font License) is in `packages/jirani_ui/fonts/OFL.txt`.
