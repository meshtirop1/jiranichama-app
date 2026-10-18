// How a ledger entry is fingerprinted, and how a phone checks a whole chain.
//
// Twin of `apps/ledger/hashing.py`. The server sends each entry's document (the exact
// object it hashed) with its hash; the phone recomputes everything and never trusts
// the stored hash on its own.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'canonical_json.dart';

const int hashVersion = 1;
final String genesisPrevHash = '0' * 64;

const List<String> hashedFields = [
  'v',
  'chama_id',
  'seq',
  'type',
  'member_code',
  'amount_cents',
  'period',
  'rule_version_id',
  'rule_refs',
  'decision',
  'source',
  'source_id',
  'reverses',
  'signatures_digest',
  'at',
  'prev_hash',
];

String sha256Hex(String text) => sha256.convert(utf8.encode(text)).toString();

String entryHash(Map<String, Object?> document) => sha256Hex(canonicalJson(document));

/// First 8 Base32 characters of the hash bytes: what a member types after VERIFY.
String receiptCode(String hashHex) => _base32(_hexToBytes(hashHex)).substring(0, 8);

/// SHA-256 over the sorted (member code, device key fingerprint, signature) triples
/// that approved an entry; null when nobody signed.
String? signaturesDigest(List<List<String>> signatures) {
  if (signatures.isEmpty) return null;
  final triples = [for (final t in signatures) List<String>.of(t)];
  triples.sort(_compareLists);
  return sha256Hex(canonicalJson(triples));
}

int _compareLists(List<String> a, List<String> b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    final c = a[i].compareTo(b[i]);
    if (c != 0) return c;
  }
  return a.length.compareTo(b.length);
}

/// One entry as the server sends it: the hashed document plus the stored hash.
class ChainEntry {
  ChainEntry({required this.document, required this.hash});

  final Map<String, Object?> document;
  final String hash;

  int get seq => document['seq'] as int;
  String get prevHash => document['prev_hash'] as String;
}

class ChainProblem {
  ChainProblem(this.seq, this.message);
  final int seq;
  final String message;

  @override
  String toString() => 'seq $seq: $message';
}

/// Checks a chain, or a continuation of one the phone already trusts.
///
/// [trustedHead] is the last hash this phone verified before (genesis for a new
/// chama); [trustedSeq] its seq. Returns every problem found, at its position.
List<ChainProblem> verifyChain(
  List<ChainEntry> entries, {
  String? trustedHead,
  int trustedSeq = 0,
}) {
  final problems = <ChainProblem>[];
  var expectedPrev = trustedHead ?? genesisPrevHash;
  var expectedSeq = trustedSeq + 1;
  for (final entry in entries) {
    final doc = entry.document;
    final keys = doc.keys.toList()..sort();
    final wanted = List<String>.of(hashedFields)..sort();
    if (keys.join(',') != wanted.join(',')) {
      problems.add(ChainProblem(entry.seq, 'unexpected fields in the entry'));
    }
    if (doc['v'] != hashVersion) {
      problems.add(ChainProblem(entry.seq, 'unknown hash version ${doc['v']}'));
    }
    if (entry.seq != expectedSeq) {
      problems.add(ChainProblem(entry.seq, 'expected seq $expectedSeq'));
      expectedSeq = entry.seq;
    }
    if (entry.prevHash != expectedPrev) {
      problems.add(ChainProblem(entry.seq, 'does not link to the entry before it'));
    }
    if (entryHash(doc) != entry.hash) {
      problems.add(ChainProblem(entry.seq, 'contents do not match its hash'));
    }
    expectedPrev = entry.hash;
    expectedSeq++;
  }
  return problems;
}

List<int> _hexToBytes(String hex) {
  if (hex.length.isOdd) throw const FormatException('odd-length hex');
  return [
    for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
  ];
}

const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

String _base32(List<int> bytes) {
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(_base32Alphabet[(buffer >> bits) & 0x1F]);
    }
    buffer &= (1 << bits) - 1;
  }
  if (bits > 0) out.write(_base32Alphabet[(buffer << (5 - bits)) & 0x1F]);
  return out.toString();
}
