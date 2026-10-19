import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/labels.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../application/chain_check.dart';
import '../data/models.dart';
import 'chama_screen.dart';

/// The records as the server sends them, shown at once while the phone checks them.
final ledgerItemsProvider = FutureProvider.autoDispose.family<List<LedgerItem>, String>(
    (ref, chamaId) {
  ref.cacheFor(const Duration(minutes: 5));
  return loadLedger(ref.watch(chamaRepositoryProvider), chamaId);
});

/// The phone's own check of those records, on a background isolate.
final chainCheckProvider = FutureProvider.autoDispose.family<ChainCheck, String>(
    (ref, chamaId) async {
  ref.cacheFor(const Duration(minutes: 5));
  final items = await ref.watch(ledgerItemsProvider(chamaId).future);
  return checkChain(ref.watch(chamaRepositoryProvider), chamaId, items: items,
      trust: ref.watch(trustStoreProvider), run: ref.watch(chainRunnerProvider));
});

final anchorCheckProvider = FutureProvider.autoDispose.family<AnchorCheck?, String>(
    (ref, chamaId) async {
  ref.cacheFor(const Duration(minutes: 5));
  final chain = await ref.watch(chainCheckProvider(chamaId).future);
  return checkAnchor(ref.watch(chamaRepositoryProvider), chamaId, chain);
});

/// Every record in the chama, newest first. They show as soon as they arrive; the notice
/// at the top says when the phone has finished checking them itself. A record the
/// treasurer assigned to me can be sent back.
class RecordsTab extends ConsumerWidget {
  const RecordsTab({super.key, required this.bundle});

  final ChamaBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final id = bundle.chama.id;
    final ledger = ref.watch(ledgerItemsProvider(id));
    return ledger.when(
      skipLoadingOnRefresh: true,
      loading: () => const _RecordsSkeleton(),
      error: (e, _) => ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Notice(problemText(l, e), tone: NoticeTone.critical),
      ]),
      data: (items) {
        final check = ref.watch(chainCheckProvider(id));
        final reversed = {for (final i in items) i.reverses}..remove(null);
        final receiptOf = {for (final i in items) i.id: i.receiptCode};
        final myCode = bundle.chama.myMemberCode;
        final newestFirst = items.reversed.toList();
        final header = <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (check) {
              AsyncData(:final value) => Notice(
                  key: ValueKey('chain-${value.ok}'),
                  value.ok ? l.chainOk(value.entries) : l.chainBad,
                  tone: value.ok ? NoticeTone.info : NoticeTone.critical),
              AsyncError() => Notice(key: const ValueKey('chain-error'), l.chainBad,
                  tone: NoticeTone.critical),
              _ => Notice(key: const ValueKey('chain-checking'),
                  l.chainChecking(items.length)),
            },
          ),
          ...switch (ref.watch(anchorCheckProvider(id)).value) {
            null => const <Widget>[],
            final a => [
                const SizedBox(height: JiraniSpace.s),
                Notice(a.ok ? l.anchorOk(a.at.substring(0, 10), '${a.seq}')
                    : l.anchorBad(a.at.substring(0, 10)),
                    tone: a.ok ? NoticeTone.info : NoticeTone.critical),
              ],
          },
          if (check.value case final c? when c.ok && c.unsigned > 0) ...[
            const SizedBox(height: JiraniSpace.s),
            Notice(l.chainUnsigned(c.unsigned), tone: NoticeTone.warning),
          ],
          const SizedBox(height: JiraniSpace.s),
        ];
        return RefreshIndicator(
          onRefresh: () => ref.refresh(ledgerItemsProvider(id).future),
          // Built lazily: a chama with thousands of records scrolls as smoothly as one
          // with ten.
          child: ListView.builder(
            padding: const EdgeInsets.all(JiraniSpace.m),
            itemCount: header.length + newestFirst.length,
            itemBuilder: (context, index) {
              if (index < header.length) return header[index];
              final item = newestFirst[index - header.length];
              return _EntryTile(
                key: ValueKey(item.id),
                item: item,
                isReversed: reversed.contains(item.id),
                correctsReceipt: item.reverses == null ? null : receiptOf[item.reverses],
                canSendBack: item.memberCode == myCode &&
                    item.decision['method'] == 'treasurer' &&
                    item.type == 'contribution' &&
                    !reversed.contains(item.id),
                onSentBack: () => ref.invalidate(ledgerItemsProvider(id)),
              );
            },
          ),
        );
      },
    );
  }
}

/// Grey placeholders the size of real records, so the screen does not jump when they
/// arrive.
class _RecordsSkeleton extends StatelessWidget {
  const _RecordsSkeleton();

  @override
  Widget build(BuildContext context) {
    final grey = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(JiraniSpace.m),
      children: [
        for (var i = 0; i < 7; i++)
          Container(
            height: i == 0 ? 56 : 76,
            margin: const EdgeInsets.only(bottom: JiraniSpace.s),
            decoration: BoxDecoration(color: grey, borderRadius: BorderRadius.circular(12)),
          ),
      ],
    );
  }
}

class _EntryTile extends ConsumerStatefulWidget {
  const _EntryTile({super.key, required this.item, required this.canSendBack, required this.onSentBack,
      this.isReversed = false, this.correctsReceipt});

  final LedgerItem item;
  final bool isReversed;
  final String? correctsReceipt;
  final bool canSendBack;
  final VoidCallback onSentBack;

  @override
  ConsumerState<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends ConsumerState<_EntryTile> {
  final _key = newIdempotencyKey();
  bool _busy = false;

  Future<void> _sendBack() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(chamaRepositoryProvider)
          .notMe(widget.item.sourceId!, idempotencyKey: _key);
      messenger.showSnackBar(SnackBar(content: Text(l.notMeDone)));
      widget.onSentBack();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(problemText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final i = widget.item;
    final details = [
      if (i.memberCode != null) i.memberCode!,
      if (i.period != null) i.period!,
      l.receipt(i.receiptCode),
      if (widget.correctsReceipt != null) l.correctsReceipt(widget.correctsReceipt!),
    ].join(' · ');
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: ListTile(
        // A reversed record stays in the list (nothing is deleted) but is marked and
        // struck through, so nobody counts it twice.
        title: Text.rich(TextSpan(children: [
          TextSpan(text: entryLabel(l, i.type),
              style: widget.isReversed ? TextStyle(decoration: TextDecoration.lineThrough,
                  color: muted) : null),
          if (widget.isReversed) TextSpan(text: '  ${l.reversedLabel}',
              style: TextStyle(color: muted, fontSize: 12)),
        ])),
        subtitle: Text(details),
        trailing: i.amount.cents == 0 ? null : MoneyText(i.amount),
        isThreeLine: widget.canSendBack,
        // The only action a member has on a record: say an assigned payment is not theirs.
        leading: widget.canSendBack
            ? IconButton(
                tooltip: l.notMe,
                icon: const Icon(Icons.undo),
                onPressed: _busy ? null : _sendBack,
              )
            : null,
      ),
    );
  }
}
