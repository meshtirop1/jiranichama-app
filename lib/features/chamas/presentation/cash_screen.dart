import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'chama_screen.dart';
import 'widgets/sms_code_sheet.dart';

final cashProvider = FutureProvider.autoDispose.family<List<CashReceipt>, String>(
    (ref, chamaId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).cashReceipts(chamaId);
});

String cashStateLabel(AppLocalizations l, CashReceipt r) => switch (r.state) {
      'recorded' => l.cashRecorded,
      'member_confirmed' => r.overdue ? l.cashOverdue : l.cashConfirmed,
      'banked' => l.cashBanked,
      _ => l.cashDeclined,
    };

/// Cash at meetings (5.4). The treasurer records cash; the member confirms or declines
/// it with an SMS code; it counts once the deposit is linked from the unmatched queue.
class CashScreen extends ConsumerStatefulWidget {
  const CashScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends ConsumerState<CashScreen> {
  String? _error;
  bool _busy = false;

  void _refresh() {
    ref.invalidate(cashProvider(widget.chamaId));
    ref.invalidate(chamaBundleProvider(widget.chamaId));
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

  Future<void> _confirm(CashReceipt r) async {
    final repo = ref.read(chamaRepositoryProvider);
    ChallengeSent? sent;
    await _run(() async => sent = await repo.startConfirmCash(r.id));
    final challenge = sent;
    if (challenge == null || !mounted) return;
    final ok = await confirmWithSmsCode(context, sent: challenge, onCode: (code) async {
      await repo.confirmCash(r.id, challengeId: challenge.challengeId, code: code);
    });
    if (ok) _refresh();
  }

  Future<void> _record(ChamaBundle bundle) async {
    final done = await showDialog<bool>(
        context: context, builder: (_) => _RecordCashDialog(bundle: bundle));
    if (done == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bundle = ref.watch(chamaBundleProvider(widget.chamaId)).value;
    final receipts = ref.watch(cashProvider(widget.chamaId));
    final myId = bundle?.me?.id;
    return Scaffold(
      appBar: AppBar(title: Text(l.cashAtMeetings)),
      bottomNavigationBar: bundle != null && bundle.chama.iAmTreasurer
          ? ActionBar(child: PrimaryButton(label: l.recordCash, busy: _busy,
              onPressed: () => _record(bundle)))
          : null,
      body: receipts.when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (items) => ListView(
          padding: const EdgeInsets.all(JiraniSpace.m),
          children: [
            if (_error != null) ...[
              Notice(_error!, tone: NoticeTone.critical),
              const SizedBox(height: JiraniSpace.s),
            ],
            if (items.isEmpty)
              SurfaceCard(child: EmptyState(icon: Icons.payments_outlined,
                  title: l.cashNoneTitle, message: l.cashNoneBody)),
            for (final r in items)
              SurfaceCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Avatar(_name(bundle, r.memberCode), size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(_name(bundle, r.memberCode),
                              style: Theme.of(context).textTheme.titleSmall),
                          Text('${r.memberCode} · ${r.receivedOn}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                      ),
                      MoneyText(r.amount, style: Theme.of(context).textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(cashStateLabel(l, r), tone: switch (r.state) {
                        _ when r.overdue => JiraniTone.critical,
                        'banked' => JiraniTone.good,
                        'declined' => JiraniTone.critical,
                        _ => JiraniTone.warning,
                      }),
                    ),
                    if (r.state == 'recorded' && r.membershipId == myId) ...[
                      const SizedBox(height: JiraniSpace.s),
                      Row(children: [
                        Expanded(child: FilledButton(onPressed: _busy ? null : () => _confirm(r),
                            child: Text(l.confirmCash))),
                        const SizedBox(width: JiraniSpace.s),
                        Expanded(child: OutlinedButton(
                            onPressed: _busy ? null : () => _run(() async {
                                  await ref.read(chamaRepositoryProvider).declineCash(r.id);
                                }),
                            child: Text(l.declineCash))),
                      ]),
                    ],
                  ]),
              ),
          ],
        ),
      ),
    );
  }

  /// The member's name for a member code, or the code when the list is not loaded.
  String _name(ChamaBundle? bundle, String code) =>
      bundle?.members.where((m) => m.memberCode == code).firstOrNull?.name ?? code;
}

class _RecordCashDialog extends ConsumerStatefulWidget {
  const _RecordCashDialog({required this.bundle});

  final ChamaBundle bundle;

  @override
  ConsumerState<_RecordCashDialog> createState() => _RecordCashDialogState();
}

class _RecordCashDialogState extends ConsumerState<_RecordCashDialog> {
  final _amount = TextEditingController();
  final _key = newIdempotencyKey();
  String? _memberId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final shillings = int.tryParse(_amount.text.trim()) ?? 0;
    if (_memberId == null || shillings <= 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(chamaRepositoryProvider).recordCash(widget.bundle.chama.id,
          membershipId: _memberId!, amountCents: Kes.shillings(shillings).cents,
          idempotencyKey: _key);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.recordCash),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          initialValue: _memberId,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.memberLabel),
          items: [
            for (final m in widget.bundle.members)
              DropdownMenuItem(value: m.id, child: Text('${m.name} (${m.memberCode})')),
          ],
          onChanged: (v) => setState(() => _memberId = v),
        ),
        const SizedBox(height: JiraniSpace.s),
        TextField(controller: _amount, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.amountKesLabel)),
        if (_error != null) ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(_error!, tone: NoticeTone.critical),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l.recordButton)),
      ],
    );
  }
}
