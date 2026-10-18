import 'dart:convert';
import 'dart:io';

import 'package:jirani_domain/jirani_domain.dart';
import 'package:test/test.dart';

void main() {
  final chain = jsonDecode(File('test/vectors/ledger_chain.json').readAsStringSync())
      as Map<String, dynamic>;
  final raw = (chain['entries'] as List).cast<Map<String, dynamic>>();

  List<ChainEntry> entries() => [
        for (final e in raw)
          ChainEntry(
            document: Map<String, Object?>.from(e['document'] as Map),
            hash: e['hash'] as String,
          ),
      ];

  test('version and genesis match the server', () {
    expect(chain['hash_version'], hashVersion);
    expect(chain['genesis_prev_hash'], genesisPrevHash);
  });

  test('every entry recomputes exactly', () {
    for (final e in raw) {
      final doc = e['document'] as Map<String, dynamic>;
      expect(canonicalJson(doc), e['canonical']);
      expect(entryHash(doc), e['hash']);
      expect(receiptCode(e['hash'] as String), e['receipt_code']);
      final sigs = [
        for (final t in e['signatures'] as List) (t as List).cast<String>(),
      ];
      expect(signaturesDigest(sigs), e['signatures_digest']);
    }
  });

  test('the whole chain verifies', () {
    expect(verifyChain(entries()), isEmpty);
  });

  test('a continuation verifies from a trusted head', () {
    final all = entries();
    expect(verifyChain(all.sublist(2), trustedHead: all[1].hash, trustedSeq: 2), isEmpty);
  });

  test('a changed amount is found at its position', () {
    final all = entries();
    all[1].document['amount_cents'] = 999999;
    final problems = verifyChain(all);
    expect(problems.map((p) => p.toString()), ['seq 2: contents do not match its hash']);
  });

  test('a removed entry breaks the link and the sequence', () {
    final all = entries()..removeAt(1);
    final problems = verifyChain(all).map((p) => p.toString()).toList();
    expect(problems, contains('seq 3: expected seq 2'));
    expect(problems, contains('seq 3: does not link to the entry before it'));
  });

  test('a server that rewrote history before the trusted head is caught', () {
    final all = entries();
    expect(verifyChain(all.sublist(2), trustedHead: 'f' * 64, trustedSeq: 2), isNotEmpty);
  });
}
