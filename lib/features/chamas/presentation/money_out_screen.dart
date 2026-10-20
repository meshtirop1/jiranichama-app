import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_secure_keys/jirani_secure_keys.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/problem.dart';
import '../../../core/labels.dart';
import '../../../core/providers.dart';
import '../../../core/tours.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'chama_screen.dart';
import 'vote_screen.dart';
import 'widgets/sms_code_sheet.dart';

final moneyOutProvider = FutureProvider.autoDispose.family<MoneyOutStatus, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).moneyOut(id);
});
final proposalsProvider = FutureProvider.autoDispose.family<List<Proposal>, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).proposals(id);
});
final unapprovedProvider = FutureProvider.autoDispose.family<List<UnapprovedDebit>, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).unapprovedDebits(id);
});

String proposalStateLabel(AppLocalizations l, String state) => switch (state) {
      'collecting_approvals' => l.stCollecting,
      'approved' => l.stApproved,
      'paid_pending_match' => l.stPaidPending,
      'paid' => l.stPaid,
      'refused' => l.stRefused,
      'rejected' => l.stRejected,
      'expired' => l.stExpired,
      _ => l.stCancelled,
    };

String refusalText(AppLocalizations l, Proposal p) {
  final why = switch (p.refusalCode) {
    'payee_in_arrears' => l.refusalArrears,
    'not_enough_money' => l.refusalMoney,
    'no_reconciled_balance' => l.refusalNoBalance,
    _ => l.refusalVote,
  };
  return l.refusedByRule(p.refusalRule ?? '', why);
}

/// Money out (5.6, 5.7): switch it on, propose payments, approve them, and see any money
/// that left the bank without approval. Every member sees all of it; officials act.
class MoneyOutScreen extends ConsumerStatefulWidget {
  const MoneyOutScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<MoneyOutScreen> createState() => _MoneyOutScreenState();
}

class _MoneyOutScreenState extends ConsumerState<MoneyOutScreen> {
  String? _error;
  bool _busy = false;
  final _statusKey = GlobalKey();
  final _phoneKeyCard = GlobalKey();

  List<TourStep> _steps() {
    final l = AppLocalizations.of(context);
    return [
      TourStep(target: _statusKey, icon: Icons.verified_user_outlined,
          title: l.tourMoneyOutTitle, body: l.tourMoneyOutBody),
      TourStep(target: _phoneKeyCard, icon: Icons.fingerprint_rounded, tone: JiraniTone.info,
          title: l.tourFingerprintTitle, body: l.tourFingerprintBody),
    ];
  }

  void _refresh() {
    ref.invalidate(moneyOutProvider(widget.chamaId));
    ref.invalidate(proposalsProvider(widget.chamaId));
    ref.invalidate(unapprovedProvider(widget.chamaId));
  }

