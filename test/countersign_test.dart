import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiranichama/features/chamas/application/chain_check.dart';
import 'package:jiranichama/features/chamas/data/models.dart';

void main() {
  final v = jsonDecode(File('packages/jirani_domain/test/vectors/key_chain.json')
      .readAsStringSync()) as Map<String, dynamic>;
  final cs = v['countersignature'] as Map<String, dynamic>;
  final p = cs['payload'] as Map<String, dynamic>;
  final signed = <Map<String, dynamic>>[
    {'member_code': p['member_code'], 'seq': p['seq'], 'hash': p['hash'],
     'signature': cs['signature'], 'device_public_key': cs['device_public_key']},
  ];

  LedgerItem item(int seq, String hash) => LedgerItem({
        'id': 'e$seq', 'hash': hash, 'receipt_code': 'X', 'platform_sig': null,
        'key_id': null, 'document': {'seq': seq, 'type': 'membership'},
      });

  test('a member\'s signature over this phone\'s own chain counts', () {
    final c = checkCountersignatures(p['chama_id'] as String, signed,
        [item(1, '00' * 32), item(3, p['hash'] as String)], p['member_code'] as String);
    expect(c.ok, isTrue);
    expect(c.members, [p['member_code']]);
    expect(c.upToSeq, 3);
    expect(c.myLatestSeq, 3);
  });

  test('a signature over a different history is flagged', () {
    final c = checkCountersignatures(p['chama_id'] as String, signed,
        [item(3, 'cd' * 32)], null);
    expect(c.ok, isFalse);
    expect(c.disagree, [p['member_code']]);
  });

  test('a signature for another chama is flagged', () {
    final c = checkCountersignatures('another', signed, [item(3, p['hash'] as String)], null);
    expect(c.ok, isFalse);
  });
}
