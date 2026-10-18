# Shared vectors

These files are copies of `vectors/` in the API repository (`jiranichama-api`). They are
the contract between the server and the app: both must produce exactly these canonical
strings, hashes and receipt codes.

When the API regenerates them (`python scripts/make_vectors.py`), copy both files here
in the same pull request series. Never edit them by hand.
