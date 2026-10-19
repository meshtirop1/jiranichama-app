/// A signing key in the phone's secure chip, used only after the owner's fingerprint,
/// face or phone PIN (JiraniChama proposal 6.7).
///
/// Android 11+ only for now. Elsewhere [SecureKeys.isAvailable] is false and the app
/// uses SMS codes.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

class CreatedKey {
  const CreatedKey({required this.publicKey, required this.chain, required this.strongBox});

  /// Base64 SubjectPublicKeyInfo.
  final String publicKey;

  /// The key's attestation certificates, base64 DER, leaf first.
  final List<String> chain;
  final bool strongBox;
}

class SecureKeysCancelled implements Exception {
  const SecureKeysCancelled(this.message);
  final String message;
  @override
  String toString() => 'SecureKeysCancelled: $message';
}

class SecureKeys {
  const SecureKeys({this.alias = 'jirani_signing_v1'});

  final String alias;
  static const _channel = MethodChannel('jirani_secure_keys');

  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false; // not built for this platform (iOS for now)
    } on PlatformException {
      return false;
    }
  }

  Future<bool> hasKey() async {
    try {
      return await _channel.invokeMethod<bool>('hasKey', {'alias': alias}) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> deleteKey() => _channel.invokeMethod('deleteKey', {'alias': alias});

  /// Makes a new key, replacing any old one. [challenge] goes into its attestation.
  Future<CreatedKey> createKey(List<int> challenge) async {
    final r = await _channel.invokeMapMethod<String, dynamic>(
        'createKey', {'alias': alias, 'challenge': base64Encode(challenge)});
    return CreatedKey(
      publicKey: r!['publicKey'] as String,
      chain: (r['chain'] as List).cast<String>(),
      strongBox: r['strongBox'] == true,
    );
  }

  Future<String?> publicKey() =>
      _channel.invokeMethod<String>('publicKey', {'alias': alias});

  /// Asks for the fingerprint, face or PIN, then signs [data] (ECDSA P-256, SHA-256).
  /// Returns the base64 DER signature. Throws [SecureKeysCancelled] if the person backs out.
  Future<String> sign(List<int> data, {required String title, required String subtitle}) async {
    try {
      final s = await _channel.invokeMethod<String>('sign', {
        'alias': alias, 'data': base64Encode(data), 'title': title, 'subtitle': subtitle,
      });
      return s!;
    } on PlatformException catch (e) {
      if (e.code == 'cancelled') throw SecureKeysCancelled(e.message ?? '');
      rethrow;
    }
  }
}
