# The chama runs itself: the app screens (2026-10-21)

The owner asked to make JiraniChama "really super automatic", and said the voting was "too
basic". The server does the chasing (jiranichama-api `docs/flows/automation.md`,
`shareout.md`, `votes.md`). These are the screens for it. They all use
`features/automation/automation_repository.dart`. In tests the chama fake also plays this
repository (`FakeAutomation` in `test/fakes.dart`), so one override covers both.

## Notices (the bell)

- **Where:** a bell on the home screen and inside every chama (`NoticesButton`), with the
  unread count.
- **What:** `NoticesScreen` lists every reminder and alert JiraniChama sent the person,
  newest first. Opening it marks them read.
- **Tapping one** goes where it is about: a vote, money out, cash, statements, unmatched
  payments, the motions, or the chama.
- **The bill notice** offers to propose paying JiraniChama's bill with one tap.

App users get these instead of SMS, which keeps the SMS bill small. Push notifications
will use the same notices once Firebase is set up.

## Pay now

The overview shows **To pay now** (`PayNowCard`): the total, with chips for months behind,
fines and the month falling due.

Where the chama's own paybill allows it, **Pay KES … with M-Pesa** works like this:

1. The app asks the server to send the M-Pesa PIN prompt to the member's phone.
2. A sheet waits for Safaricom's answer (checked every 3 seconds, up to two minutes).
3. It shows the receipt, or says plainly that nothing was taken.

The usual "How to pay" card stays below it.

## Another phone that pays for me

After the treasurer counted a payment from someone else's phone for a member, the
member's overview asks once (`PayerLinkQuestion`): "should payments from that number
always count for you?" **Yes, always** makes the next ones match by themselves; **No**
keeps them for the treasurer.

## Likely members (unmatched payments)

For each payment waiting to be matched, the treasurer sees up to three likely members as
chips, each with its reasons (a member code with a slip, the payer's name, a number that
paid for them before, their usual amount). A tap opens the assignment with the member and
the reason filled in.

## Richer votes (`VoteScreen`)

- **Yes / Abstain / No.** Abstaining counts as taking part, not for or against.
- **Polls:** the options as a list. Pick one, or abstain, then **Vote: …**. Once it closes,
  each option shows its count and the winner a trophy.
- **Changing a vote:** where the vote allows it, the member sees "you can change your vote
  until it closes" and the buttons stay.
- The question's details and who raised it are shown.
- **Comments:** "What members say", with a field to add a view while the vote is open.

## Members' motions (`MotionsScreen`)

- **Where:** under "Members' motions" on the overview.
- **The list:** each motion, who raised it, how many seconds it has of how many it needs,
  and who seconded it. **Second it** for others, **Withdraw** for the member who raised it.
- **Raise a motion:** a question, why, yes/no or two to six options, and how many days the
  vote runs.
- Once seconded, **Vote now** opens the vote.

## Share-out (`ShareOutScreen`)

- **Where:** "Share-out" in the overview's shortcuts.
- **Officials prepare it:**
  - the cycle;
  - give savings back or not;
  - a reserve (0 to 50%);
  - share by savings, or by savings and months.

  **Work out the figures** shows what the chama earned, what is shared, the reserve and
  each member's line (savings, share, fines and loan taken off, what they are paid).
  Every member sees it, with their own line marked.
- **Send to the members to vote** opens the vote. Once it passes, each payment is in money
  out and shows **In money out**, then **Paid**.