  Future<void> _switchOn() async {
    final repo = ref.read(chamaRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    ChallengeSent? sent;
    try {
      sent = await repo.startEnableMoneyOut(widget.chamaId);
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final challenge = sent;
    if (challenge == null || !mounted) return;
    final ok = await confirmWithSmsCode(context, sent: challenge, onCode: (code) async {
      await repo.enableMoneyOut(widget.chamaId, challengeId: challenge.challengeId, code: code);
    });
    if (ok) _refresh();
  }

  Future<void> _propose(ChamaBundle bundle) async {
    final done = await showModalBottomSheet<bool>(
        context: context, isScrollControlled: true,
        builder: (_) => _ProposeSheet(bundle: bundle));
    if (done == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bundle = ref.watch(chamaBundleProvider(widget.chamaId)).value;
    final status = ref.watch(moneyOutProvider(widget.chamaId));
    final official = bundle?.chama.iAmOfficial ?? false;
    final on = status.value?.on ?? false;
    showTourOnce(context, ref, 'money-out', _steps);
    return Scaffold(
      appBar: AppBar(title: Text(l.moneyOut),
          actions: [TourButton(steps: _steps), const SizedBox(width: 4)]),
      bottomNavigationBar: official && on && bundle != null
          ? ActionBar(child: PrimaryButton(label: l.proposePayment, busy: _busy,
              onPressed: () => _propose(bundle)))
          : null,
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(JiraniSpace.m),
          children: [
            if (_error != null) ...[
              Notice(_error!, tone: NoticeTone.critical),
              const SizedBox(height: JiraniSpace.s),
            ],
            ...status.when(
              loading: () => [const Padding(padding: EdgeInsets.all(JiraniSpace.l), child: LoadingView())],
              error: (e, _) => [Notice(problemText(l, e), tone: NoticeTone.critical)],
              data: (s) => s.on
                  ? [
                      TitledCard(
                        key: _statusKey,
                        title: l.moneyOutOn,
                        icon: Icons.lock_open_rounded,
                        tone: JiraniTone.good,
                        children: [
                          Text(s.available == null
                              ? l.balanceUnknown
                              : l.availableToPromise(s.available!.format()),
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ]
                  : [
                      TitledCard(
                        key: _statusKey,
                        title: l.moneyOutOffTitle,
                        icon: Icons.lock_outline_rounded,
                        tone: JiraniTone.warning,
                        children: [
                          Text(l.moneyOutOffIntro,
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: JiraniSpace.m),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                                minHeight: 8,
                                value: s.needed == 0 ? 0 : s.consents / s.needed),
                          ),
                          const SizedBox(height: JiraniSpace.s),
                          Text(l.consentsSoFar('${s.consents}', '${s.needed}'),
                              style: Theme.of(context).textTheme.titleSmall),
                          if (official) ...[
                            const SizedBox(height: JiraniSpace.m),
                            FilledButton(onPressed: _busy ? null : _switchOn,
                                child: Text(l.switchOnMoneyOut)),
                          ],
                        ],
                      ),
                    ],
            ),
            if (official) _PhoneKeyCard(key: _phoneKeyCard),
            _Unapproved(chamaId: widget.chamaId, official: official),
            if (on) ...[
              SectionHeader(l.proposalsHeading),
              ...ref.watch(proposalsProvider(widget.chamaId)).when(
                    loading: () => [const Padding(padding: EdgeInsets.all(JiraniSpace.l), child: LoadingView())],
                    error: (e, _) => [Notice(problemText(l, e), tone: NoticeTone.critical)],
                    data: (items) => items.isEmpty
                        ? [SurfaceCard(child: EmptyState(icon: Icons.outbox_outlined,
                            title: l.noProposals))]
                        : [for (final p in items) _ProposalTile(p, onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ProposalScreen(chamaId: widget.chamaId,
                                    proposalId: p.id)));
                            _refresh();
                          })],
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProposalTile extends StatelessWidget {
  const _ProposalTile(this.p, {required this.onTap});

  final Proposal p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final waiting = p.canAnswer;
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Avatar(p.payeeName, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.payeeName} · ${p.purpose}', style: text.titleSmall),
            const SizedBox(height: 2),
            Text([
              proposalStateLabel(l, p.state),
              if (p.state == 'collecting_approvals') l.approvalsCount('${p.approved}',
                  '${p.needsOfficials}'),
            ].join(' · '), style: text.bodySmall),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          MoneyText(p.amount, style: text.titleSmall),
          if (waiting) ...[
            const SizedBox(height: 4),
            StatusPill(l.approveButton, tone: JiraniTone.warning,
                icon: Icons.how_to_vote_outlined),
          ],
        ]),
      ]),
    );
  }
}

class _Unapproved extends ConsumerWidget {
  const _Unapproved({required this.chamaId, required this.official});

  final String chamaId;
  final bool official;

  Future<void> _explain(BuildContext context, WidgetRef ref, UnapprovedDebit d) async {
    final l = AppLocalizations.of(context);
    final text = await _askText(context, l.explainButton, l.whyLabel);
    if (text == null || text.isEmpty) return;
    try {
      await ref.read(chamaRepositoryProvider).explainDebit(d.id, text);
      ref.invalidate(unapprovedProvider(chamaId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(problemText(l, e))));
      }
    }
  }

