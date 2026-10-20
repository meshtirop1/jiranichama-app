import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/labels.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'support_screen.dart';
import 'widgets/sms_code_sheet.dart';

final disputesProvider = FutureProvider.autoDispose.family<List<DisputeInfo>, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).disputes(id);
});
final electionsProvider = FutureProvider.autoDispose.family<ElectionsInfo, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).elections(id);
});
final newPhonesProvider = FutureProvider.autoDispose.family<List<WaitingPhone>, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).newPhones(id);
});
final exitsProvider = FutureProvider.autoDispose.family<List<ExitInfo>, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).exits(id);
});
final _membersProvider = FutureProvider.autoDispose.family<List<Member>, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).members(id);
});

String _kes(int cents) => Kes(cents).format();

String disputeStateLabel(AppLocalizations l, String s) => switch (s) {
      'awaiting_response' => l.dspAwaiting,
      'deciding' => l.dspDeciding,
      'resolved' => l.dspResolved,
      'withdrawn' => l.dspWithdrawn,
      _ => l.dspEscalated,
    };

String outcomeLabel(AppLocalizations l, String o) => switch (o) {
      'no_change' => l.outNoChange,
      'reversal' => l.outReversal,
      'correction' => l.outCorrection,
      _ => l.outRefund,
    };

String electionStateLabel(AppLocalizations l, String s) => switch (s) {
      'voting' => l.elVoting,
      'won' => l.elWon,
      'in_office' => l.elInOffice,
      'acting' => l.elActing,
      'lost' => l.elLost,
      _ => l.elCancelled,
    };

Future<String?> _ask(BuildContext context, String title, {String? label}) =>
    showDialog<String>(context: context, builder: (_) => _AskText(title: title, label: label));

class _AskText extends StatefulWidget {
  const _AskText({required this.title, this.label});

  final String title;
  final String? label;

  @override
  State<_AskText> createState() => _AskTextState();
}

class _AskTextState extends State<_AskText> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(key: const ValueKey('gov-text'), controller: _c, autofocus: true,
            maxLines: 3, decoration: InputDecoration(labelText: widget.label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          FilledButton(key: const ValueKey('gov-ok'),
              onPressed: () => Navigator.pop(context, _c.text.trim()),
              child: Text(MaterialLocalizations.of(context).okButtonLabel)),
        ],
      );
}

/// On the overview: everything about running the chama, with what needs me first.
class GovernanceCard extends ConsumerWidget {
  const GovernanceCard({super.key, required this.chama});

  final Chama chama;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final disputes = ref.watch(disputesProvider(chama.id)).value ?? const <DisputeInfo>[];
    final elections = ref.watch(electionsProvider(chama.id)).value;
    final phones = chama.iAmOfficial
        ? ref.watch(newPhonesProvider(chama.id)).value ?? const <WaitingPhone>[]
        : const <WaitingPhone>[];
    final notes = [
      if (elections != null && elections.electionNeeded) l.govElectionNeeded,
      if (phones.isNotEmpty) l.govPhonesWaiting(phones.length),
      if (disputes.any((d) => d.iCanDecide || (d.iAmInvolved && d.state == 'awaiting_response')))
        l.govDisputesForMe,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: JiraniSpace.s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SupportNotice(chamaId: chama.id),
        for (final n in notes)
          Padding(padding: const EdgeInsets.only(bottom: JiraniSpace.xs),
              child: Notice(n, tone: NoticeTone.warning)),
        NavTile(
          key: const ValueKey('governance-card'),
          icon: Icons.how_to_vote_outlined,
          tone: JiraniTone.info,
          margin: EdgeInsets.zero,
          title: l.govTitle,
          subtitle: l.govSubtitle(disputes.where((d) => d.open).length),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GovernanceScreen(chama: chama))),
        ),
      ]),
    );
  }
}

class GovernanceScreen extends ConsumerStatefulWidget {
  const GovernanceScreen({super.key, required this.chama});

