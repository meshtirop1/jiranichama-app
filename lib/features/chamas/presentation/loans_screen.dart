import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'widgets/sms_code_sheet.dart';

final loansProvider = FutureProvider.autoDispose.family<List<LoanInfo>, String>(
    (ref, chamaId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).loans(chamaId);
});

String loanStateLabel(AppLocalizations l, String state) => switch (state) {
      'awaiting_guarantors' => l.loanAwaitingGuarantors,
      'awaiting_approval' => l.loanAwaitingApproval,
      'approved' => l.loanApproved,
      'repaying' => l.loanRepaying,
      'in_arrears' => l.loanInArrears,
      'defaulted' => l.loanDefaulted,
      'repaid' => l.loanRepaid,
      'declined' => l.loanDeclined,
      'expired' => l.loanExpired,
      _ => l.loanCancelled,
    };

String guaranteeStateLabel(AppLocalizations l, String state) => switch (state) {
      'requested' => l.guaranteeRequested,
      'accepted' => l.guaranteeAccepted,
      'declined' => l.guaranteeDeclined,
      'expired' => l.guaranteeExpired,
      'called' => l.guaranteeCalled,
      _ => l.guaranteeReleased,
    };

String _kes(int cents) => Kes(cents).format();

/// On the overview, only where loans are switched on: my loan, and requests to guarantee.
class LoansCard extends ConsumerWidget {
  const LoansCard({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(loansProvider(chamaId)).value ?? const <LoanInfo>[];
    final asks = list.where((x) => x.guarantees.any((g) => g.mine && g.state == 'requested'));
    final mine = list.where((x) => x.mine && x.open).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: JiraniSpace.s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final x in asks)
          Padding(
            padding: const EdgeInsets.only(bottom: JiraniSpace.s),
            child: Notice(l.guaranteeAsked(x.borrower, _kes(x.amountCents)),
                tone: NoticeTone.warning, onTap: () => _open(context, x.id)),
          ),
        NavTile(
          key: const ValueKey('loans-card'),
          icon: Icons.account_balance_wallet_outlined,
          tone: JiraniTone.brand,
          margin: EdgeInsets.zero,
          title: l.loansTitle,
          subtitle: mine == null ? l.loansNone
                : '${loanStateLabel(l, mine.state)} · '
                  '${l.loanOwed(_kes(mine.balance.outstandingCents))}',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LoansScreen(chamaId: chamaId))),
        ),
      ]),
    );
  }

  void _open(BuildContext context, String id) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoanScreen(chamaId: chamaId, loanId: id)));
}

/// The chama's loan book: every member sees every loan (transparency, 6.1).
class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(loansProvider(chamaId));
    return Scaffold(
      appBar: AppBar(title: Text(l.loansTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('request-loan'),
        icon: const Icon(Icons.add),
        label: Text(l.loanRequest),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => LoanRequestScreen(chamaId: chamaId))),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (list) => list.isEmpty
            ? Padding(padding: const EdgeInsets.all(JiraniSpace.m), child: Notice(l.loansNone))
            : ListView(children: [
                for (final x in list)
                  ListTile(
                    title: Text('${x.borrower} · ${_kes(x.amountCents)}'),
                    subtitle: Text('${loanStateLabel(l, x.state)} · ${x.purpose}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LoanScreen(chamaId: chamaId, loanId: x.id))),
                  ),
              ]),
      ),
    );
  }
}

Widget _scheduleTable(BuildContext context, AppLocalizations l, List<Json> rows) {
  final style = Theme.of(context).textTheme.bodySmall;
  return Table(
    columnWidths: const {0: IntrinsicColumnWidth()},
    children: [
      TableRow(children: [
        for (final h in [l.loanColDue, l.loanColPrincipal, l.loanColInterest, l.loanColTotal])
          Padding(padding: const EdgeInsets.all(4),
              child: Text(h, style: style?.copyWith(fontWeight: FontWeight.bold))),
      ]),
      for (final r in rows)
        TableRow(children: [
          for (final v in [r['due'] as String, _kes(r['principal_cents'] as int),
            _kes(r['interest_cents'] as int), _kes(r['total_cents'] as int)])
            Padding(padding: const EdgeInsets.all(4), child: Text(v, style: style)),
        ]),
    ],
  );
}

class LoanRequestScreen extends ConsumerStatefulWidget {
  const LoanRequestScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<LoanRequestScreen> createState() => _LoanRequestScreenState();
}

