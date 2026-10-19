import 'package:flutter_test/flutter_test.dart';
import 'package:jiranichama/features/chamas/application/chain_check.dart';

import 'fakes.dart';

Future<Map<String, Object>> _inline(Map<String, Object> Function() work) async => work();

void main() {
  test('signatures already checked on this phone are not checked again', () async {
    final repo = FakeChamaRepository();
    final trust = MemoryTrustStore();
    final first = await checkChain(repo, 'c1', trust: trust, run: _inline);
    expect(first.ok, isTrue);
    final head = await trust.read('c1');
    expect(head!.seq, repo.ledgerItems.last['document']['seq']);

    // A signature the phone already accepted is not re-checked (the hashes still are).
    for (final e in repo.ledgerItems) {
      e['platform_sig'] = 'AAAA';
    }
    expect((await checkChain(repo, 'c1', trust: trust, run: _inline)).ok, isTrue);
    // Without that trust, the same bad signatures are caught.
    final fresh = await checkChain(repo, 'c1', trust: MemoryTrustStore(), run: _inline);
    expect(fresh.ok, isFalse);
  });

  test('a changed record is caught even when the phone trusted the chain before', () async {
    final repo = FakeChamaRepository();
    final trust = MemoryTrustStore();
    await checkChain(repo, 'c1', trust: trust, run: _inline);
    (repo.ledgerItems.first['document'] as Map)['amount_cents'] = 999999;
    final again = await checkChain(repo, 'c1', trust: trust, run: _inline);
    expect(again.ok, isFalse);
  });
}