  final Chama chama;

  @override
  ConsumerState<GovernanceScreen> createState() => _GovernanceScreenState();
}

class _GovernanceScreenState extends ConsumerState<GovernanceScreen> {
  String? _error;
  bool _busy = false;

  String get _id => widget.chama.id;

  void _refresh() {
    ref.invalidate(disputesProvider(_id));
    ref.invalidate(electionsProvider(_id));
    ref.invalidate(newPhonesProvider(_id));
    ref.invalidate(exitsProvider(_id));
  }

  Future<void> _run(Future<void> Function() action) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _vouch(WaitingPhone p) async {
    final repo = ref.read(chamaRepositoryProvider);
    await _run(() async {
      final sent = await repo.startVouch(p.id, _id);
      if (!mounted) return;
      await confirmWithSmsCode(context, sent: sent, onCode: (code) =>
          repo.vouch(p.id, _id, challengeId: sent.challengeId, code: code));
    });
  }

  Future<void> _leave() async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(chamaRepositoryProvider);
    final q = await repo.exitQuote(_id);
    if (!mounted) return;
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(l.exitLeave),
      content: Text(l.exitQuoteText(_kes(q.savingsCents), _kes(q.finesCents),
          _kes(q.loanCents), _kes(q.deductionCents), _kes(q.settlementCents), q.noticeDays)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false),
            child: Text(MaterialLocalizations.of(c).cancelButtonLabel)),
        FilledButton(key: const ValueKey('exit-confirm'),
            onPressed: () => Navigator.pop(c, true), child: Text(l.exitLeaveConfirm)),
      ],
    ));
    if (ok != true || !mounted) return;
    await _run(() async {
      final sent = await repo.startLeave(_id);
      if (!mounted) return;
      await confirmWithSmsCode(context, sent: sent, onCode: (code) =>
          repo.leave(_id, challengeId: sent.challengeId, code: code));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final official = widget.chama.iAmOfficial;
    final disputes = ref.watch(disputesProvider(_id)).value ?? const <DisputeInfo>[];
    final elections = ref.watch(electionsProvider(_id)).value;
    final phones = official
        ? ref.watch(newPhonesProvider(_id)).value ?? const <WaitingPhone>[]
        : const <WaitingPhone>[];
    final exits = ref.watch(exitsProvider(_id)).value ?? const <ExitInfo>[];
    final myExit = exits.where((e) => e.mine && e.state == 'notice').firstOrNull;
    final repo = ref.read(chamaRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.govTitle)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        SupportNotice(chamaId: _id),
        if (_error != null) ...[
          Notice(_error!, tone: NoticeTone.critical),
          const SizedBox(height: JiraniSpace.s),
        ],
        if (elections != null && elections.electionNeeded) ...[
          Notice(l.govElectionNeeded, tone: NoticeTone.warning),
          const SizedBox(height: JiraniSpace.s),
        ],
        // New phones
        for (final p in phones)
          TitledCard(
            key: ValueKey('phone-${p.id}'),
            title: l.govPhoneOf(p.owner),
            subtitle: l.govPhoneCheck,
            icon: Icons.phonelink_lock_rounded,
            tone: JiraniTone.warning,
            children: [
              FilledButton(onPressed: _busy ? null : () => _vouch(p),
                  child: Text(l.govVouch)),
            ],
          ),
        // Disputes
        TitledCard(
          title: l.dspTitle,
          icon: Icons.report_problem_outlined,
          tone: JiraniTone.critical,
          children: [
            for (final d in disputes)
              ListTile(
                key: ValueKey('dispute-${d.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(d.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${d.raisedBy} · ${disputeStateLabel(l, d.state)}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DisputeScreen(chamaId: _id, disputeId: d.id))),
              ),
            if (disputes.isNotEmpty) const SizedBox(height: JiraniSpace.s),
            OutlinedButton.icon(
              key: const ValueKey('raise-dispute'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.dspRaise),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RaiseDisputeScreen(chamaId: _id))),
            ),
          ],
        ),
        // Elections
        TitledCard(
          title: l.elTitle,
          icon: Icons.how_to_vote_outlined,
          tone: JiraniTone.info,
          children: [
        for (final e in elections?.elections ?? const <ElectionInfo>[])
          ListTile(
            key: ValueKey('election-${e.id}'),
            contentPadding: EdgeInsets.zero,
            leading: Avatar(e.candidate, size: 38),
            title: Text('${e.candidate} · ${roleLabel(l, e.role)}'),
            subtitle: Text([
              electionStateLabel(l, e.state),
              if (e.state == 'won' && !e.candidateReady) l.elWaitingKey,
              if (e.mandateNeeded && e.mandateConfirmedAt == null) l.elMandateNeeded,
            ].join(' · ')),
            trailing: official && e.mandateNeeded && e.mandateConfirmedAt == null
                ? TextButton(key: ValueKey('mandate-${e.id}'),
                    onPressed: _busy ? null : () => _run(() => repo.confirmMandate(e.id)),
                    child: Text(l.elMandateDone))
                : null,
          ),
        if (official) ...[
          if ((elections?.elections ?? const []).isNotEmpty)
            const SizedBox(height: JiraniSpace.s),
          OutlinedButton.icon(
            key: const ValueKey('hold-election'),
            icon: const Icon(Icons.add_rounded),
            label: Text(l.elHold),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ElectionScreen(chamaId: _id))),
          ),
        ],
          ],
        ),
        // Leaving and deaths
        TitledCard(
          title: l.exitTitle,
          icon: Icons.logout_rounded,
          tone: JiraniTone.neutral,
          children: [
            for (final e in exits)
              ListTile(
                key: ValueKey('exit-${e.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Avatar(e.member, size: 38),
                title: Text(e.kind == 'death' ? l.exitDied(e.member)
                    : l.exitLeaving(e.member)),
                subtitle: Text(l.exitLine(e.exitOn, _kes(e.settlementCents), e.state)),
              ),
            if (myExit != null)
              OutlinedButton(key: const ValueKey('exit-stay'),
                  onPressed: _busy ? null : () => _run(() => repo.cancelExit(myExit.id)),
                  child: Text(l.exitStay))
            else if (!official && !exits.any((e) => e.mine))
              OutlinedButton(key: const ValueKey('exit-leave'),
                  onPressed: _busy ? null : _leave, child: Text(l.exitLeave)),
            if (official)
              TextButton.icon(
                key: const ValueKey('record-death'),
                icon: const Icon(Icons.local_florist_outlined),
                label: Text(l.deathRecord),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DeathScreen(chamaId: _id))),
              ),
          ],
        ),
        if (official)
          NavTile(
            key: const ValueKey('get-help'),
            icon: Icons.support_agent_outlined,
            tone: JiraniTone.info,
            title: l.supportTitle,
            subtitle: l.supportGetHelp,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SupportScreen(chama: widget.chama))),
          ),
      ]),
    );
  }
}

