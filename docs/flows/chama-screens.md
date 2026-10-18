# Chama screens (Phase 1)

What a member sees depends on the chama's state. The server flows behind each screen are
in the API repo: `docs/flows/chama-setup.md`, `statements.md` and `payments.md`.

## Home

The member's chamas, with type, state and their role; buttons to create one or join with
an invite code.

## Create and set up (founder)

1. **Create**: name, type, and the founder's own role.
2. **Setup** shows, to the founder only:
   - **Bank account**: bank, account name and number, paybill, and how statements
     arrive. Choosing "the bank emails them" shows the chama's inbox address to give the
     bank.
   - **Rules**: the four settings most chamas change (monthly amount, due day, grace
     days, late fine), and the full rule book as it will read.
   - **Invites**: officials by phone number; the invite code is shown to share.
   - **Send the rules for confirmation**, once the bank account is in.
   Everyone else sees "the founder is still setting up" and the rule book.

## Join

Type the invite code, read the chama's rule book, then **Join and accept these rules**.
An SMS code that names the chama confirms it.

## Confirm the rules (founding members)

The rule book, how many founding members have confirmed and how many are needed, and a
**Confirm these rules** button that sends an SMS code.

## Active chama

- **Overview**: my contributions, unpaid months, fines and next amount due; how to pay
  (the bank account, the paybill, and my member code as the reference); a note that the
  chama records money only until Phase 2. Officials also get **Bank statements** and
  **Unmatched payments**.
- **Records**: every record, newest first, after the phone has checked the whole chain
  itself (see [chain check](chain-check.md)). A green note when it holds, a red warning
  when it does not, and a note when new records are still waiting for the platform
  signature. On a payment the treasurer assigned to me, **This was not me** sends it back.
- **Members** and **Rules**.

## Bank statements (officials)

Upload a CSV statement; the list shows each statement's state, period, number of lines,
closing balance, who uploaded and who confirmed it, and any problems or flags. A
statement waiting for confirmation has **Confirm this statement** (SMS code). The server
refuses the treasurer as uploader, and the uploader as confirmer, and the app shows why.

## Unmatched payments

Officials see payments the app could not match. Only the treasurer has **Assign**:
choose the member and write why it belongs to them.

## Design notes

- **The main action is pinned to the bottom** of the join, confirm-rules and setup
  screens (`ActionBar` in `jirani_ui`), so it stays in reach above a long rule book.
- **Reversed records stay visible but are struck through and marked**, and each
  correction names the receipt it corrects. Nothing is ever deleted.

- **SMS codes**: one bottom sheet for every confirmation. Wrong codes show the tries left.
  The screen behind is busy only while the code is being sent, never while the member
  types it.
- **Retries never double-record**: creating a chama, uploading, assigning and "not me"
  each send an `Idempotency-Key` made once per action.
- **Brand colour**: JiraniChama green `#1B6B4A`, chosen by the owner on 2026-10-19.

## Not yet

Opening balances, cash at meetings, PDF member statements, the full rules editor (all
settings, not only the main four), the encrypted offline copy of the ledger, and pull to
refresh on every list.
