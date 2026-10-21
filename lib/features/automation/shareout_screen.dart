import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../l10n/app_localizations.dart';
import '../auth/presentation/problem_text.dart';
import '../chamas/data/models.dart';
import '../chamas/presentation/vote_screen.dart';
import 'automation_repository.dart';
import 'models.dart';

String shareOutStateLabel(AppLocalizations l, String state) => switch (state) {
      'draft' => l.shrDraft,
      'voting' => l.shrVoting,
      'paying' => l.shrPaying,
      'done' => l.shrDone,
      'rejected' => l.shrRejected,
      _ => l.shrCancelled,
    };

/// Year-end share-out: savings back and a share of what the chama earned, worked out from
/// the records, voted on by the members, then paid through money out like any payment.
class ShareOutScreen extends ConsumerStatefulWidget {
  const ShareOutScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<ShareOutScreen> createState() => _ShareOutScreenState();
}

class _ShareOutScreenState extends ConsumerState<ShareOutScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(shareOutsProvider(widget.chamaId));
    } catch (e) {
      setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(shareOutsProvider(widget.chamaId));
    return Scaffold(
      appBar: AppBar(title: Text(l.shrTitle)),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (list) {
          final open = list.items.where((s) =>
              const ['draft', 'voting', 'paying'].contains(s.state)).firstOrNull;
          return ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
            Notice(l.shrIntro),
            if (_error != null) ...[
              const SizedBox(height: JiraniSpace.s),
              Notice(_error!, tone: NoticeTone.critical),
            ],
            const SizedBox(height: JiraniSpace.s),
            if (open == null && list.canManage)
              _DraftForm(list: list, busy: _busy, onDraft: (body) => _run(() =>
                  ref.read(automationRepositoryProvider).draftShareOut(widget.chamaId, body))),
            if (open == null && !list.canManage)
              SurfaceCard(child: EmptyState(icon: Icons.savings_outlined, title: l.shrNone)),
            if (open != null)
              _ShareOutView(so: open, chamaId: widget.chamaId, busy: _busy,
                  onAction: (a) => _run(() =>
                      ref.read(automationRepositoryProvider).shareOutAction(open.id, a))),
            for (final s in list.items.where((s) => s.id != open?.id))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded),
                title: Text(l.shrPast(s.label)),
                subtitle: Text('${shareOutStateLabel(l, s.state)} · ${s.payoutTotal.format()}'),
              ),
          ]);
        },
      ),
    );
  }
}

class _DraftForm extends StatefulWidget {
  const _DraftForm({required this.list, required this.busy, required this.onDraft});

  final ShareOutList list;
  final bool busy;
  final void Function(Json body) onDraft;

  @override
  State<_DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends State<_DraftForm> {
  late DateTime _from = DateTime.parse(widget.list.suggestedFrom);
  late DateTime _to = DateTime.parse(widget.list.suggestedTo);
  bool _returnSavings = true;
  double _keep = 0;
  String _weight = 'savings_months';

  String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> _pick(bool from) async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, firstDate: DateTime(now.year - 5),
        lastDate: now, initialDate: from ? _from : (_to.isAfter(now) ? now : _to));
    if (picked != null) setState(() => from ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TitledCard(
      key: const ValueKey('shareout-form'),
      icon: Icons.savings_outlined,
      tone: JiraniTone.good,
      title: l.shrPrepare,
      children: [
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _pick(true),
              child: Text(l.shrFrom(_d(_from))))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () => _pick(false),
              child: Text(l.shrTo(_d(_to))))),
        ]),
        SwitchListTile(
          key: const ValueKey('shareout-return-savings'),
          contentPadding: EdgeInsets.zero,
          title: Text(l.shrReturnSavings),
          subtitle: Text(_returnSavings ? l.shrReturnSavingsYes : l.shrReturnSavingsNo),
          value: _returnSavings,
          onChanged: (v) => setState(() => _returnSavings = v),
        ),
        Text(l.shrKeep('${_keep.round()}')),
        Slider(value: _keep, min: 0, max: 50, divisions: 10, label: '${_keep.round()}%',
            onChanged: (v) => setState(() => _keep = v)),
        Text(l.shrShareBy),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'savings_months', label: Text(l.shrBySavingsMonths)),
            ButtonSegment(value: 'savings', label: Text(l.shrBySavings)),
          ],
          selected: {_weight},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _weight = s.first),
        ),
        const SizedBox(height: JiraniSpace.m),
        PrimaryButton(
          key: const ValueKey('shareout-draft'),
          label: l.shrWorkOut,
          busy: widget.busy,
          onPressed: () => widget.onDraft({
            'period_from': _d(_from), 'period_to': _d(_to),
            'return_savings': _returnSavings, 'keep_pct': _keep.round(), 'weight': _weight,
          }),
        ),
      ],
    );
  }
}

