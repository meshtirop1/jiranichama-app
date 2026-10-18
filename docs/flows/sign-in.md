# Sign-in

1. **Phone.** The member types their number in any Kenyan format. The app normalises it
   to `+254…` with the same rules as the server (`normalisePhone` in `jirani_domain`) and
   refuses anything else before calling the API. The language picker (top right) switches
   between English and Kiswahili; the SMS comes in the chosen language.
2. **Code.** The server sends a 6-digit code by SMS. The screen shows only a hint of the
   number (`+2547••• ••• 678`). A wrong code shows how many tries are left; after 5 the
   code is locked and the member asks for a new one.
3. **Name and PIN.** A new member gives the name their chama knows them by (other members
   see it on statements and lists) and sets a 6-digit app PIN, typed twice. Very common
   PINs are refused by the server.
4. **Home.** From then on the app opens straight to home. Signing out ends the session on
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

The server side of this flow is `docs/flows/phone-sign-in.md` in the API repository.
