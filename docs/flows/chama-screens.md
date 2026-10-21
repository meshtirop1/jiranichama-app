# Chama screens (Phase 1)

What a member sees depends on the chama's state. The server flows behind each screen are
in the API repo: `docs/flows/chama-setup.md`, `statements.md` and `payments.md`.

## Home

The member's chamas, one card each: initials, name, type, their role, and the state as a
coloured pill (green when active). Under them, two cards side by side: **Create a chama**
(green) and **Join with a code**.

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

## Money in the chama's own currency

A chama keeps its records in the currency of its country: KES, UGX or TZS for now. When a
chama is opened, the app sets that currency (`Kes.currency`) and every amount on its
screens shows in it ("UGX 28,000"; Uganda and Tanzania without cents). Screen readers say
"Uganda shillings". Field labels no longer say "(KES)". The bank list in setup shows the
chama's country's banks, and "how to pay" says "Mobile money", not "M-Pesa", because
Uganda and Tanzania pay with MTN MoMo, Airtel Money, Mixx and others too.

If a member has missed as many months as the rules allow fines for, fines stop. The
headline card then says so, and tells the member to talk to their officials about a
payment plan. Officials set the number of months in the rules editor (default 3).

## Active chama

Four sections behind a bottom navigation bar: Overview, Records, Members and Rules. The
app bar shows the chama's initials, name, type and my role. (It used to be four tabs at
the top; the bar keeps them in thumb reach.)

- **Overview**: a green headline card with what I have contributed, then my arrears,
  fines (each with an amber dot when not zero) and next amount due, and **See my
  statement**. Under it, anything that needs me (as coloured notes that open the right
  screen), then how to pay (the bank account, the paybill, and my member code as the
  reference) and a note that the chama records money only until Phase 2. Then a
  **Shortcuts** grid: Money out, Chama statement, Cash at meetings, Opening balances (and
  the merry-go-round where the rules have one). Officials also get **Bank statements** and
  **Unmatched payments**.
- **Records**: every record, newest first, after the phone has checked the whole chain
  itself (see [chain check](chain-check.md)). A green note when it holds, a red warning
  when it does not, and a note when new records are still waiting for the platform
  signature. On a payment the treasurer assigned to me, **This was not me** sends it back.
- **Members** and **Rules**.

## Does the bank match the records?

Where the chama's bank is read through its API (Phase 4, API `docs/flows/bank-feeds.md`),
the card adds "Balance read straight from the bank."

Near the top of every member's overview, the result of the daily check (5.5):
- **Records match the bank · checked {date}**, or
- **The records and the bank differ by KES X since {date}** (amber): how much is payments
  not yet matched to a member, how much nothing explains, and that it becomes a breach,
  and everyone is told, after 7 days; with the bank and records figures; or
- **BREACH** (red), with how many days it has been open; or
- that no bank statement has been accepted yet.

An overdue bank statement shows above it, to the people the rules' timetable is for: the
treasurer when it falls overdue ("The bank statement is 3 day(s) overdue…"), every
official after 7 more days, and every member after 14 more ("Records not checked against
the bank since {date}.").

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

Officials see payments the app could not match. A payment that came straight from the
chama's M-Pesa paybill (seconds after it was made) says "From M-Pesa just now"; most
such payments are matched before anyone looks. Only the treasurer has **Assign**:
choose the member and write why it belongs to them.

## Money out

A **Money out** button on the overview, for every member.
- **Switching on**: while it is off, the screen explains what changes, shows how many
  officials have agreed (two are needed) and lets an official agree by SMS code.
- **Proposing** (officials): *Propose a payment*, to a member (picked from the list) or
  to someone else (typed in), with their account if known, amount and what it is for.
  The API answers at once: waiting for approvals, or refused, with the rule named
  ("Rule 4.2: this amount needs a members' vote…").
- **A proposal**: payee, amount, purpose, who proposed, how many approvals of how many,
  and each official's answer. An official who may answer sees **Decline** (with a
  reason) and **Approve** (SMS code naming exactly what is paid). The member being paid
  is told they do not approve. When approved, an official taps **Mark as paid at the
  bank** with the bank reference; when the statement shows the debit it becomes **Paid
  and matched to the bank**. The proposer can cancel before payment.
