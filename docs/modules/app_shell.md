# App shell

| File | What it does |
| --- | --- |
| `lib/config.dart` | `API_BASE_URL` and `FLAVOR` from `--dart-define`. Non-production builds show a corner banner |
| `lib/router.dart` | go_router; redirects follow the session (see [sign-in](../flows/sign-in.md)) |
| `lib/core/api/api_client.dart` | Dio wrapper: adds the token, refreshes once on 401, turns failures into `ApiProblem` |
| `lib/core/api/token_store.dart` | Tokens in the platform keystore |
| `lib/core/providers.dart` | Riverpod providers for the store, client and repositories; tests override these |
| `lib/core/locale.dart` | The language the member picked (null follows the phone) |
| `lib/features/auth/` | Sign-in data, session state and screens |
| `lib/features/home/` | Placeholder home until Phase 1 |

## Languages

English and Kiswahili ship together. `test/l10n_parity_test.dart` fails the build if a key
or placeholder exists in one language and not the other.

## Platforms

Android 8.0 (API 26) and up; iOS 15 and up. Debug Android builds allow plain HTTP to reach
a local dev server; release builds do not.
