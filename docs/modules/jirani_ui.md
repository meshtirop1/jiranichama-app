# jirani_ui

The design system. Screens use its tokens and widgets, never raw colours or sizes, so the
Figma export can replace the placeholder values in one place.

| Piece | Use |
| --- | --- |
| `JiraniTheme.light()` / `.dark()` | Material 3 themes from the brand colour |
| `JiraniColors`, `JiraniSpace`, `JiraniRadius` | Tokens. Brand green `#1B6B4A` is final (owner, 2026-10-19); the rest wait for Figma |
| `PrimaryButton` | The one main action on a screen; shows a spinner while busy |
| `DigitsField` | Codes and PINs: digits only, fixed length, one-time-code autofill |
| `MoneyText` | Amounts, read out as "Kenya shillings" by screen readers |
| `Notice` | In-screen messages (info, warning, critical), announced to screen readers |

Text sizes must work up to 200%; tap targets are at least 48 points.
