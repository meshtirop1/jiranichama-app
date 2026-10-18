# JiraniChama app docs

Plain-English notes on how the app works and why. Every pull request updates the pages
it touches.

## Flows

- [Sign-in](flows/sign-in.md): phone, SMS code, PIN.
- [Checking the chain on the phone](flows/chain-check.md): how a phone catches changed history.
- [Chama screens](flows/chama-screens.md): home, create and set up, join, confirm the rules, the active chama, statements, unmatched payments.

## Modules

- [jirani_domain](modules/jirani_domain.md): canonical JSON, hashing, money, phones.
- [jirani_ui](modules/jirani_ui.md): design system.
- [app shell](modules/app_shell.md): routing, session, API client, languages.

## Where we are

Phase 0 is done (shell, sign-in, both languages, design system, domain package). Phase 1
screens are in progress: chamas, setup, joining, confirming the rules, position and how
to pay, records checked on the phone (hashes and platform signatures), statements and the
unmatched queue are built.

## Not in Phase 0, on purpose

The proposal's full app stack arrives with the features that need it:

| Piece | Arrives in | Why not now |
| --- | --- | --- |
| OpenAPI-generated Dio client and `freezed` models | Later in Phase 1 | Hand-written readers in `features/chamas/data/models.dart` follow the schema names; generating them is a follow-up |
| Drift (SQLCipher) offline ledger | Phase 1 | Needs the ledger endpoints to sync from |
| `jirani_secure_keys` signing plugin (Keystore / Secure Enclave) | Phase 2 | Approvals ship in Phase 2 |
| App Check, freeRASP, certificate pinning | Phase 2 | Before money-out goes live (Gate B) |
| Riverpod code generation | When providers multiply | Plain providers are clearer at this size |
| Figma design tokens | Phase 1 (with the designer) | The brand green `#1B6B4A` is decided; the rest of `jirani_ui` waits for Figma |