class _LoanRequestScreenState extends ConsumerState<LoanRequestScreen> {
  final _amount = TextEditingController();
  final _term = TextEditingController(text: '6');
  final _purpose = TextEditingController();
  final _key = newIdempotencyKey();
  final Set<String> _guarantors = {};
  LoanQuote? _quote;
  List<Member> _members = const [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(chamaRepositoryProvider).members(widget.chamaId).then((m) {
      if (mounted) setState(() => _members = m);
    });
  }

  @override
  void dispose() {
    for (final c in [_amount, _term, _purpose]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _cents => Kes.shillings(int.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0)
      .cents;
  int get _months => int.tryParse(_term.text.trim()) ?? 0;

  Future<void> _check() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final q = await ref.read(chamaRepositoryProvider)
          .loanQuote(widget.chamaId, amountCents: _cents, termMonths: _months);
      if (mounted) setState(() => _quote = q);
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final loan = await ref.read(chamaRepositoryProvider).requestLoan(widget.chamaId, {
        'amount_cents': _cents, 'term_months': _months, 'purpose': _purpose.text.trim(),
        'guarantor_ids': _guarantors.toList(),
      }, idempotencyKey: _key);
      ref.invalidate(loansProvider(widget.chamaId));
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => LoanScreen(chamaId: widget.chamaId, loanId: loan.id)));
      }
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final q = _quote;
    final me = ref.watch(_myMemberCode(widget.chamaId)).value;
    final needed = q?.guarantorsNeeded ?? 0;
    final ready = q != null && q.eligible && _guarantors.length == needed
        && _purpose.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(l.loanRequest)),
      bottomNavigationBar: ActionBar(child: PrimaryButton(
          label: q == null ? l.loanSeeTerms : l.loanSend, busy: _busy,
          onPressed: q == null ? _check : ready ? _send : null)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Notice(l.loanIntro),
        if (_error != null) ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(_error!, tone: NoticeTone.critical),
        ],
        TextField(key: const ValueKey('loan-amount'), controller: _amount,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() => _quote = null),
            decoration: InputDecoration(labelText: l.loanAmountLabel)),
        TextField(key: const ValueKey('loan-term'), controller: _term,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() => _quote = null),
            decoration: InputDecoration(labelText: l.loanTermLabel)),
        if (q != null) ...[
          const SizedBox(height: JiraniSpace.m),
          Text(l.loanLimit(_kes(q.limitCents), _kes(q.savingsCents)), style: text.bodyMedium),
          Text(l.loanTerms(q.ratePct, q.flat ? l.loanFlat : l.loanReducing),
              style: text.bodySmall),
          for (final r in q.reasons)
            Padding(padding: const EdgeInsets.only(top: JiraniSpace.xs),
                child: Notice(l.loanReason(r.rule, loanReasonText(l, r.code)),
                    tone: NoticeTone.critical)),
          if (q.schedule.isNotEmpty) ...[
            const SizedBox(height: JiraniSpace.s),
            _scheduleTable(context, l, q.schedule),
            Text(l.loanTotals(_kes(q.totalInterestCents), _kes(q.totalCents)),
                style: text.titleSmall),
          ],
          if (q.eligible) ...[
            const SizedBox(height: JiraniSpace.m),
            TextField(key: const ValueKey('loan-purpose'), controller: _purpose,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l.loanPurposeLabel)),
            if (needed > 0) ...[
              const SizedBox(height: JiraniSpace.s),
              Text(l.loanPickGuarantors(needed, _kes(q.shareCents)), style: text.titleSmall),
              for (final m in _members.where((m) => m.memberCode != me))
                CheckboxListTile(
                  key: ValueKey('guarantor-${m.memberCode}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.name),
                  value: _guarantors.contains(m.id),
                  onChanged: !_guarantors.contains(m.id) && _guarantors.length >= needed
                      ? null
                      : (v) => setState(() =>
                          v == true ? _guarantors.add(m.id) : _guarantors.remove(m.id)),
                ),
            ],
          ],
        ],
      ]),
    );
  }
}

final _myMemberCode = FutureProvider.autoDispose.family<String?, String>((ref, id) async =>
    (await ref.watch(chamaRepositoryProvider).get(id)).json['my_member_code'] as String?);

class LoanScreen extends ConsumerStatefulWidget {
  const LoanScreen({super.key, required this.chamaId, required this.loanId});

  final String chamaId;
  final String loanId;

