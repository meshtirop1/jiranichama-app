import 'dart:convert';
import 'dart:io';

import 'package:jirani_domain/jirani_domain.dart';
import 'package:test/test.dart';

void main() {
  final v = jsonDecode(File('test/vectors/platform_signatures.json').readAsStringSync())
      as Map<String, dynamic>;
  final key = PlatformKey.fromPem(v['public_key_pem'] as String);

  test('every server signature verifies', () {
    for (final s in v['valid'] as List) {
      expect(key.verifyHash(s['hash'] as String, s['signature_b64'] as String), isTrue);
    }
  });

  for (final s in v['invalid'] as List) {
    test('refuses ${s['name']}', () {
      expect(key.verifyHash(s['hash'] as String, s['signature_b64'] as String), isFalse);
    });
  }

  test('a key that is not P-256 is refused', () {
    expect(() => PlatformKey.fromPem('-----BEGIN PUBLIC KEY-----\nAAAA\n-----END PUBLIC KEY-----'),
        throwsFormatException);
  });
}