- **Money out with no approval**: shown in red to every member, on the overview and the
  Money out screen ("KES 45,000 left the bank on … with no approval. Every member was
  told."). Officials **Explain** it or **Link** it to an approved payment of the same
  amount; the explanation or link then shows to everyone.
- The overview also says when payments are waiting for your approval.

### Approving with the fingerprint (6.7)

On Money out, an official sees **Approve with your fingerprint** with **Set up this
phone**. Setting up makes a key in the phone's keystore, locked behind the fingerprint,
face or phone PIN, with an attestation that the phone vouches for it. An SMS code
confirms the account owner is holding the phone.

From then on **Approve** on a proposal fetches the exact payload with a fresh nonce. The
app checks it is the proposal on screen (amount, payee, hash), then Android asks for
the fingerprint, face or PIN ("Approve KES 20,000 to Wanjiru"). The key signs, and
nothing else is asked. The answer shows "approved with their phone key" and a
fingerprint icon. A payload that does not match what is on screen is never signed.
Backing out sends nothing.

Officials on phones without a screen lock or fingerprint, older than Android 11, or on
iPhone (for now) keep SMS codes. Signing out forgets the phone's key, so the next person
to sign in on that phone never inherits it.

## Inviting members after the chama is active

Officials have **Invite a member** on the Members tab: a phone number, and **They have
no smartphone** for someone on a basic phone, in English or Kiswahili. Without the
switch it creates an invite code to share; they enter it in the app. With it, they get
the main rules by SMS and reply YES with the code to join (jiranichama-api
docs/flows/sms-commands.md).

## Members' votes

A payout above the rules' vote level opens a members' vote alongside the officials'
approvals.
- **Overview**: every member who may vote sees "Your vote is needed: {question}" until
  they have voted.
- **Vote screen**:
  - the question, whether it is open, passed, failed or lapsed, and when it closes;
  - how many have voted out of how many, and the number needed for it to count;
  - the pass rule, and whether it is secret;
  - **Vote yes** / **Vote no**. With a phone key, Android asks for the fingerprint and
    the phone signs the choice; otherwise an SMS code naming the choice confirms it.
- **After voting**: "You voted yes" (not shown in a secret vote) and who has voted. The
  yes/no count appears only once the vote has closed, with its receipt.
- **Proposal screen**: a payout that needs a vote shows the vote's state and opens it.

## Changing the rules (5.10)

The rules of an active chama change only by a members' vote (API
`docs/flows/rule-changes.md`).
- **Rules tab**: officials see **Propose a rule change**; everyone sees the changes being
  decided or recently decided, with where each stands (reading, voting, adopted, in force,
  turned down, too few voted, withdrawn).
- **Proposing**: the same All rules editor, filled with the rules in force, plus "Why should
  the rules change?". **Send to members** sends the whole set; setting errors come back next
  to the setting as in setup. Sending the rules unchanged is refused.
- **A change's screen**: the reason and who proposed it, where it stands ("Members can read
  it until {date}. Then the vote opens for {days} days."), the thresholds, and each changed
  rule-book clause: **Now** (struck through) and **Proposed**, in the member's language.
  During voting, **Go to the vote** opens the usual vote screen. The official who proposed
  it can withdraw it during the notice period.
- **Why the whole rule set is edited**: members compare whole clauses in plain words, and
  the API checks the complete result, so a change that clashes with another setting is
  caught before anyone votes.

## Growth (Phase 5)

A Growth card on the overview shows the net worth (bank plus investments) and opens three
tabs (API: `docs/flows/analytics.md`, `investments.md`, `referrals.md`):
- **Numbers**, for every member: the money (contributed, bank, investments, net worth),
  each month's share paid with late money and fines, who is behind, and meeting
  attendance.
- **Investments**: each holding at cost and at its latest confirmed value, with income
  so far. Officials record one (kind, name, cost) and add a valuation with its source; a
  valuation waits until a different official confirms it.
