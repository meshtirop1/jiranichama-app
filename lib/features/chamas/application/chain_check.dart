import 'dart:isolate';

import 'package:jirani_domain/jirani_domain.dart';

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
  const AnchorCheck({required this.at, required this.seq, required this.ok});

  final String at;
  final int seq;
  final bool ok;
}

Future<AnchorCheck?> checkAnchor(ChamaRepository repo, String chamaId, ChainCheck chain) async {
  final proofs = await repo.anchors(chamaId);
  if (proofs.isEmpty) return null;
  final p = proofs.first;
  final mine = chain.items.where((i) => i.seq == p.seq).firstOrNull;
  final ok = chain.ok && mine != null && mine.hash == p.hash &&
      verifyAnchorPath(anchorLeaf(chamaId, p.seq, p.hash), p.path, p.merkleRoot);
  return AnchorCheck(at: p.at, seq: p.seq, ok: ok);
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
}

class MemoryTrustStore implements TrustStore {
  final _heads = <String, TrustedHead>{};

  @override
  Future<TrustedHead?> read(String chamaId) async => _heads[chamaId];

  @override
  Future<void> write(String chamaId, TrustedHead head) async => _heads[chamaId] = head;
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
  final pem = all.isEmpty ? '' : await repo.platformKeyPem();
  final head = await trust?.read(chamaId);
  final jsons = [for (final i in all) i.json];
  final result = await run(() => _verify(jsons, pem, head?.seq, head?.hash));
  final problems = (result['problems'] as List).cast<String>();
  if (problems.isEmpty && all.isNotEmpty) {
    await trust?.write(chamaId, (seq: all.last.seq, hash: all.last.hash));
  }
  return ChainCheck(entries: all.length, problems: problems,
      unsigned: result['unsigned'] as int, items: all);
}

Map<String, Object> _verify(List<Map<String, dynamic>> jsons, String pem, int? trustedSeq,
    String? trustedHash) {
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
  if (items.isNotEmpty) {
    final key = PlatformKey.fromPem(pem);
    for (final i in items) {
      final sig = i.signature;
      if (sig == null) {
        unsigned++;
      } else if (i.seq > from && !key.verifyHash(i.hash, sig)) {
        problems.add('seq ${i.seq}: platform signature is not valid');
      }
    }
  }
  return {'problems': problems, 'unsigned': unsigned};
}
