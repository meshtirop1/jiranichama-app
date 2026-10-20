import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'widgets/sms_code_sheet.dart';

final finesProvider = FutureProvider.autoDispose.family<List<FineInfo>, String>(
    (ref, chamaId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).fines(chamaId);
});

String _kes(int cents) => Kes(cents).format();

String fineStateLabel(AppLocalizations l, String state) => switch (state) {
      'raised' => l.fineOwed,
      'paid' => l.finePaid,
      'waived' => l.fineWaived,
      _ => l.fineReversed,
    };

String waiverStateLabel(AppLocalizations l, String state) => switch (state) {
      'requested' => l.waiverRequested,
      'waived' => l.waiverWaived,
      'refused' => l.waiverRefused,
      _ => l.waiverExpired,
    };

/// On the overview: waivers waiting for my decision, and the way to every fine.
class FinesCard extends ConsumerWidget {
  const FinesCard({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(finesProvider(chamaId)).value ?? const <FineInfo>[];
    final toDecide = list.where((f) => f.waiver?.iCanDecide == true).length;
    final mine = list.where((f) => f.mine && f.outstandingCents > 0)
        .fold(0, (t, f) => t + f.outstandingCents);
    return Padding(
      padding: const EdgeInsets.only(top: JiraniSpace.s),
      child: NavTile(
        key: const ValueKey('fines-card'),
        icon: Icons.gavel_rounded,
        tone: JiraniTone.critical,
        margin: EdgeInsets.zero,
        title: l.finesTitle,
        subtitle: [
            if (mine > 0) l.finesMineOwed(_kes(mine)),
            if (toDecide > 0) l.waiversToDecide(toDecide),
            if (mine == 0 && toDecide == 0) l.finesNoneOwed,
          ].join(' · '),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FinesScreen(chamaId: chamaId))),
      ),
    );
  }
}

/// Every fine in the chama, who was fined and why, and every waiver (5.9).
class FinesScreen extends ConsumerStatefulWidget {
  const FinesScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<FinesScreen> createState() => _FinesScreenState();
}

class _FinesScreenState extends ConsumerState<FinesScreen> {
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
      ref.invalidate(finesProvider(widget.chamaId));
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _reason(String title) => showDialog<String>(
      context: context, builder: (_) => _ReasonDialog(title: title));

  Future<void> _approve(WaiverInfo w) async {
    final repo = ref.read(chamaRepositoryProvider);
    await _run(() async {
      final sent = await repo.startWaiverApproval(w.id);
      if (!mounted) return;
      await confirmWithSmsCode(context, sent: sent, onCode: (code) =>
          repo.approveWaiver(w.id, challengeId: sent.challengeId, code: code));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final async = ref.watch(finesProvider(widget.chamaId));
    final repo = ref.read(chamaRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.finesTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (list) => ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
          if (_error != null) Notice(_error!, tone: NoticeTone.critical),
          if (list.isEmpty) Notice(l.finesNone),
          for (final f in list)
            Card(
              key: ValueKey('fine-${f.id}'),
              child: Padding(
                padding: const EdgeInsets.all(JiraniSpace.m),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Avatar(f.member, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(f.member, style: text.titleSmall),
                        const SizedBox(height: 2),
                        Text(l.fineLine(f.ruleRef, f.period, fineStateLabel(l, f.state),
                            f.receipt), style: text.bodySmall),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(_kes(f.amountCents), style: text.titleSmall?.copyWith(
                        color: f.outstandingCents > 0
                            ? Theme.of(context).colorScheme.error : null)),
                  ]),
                  if (f.waiver != null) ...[
                    const SizedBox(height: JiraniSpace.xs),
                    Text(l.waiverLine(waiverStateLabel(l, f.waiver!.state), f.waiver!.reason,
                        f.waiver!.approvals, f.waiver!.needsOfficials), style: text.bodySmall),
                  ],
                  if (f.mine && f.state == 'raised' && f.outstandingCents > 0
                      && f.waiver?.state != 'requested')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: ValueKey('ask-waiver-${f.id}'),
                        onPressed: _busy ? null : () async {
                          final reason = await _reason(l.waiverAsk);
                          if (reason == null || reason.trim().isEmpty) return;
                          await _run(() => repo.requestWaiver(f.id, reason.trim()));
                        },
                        child: Text(l.waiverAsk),
                      ),
                    ),
                  if (f.waiver?.iCanDecide == true)
                    Row(children: [
                      Expanded(child: FilledButton(
                        key: ValueKey('approve-waiver-${f.id}'),
                        onPressed: _busy ? null : () => _approve(f.waiver!),
                        child: Text(l.waiverApprove),
                      )),
                      const SizedBox(width: JiraniSpace.s),
                      TextButton(
                        key: ValueKey('decline-waiver-${f.id}'),
                        onPressed: _busy ? null : () async {
                          final reason = await _reason(l.waiverDecline);
                          if (reason == null) return;
                          await _run(() => repo.declineWaiver(f.waiver!.id, reason.trim()));
                        },
                        child: Text(l.waiverDecline),
                      ),
                    ]),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});

  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
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
      content: TextField(key: const ValueKey('reason-text'), controller: _c, autofocus: true,
          maxLines: 3, decoration: InputDecoration(labelText: l.waiverReasonLabel)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        FilledButton(key: const ValueKey('reason-ok'),
            onPressed: () => Navigator.pop(context, _c.text),
            child: Text(MaterialLocalizations.of(context).okButtonLabel)),
      ],
    );
  }
}
