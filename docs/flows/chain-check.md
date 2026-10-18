# Checking the chain on the phone

The promise to members is that nobody can quietly change their chama's history, not even
JiraniChama. The phone is where that is checked.

## How it works (`verifyChain` in `jirani_domain`)

For each entry the server sends, the phone:

1. turns the entry's document into canonical JSON, exactly as the server did;
2. computes its SHA-256 fingerprint and compares it with the hash the server sent;
3. checks the entry points at the fingerprint of the entry before it, and that the
   sequence has no gaps;
4. remembers the last fingerprint it checked (its **trusted head**).

On the next sync it checks only the new entries, starting from its trusted head. If the
server's history no longer leads from that head, for example because an old entry was
changed or removed, the check fails at that position.

Phase 1 adds the platform signature check and stores the chain in the encrypted offline
database; Phase 2 adds the nightly public anchor. A failed check shows a red banner and is
reported to the server.

## Why the phone and the server cannot disagree

Both use the same canonical JSON rules and are tested against the same files:
`packages/jirani_domain/test/vectors/` here, copied from `vectors/` in the API. The tests
include the hard cases: keys sorted by UTF-16 code units, emoji, control characters,
and the refusal of decimals (money is always whole cents).