class RaiseDisputeScreen extends ConsumerStatefulWidget {
  const RaiseDisputeScreen({super.key, required this.chamaId, this.subjectType = 'other',
      this.subjectId});

  final String chamaId;
  final String subjectType;
  final String? subjectId;

  @override
  ConsumerState<RaiseDisputeScreen> createState() => _RaiseDisputeScreenState();
}

class _RaiseDisputeScreenState extends ConsumerState<RaiseDisputeScreen> {
  final _text = TextEditingController();
  String _reason = 'wrong_amount';
  bool _private = false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await ref.read(chamaRepositoryProvider).raiseDispute(widget.chamaId, {
        'subject_type': widget.subjectType, 'subject_id': widget.subjectId,
        'reason': _reason, 'text': _text.text.trim(), 'officials_only': _private,
      });
      ref.invalidate(disputesProvider(widget.chamaId));
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => DisputeScreen(chamaId: widget.chamaId, disputeId: d.id)));
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
    final reasons = {
      'wrong_amount': l.rsnWrongAmount, 'not_mine': l.rsnNotMine,
      'wrong_rule': l.rsnWrongRule, 'not_approved': l.rsnNotApproved, 'other': l.rsnOther,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.dspRaise)),
      bottomNavigationBar: ActionBar(
          child: PrimaryButton(label: l.dspSend, busy: _busy, onPressed: _send)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Notice(l.dspIntro),
        if (_error != null) ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(_error!, tone: NoticeTone.critical),
        ],
        SectionHeader(l.dspWhatsWrong),
        RadioGroup<String>(
          groupValue: _reason,
          onChanged: (v) => setState(() => _reason = v ?? _reason),
          child: Column(children: [
            for (final e in reasons.entries)
              RadioListTile(key: ValueKey('reason-${e.key}'), value: e.key,
                  contentPadding: EdgeInsets.zero, title: Text(e.value)),
          ]),
        ),
        const SizedBox(height: JiraniSpace.s),
        TextField(key: const ValueKey('dispute-text'), controller: _text, maxLines: 4,
            decoration: InputDecoration(labelText: l.dspWhatsWrong)),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: _private,
            onChanged: (v) => setState(() => _private = v), title: Text(l.dspPrivate)),
      ]),
    );
  }
}