  Future<void> _link(BuildContext context, WidgetRef ref, UnapprovedDebit d) async {
    final l = AppLocalizations.of(context);
    final proposals = await ref.read(chamaRepositoryProvider).proposals(chamaId);
    final fits = proposals.where((p) =>
        (p.state == 'approved' || p.state == 'paid_pending_match') &&
        p.amount.cents == d.amount.cents).toList();
    if (!context.mounted) return;
    final chosen = await showDialog<Proposal>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.linkButton),
        children: [
          if (fits.isEmpty) Padding(padding: const EdgeInsets.all(JiraniSpace.m),
              child: Text(l.errNotLinkable)),
          for (final p in fits)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(p),
              child: Text('${p.payeeName} · ${p.purpose} · ${p.amount.format()}'),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    try {
      await ref.read(chamaRepositoryProvider).linkDebit(d.id, chosen.id);
      ref.invalidate(unapprovedProvider(chamaId));
      ref.invalidate(proposalsProvider(chamaId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(problemText(l, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = ref.watch(unapprovedProvider(chamaId)).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: JiraniSpace.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader(l.unapprovedHeading, padding: const EdgeInsets.only(left: 4)),
        for (final d in items)
          Padding(
            padding: const EdgeInsets.only(top: JiraniSpace.s),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Notice(l.unapprovedAlert(d.amount.format(), d.valueDate),
                  tone: d.open ? NoticeTone.critical : NoticeTone.warning),
              if (d.state == 'explained')
                Text(l.unapprovedExplained(d.resolvedBy ?? '', d.explanation)),
              if (d.state == 'linked') Text(l.unapprovedLinked(d.resolvedBy ?? '')),
              if (d.open && d.explanation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: JiraniSpace.xs),
                  child: Text(l.unapprovedVoting(d.explanation),
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              if (d.open && official)
                Wrap(spacing: JiraniSpace.s, children: [
                  if (d.explanation.isEmpty)
                    TextButton(onPressed: () => _explain(context, ref, d),
                        child: Text(l.explainButton)),
                  TextButton(onPressed: () => _link(context, ref, d),
                      child: Text(l.linkButton)),
                ]),
            ]),
          ),
      ]),
    );
  }
}

Future<String?> _askText(BuildContext context, String title, String label) =>
    showDialog<String>(context: context, builder: (_) => _TextDialog(title, label));

/// Asks for one line of text. Owns its controller, so it is disposed only once the
/// dialog has finished closing.
class _TextDialog extends StatefulWidget {
  const _TextDialog(this.title, this.label);

  final String title;
  final String label;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(key: const ValueKey('ask-text'), controller: _c, autofocus: true,
          maxLines: 3, decoration: InputDecoration(labelText: widget.label)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(_c.text.trim()),
            child: Text(widget.title)),
      ],
    );
  }
}

class _ProposeSheet extends ConsumerStatefulWidget {
  const _ProposeSheet({required this.bundle});

  final ChamaBundle bundle;

  @override
  ConsumerState<_ProposeSheet> createState() => _ProposeSheetState();
}