class _ShareOutView extends StatelessWidget {
  const _ShareOutView({required this.so, required this.chamaId, required this.busy,
      required this.onAction});

  final ShareOutInfo so;
  final String chamaId;
  final bool busy;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TitledCard(
        key: const ValueKey('shareout-figures'),
        icon: Icons.savings_outlined,
        tone: JiraniTone.good,
        title: l.shrCycle(so.label),
        subtitle: '${so.from} – ${so.to} · ${shareOutStateLabel(l, so.state)}',
        children: [
          InfoRow(l.shrEarned, MoneyText(so.earned)),
          InfoRow(l.shrShared, MoneyText(so.shared)),
          if (so.reserve.cents > 0) InfoRow(l.shrReserve, MoneyText(so.reserve)),
          if (so.returnSavings) InfoRow(l.shrSavingsBack, MoneyText(so.savingsBack)),
          InfoRow(l.shrToPay, MoneyText(so.payoutTotal)),
          if (so.short != null && so.short!.cents > 0) ...[
            const SizedBox(height: 8),
            Notice(l.shrShort(so.short!.format()), tone: NoticeTone.warning),
          ],
        ],
      ),
      SurfaceCard(
        margin: const EdgeInsets.only(top: JiraniSpace.s),
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final (i, x) in so.lines.indexed) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              key: ValueKey('share-line-${x.memberCode}'),
              tileColor: x.mine ? Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: .35) : null,
              title: Text(x.name),
              subtitle: Text([
                x.memberCode,
                if (x.savings.cents > 0) l.shrLineSavings(x.savings.format()),
                l.shrLineProfit(x.profit.format()),
                if (x.fines.cents > 0) l.shrLineFines(x.fines.format()),
                if (x.loan.cents > 0) l.shrLineLoan(x.loan.format()),
              ].join(' · ')),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end, children: [
                MoneyText(x.payout, style: text.titleSmall),
                if (x.proposalState != null)
                  Text(x.proposalState == 'paid' ? l.shrPaid : l.shrInMoneyOut,
                      style: text.bodySmall),
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(height: JiraniSpace.m),
      if (so.state == 'draft' && so.canManage) ...[
        PrimaryButton(key: const ValueKey('shareout-submit'), label: l.shrSubmit, busy: busy,
            onPressed: () => onAction('submit')),
        const SizedBox(height: 8),
        OutlinedButton(key: const ValueKey('shareout-cancel'),
            onPressed: busy ? null : () => onAction('cancel'), child: Text(l.shrCancel)),
      ],
      if (so.state == 'voting' && so.voteId != null)
        PrimaryButton(key: const ValueKey('shareout-vote'), label: l.shrVoteNow,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VoteScreen(chamaId: chamaId, voteId: so.voteId!)))),
      if (so.state == 'paying' && so.canManage &&
          so.lines.any((x) => x.payout.cents > 0 && x.proposalState == null))
        OutlinedButton(key: const ValueKey('shareout-propose'),
            onPressed: busy ? null : () => onAction('propose'),
            child: Text(l.shrProposeAgain)),
    ]);
  }
}