class DisputeScreen extends ConsumerStatefulWidget {
  const DisputeScreen({super.key, required this.chamaId, required this.disputeId});

  final String chamaId;
  final String disputeId;

  @override
  ConsumerState<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends ConsumerState<DisputeScreen> {
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
      ref.invalidate(disputesProvider(widget.chamaId));
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _propose(DisputeInfo d) async {
    final members = await ref.read(_membersProvider(widget.chamaId).future);
    if (!mounted) return;
    final body = await Navigator.of(context).push<Json>(MaterialPageRoute(
        builder: (_) => _OutcomeForm(members: members)));
    if (body == null) return;
    await _run(() => ref.read(chamaRepositoryProvider).proposeOutcome(d.id, body));
  }

  Future<void> _agree(DisputeInfo d) async {
    final repo = ref.read(chamaRepositoryProvider);
    await _run(() async {
      final sent = await repo.startAgreeDispute(d.id);
      if (!mounted) return;
      await confirmWithSmsCode(context, sent: sent, onCode: (code) =>
          repo.agreeDispute(d.id, challengeId: sent.challengeId, code: code));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final list = ref.watch(disputesProvider(widget.chamaId));
    final d = list.value?.where((x) => x.id == widget.disputeId).firstOrNull;
    if (d == null) {
      return Scaffold(appBar: AppBar(), body: list.hasError
          ? Padding(padding: const EdgeInsets.all(JiraniSpace.m),
              child: Notice(problemText(l, list.error!), tone: NoticeTone.critical))
          : const Center(child: CircularProgressIndicator()));
    }
    final repo = ref.read(chamaRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.dspOne)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Text(d.text, style: text.titleMedium),
        Text(l.dspBy(d.raisedBy, d.involved.join(', ')), style: text.bodySmall),
        const SizedBox(height: JiraniSpace.s),
        Notice(disputeStateLabel(l, d.state)),
        if (_error != null) Notice(_error!, tone: NoticeTone.critical),
        if (d.outcome.isNotEmpty) ...[
          const SizedBox(height: JiraniSpace.s),
          Text(l.dspOutcome(outcomeLabel(l, d.outcome), d.outcomeText,
              d.agreed, d.officialsNeeded), style: text.bodyMedium),
          if (d.receipt != null) Text(l.dspReceipt(d.receipt!), style: text.bodySmall),
        ],
        const SizedBox(height: JiraniSpace.m),
        for (final m in d.messages)
          ListTile(dense: true, contentPadding: EdgeInsets.zero,
              title: Text(m.text.isEmpty ? m.kind : m.text), subtitle: Text(m.by)),
        if (d.open) ...[
          OutlinedButton(key: const ValueKey('dispute-respond'),
              onPressed: _busy ? null : () async {
                final t = await _ask(context, l.dspRespond);
                if (t == null || t.isEmpty) return;
                await _run(() => repo.respondDispute(d.id, t));
              },
              child: Text(l.dspRespond)),
          if (d.iCanDecide && d.state == 'awaiting_response')
            FilledButton(key: const ValueKey('dispute-propose'),
                onPressed: _busy ? null : () => _propose(d), child: Text(l.dspPropose)),
          if (d.iCanDecide && d.state == 'deciding' && d.decidedBy == 'officials') ...[
            FilledButton(key: const ValueKey('dispute-agree'),
                onPressed: _busy ? null : () => _agree(d), child: Text(l.dspAgree)),
            TextButton(key: const ValueKey('dispute-disagree'),
                onPressed: _busy ? null : () async {
                  final t = await _ask(context, l.dspDisagree);
                  if (t == null) return;
                  await _run(() => repo.disagreeDispute(d.id, t));
                },
                child: Text(l.dspDisagree)),
          ],
          if (d.mine)
            TextButton(key: const ValueKey('dispute-withdraw'),
                onPressed: _busy ? null : () => _run(() => repo.withdrawDispute(d.id)),
                child: Text(l.dspWithdraw)),
          if (d.mine || d.iCanDecide)
            TextButton(key: const ValueKey('dispute-escalate'),
                onPressed: _busy ? null : () async {
                  final t = await _ask(context, l.dspEscalate, label: l.dspWhere);
                  if (t == null || t.isEmpty) return;
                  await _run(() => repo.escalateDispute(d.id, t));
                },
                child: Text(l.dspEscalate)),
        ],
      ]),
    );
  }
}

