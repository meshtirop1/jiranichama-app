import 'dart:convert';
import 'dart:io';

import 'package:jirani_domain/jirani_domain.dart';
import 'package:test/test.dart';

void main() {
  final v = jsonDecode(File('test/vectors/key_chain.json').readAsStringSync())
      as Map<String, dynamic>;
  final chain = [for (final k in v['chain'] as List) Map<String, Object?>.from(k as Map)];
  final pinned = v['pinned_fingerprint'] as String;

  test('the chain from the pinned key is trusted, key by key', () {
    final t = verifyKeyChain(chain, pinned);
    expect(t.ok, isTrue);
    expect(t.keys.keys, ['t', 't2']);
  });

  test('a chain that does not start at the pinned key is not trusted', () {
    final t = verifyKeyChain(chain, 'f' * 64);
    expect(t.ok, isFalse);
    expect(t.keys, isEmpty);
  });

  test('a key endorsed by someone else is not trusted', () {
    final forged = Map<String, Object?>.from(v['forged_next'] as Map);
    final t = verifyKeyChain([...chain, forged], pinned);
    expect(t.ok, isFalse);
    expect(t.keys.keys, ['t', 't2']);
  });

  test('a key passed off under another key\'s fingerprint is not trusted', () {
    final swapped = Map<String, Object?>.from(chain[1])
      ..['public_key_pem'] = (v['forged_next'] as Map)['public_key_pem'];
    expect(verifyKeyChain([chain[0], swapped], pinned).ok, isFalse);
  });

  test('a member countersignature verifies, and only for what was signed', () {
    final cs = v['countersignature'] as Map;
    final p = cs['payload'] as Map;
    bool check({String? hash, int? seq}) => verifyCountersignature(
        chamaId: p['chama_id'] as String, memberCode: p['member_code'] as String,
        seq: seq ?? p['seq'] as int, hash: hash ?? p['hash'] as String,
        devicePublicKeyB64: cs['device_public_key'] as String,
        signatureB64: cs['signature'] as String);
    expect(check(), isTrue);
    expect(check(hash: 'cd' * 32), isFalse);
    expect(check(seq: 4), isFalse);
  });
}
