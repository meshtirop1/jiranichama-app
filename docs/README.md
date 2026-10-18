# JiraniChama app docs

Plain-English notes on how the app works and why. Every pull request updates the pages
it touches.

## Flows

- [Sign-in](flows/sign-in.md): phone, SMS code, PIN.
- [Checking the chain on the phone](flows/chain-check.md): how a phone catches changed history.

## Modules

- [jirani_domain](modules/jirani_domain.md): canonical JSON, hashing, money, phones.
- [jirani_ui](modules/jirani_ui.md): design system.
- [app shell](modules/app_shell.md): routing, session, API client, languages.

## Where we are

Phase 0 of the proposal: the app shell, sign-in, both languages, the design system
package, and the domain package that recomputes the server's hashes.

## Not in Phase 0, on purpose

The proposal's full app stack arrives with the features that need it:

| Piece | Arrives in | Why not now |
| --- | --- | --- |
| OpenAPI-generated Dio client and `freezed` models | Phase 1 | Sign-in is four calls; the generated client earns its keep with the chama endpoints |
| Drift (SQLCipher) offline ledger | Phase 1 | Needs the ledger endpoints to sync from |
| Platform signature check on the phone (ECDSA P-256) | Phase 1 | Needs the published platform key endpoint |
| `jirani_secure_keys` signing plugin (Keystore / Secure Enclave) | Phase 2 | Approvals ship in Phase 2 |
| App Check, freeRASP, certificate pinning | Phase 2 | Before money-out goes live (Gate B) |
| Riverpod code generation | When providers multiply | Plain providers are clearer at this size |
| Figma design tokens | Phase 1 (with the designer) | `jirani_ui` tokens are placeholders until then |
