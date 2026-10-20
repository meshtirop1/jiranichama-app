import 'dart:isolate';

import 'package:jirani_domain/jirani_domain.dart';

import '../../../config.dart';
import '../data/chama_repository.dart';
import '../data/models.dart';

class ChainCheck {
  const ChainCheck({required this.entries, required this.problems, required this.unsigned,
      required this.items});

  final int entries;
  final List<String> problems;
  final int unsigned;
  final List<LedgerItem> items;

  bool get ok => problems.isEmpty;
}

/// Whether the chain this phone checked is the one in the latest public anchor.
class AnchorCheck {
  const AnchorCheck({required this.at, required this.seq, required this.ok,
      this.anchorId = '', this.hasProof = false});

  final String at;
  final int seq;
  final bool ok;
  final String anchorId;
  final bool hasProof;
}

Future<AnchorCheck?> checkAnchor(ChamaRepository repo, String chamaId, ChainCheck chain) async {
  final proofs = await repo.anchors(chamaId);
  if (proofs.isEmpty) return null;
  final p = proofs.first;
  final mine = chain.items.where((i) => i.seq == p.seq).firstOrNull;
  final ok = chain.ok && mine != null && mine.hash == p.hash &&
      verifyAnchorPath(anchorLeaf(chamaId, p.seq, p.hash), p.path, p.merkleRoot);
  return AnchorCheck(at: p.at, seq: p.seq, ok: ok, anchorId: p.anchorId,
      hasProof: p.hasProof);
}

/// Runs the heavy part of the check: on a background isolate in the app, inline in
/// widget tests (whose clock does not wait for other isolates).
typedef ChainRunner = Future<Map<String, Object>> Function(Map<String, Object> Function() work);

Future<Map<String, Object>> isolateRunner(Map<String, Object> Function() work) =>
    Isolate.run(work);

/// The last record this phone has already checked in a chama: its seq and hash.
typedef TrustedHead = ({int seq, String hash});

/// Where the phone keeps the records it has already checked, per chama (6.10). Behind
/// an interface so tests keep it in memory.
abstract class TrustStore {
  Future<TrustedHead?> read(String chamaId);
  Future<void> write(String chamaId, TrustedHead head);

  /// The first platform key this phone trusted, when the app was not built with one.
  Future<String?> pinnedKey();
  Future<void> pinKey(String fingerprint);
}

class MemoryTrustStore implements TrustStore {
  final _heads = <String, TrustedHead>{};
  String? pinned;

  @override
  Future<TrustedHead?> read(String chamaId) async => _heads[chamaId];

  @override
  Future<void> write(String chamaId, TrustedHead head) async => _heads[chamaId] = head;

  @override
  Future<String?> pinnedKey() async => pinned;

  @override
  Future<void> pinKey(String fingerprint) async => pinned = fingerprint;
}

/// The platform keys this phone accepts (protection plan 2026-10-20): the chain from the
/// key built into the app, or, on a dev build, from the first key this phone saw. A key
/// the old key did not endorse is never trusted, whatever the server says.
Future<TrustedKeys> trustedKeys(ChamaRepository repo, TrustStore? trust,
    {String built = AppConfig.platformKeyFingerprint}) async {
  final chain = await repo.platformKeyChain();
  var pin = built.isNotEmpty ? built : await trust?.pinnedKey();
  if (pin == null && chain.isNotEmpty) {
    pin = chain.first['fingerprint'] as String? ?? '';
    await trust?.pinKey(pin);
  }
  return verifyKeyChain(chain, pin ?? '');
}

/// What members' phones vouched for, checked on this phone against its own chain.
class CountersignCheck {
  const CountersignCheck({required this.members, required this.disagree,
      required this.myLatestSeq, required this.upToSeq});

  /// Member codes whose valid signature matches this phone's chain.
  final List<String> members;

  /// Member codes whose signed hash (or signature) does NOT match this phone's chain.
  final List<String> disagree;
  final int myLatestSeq;

  /// The highest record any member has vouched for.
  final int upToSeq;

  bool get ok => disagree.isEmpty;
}

