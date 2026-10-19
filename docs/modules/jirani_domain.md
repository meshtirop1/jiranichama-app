# jirani_domain

Pure Dart, no Flutter imports, so it is fast to test and could run anywhere.

| File | What it does |
| --- | --- |
| `canonical_json.dart` | RFC 8785 canonical JSON, twin of the server's `apps/core/canonical.py`. Refuses doubles |
| `ledger_chain.dart` | Entry fingerprints, receipt codes, signature digests, and `verifyChain` |
| `platform_signature.dart` | `PlatformKey`: reads the server's P-256 public key and verifies entry signatures (pointycastle) |
| `money.dart` | `Kes`: an amount as integer cents, formatted `KES 1,284,500` |
| `phone.dart` | `normalisePhone`, the same rules as the server |

## Rules

- Never use `double` for money. `Kes` holds cents.
- `test/vectors/` are copies of the API's vectors. Never edit them by hand; when the API
  regenerates them, copy them over.
- A change to hashing must match a server change and a new `hashVersion`.

- `anchor.dart`: `anchorLeaf` and `verifyAnchorPath` for the nightly public anchor (same hashing as the API).
