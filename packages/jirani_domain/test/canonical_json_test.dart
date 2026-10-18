import 'dart:convert';
import 'dart:io';

import 'package:jirani_domain/jirani_domain.dart';
import 'package:test/test.dart';

void main() {
  final vectors = jsonDecode(File('test/vectors/canonical_json.json').readAsStringSync())
      as Map<String, dynamic>;

  group('shared vectors', () {
    for (final c in vectors['cases'] as List) {
      final input = c['input'] as String;
      test(c['name'], () {
        final out = canonicalJson(jsonDecode(input));
        expect(out, c['expected']);
        expect(sha256Hex(out), c['sha256']);
      });
    }
    for (final c in vectors['must_reject'] as List) {
      test('rejects ${c['name']}', () {
        expect(() => canonicalJson(jsonDecode(c['input'] as String)),
            throwsA(isA<CanonicalError>()));
      });
    }
  });

  test('rejects non-string keys and lone surrogates', () {
    expect(() => canonicalJson({1: 'x'}), throwsA(isA<CanonicalError>()));
    expect(() => canonicalJson('\uD800'), throwsA(isA<CanonicalError>()));
    expect(() => canonicalJson('\uDC00x'), throwsA(isA<CanonicalError>()));
  });

  test('isoMs truncates to milliseconds in UTC', () {
    final dt = DateTime.utc(2026, 3, 4, 9, 15, 30, 123, 999);
    expect(isoMs(dt), '2026-03-04T09:15:30.123Z');
    expect(isoMs(DateTime.utc(2026)), '2026-01-01T00:00:00.000Z');
  });
}