CountersignCheck checkCountersignatures(String chamaId, List<Map<String, dynamic>> signed,
    List<LedgerItem> items, String? myMemberCode) {
  final bySeq = {for (final i in items) i.seq: i.hash};
  final good = <String>[], bad = <String>[];
  var mine = 0, upTo = 0;
  for (final c in signed) {
    final code = c['member_code'] as String;
    final seq = c['seq'] as int;
    final hash = c['hash'] as String;
    final valid = verifyCountersignature(chamaId: chamaId, memberCode: code, seq: seq,
        hash: hash, devicePublicKeyB64: c['device_public_key'] as String,
        signatureB64: c['signature'] as String);
    final known = bySeq[seq];
    if (!valid || (known != null && known != hash)) {
      bad.add(code);
      continue;
    }
    if (known == null) continue; // signed beyond what this phone has loaded
    good.add(code);
    if (seq > upTo) upTo = seq;
    if (code == myMemberCode && seq > mine) mine = seq;
  }
  return CountersignCheck(members: good, disagree: bad, myLatestSeq: mine, upToSeq: upTo);
}

/// Every record of a chama, oldest first, as the server sends them (not yet checked).
Future<List<LedgerItem>> loadLedger(ChamaRepository repo, String chamaId) async {
  final items = <LedgerItem>[];
  var after = 0;
  while (true) {
    final page = await repo.ledger(chamaId, afterSeq: after);
    items.addAll(page.entries);
    if (!page.more || page.entries.isEmpty) break;
    after = page.nextAfterSeq;
  }
  return items;
}

/// Checks a chama's whole chain on the phone (6.10): every hash recomputed and every
/// link followed, every time. Platform signatures are checked for records after the last
/// one this phone already checked: when that record's hash still matches, everything up
/// to it is exactly what was checked before, so its signatures need no second check.
///
/// The work runs on a background isolate, so the screen never freezes while it runs.
Future<ChainCheck> checkChain(ChamaRepository repo, String chamaId,
    {List<LedgerItem>? items, TrustStore? trust, ChainRunner run = isolateRunner}) async {
  final all = items ?? await loadLedger(repo, chamaId);
  final keys = all.isEmpty ? const TrustedKeys({}) : await trustedKeys(repo, trust);
  final keyPems = keys.keys;
  final head = await trust?.read(chamaId);
  final jsons = [for (final i in all) i.json];
  final result = await run(() => _verify(jsons, keyPems, head?.seq, head?.hash));
  final problems = [
    if (!keys.ok) 'platform keys: ${keys.problem}',
    ...(result['problems'] as List).cast<String>(),
  ];
  if (problems.isEmpty && all.isNotEmpty) {
    await trust?.write(chamaId, (seq: all.last.seq, hash: all.last.hash));
  }
  return ChainCheck(entries: all.length, problems: problems,
      unsigned: result['unsigned'] as int, items: all);
}

Map<String, Object> _verify(List<Map<String, dynamic>> jsons, Map<String, String> keyPems,
    int? trustedSeq, String? trustedHash) {
  final items = [for (final j in jsons) LedgerItem(j)];
  final problems = [
    for (final p in verifyChain([
      for (final i in items) ChainEntry(document: i.document, hash: i.hash),
    ]))
      p.toString(),
  ];
  // Signatures already checked on this phone are trusted only if the record that ended
  // that check is still there with the same hash.
  final stillTrusted = trustedSeq != null &&
      items.any((i) => i.seq == trustedSeq && i.hash == trustedHash);
  final from = stillTrusted ? trustedSeq : 0;
  var unsigned = 0;
  final keys = {for (final e in keyPems.entries) e.key: PlatformKey.fromPem(e.value)};
  for (final i in items) {
    final sig = i.signature;
    if (sig == null) {
      unsigned++;
    } else if (i.seq > from) {
      final key = keys[i.keyId];
      if (key == null) {
        problems.add('seq ${i.seq}: signed by a key this phone does not trust');
      } else if (!key.verifyHash(i.hash, sig)) {
        problems.add('seq ${i.seq}: platform signature is not valid');
      }
    }
  }
  return {'problems': problems, 'unsigned': unsigned};
}
