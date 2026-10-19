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

final anchorCheckProvider = FutureProvider.autoDispose.family<AnchorCheck?, String>(
    (ref, chamaId) async {
  final chain = await ref.watch(chainCheckProvider(chamaId).future);
  return checkAnchor(ref.watch(chamaRepositoryProvider), chamaId, chain);
});

final chainCheckProvider = FutureProvider.autoDispose.family<ChainCheck, String>(
    (ref, chamaId) => checkChain(ref.watch(chamaRepositoryProvider), chamaId));

/// Every record in the chama, newest first, after the phone has checked the whole
/// chain itself. A record the treasurer assigned to me can be sent back.
class RecordsTab extends ConsumerWidget {
  const RecordsTab({super.key, required this.bundle});

  final ChamaBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final check = ref.watch(chainCheckProvider(bundle.chama.id));
    return check.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Notice(problemText(l, e), tone: NoticeTone.critical),
      ]),
      data: (c) {
        final reversed = {for (final i in c.items) i.reverses}..remove(null);
        final receiptOf = {for (final i in c.items) i.id: i.receiptCode};
        final myCode = bundle.chama.myMemberCode;
        return RefreshIndicator(
          onRefresh: () => ref.refresh(chainCheckProvider(bundle.chama.id).future),
          child: ListView(
            padding: const EdgeInsets.all(JiraniSpace.m),
            children: [
              Notice(
                c.ok ? l.chainOk(c.entries) : l.chainBad,
                tone: c.ok ? NoticeTone.info : NoticeTone.critical,
              ),
              ...switch (ref.watch(anchorCheckProvider(bundle.chama.id)).value) {
                null => const <Widget>[],
                final a => [
                    const SizedBox(height: JiraniSpace.s),
                    Notice(a.ok ? l.anchorOk(a.at.substring(0, 10), '${a.seq}')
                        : l.anchorBad(a.at.substring(0, 10)),
                        tone: a.ok ? NoticeTone.info : NoticeTone.critical),
                  ],
              },
              if (c.ok && c.unsigned > 0) ...[
                const SizedBox(height: JiraniSpace.s),
                Notice(l.chainUnsigned(c.unsigned), tone: NoticeTone.warning),
              ],
              const SizedBox(height: JiraniSpace.s),
              for (final item in c.items.reversed)
                _EntryTile(
                  item: item,
                  isReversed: reversed.contains(item.id),
                  correctsReceipt: item.reverses == null ? null : receiptOf[item.reverses],
                  canSendBack: item.memberCode == myCode &&
                      item.decision['method'] == 'treasurer' &&
                      item.type == 'contribution' &&
                      !reversed.contains(item.id),
                  onSentBack: () => ref.invalidate(chainCheckProvider(bundle.chama.id)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EntryTile extends ConsumerStatefulWidget {
  const _EntryTile({required this.item, required this.canSendBack, required this.onSentBack,
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
