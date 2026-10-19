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

/// Downloads a chama's whole chain and checks it on the phone (6.10): every hash
/// recomputed, every link followed, every platform signature verified. The phone never
/// trusts a stored hash or the server's word that the chain is fine.
///
/// Phase 1 checks the full chain on each load. Keeping a trusted head between sessions
/// arrives with the encrypted offline store.
Future<ChainCheck> checkChain(ChamaRepository repo, String chamaId) async {
  final items = <LedgerItem>[];
  var after = 0;
  while (true) {
    final page = await repo.ledger(chamaId, afterSeq: after);
    items.addAll(page.entries);
    if (!page.more || page.entries.isEmpty) break;
    after = page.nextAfterSeq;
  }
  final problems = [
    for (final p in verifyChain([
      for (final i in items) ChainEntry(document: i.document, hash: i.hash),
    ]))
      p.toString(),
  ];
  var unsigned = 0;
  if (items.isNotEmpty) {
    final key = PlatformKey.fromPem(await repo.platformKeyPem());
    for (final i in items) {
      final sig = i.signature;
      if (sig == null) {
        unsigned++;
      } else if (!key.verifyHash(i.hash, sig)) {
        problems.add('seq ${i.seq}: platform signature is not valid');
      }
    }
  }
  return ChainCheck(entries: items.length, problems: problems, unsigned: unsigned,
      items: items);
}
