// Checking the platform's signature on a ledger entry.
//
// The server signs each entry hash with ECDSA P-256, treating the 32-byte hash itself
// as the pre-hashed SHA-256 digest (AWS KMS "MessageType=DIGEST"), and sends the DER
// signature in base64. Twin of `apps/ledger/signing.py`; both are held to
// `test/vectors/platform_signatures.json`.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:pointycastle/export.dart';

/// The DER prefix of a P-256 SubjectPublicKeyInfo; the 65-byte point follows it.
const List<int> _p256SpkiPrefix = [
  0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, //
  0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00,
];

class PlatformKey {
  PlatformKey._(this._key);

  final ECPublicKey _key;

  /// Reads the PEM from `GET /platform-key/`. Throws [FormatException] for anything that
  /// is not an uncompressed P-256 public key.
  factory PlatformKey.fromPem(String pem) => PlatformKey.fromDer(pemToDer(pem));

  /// A P-256 SubjectPublicKeyInfo (DER), as a phone key is sent (base64 of this).
  factory PlatformKey.fromDer(List<int> der) {
    if (der.length != _p256SpkiPrefix.length + 65) {
      throw const FormatException('not a P-256 public key');
    }
    for (var i = 0; i < _p256SpkiPrefix.length; i++) {
      if (der[i] != _p256SpkiPrefix[i]) throw const FormatException('not a P-256 public key');
    }
    final params = ECCurve_secp256r1();
    final point = params.curve.decodePoint(
        Uint8List.fromList(der.sublist(_p256SpkiPrefix.length)));
    if (point == null) throw const FormatException('bad public key point');
    return PlatformKey._(ECPublicKey(point, params));
  }

  /// True only for a valid ECDSA/SHA-256 signature over exactly these bytes (a phone key
  /// signs this way). Never throws.
  bool verifyMessage(List<int> message, String signatureB64) =>
      verifyHash(sha256.convert(message).toString(), signatureB64);

  /// True only for a valid signature over exactly this hash. Never throws.
  bool verifyHash(String hashHex, String signatureB64) {
    try {
      final sig = _parseDer(base64.decode(signatureB64));
      if (sig == null) return false;
      final signer = ECDSASigner() // no digest: the message is already the hash
        ..init(false, PublicKeyParameter<ECPublicKey>(_key));
      return signer.verifySignature(_hex(hashHex), sig);
    } catch (_) {
      return false;
    }
  }
}

/// The DER inside a PEM public key.
List<int> pemToDer(String pem) => base64.decode(pem
    .split(RegExp(r'\r?\n'))
    .where((l) => l.trim().isNotEmpty && !l.startsWith('-----'))
    .join());

/// SHA-256 of a public key's DER, in hex: how keys are named on the platform key chain.
String keyFingerprint(String pem) => sha256.convert(pemToDer(pem)).toString();

Uint8List _hex(String hex) => Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
    ]);

/// SEQUENCE { INTEGER r, INTEGER s }, strictly: short-form lengths (a P-256 signature is
/// at most 72 bytes) and no trailing bytes.
ECSignature? _parseDer(List<int> der) {
  if (der.length < 8 || der[0] != 0x30 || der[1] != der.length - 2) return null;
  var i = 2;
  BigInt? readInt() {
    if (i + 2 > der.length || der[i] != 0x02) return null;
    final len = der[i + 1];
    if (len == 0 || len > 33 || i + 2 + len > der.length) return null;
    final bytes = der.sublist(i + 2, i + 2 + len);
    i += 2 + len;
    var value = BigInt.zero;
    for (final b in bytes) {
      value = (value << 8) | BigInt.from(b);
    }
    return value;
  }

  final r = readInt();
  final s = readInt();
  if (r == null || s == null || i != der.length) return null;
  return ECSignature(r, s);
}
