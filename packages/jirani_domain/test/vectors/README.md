# Shared vectors

These files are copies of `vectors/` in the API repository (`jiranichama-api`). They are
the contract between the server and the app: both must produce exactly these canonical
strings, hashes and receipt codes.

When the API regenerates them (`python scripts/make_vectors.py`), copy both files here
in the same pull request series. Never edit them by hand.

`key_chain.json` (2026-10-20): the platform key chain with one endorsed rotation, a forged key, and a member countersignature. Generated once by `make_vectors.py` (the signatures are random), then kept.