- **Partners**: what JiraniChama does and does not do, any referrals with where they
  stand, and the licensed partners with their regulator and licence number. An official
  can ask the members to agree to a referral (it goes to a members' vote) and withdraw it
  until it is sent.

## Running the chama (5.12, 5.13, 5.14)

- **Get help** (officials, API `docs/flows/support-access.md`): choose what JiraniChama
  support may read (bank statements, rules, records, members, disputes) and for how long
  (24 hours, 72 hours or 7 days), and say why. A second official confirms; until then the
  request waits. While access is open, every member sees "JiraniChama support can read …
  until …" on the overview, and any official can end it.

The overview ends with **More for this chama**, the places to go: Fines, **Running the chama**, Meetings and
(where switched on) Loans. Anything that needs me shows as a warning above the Running
the chama card: an election is needed, a new phone waits for my vouching, or a dispute
waits for my answer.

- **Disputes** (API `docs/flows/disputes.md`): **Raise a problem** (reason, words,
  optionally officials only). A dispute shows who raised it, who is involved, where it
  stands, the messages, and the outcome with how many officials agreed and its receipt.
  Anyone can **Respond**. An uninvolved official can **Propose an outcome** (no change,
  reverse the entry, correct or refund a member's amount) and others **Agree** with an
  SMS code or **Disagree**. The member who raised it can withdraw it, and they or an
  official can take it outside the chama.
- **New phones** (API `docs/flows/device-keys.md`): officials see another official's
  new phone after a lost one, are told to call them first, and **Vouch** with an SMS code.
- **Elections** (API `docs/flows/elections.md`): officials **Hold an election**: the role,
  the candidate (members only), and whether it is an acting official for an empty role.
  Each election shows its state, "starts when their phone is set up" for a winner without
  a key, and "update the bank signatories" with **Bank updated** for officials.
- **Leaving and deaths** (API `docs/flows/exits.md`): a member taps **Leave the chama**,
  reads what comes back (savings, fines, loan, deduction, notice), and confirms with an
  SMS code; during the notice they can **Stay in the chama**. Officials **Record a
  member's death** with the next of kin's name and phone and a photo of the permit or
  certificate. Every exit and death is listed with its date, amount and state.

## Fines and waivers (5.9)

API flow: `docs/flows/fine-waivers.md`.
- **Overview**: a Fines card with what I owe in fines and how many waivers wait for my
  decision.
- **Fines**: every fine in the chama, with who, the rule, the month, its state and its
  receipt, plus the latest waiver with its reason and approvals so far.
- A member can **Ask for a waiver** of their own unpaid fine, with a reason.
- An official who may decide sees **Approve the waiver (SMS code)** and **Decline**.
  Nobody sees these for their own fine.

## Loans (5.8, switched off for now)

Shown only where the chama data says `loans_on` (the API's `loans` flag, off until the
lending opinion; API `docs/flows/loans.md`).
- **Overview**: a Loans card with my open loan and what I owe, and a warning line for
  every request asking me to guarantee a loan.
- **Loans**: the chama's loan book. Every member sees every loan.
- **Request a loan**: enter the amount and months, then **See the terms**. The screen shows
  the limit and savings, the interest, every reason the rules refuse (with its rule
  number, in the member's language), and the whole schedule with totals, all before
  anything is sent. Then the purpose and the guarantors (exactly as many as the rules
  need), and **Ask the guarantors**.
- **A loan**: where it stands, the balance (owed, repaid, interest so far, due now), the
  guarantors and their answers, and the schedule. The borrower can cancel while
  guarantors are answering, and can choose someone else in place of a guarantor who
  declined or did not answer.
- **Guaranteeing**: the guarantor reads the amount and their share, and that the rules can
  recover it from their savings. They accept with an SMS code (which names both amounts)
  or decline.

## Meetings (5.11)

API flow: `docs/flows/meetings.md`.
- **Overview** shows a Meetings card with the next meeting; it opens every meeting, newest
  first.
- **The secretary** (or an official when there is no secretary) schedules one: what, day,
  time, where or an online link, and agenda. It cannot be edited afterwards; cancelling
  (with a reason) tells members by SMS.
- **Before it starts**, a member can **Send an apology** with a reason.
- **At the meeting** the secretary opens it for check-in and **shows the check-in code**:
  a QR code and its six digits, refreshed before they change (every 30 seconds). Members
  tap **Check in** and scan it with the camera, or **type the code**. The secretary marks
  members on basic phones as present or late from the attendance list.
- **Close attendance** asks for confirmation, since members not checked in become absent
  and the rules' fines are raised. The attendance receipt shows afterwards.
- **Minutes**: the secretary writes them and/or adds a photo of handwritten ones. Members
  see them, with the date the objection week ends, and can **Object** with a reason. If
  there are objections the secretary can **Revise the minutes** (a new version). Sealed
  minutes show their ledger receipt.
- **Rules editor**: a Meetings section for the absence and lateness fines, minutes after
  which a member is late, whether an apology avoids the fine, and the days to object.
- **Why a typed code as well as the QR**: an old phone camera, a cracked screen, or a dim
  hall can make scanning fail; the code always works and changes just as often.

## Merry-go-round

For chamas whose rules have a rotation, a **Merry-go-round** button on the overview.
- The rules' settings in words: how the order is made (drawn, or set by the officials)
  and what happens to a member behind on contributions (moved to the end, paid less
  what they owe, or the rotation waits).
- **Start the rotation** (officials): for a drawn order, a confirmation that the app
  draws from the records and everyone can re-check; for a fixed order, a list to move
  members up and down.
- The cycle: what each turn receives, the draw's seed and receipt, and every turn in
  order (next, waiting, paid, or skipped with the reason), with its payout's state.
- **Propose next payout** (officials, money out on) fills in the member and the pot and
  opens the proposal, which then goes through the usual approvals.
- The full rules editor has a Merry-go-round section for both settings.

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

## Protections (2026-10-20)

- **Reported as dead.** The member sees a red notice first on their home screen, with
  "I am alive". Tapping it cancels the report, and every member is told who made it.
- **Confirming a death.** In the exits list, an official who did not make the report sees
  "Confirm this death". The reporter never does. The row shows who reported it and
  whether a second official has confirmed.
- **Withdrawals with no approval.** Once an official has explained one, the row says the
  members are voting on it and that nothing can be paid until they accept it. The explain
  button is hidden while that vote runs.

## Bank signatories (2026-10-20)

- **Running the chama → Bank signatories** shows what the bank has on file: who signs,
  how many must sign, whether each signatory approves in the bank's own app, and who
  uploaded and confirmed it.
- An official ticks the signatories, sets how many must sign (two at least), attaches a
  photo of the bank's form and sends it. A different official confirms it with an SMS code.
- Until a mandate needing two signatures is confirmed, every member's overview shows a
  warning, and money out cannot be switched on.
- Records show "Bank statement sealed" for every accepted statement and "Bank signatories
  confirmed" for the mandate.

## JiraniChama bill (2026-10-21)

**Running the chama → JiraniChama bill** shows every member what the chama pays JiraniChama:

- this month so far (active members × the price per member);
- why it is free when it is (the first three months, or five active members or fewer);
- how the price works;
- where to pay, once the paybill is set;
- past bills, marked paid, free, or due by a date.

See `docs/flows/billing.md` in the API repository.

## Screen-by-screen polish (2026-10-21)

After a screen-by-screen pass on the emulator:

- **Records:** every kind of record has a real name and icon, for example "Phone key set
  up", "Records sealed", "Vote result" and "Loan repayment". Membership records say what
  changed: "Death reported", "Gave notice to leave", "Left the chama" and so on. A death
  report used to read "Joined".
- **Records totals:** a total of zero is shown plain grey, not in green or red.
- **Fines:**
  - a header shows the total still owed and how many unpaid fines and members there are;
  - filter chips show unpaid fines (the default), mine, or all;
  - each fine has a status pill (Owed, Paid, Waived);
  - the line under the name drops the lowercase status word.
- **Leaving and deaths:** an unconfirmed report reads "Name: reported dead", not "has died".
- **Meetings:** when the list is empty it says who schedules meetings. The secretary sees
  how to start one.
- **Money out:** without a safe bank mandate, officials see what to do first instead of a
  "Switch on" button that would fail.
- **Settings:** the profile card shows the phone and the country on their own lines.
- **Create a chama and Join a chama:** each has a short heading and explanation. Create
  also explains each kind of chama and what comes next.

## The law in your country (2026-10-21)

At the top of the Rules tab, every member sees what their country's law asks of savings groups:

- the group size the law allows;
- any rule settings the law forbids;
- duties such as registering, quarterly reports or required officials.

Each item is marked done (green tick), to do (empty circle) or a problem (red or amber). The card says how many things need fixing. Text comes from `GET /chamas/{id}/country-rules/`.
