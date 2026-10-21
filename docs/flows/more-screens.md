# More screens (2026-10-22)

The owner said the app was "too basic" and asked for about 60 screens. It had 43 full
screens (48 counting tabs and sheets). These 17 bring it to 60 full screens (66 counting tabs
and sheets). They all use data the API already serves, so the change is app-only.
`features/more/` holds them.

## Finding things

- **Everything** (`ChamaMenuScreen`, the grid button in a chama's top bar, and "Everything"
  in the shortcuts): every screen of the chama in one list, grouped as Money, People and
  decisions, Records and trust, and The chama.
- **Search** (the magnifier in a chama's top bar): members by name or code, and records by
  receipt, member code, kind or amount.

## About me

- **Welcome** (`WelcomeScreen`): four pages before the first sign-in on a phone.
  - The pages: your money stays in your bank; records nobody can change; decide together;
    every phone works.
  - Shown once (the tour memory's `welcome`). Help shows it again.
  - Shown in place of the sign-in form, so the sign-in tour waits for it.
- **Security** (Settings): change the PIN (current PIN, new twice), see the phones whose
  keys sign for you and retire a lost one, sign out.
- **My payments** (menu): every money record of mine, filtered by paid in, fines, or paid to
  me. Press and hold a record to copy its receipt.
- **Months at a glance** (`ContributionCalendarScreen`, from a member's profile or the
  menu): each month of a year as paid in full, part paid, not paid, coming, or before they
  joined. It is worked out from the member's own statement lines and the rules' monthly
  amount.

## People and records

- **Member profile** (tap a member on the Members tab):
  - role, member code, founding member, the ID check tick;
  - savings, months behind and fines;
  - their months at a glance and their statement;
  - their latest five records.

  Before this, tapping a member went straight to their statement, which is now one tap
  further.
- **Record details** (tap any record on the Records tab):
  - what it is and the amount;
  - whether this phone checked it;
  - member, month, when written, record number;
  - the receipt, to copy, and how anyone can check it by SMS;
  - what the rules decided;
  - its fingerprint and the previous one;
  - whether JiraniChama has signed it;
  - **Dispute this record**.
- **Check a code** (Settings and the menu):
  - a statement's 10-character check code is checked with the server (`/verify/{code}/`),
    which says genuine or not, the chama, the member, the period and the fingerprint;
  - a record's 8-character receipt is looked up in this chama's records on the phone.

  Check codes are Crockford Base32 (O, I and L read as 0, 1, 1); receipts are plain Base32,
  so they are compared as typed.
- **All votes**: open and closed tabs, with turnout and whether your vote is needed, and a
  button to raise a motion.

## The chama

- **About the chama**:
  - type, country, currency;
  - records-only or paying out, registered or not;
  - members, rule book version, active since, my member code;
  - the bank account (bank, name, last four digits, paybill or till) and whether the
    signatories are confirmed;
  - the statement inbox address, to copy;
  - the officials.
- **Invite a member** (Members tab, and the menu for officials): replaces the old bottom
  sheet.
  - It makes a code, or sends an SMS invite.
  - It then shows the code large, with a QR code for a phone next to yours.
  - **Copy** and **Share** (WhatsApp or SMS) the joining message.
- **Phones that pay** (`PayerLinksScreen`): numbers that pay for members. A member sees
  their own; officials see all; either can end one.

## Pictures and checks

- **Reports**:
  - saved in all, in the bank, net worth;
  - a bar chart of each month's contributions against what was due, with the share paid;
  - late payments and fines by month;
  - who is behind;
  - meeting attendance bars.
- **Bank check** (tap the bank-check notice on the overview):
  - the status;
  - the bank's figure (statement or bank feed) against the records, and the gap;
  - payments not matched (with a link to them) and what is unexplained;
  - how long a gap has been open;
  - the last two weeks as bars;
  - whether the bank statement is fresh.
- **What's coming**: my next payment, meetings, votes closing, JiraniChama's bill and the
  next bank statement, soonest first.
- **How your records are protected** (`TrustScreen`): the four locks in plain words, each
  with this phone's live answer.
  - The chain it checked.
  - The platform's signature.
  - The members who vouched, and whether they agree.
  - Last night's public stamp.
  - Staff need two officials' permission.
- **Help** (Settings): nine questions members ask, the SMS words, the USSD menu, the
  welcome pages again, and the guided tours again.

## Also fixed

Payouts now show the red money-out arrow on the Records tab. `flowOf` listed `payment`,
but the ledger type is `payout`.

## Tests

`test/more_screens_test.dart`:

- opens every screen in the Everything menu (and fails on any layout overflow);
- the welcome pages;
- a member profile and the months grid;
- record details;
- search;
- checking a statement code and a receipt;
- changing the PIN and retiring a phone;
- help;
- the invite QR.
