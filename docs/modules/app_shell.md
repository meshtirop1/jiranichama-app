# App shell

| File | What it does |
| --- | --- |
| `lib/config.dart` | `API_BASE_URL` and `FLAVOR` from `--dart-define`. Non-production builds show a corner banner |
| `lib/router.dart` | go_router; redirects follow the session (see [sign-in](../flows/sign-in.md)) |
| `lib/core/api/api_client.dart` | Dio wrapper: GET, POST, PUT, PATCH, multipart upload and file download (bytes; a failed download's JSON error is still read); adds the token and `Idempotency-Key`, refreshes once on 401, turns failures into `ApiProblem` |
| `lib/core/api/token_store.dart` | Tokens in the platform keystore |
| `lib/core/providers.dart` | Riverpod providers for the store, client and repositories, the statement file picker, `PhoneSigner` (the phone's signing key, see `packages/jirani_secure_keys`), and `DocumentSaver` (keeps a PDF in app documents and opens the share sheet, via `path_provider` and `share_plus`); tests override these |
| `lib/core/locale.dart` | The language the member picked (null follows the phone) |
| `lib/features/auth/` | Sign-in data, session state and screens |
| `lib/features/home/` | The member's chamas |
| `lib/features/chamas/data/` | Models and `ChamaRepository` (every Phase 1 endpoint) |
| `lib/features/chamas/application/chain_check.dart` | Downloads and checks the whole chain on the phone |
| `lib/features/chamas/presentation/` | Create, setup, join, adoption, active chama, records, bank statements, unmatched, opening balances, cash, member and chama statements (`statement_screens.dart`); the SMS-code sheet |
| `lib/core/labels.dart` | The member's words for roles, types, states and record types |

## Languages

English and Kiswahili ship together. `test/l10n_parity_test.dart` fails the build if a key
or placeholder exists in one language and not the other.

## Platforms

Android 8.0 (API 26) and up; iOS 15 and up. Debug Android builds allow plain HTTP to reach
a local dev server; release builds do not.

## packages/jirani_secure_keys

A Flutter plugin (Kotlin) for the phone's signing key (6.7): a P-256 key in the Android
keystore, StrongBox where the phone has one, requiring a fresh fingerprint, face or
phone PIN for every signature (Android 11+, `BiometricPrompt` with a `CryptoObject`).
`createKey` returns the public key and the attestation chain made with our challenge;
`sign` asks for the fingerprint and returns an ECDSA SHA-256 signature. `MainActivity`
is a `FlutterFragmentActivity` so the prompt can show. On other platforms it reports
unavailable and the app uses SMS codes.

## Camera and QR (meetings)

`mobile_scanner` reads the meeting QR code (`CodeScanner` in
`features/chamas/presentation/meetings_screen.dart`, behind `codeScannerProvider` so tests
hand in a code). `qr_flutter` draws the secretary's code. `FileSource.pickPhoto` picks a
photo of handwritten minutes. The camera permission comes from the scanner plugin's
manifest.

## Caching and smoothness

Screens' data providers call `ref.cacheFor(5 minutes)` (`core/providers.dart`): going back
or switching tabs shows the data at once instead of a spinner; anything that changes the
data still refreshes it (`ref.invalidate`). Every sign-in and sign-out bumps
`signInEpochProvider`, which drops all cached data, so nobody sees the previous person's.
Long lists are built lazily (`ListView.builder`). The ledger check runs on a background
isolate behind `chainRunnerProvider` (tests run it inline) with its trusted head in
`trustStoreProvider` (secure storage).

## Branding

Android launcher icon: an adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`) with the
mark (members around a common pot, `drawable/ic_launcher_foreground.xml`, a vector) on
brand green. Splash: brand green with the mark (`values-v31/styles.xml` for Android 12+,
`launch_background.xml` before), and the app's own background behind Flutter while it
starts, so there is no white flash.