class _ProposeSheetState extends ConsumerState<_ProposeSheet> {
  final _amount = TextEditingController();
  final _purpose = TextEditingController();
  final _payee = TextEditingController();
  final _account = TextEditingController();
  final _key = newIdempotencyKey();
  bool _toMember = true;
  String? _memberId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_amount, _purpose, _payee, _account]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final shillings = int.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;
    if (shillings <= 0 || _purpose.text.trim().isEmpty ||
        (_toMember ? _memberId == null : _payee.text.trim().isEmpty)) {
      setState(() => _error = l.errFillIn);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(chamaRepositoryProvider).propose(widget.bundle.chama.id, {
        'kind': _toMember ? 'payout' : 'withdrawal',
        'amount_cents': Kes.shillings(shillings).cents,
        'purpose': _purpose.text.trim(),
        if (_toMember) 'payee_membership_id': _memberId else 'payee_name': _payee.text.trim(),
        'payee_account': _account.text.trim(),
      }, idempotencyKey: _key);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(left: JiraniSpace.m, right: JiraniSpace.m,
          top: JiraniSpace.m, bottom: MediaQuery.of(context).viewInsets.bottom + JiraniSpace.m),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.proposePayment, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: JiraniSpace.s),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(l.toAMember)),
              ButtonSegment(value: false, label: Text(l.toSomeoneElse)),
            ],
            selected: {_toMember},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _toMember = s.first),
          ),
          const SizedBox(height: JiraniSpace.s),
          if (_toMember)
            DropdownButtonFormField<String>(
              key: const ValueKey('payee-member'),
              initialValue: _memberId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.payeeLabel),
              items: [
                for (final m in widget.bundle.members)
                  DropdownMenuItem(value: m.id, child: Text('${m.name} (${m.memberCode})')),
              ],
              onChanged: (v) => setState(() => _memberId = v),
            )
          else
            TextField(key: const ValueKey('payee-name'), controller: _payee,
                decoration: InputDecoration(labelText: l.payeeLabel)),
          const SizedBox(height: JiraniSpace.s),
          TextField(key: const ValueKey('payee-account'), controller: _account,
              decoration: InputDecoration(labelText: l.payeeAccountLabel)),
          const SizedBox(height: JiraniSpace.s),
          TextField(key: const ValueKey('propose-amount'), controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.amountKesLabel)),
          const SizedBox(height: JiraniSpace.s),
          TextField(key: const ValueKey('propose-purpose'), controller: _purpose,
              decoration: InputDecoration(labelText: l.purposeLabel)),
          if (_error != null) ...[
            const SizedBox(height: JiraniSpace.s),
            Notice(_error!, tone: NoticeTone.critical),
          ],
          const SizedBox(height: JiraniSpace.m),
          PrimaryButton(label: l.proposeButton, busy: _busy, onPressed: _submit),
        ]),
      ),
    );
  }
}

/// One proposal: what is paid, the rules' answer, who approved or declined, and the
/// actions the person looking at it may take.
class ProposalScreen extends ConsumerStatefulWidget {
  const ProposalScreen({super.key, required this.chamaId, required this.proposalId});

  final String chamaId;
  final String proposalId;

  @override
  ConsumerState<ProposalScreen> createState() => _ProposalScreenState();
}

class _ProposalScreenState extends ConsumerState<ProposalScreen> {
  String? _error;
  bool _busy = false;

  Proposal? _find(List<Proposal>? items) =>
      items?.where((p) => p.id == widget.proposalId).firstOrNull;

  void _refresh() {
    ref.invalidate(proposalsProvider(widget.chamaId));
    ref.invalidate(moneyOutProvider(widget.chamaId));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve(Proposal p) async {
    final signer = ref.read(phoneSignerProvider);
    if (await signer.ready()) return _approveWithPhone(p, signer);
    final repo = ref.read(chamaRepositoryProvider);
    ChallengeSent? sent;
    await _run(() async => sent = await repo.startApprove(p.id));
    final challenge = sent;
    if (challenge == null || !mounted) return;
    final ok = await confirmWithSmsCode(context, sent: challenge, onCode: (code) async {
      await repo.approve(p.id, challengeId: challenge.challengeId, code: code);
    });
    if (ok) _refresh();
  }

  /// 6.7: the server sends the exact payload with a single-use nonce; we check it is the
  /// proposal on screen, then the phone signs it after the fingerprint, face or PIN.
  Future<void> _approveWithPhone(Proposal p, PhoneSigner signer) async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(chamaRepositoryProvider);
    await _run(() async {
      final body = await repo.signingPayload(p.id);
      if (body['device_id'] != await signer.deviceId()) {
        throw ApiProblem(code: 'other_phone', detail: '', status: 409);
      }
      final payload = Map<String, Object?>.from(body['payload'] as Map);
      final message = canonicalJson(payload);
      final shownIsSigned = sha256Hex(message) == body['payload_hash'] &&
          payload['proposal_id'] == p.id &&
          payload['amount_cents'] == p.amount.cents &&
          payload['payee'] == p.payeeName;
      if (!shownIsSigned) throw ApiProblem(code: 'payload_changed', detail: '', status: 409);
      final String signature;
      try {
        signature = await signer.sign(utf8.encode(message),
            title: l.approvePromptTitle(p.amount.format(), p.payeeName), subtitle: p.purpose);
      } on SecureKeysCancelled {
        return; // they backed out; nothing to say
      }
      await repo.submitSignature(p.id, {
        'device_id': body['device_id'], 'nonce': payload['nonce'],
        'payload_hash': body['payload_hash'], 'signature': signature,
      });
    });
  }

