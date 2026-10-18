/// Pure-Dart domain code shared by the app: canonical JSON, ledger hashing and chain
/// checks, money and phone numbers. Mirrors the server byte for byte; both are held
/// to the vectors in `test/vectors/`.
library;

export 'src/canonical_json.dart';
export 'src/ledger_chain.dart';
export 'src/money.dart';
export 'src/phone.dart';
