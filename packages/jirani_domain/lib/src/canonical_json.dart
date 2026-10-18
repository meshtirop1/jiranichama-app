// Canonical JSON (RFC 8785, JCS) for the values JiraniChama hashes and signs.
//
// Twin of `apps/core/canonical.py` on the server. The supported domain is small on
// purpose: maps with string keys, lists, strings, booleans, null and integers within
// the I-JSON safe range. Doubles are refused because money is always integer cents.

const int maxSafeInteger = 9007199254740991;

class CanonicalError implements Exception {
  CanonicalError(this.message);
  final String message;

  @override
  String toString() => 'CanonicalError: $message';
}

String canonicalJson(Object? value) {
  final out = StringBuffer();
  _encode(value, out);
  return out.toString();
}

/// UTC ISO 8601 truncated to milliseconds with a Z: 2026-10-18T06:30:00.123Z.
String isoMs(DateTime dt) {
  final u = dt.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final year = u.year.toString().padLeft(4, '0');
  final ms = u.millisecond.toString().padLeft(3, '0');
  return '$year-${two(u.month)}-${two(u.day)}T${two(u.hour)}:${two(u.minute)}:'
      '${two(u.second)}.${ms}Z';
}

void _encode(Object? value, StringBuffer out) {
  switch (value) {
    case null:
      out.write('null');
    case true:
      out.write('true');
    case false:
      out.write('false');
    case int():
      if (value > maxSafeInteger || value < -maxSafeInteger) {
        throw CanonicalError('integer outside the safe range: $value');
      }
      out.write(value.toString());
    case double():
      throw CanonicalError('doubles are not allowed; use integer cents');
    case String():
      _encodeString(value, out);
    case List():
      out.write('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) out.write(',');
        _encode(value[i], out);
      }
      out.write(']');
    case Map():
      final keys = <String>[];
      for (final key in value.keys) {
        if (key is! String) {
          throw CanonicalError('object keys must be strings, got ${key.runtimeType}');
        }
        keys.add(key);
      }
      // String.compareTo compares UTF-16 code units, which is what RFC 8785 requires.
      keys.sort();
      out.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        _encodeString(keys[i], out);
        out.write(':');
        _encode(value[keys[i]], out);
      }
      out.write('}');
    default:
      throw CanonicalError('cannot canonicalise ${value.runtimeType}');
  }
}

void _encodeString(String s, StringBuffer out) {
  final units = s.codeUnits;
  out.write('"');
  for (var i = 0; i < units.length; i++) {
    final c = units[i];
    if (c >= 0xD800 && c <= 0xDBFF) {
      if (i + 1 >= units.length || units[i + 1] < 0xDC00 || units[i + 1] > 0xDFFF) {
        throw CanonicalError('strings must be valid Unicode (no lone surrogates)');
      }
      out.writeCharCode(c);
      out.writeCharCode(units[++i]);
      continue;
    }
    if (c >= 0xDC00 && c <= 0xDFFF) {
      throw CanonicalError('strings must be valid Unicode (no lone surrogates)');
    }
    switch (c) {
      case 0x22:
        out.write(r'\"');
      case 0x5C:
        out.write(r'\\');
      case 0x08:
        out.write(r'\b');
      case 0x0C:
        out.write(r'\f');
      case 0x0A:
        out.write(r'\n');
      case 0x0D:
        out.write(r'\r');
      case 0x09:
        out.write(r'\t');
      default:
        if (c < 0x20) {
          out.write(r'\u');
          out.write(c.toRadixString(16).padLeft(4, '0'));
        } else {
          out.writeCharCode(c);
        }
    }
  }
  out.write('"');
}