class _OutcomeForm extends StatefulWidget {
  const _OutcomeForm({required this.members});

  final List<Member> members;

  @override
  State<_OutcomeForm> createState() => _OutcomeFormState();
}

class _OutcomeFormState extends State<_OutcomeForm> {
  final _text = TextEditingController();
  final _amount = TextEditingController();
  String _outcome = 'no_change';
  String? _member;

  @override
  void dispose() {
    _text.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final money = _outcome == 'correction' || _outcome == 'refund';
    return Scaffold(
      appBar: AppBar(title: Text(l.dspPropose)),
      bottomNavigationBar: ActionBar(child: PrimaryButton(
        label: l.dspPropose,
        onPressed: () => Navigator.of(context).pop(<String, Object?>{
          'outcome': _outcome, 'text': _text.text.trim(),
          if (money) 'member_id': _member,
          if (money) 'amount_cents':
              Kes.shillings(int.tryParse(_amount.text.trim()) ?? 0).cents,
        }),
      )),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        RadioGroup<String>(
          groupValue: _outcome,
          onChanged: (v) => setState(() => _outcome = v ?? _outcome),
          child: Column(children: [
            for (final o in const ['no_change', 'reversal', 'correction', 'refund'])
              RadioListTile(key: ValueKey('outcome-$o'), value: o,
                  contentPadding: EdgeInsets.zero, title: Text(outcomeLabel(l, o))),
          ]),
        ),
        TextField(key: const ValueKey('outcome-text'), controller: _text, maxLines: 3,
            decoration: InputDecoration(labelText: l.dspWhy)),
        if (money) ...[
          DropdownButtonFormField<String>(
            initialValue: _member,
            decoration: InputDecoration(labelText: l.dspMember),
            items: [for (final m in widget.members)
              DropdownMenuItem(value: m.id, child: Text(m.name))],
            onChanged: (v) => setState(() => _member = v),
          ),
          TextField(controller: _amount, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.dspAmount)),
        ],
      ]),
    );
  }
}