  @override
  ConsumerState<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends ConsumerState<LoanScreen> {
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
      ref.invalidate(loansProvider(widget.chamaId));
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(LoanGuarantee g) async {
    final repo = ref.read(chamaRepositoryProvider);
    await _run(() async {
      final sent = await repo.startGuarantee(g.id);
      if (!mounted) return;
      await confirmWithSmsCode(context, sent: sent, onCode: (code) =>
          repo.acceptGuarantee(g.id, challengeId: sent.challengeId, code: code));
    });
  }

  Future<void> _replace(LoanInfo loan, LoanGuarantee g) async {
    final l = AppLocalizations.of(context);
    final members = await ref.read(chamaRepositoryProvider).members(widget.chamaId);
    if (!mounted) return;
    final taken = {loan.borrowerId, for (final x in loan.guarantees) x.guarantorId};
    final pick = await showModalBottomSheet<Member>(context: context, builder: (c) => ListView(
      children: [
        ListTile(title: Text(l.loanPickReplacement)),
        for (final m in members.where((m) => !taken.contains(m.id)))
          ListTile(title: Text(m.name), onTap: () => Navigator.pop(c, m)),
      ],
    ));
    if (pick == null) return;
    await _run(() => ref.read(chamaRepositoryProvider)
        .replaceGuarantor(loan.id, guaranteeId: g.id, membershipId: pick.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final list = ref.watch(loansProvider(widget.chamaId));
    final loan = list.value?.where((x) => x.id == widget.loanId).firstOrNull;
    if (loan == null) {
      return Scaffold(appBar: AppBar(), body: list.hasError
          ? Padding(padding: const EdgeInsets.all(JiraniSpace.m),
              child: Notice(problemText(l, list.error!), tone: NoticeTone.critical))
          : const Center(child: CircularProgressIndicator()));
    }
    final repo = ref.read(chamaRepositoryProvider);
    final b = loan.balance;
    return Scaffold(
      appBar: AppBar(title: Text('${loan.borrower} · ${_kes(loan.amountCents)}')),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Text(loan.purpose, style: text.titleMedium),
        const SizedBox(height: JiraniSpace.s),
        Notice(loan.stateReason.isEmpty ? loanStateLabel(l, loan.state)
            : '${loanStateLabel(l, loan.state)}: ${loan.stateReason}',
            tone: loan.state == 'in_arrears' || loan.state == 'defaulted'
                ? NoticeTone.warning : NoticeTone.info),
        if (_error != null) ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(_error!, tone: NoticeTone.critical),
        ],
        if (b.principalCents > 0) ...[
          const SizedBox(height: JiraniSpace.s),
          Text(l.loanBalance(_kes(b.outstandingCents), _kes(b.repaidCents),
              _kes(b.interestChargedCents)), style: text.bodyMedium),
          if (b.dueNowCents > 0)
            Text(l.loanDueNow(_kes(b.dueNowCents)), style: text.titleSmall),
        ],
        const SizedBox(height: JiraniSpace.m),
        Text(l.loanGuarantors, style: text.titleSmall),
        for (final g in loan.guarantees)
          ListTile(
            key: ValueKey('guarantee-${g.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text('${g.guarantor} · ${_kes(g.shareCents)}'),
            subtitle: Text(guaranteeStateLabel(l, g.state)),
            // Replace only while a place is open: fewer guarantors asked or accepted than
            // the rules need.
            trailing: loan.mine && loan.state == 'awaiting_guarantors'
                && (g.state == 'declined' || g.state == 'expired')
                && loan.guarantees.where((x) => x.state == 'requested'
                    || x.state == 'accepted').length < loan.guarantorsNeeded
                ? TextButton(
                    key: ValueKey('replace-${g.id}'),onPressed: _busy ? null : () => _replace(loan, g),
                    child: Text(l.loanReplace))
                : null,
          ),
        for (final g in loan.guarantees.where((g) => g.mine && g.state == 'requested'))
          Padding(
            padding: const EdgeInsets.only(top: JiraniSpace.s),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Notice(l.guaranteeExplain(loan.borrower, _kes(loan.amountCents),
                  _kes(g.shareCents))),
              FilledButton(key: const ValueKey('guarantee-accept'),
                  onPressed: _busy ? null : () => _accept(g),
                  child: Text(l.guaranteeAccept)),
              TextButton(key: const ValueKey('guarantee-decline'),
                  onPressed: _busy ? null : () => _run(() => repo.declineGuarantee(g.id)),
                  child: Text(l.guaranteeDecline)),
            ]),
          ),
        if (loan.mine && loan.state == 'awaiting_guarantors')
          TextButton(key: const ValueKey('loan-cancel'),
              onPressed: _busy ? null : () => _run(() => repo.cancelLoan(loan.id)),
              child: Text(l.loanCancel)),
        const SizedBox(height: JiraniSpace.m),
        Text(l.loanSchedule, style: text.titleSmall),
        _scheduleTable(context, l, loan.schedule),
      ]),
    );
  }
}