  Future<void> _decline(Proposal p) async {
    final l = AppLocalizations.of(context);
    final reason = await _askText(context, l.declineButton, l.whyLabel);
    if (reason == null || reason.isEmpty) return;
    await _run(() => ref.read(chamaRepositoryProvider).declineProposal(p.id, reason));
  }

  Future<void> _cancel(Proposal p) async {
    final l = AppLocalizations.of(context);
    final reason = await _askText(context, l.cancelProposal, l.whyLabel);
    if (reason == null) return;
    await _run(() => ref.read(chamaRepositoryProvider).cancelProposal(p.id, reason));
  }

  Future<void> _paid(Proposal p) async {
    final l = AppLocalizations.of(context);
    final ref_ = await _askText(context, l.markPaid, l.bankReferenceLabel);
    if (ref_ == null) return;
    await _run(() => ref.read(chamaRepositoryProvider)
        .markPaid(p.id, ref_, idempotencyKey: newIdempotencyKey()));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final bundle = ref.watch(chamaBundleProvider(widget.chamaId)).value;
    final p = _find(ref.watch(proposalsProvider(widget.chamaId)).value);
    if (p == null) {
      return Scaffold(appBar: AppBar(),
          body: const LoadingView());
    }
    final me = bundle?.me;
    final official = bundle?.chama.iAmOfficial ?? false;
    final iAmPayee = me != null && me.memberCode == p.payeeMemberCode;
    final mine = me != null && me.memberCode == p.proposedByCode;
    return Scaffold(
      appBar: AppBar(title: Text(proposalStateLabel(l, p.state))),
      bottomNavigationBar: p.canAnswer
          ? ActionBar(child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _decline(p),
                  child: Text(l.declineButton))),
              const SizedBox(width: JiraniSpace.s),
              Expanded(child: PrimaryButton(label: l.approveButton, busy: _busy,
                  onPressed: () => _approve(p))),
            ]))
          : null,
      body: ListView(
        padding: const EdgeInsets.all(JiraniSpace.m),
        children: [
          SurfaceCard(
            margin: const EdgeInsets.only(bottom: JiraniSpace.m),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(p.payeeName, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(p.payeeName +
                      (p.payeeAccount.isEmpty ? '' : ' · ${p.payeeAccount}'),
                      style: text.titleMedium),
                ),
              ]),
              const SizedBox(height: JiraniSpace.m),
              MoneyText(p.amount, style: text.displaySmall),
              const SizedBox(height: 4),
              Text(p.purpose, style: text.bodyLarge),
              const SizedBox(height: JiraniSpace.s),
              Text(l.proposedByLine(p.proposedBy), style: text.bodySmall),
            ]),
          ),
          if (_error != null) ...[
            Notice(_error!, tone: NoticeTone.critical),
            const SizedBox(height: JiraniSpace.s),
          ],
          if (p.state == 'refused')
            Notice(refusalText(l, p), tone: NoticeTone.warning)
          else if (p.stateReason.isNotEmpty)
            Notice(p.stateReason),
          if (p.state == 'collecting_approvals') ...[
            const SizedBox(height: JiraniSpace.s),
            Text(l.approvalsCount('${p.approved}', '${p.needsOfficials}'),
                style: text.titleSmall),
            const SizedBox(height: JiraniSpace.s),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(minHeight: 8,
                  value: p.needsOfficials == 0 ? 0 : p.approved / p.needsOfficials),
            ),
            if (iAmPayee) ...[
              const SizedBox(height: JiraniSpace.s),
              Notice(l.payeeNeverApproves),
            ],
          ],
          if (p.answers.isNotEmpty) const SizedBox(height: JiraniSpace.s),
          for (final a in p.answers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(a.approved
                  ? (a.byPhoneKey ? Icons.fingerprint : Icons.check_circle_outline)
                  : Icons.cancel_outlined,
                  color: a.approved ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error),
              title: Text(a.approved
                  ? (a.byPhoneKey
                      ? l.answeredApprovedPhone(a.name, roleLabel(l, a.role))
                      : l.answeredApproved(a.name, roleLabel(l, a.role)))
                  : l.answeredDeclined(a.name, roleLabel(l, a.role), a.reason)),
            ),
          if (p.needsVote && p.voteId != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.how_to_vote_outlined),
              title: Text(l.membersVote),
              subtitle: Text(voteStateLabel(l, p.voteState ?? 'open')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VoteScreen(chamaId: widget.chamaId, voteId: p.voteId!))),
            ),
          if (p.bankReference.isNotEmpty)
            Text('${l.bankReferenceLabel}: ${p.bankReference}', style: text.bodySmall),
          if (p.receipt != null) Text('${l.receiptLabel}: ${p.receipt}', style: text.bodySmall),
          const SizedBox(height: JiraniSpace.m),
          if (official && p.state == 'approved')
            FilledButton(onPressed: _busy ? null : () => _paid(p), child: Text(l.markPaid)),
          if (mine && (p.state == 'collecting_approvals' || p.state == 'approved'))
            TextButton(onPressed: _busy ? null : () => _cancel(p),
                child: Text(l.cancelProposal)),
        ],
      ),
    );
  }
}