class ElectionScreen extends ConsumerStatefulWidget {
  const ElectionScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<ElectionScreen> createState() => _ElectionScreenState();
}

class _ElectionScreenState extends ConsumerState<ElectionScreen> {
  String _role = 'treasurer';
  String? _candidate;
  bool _acting = false;
  String? _error;
  bool _busy = false;

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(chamaRepositoryProvider).nominate(widget.chamaId,
          role: _role, candidateId: _candidate ?? '', acting: _acting);
      ref.invalidate(electionsProvider(widget.chamaId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final members = ref.watch(_membersProvider(widget.chamaId)).value ?? const <Member>[];
    return Scaffold(
      appBar: AppBar(title: Text(l.elHold)),
      bottomNavigationBar: ActionBar(child: PrimaryButton(
          label: l.elStart, busy: _busy, onPressed: _candidate == null ? null : _send)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Notice(l.elIntro),
        if (_error != null) Notice(_error!, tone: NoticeTone.critical),
        SegmentedButton<String>(
          key: const ValueKey('election-role'),
          segments: [
            for (final r in const ['chair', 'treasurer', 'secretary'])
              ButtonSegment(value: r, label: Text(roleLabel(l, r))),
          ],
          selected: {_role},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _role = s.first),
        ),
        RadioGroup<String>(
          groupValue: _candidate,
          onChanged: (v) => setState(() => _candidate = v),
          child: Column(children: [
            for (final m in members.where((m) => m.role == 'member'))
              RadioListTile(key: ValueKey('candidate-${m.memberCode}'), value: m.id,
                  contentPadding: EdgeInsets.zero, title: Text(m.name)),
          ]),
        ),
        SwitchListTile(key: const ValueKey('election-acting'), contentPadding: EdgeInsets.zero,
            value: _acting, onChanged: (v) => setState(() => _acting = v),
            title: Text(l.elActingSwitch)),
      ]),
    );
  }
}

class DeathScreen extends ConsumerStatefulWidget {
  const DeathScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<DeathScreen> createState() => _DeathScreenState();
}

class _DeathScreenState extends ConsumerState<DeathScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _member;
  PickedFile? _document;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(chamaRepositoryProvider).recordDeath(_member ?? '',
          diedOn: DateTime.now().toIso8601String().substring(0, 10),
          nextOfKinName: _name.text.trim(), nextOfKinPhone: _phone.text.trim(),
          document: _document);
      ref.invalidate(exitsProvider(widget.chamaId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final members = ref.watch(_membersProvider(widget.chamaId)).value ?? const <Member>[];
    return Scaffold(
      appBar: AppBar(title: Text(l.deathRecord)),
      bottomNavigationBar: ActionBar(child: PrimaryButton(
          label: l.deathSave, busy: _busy,
          onPressed: _member == null || _document == null ? null : _send)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Notice(l.deathIntro),
        if (_error != null) Notice(_error!, tone: NoticeTone.critical),
        DropdownButtonFormField<String>(
          key: const ValueKey('death-member'),
          initialValue: _member,
          decoration: InputDecoration(labelText: l.dspMember),
          items: [for (final m in members)
            DropdownMenuItem(value: m.id, child: Text(m.name))],
          onChanged: (v) => setState(() => _member = v),
        ),
        TextField(key: const ValueKey('death-nok'), controller: _name,
            decoration: InputDecoration(labelText: l.deathNokName)),
        TextField(key: const ValueKey('death-nok-phone'), controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l.deathNokPhone)),
        const SizedBox(height: JiraniSpace.s),
        OutlinedButton.icon(
          key: const ValueKey('death-document'),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(_document?.name ?? l.deathDocument),
          onPressed: () async {
            final p = await ref.read(fileSourceProvider).pickPhoto();
            if (p != null) setState(() => _document = p);
          },
        ),
      ]),
    );
  }
}
