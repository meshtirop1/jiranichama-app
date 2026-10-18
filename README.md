# JiraniChama app

Flutter app (Android and iOS) for JiraniChama: a chama app that records every shilling,
enforces every rule, and never touches the money. The design is the *JiraniChama
Architecture Proposal v1.1*; this repo is at **Phase 0 (foundations)**.

Start with [docs/README.md](docs/README.md).

## Layout

| Path | What it is |
| --- | --- |
| `lib/` | The app: routing, sign-in screens, API client, session |
| `lib/l10n/` | English and Kiswahili strings (`app_en.arb`, `app_sw.arb`) |
| `packages/jirani_domain/` | Pure Dart: canonical JSON, ledger hashing and chain checks, money, phone numbers. Held to the server's hash vectors |
| `packages/jirani_ui/` | Design system: theme tokens and shared widgets |

## Run it

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 --dart-define=FLAVOR=dev
```

`10.0.2.2` is the host machine as seen from the Android emulator. Debug builds allow
plain HTTP for that; release builds are HTTPS-only.

## Test

```bash
cd packages/jirani_domain && dart test && cd ../..
cd packages/jirani_ui && flutter test && cd ../..
flutter test
```