/// For officials: set this phone up to approve with a fingerprint (6.7), once.
class _PhoneKeyCard extends ConsumerStatefulWidget {
  const _PhoneKeyCard({super.key});

  @override
  ConsumerState<_PhoneKeyCard> createState() => _PhoneKeyCardState();
}

class _PhoneKeyCardState extends ConsumerState<_PhoneKeyCard> {
  bool? _available;
  bool _ready = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final signer = ref.read(phoneSignerProvider);
    final available = await signer.available();
    final ready = available && await signer.ready();
    if (mounted) {
      setState(() {
        _available = available;
        _ready = ready;
      });
    }
  }

  Future<void> _setUp() async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(chamaRepositoryProvider);
    final signer = ref.read(phoneSignerProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    Json? body;
    ChallengeSent? sent;
    try {
      final nonce = await repo.attestNonce();
      final key = await signer.create(utf8.encode(nonce));
      body = {
        'public_key': key.publicKey, 'platform': 'android', 'label': 'Android phone',
        'attestation_chain': key.chain, 'attest_nonce': nonce,
      };
      sent = await repo.startRegisterDevice(body);
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final challenge = sent;
    final registered = body;
    if (challenge == null || registered == null || !mounted) return;
    final ok = await confirmWithSmsCode(context, sent: challenge, onCode: (code) async {
      final device = await repo.registerDevice(registered,
          challengeId: challenge.challengeId, code: code);
      await signer.remember(device['id'] as String);
    });
    if (ok) await _check();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_available != true) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: JiraniSpace.s),
      child: TitledCard(
        title: _ready ? l.phoneReady : l.fingerprintCardTitle,
        icon: Icons.fingerprint_rounded,
        tone: _ready ? JiraniTone.good : JiraniTone.info,
        margin: EdgeInsets.zero,
        children: [
          if (!_ready) ...[
            Text(l.fingerprintCardBody, style: Theme.of(context).textTheme.bodyMedium),
            if (_error != null) ...[
              const SizedBox(height: JiraniSpace.s),
              Notice(_error!, tone: NoticeTone.critical),
            ],
            const SizedBox(height: JiraniSpace.m),
            OutlinedButton.icon(onPressed: _busy ? null : _setUp,
                icon: const Icon(Icons.fingerprint_rounded),
                label: Text(l.setUpThisPhone)),
          ],
        ],
      ),
    );
  }
}
