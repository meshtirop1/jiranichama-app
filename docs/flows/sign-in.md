# Sign-in

1. **Country and language.** Two boxes above the phone number:
   - **Country:** Kenya, Uganda and Tanzania can be chosen. The other six (Rwanda,
     Burundi, DR Congo, South Sudan, Ethiopia, Somalia) are listed as "Coming soon" (see
     the API's `docs/flows/countries.md`).
   - Choosing a country sets the dialling code shown in the phone field (+254, +256,
     +255) and the example number. It also switches to the country's own language where
     the app has it, so Tanzania opens in Kiswahili.
   - **Language:** lists the country's languages first. Only English and Kiswahili can
     be chosen today; the rest (Luganda, Runyankore, Somali and others) show "Coming soon"
     until a native speaker has checked a translation.
2. **Phone.** The member types their number the local way (0772…) or with a country code
   (+256…). The app reads it with the same rules as the server (`normalisePhoneIn` in
   `jirani_domain`) and refuses a wrong number before calling the API. The message names
   the country: "Enter a Uganda mobile number, for example 0772 123 456". The SMS comes in
   the chosen language. The country is saved on the member's profile with their name.
3. **Code.** The server sends a 6-digit code by SMS. The screen shows only a hint of the
   number (`+2547••• ••• 678`). A wrong code shows how many tries are left; after 5 the
   code is locked and the member asks for a new one.
4. **Name and PIN.** A new member gives the name their chama knows them by (other members
   see it on statements and lists) and sets a 6-digit app PIN, typed twice. Very common
   PINs are refused by the server.
5. **Home.** From then on the app opens straight to home. Signing out ends the session on
   the server and clears the tokens on the phone, even when offline.

## Why it is built this way

- **Tokens live in the platform keystore** (`flutter_secure_storage`), never in plain
  preferences.
- **The router follows the session.** A signed-out member can only see sign-in; a member
  without a PIN is always sent to set one; a signed-in member never sees sign-in again.
- **Every message is ours, in both languages.** The app maps each server problem `code`
  to its own wording (`problem_text.dart`) instead of showing server text, so nothing
  appears in English only.
- **An expired access token is refreshed once, silently.** If the refresh token is also
  expired, the session ends and the member signs in again.
- **One refresh at a time.** Access tokens last 15 minutes, and refresh tokens are single
  use (the server rotates them). When several screens hit an expired token together, only
  one refresh is sent; the others wait for it and then retry with the new token. Before
  2026-10-20 each screen refreshed on its own: the second refresh used the old token, was
  refused, wiped the session, and the screens spun forever on 401s.
- **A dead session goes back to sign-in.** If the refresh is refused, the API client says
  so (`sessionEnded`) and the app returns to the phone screen instead of leaving screens
  waiting.
- **Loads are retried only when the server was not reached** (three tries, backing off).
  A refusal such as 401, 403 or a rule is shown at once.

The server side of this flow is `docs/flows/phone-sign-in.md` in the API repository.
