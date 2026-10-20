// Which platform keys a phone trusts, and members' countersignatures.
// Twin of `apps/ledger/trust.py` in the API; both are held to
// `test/vectors/key_chain.json`.

import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;

import 'canonical_json.dart';
import 'platform_signature.dart';

/// The keys a phone accepts: the pinned first key, then each key endorsed by the one
/// before it. [problem] says where the chain broke (anything after it is not trusted).
class TrustedKeys {
  const TrustedKeys(this.keys, {this.problem});

  /// key_id → PEM, for every key on the verified part of the chain.
  final Map<String, String> keys;
  final String? problem;

  bool get ok => problem == null;
}

/// Walks the platform key chain from [pinnedFingerprint]. A key is trusted only if its
/// fingerprint is really its own, and the previous trusted key signed it.
TrustedKeys verifyKeyChain(List<Map<String, Object?>> chain, String pinnedFingerprint) {
  final trusted = <String, String>{};
  if (chain.isEmpty) return const TrustedKeys({}, problem: 'no platform keys');
  String? prevId;
  PlatformKey? prevKey;
  for (final (i, k) in chain.indexed) {
    final id = k['key_id'] as String? ?? '';
    final pem = k['public_key_pem'] as String? ?? '';
    final String fp;
    try {
      fp = keyFingerprint(pem);
    } catch (_) {
      return TrustedKeys(trusted, problem: 'key $id is not a valid key');
    }
    if (fp != k['fingerprint']) {
      return TrustedKeys(trusted, problem: 'key $id has the wrong fingerprint');
    }
    if (i == 0) {
      if (fp != pinnedFingerprint) {
        return TrustedKeys(trusted, problem: 'the first key is not the one this app trusts');
      }
    } else {
      final sig = k['endorsement_sig'] as String?;
      final digest = sha256.convert(utf8.encode(canonicalJson(endorsementPayload(
          keyId: id, fingerprint: fp, prevKeyId: prevId!)))).toString();
      if (k['prev_key_id'] != prevId || sig == null || !prevKey!.verifyHash(digest, sig)) {
        return TrustedKeys(trusted, problem: 'key $id is not endorsed by key $prevId');
      }
    }
    trusted[id] = pem;
    prevId = id;
    prevKey = PlatformKey.fromPem(pem);
  }
  return TrustedKeys(trusted);
}

Map<String, Object?> endorsementPayload(
        {required String keyId, required String fingerprint, required String prevKeyId}) =>
    {'v': 1, 'purpose': 'platform_key_endorsement', 'key_id': keyId,
     'fingerprint': fingerprint, 'prev_key_id': prevKeyId};

/// What a member's phone signs to vouch for a chama's chain up to [seq].
Map<String, Object?> countersignPayload(
        {required String chamaId, required String memberCode, required int seq,
        required String hash}) =>
    {'v': 1, 'purpose': 'countersign_chain', 'chama_id': chamaId,
     'member_code': memberCode, 'seq': seq, 'hash': hash};

/// True only if [signatureB64] is the phone key's ([devicePublicKeyB64], DER) signature
/// over this countersignature. Never throws.
bool verifyCountersignature({required String chamaId, required String memberCode,
    required int seq, required String hash, required String devicePublicKeyB64,
    required String signatureB64}) {
  try {
    final key = PlatformKey.fromDer(base64.decode(devicePublicKeyB64));
    final message = utf8.encode(canonicalJson(countersignPayload(
        chamaId: chamaId, memberCode: memberCode, seq: seq, hash: hash)));
    return key.verifyMessage(message, signatureB64);
  } catch (_) {
    return false;
  }
}
