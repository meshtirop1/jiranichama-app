// Both languages must be complete: the same keys and the same placeholders in English
// and Kiswahili. Checked by the build, not by eye.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map<String, dynamic>;

Set<String> _messages(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

Set<String> _placeholders(String message) =>
    // A placeholder is a name followed by "}" or ",": {phone} or {left, plural, ...}.
    // Plural branch text such as "{No tries left" is not a placeholder.
    RegExp(r'\{(\w+)\s*[},]').allMatches(message).map((m) => m.group(1)!).toSet();

void main() {
  final en = _arb('en');
  final sw = _arb('sw');

  test('Kiswahili has exactly the English keys', () {
    expect(_messages(sw).difference(_messages(en)), isEmpty, reason: 'extra in sw');
    expect(_messages(en).difference(_messages(sw)), isEmpty, reason: 'missing in sw');
  });

  test('placeholders match in every message', () {
    for (final key in _messages(en)) {
      expect(_placeholders(sw[key] as String), _placeholders(en[key] as String), reason: key);
    }
  });

  test('no message is left empty', () {
    for (final arb in [en, sw]) {
      for (final key in _messages(arb)) {
        expect((arb[key] as String).trim(), isNotEmpty, reason: key);
      }
    }
  });
}
