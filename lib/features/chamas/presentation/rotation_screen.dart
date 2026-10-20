import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'chama_screen.dart';
import 'money_out_screen.dart';

final rotationProvider = FutureProvider.autoDispose.family<RotationInfo, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).rotation(id);
});

/// The merry-go-round (rules 8.1, 8.2): the order, whose turn is next, and filling in the
/// next payout. Every member sees it; officials start a cycle and propose payouts.
class RotationScreen extends ConsumerStatefulWidget {
  const RotationScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<RotationScreen> createState() => _RotationScreenState();
}

class _RotationScreenState extends ConsumerState<RotationScreen> {
  String? _error;
  bool _busy = false;

  Future<T?> _run<T>(Future<T> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      return await action();
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start(RotationInfo r, ChamaBundle bundle) async {
    final l = AppLocalizations.of(context);
    List<String>? order;
    if (r.order == 'fixed') {
      order = await showDialog<List<String>>(
          context: context, builder: (_) => _OrderDialog(members: bundle.members));
      if (order == null) return;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.startRotation),
          content: Text(l.startRotationDrawConfirm),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l.startRotation)),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _run(() => ref.read(chamaRepositoryProvider)
        .startRotation(widget.chamaId, order: order, idempotencyKey: newIdempotencyKey()));
    ref.invalidate(rotationProvider(widget.chamaId));
  }

  Future<void> _proposeNext() async {
    final p = await _run(() => ref.read(chamaRepositoryProvider)
        .proposeNextTurn(widget.chamaId, idempotencyKey: newIdempotencyKey()));
    ref.invalidate(rotationProvider(widget.chamaId));
    ref.invalidate(proposalsProvider(widget.chamaId));
    if (p == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProposalScreen(chamaId: widget.chamaId, proposalId: p.id)));
    ref.invalidate(rotationProvider(widget.chamaId));
  }

  String _turnLabel(AppLocalizations l, RotationInfo r, RotationTurnInfo t) {
    if (t.state == 'paid') return l.turnPaid;
    if (t.state == 'skipped') return '${l.turnSkipped}: ${t.note}';
    final base = r.running && r.nextPosition == t.position ? l.turnNext : l.turnPending;
    return t.proposalState == null ? base : '$base · ${proposalStateLabel(l, t.proposalState!)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final bundle = ref.watch(chamaBundleProvider(widget.chamaId)).value;
    final official = bundle?.chama.iAmOfficial ?? false;
    final moneyOut = bundle?.chama.mode == 'money_out';
    final info = ref.watch(rotationProvider(widget.chamaId));
    final r = info.value;
    return Scaffold(
      appBar: AppBar(title: Text(l.merryGoRound)),
      bottomNavigationBar: official && bundle != null && r != null
          ? ActionBar(
              child: r.running
                  ? (moneyOut
                      ? PrimaryButton(label: l.proposeNextTurn, busy: _busy,
                          onPressed: _proposeNext)
                      : Text(l.errMoneyOutOff, textAlign: TextAlign.center))
                  : PrimaryButton(label: l.startRotation, busy: _busy,
                      onPressed: () => _start(r, bundle)))
          : null,
      body: info.when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (r) => ListView(
          padding: const EdgeInsets.all(JiraniSpace.m),
          children: [
            Text(r.order == 'fixed' ? l.rotationOrderFixed : l.rotationOrderDraw),
            Text(switch (r.arrears) {
              'deduct' => l.rotationArrearsDeduct,
              'block' => l.rotationArrearsBlock,
              _ => l.rotationArrearsSkip,
            }),
            const SizedBox(height: JiraniSpace.s),
            if (_error != null) ...[
              Notice(_error!, tone: NoticeTone.critical),
              const SizedBox(height: JiraniSpace.s),
            ],
            if (!r.running) Notice(r.cycleNo == null ? l.rotationNotStarted
                : l.errRotationComplete),
            if (r.cycleNo != null) ...[
              const SizedBox(height: JiraniSpace.s),
              Text(l.cycleLine('${r.cycleNo}', r.pot?.format() ?? ''), style: text.titleMedium),
              if ((r.seed ?? '').isNotEmpty)
                Text(l.drawSeedLine(r.seed!.substring(0, 12), r.receipt ?? ''),
                    style: text.bodySmall),
              const SizedBox(height: JiraniSpace.s),
              Card(
                child: Column(children: [
                  for (final t in r.turns)
                    ListTile(
                      key: ValueKey('turn-${t.position}'),
                      leading: CircleAvatar(child: Text('${t.position}')),
                      title: Text('${t.name} (${t.memberCode})',
                          style: t.state == 'skipped'
                              ? const TextStyle(decoration: TextDecoration.lineThrough)
                              : null),
                      subtitle: Text(_turnLabel(l, r, t)),
                      trailing: t.state == 'paid'
                          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                          : r.nextPosition == t.position
                              ? const Icon(Icons.arrow_forward)
                              : null,
                    ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The officials' order for a fixed rotation: everyone, moved up or down.
class _OrderDialog extends StatefulWidget {
  const _OrderDialog({required this.members});

  final List<Member> members;

  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  late final List<Member> _order = [...widget.members];

  void _move(int i, int by) => setState(() {
        final m = _order.removeAt(i);
        _order.insert(i + by, m);
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.setOrderTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(shrinkWrap: true, children: [
          for (var i = 0; i < _order.length; i++)
            ListTile(
              key: ValueKey('order-${_order[i].memberCode}'),
              contentPadding: EdgeInsets.zero,
              leading: Text('${i + 1}.'),
              title: Text(_order[i].name),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: l.moveUp, icon: const Icon(Icons.arrow_upward),
                    onPressed: i == 0 ? null : () => _move(i, -1)),
                IconButton(tooltip: l.moveDown, icon: const Icon(Icons.arrow_downward),
                    onPressed: i == _order.length - 1 ? null : () => _move(i, 1)),
              ]),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop([for (final m in _order) m.id]),
            child: Text(l.startRotation)),
      ],
    );
  }
}
