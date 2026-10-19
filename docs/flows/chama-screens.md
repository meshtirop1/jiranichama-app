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

### All rules (founder, during setup)

Below the main four settings, **Edit all rules** opens every setting in rules schema v1:
- **Contributions**: amount, due day, grace days, days to bank meeting cash, and the order
  a payment pays things off (months behind, fines, this month; arrows move them).
- **Late fine**: on or off, amount, and a monthly limit (empty for none).
- **Officials**: which of chair, treasurer and secretary the chama has (at least two).
- **Approving money out**: up to four levels, each with a limit (the last covers any
  amount), how many officials approve, and whether members also vote; hours to approve.
  These are used once the chama pays out through the app.
- **Membership**: entry fee, and whether new members need a vote.
- **Adopting these rules**: the share of members who must confirm.
- **Bank statements**: how often a new one is due.
- **ID checks**: the chama pays, or each member pays.

**Save rules** sends the whole set. The API checks ranges and contradictions; each error
comes back with the setting's path and a stable code, and shows under that setting in the
member's language. Saving returns to setup, which shows the new main settings.

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

### A line the app could not read

If a row in the bank's file is damaged, the statement shows **Lines to type in** with
how many rows. **Type in lines** opens one card per row: what the file had (so the
official can find it on the bank's copy), then date (with a calendar), money in or money
out, amount, description (filled from the file), and reference and balance if shown.
**Save typed lines** sends them all at once. The API refuses them, saying so, unless the
whole statement then adds up. Afterwards an official who neither uploaded nor typed
confirms as usual. The statement then says "1 line(s) typed in by …", and the payment
shows **Typed in** on Unmatched payments and the records.

## Opening balances

For a chama moving from a notebook. The treasurer enters each member's savings and unpaid
fines and saves a draft. A different official sees "waiting for another official" and
confirms with an SMS code. After that the figures are read-only; each member sees their
own line, can object to it for 14 days, and every member sees objections.

## Cash at meetings

The treasurer records cash handed over at a meeting (member, amount). The member gets a
note on their overview ("1 cash payment is waiting for you to confirm") and confirms with
an SMS code, or says it was not them. Confirmed cash shows as "waiting for the bank
deposit", and as overdue if not banked in time. When the deposit appears on a statement,
the treasurer opens it in Unmatched payments, taps the cash icon, and ticks the receipts
it carries; the button only works when they add up to the deposit exactly.

## Statements

- **My statement**: "See my statement" under *Your position* on the overview. Tapping a
  name on the Members tab opens that member's statement: the records are open, so any
  member can read any member's figures.
- **Chama statement**: a button on the overview for every member. Every member's totals,
  and the bank side (the last reconciled bank statement, payments not yet matched, cash
  waiting for the bank).
- **Period**: since joining, this year, or the last 3 months. The position part is
  always today's.
- **Get PDF statement** asks the API for a sealed PDF in the language the app is in,
  downloads it, keeps it on the phone (app documents, `statements/`) and shows the
  10-character check code with **Share PDF** (WhatsApp, email, print). A member's PDF is
  only for that member, an official or the auditor; others see why the button is missing.
  Whoever receives the PDF scans its QR code, or opens the check address, to see that it
  is genuine. See jiranichama-api docs/flows/member-statements.md.

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

Monthly statements made and sent automatically, the encrypted offline copy of the ledger, and pull to
refresh on every list.
