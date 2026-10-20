import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'cash_screen.dart';
import 'chama_screen.dart';

final unmatchedProvider = FutureProvider.autoDispose.family<List<BankLine>, String>(
    (ref, chamaId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).unmatched(chamaId);
});

/// Payments the app could not match to a member (5.3). Officials see them; only the
/// treasurer assigns one, with a reason every member can read.
class UnmatchedScreen extends ConsumerWidget {
  const UnmatchedScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lines = ref.watch(unmatchedProvider(chamaId));
    final bundle = ref.watch(chamaBundleProvider(chamaId)).value;
    return Scaffold(
      appBar: AppBar(title: Text(l.unmatched)),
      body: lines.when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (items) => ListView(
          padding: const EdgeInsets.all(JiraniSpace.m),
          children: [
            if (items.isEmpty)
              SurfaceCard(child: EmptyState(icon: Icons.task_alt_rounded,
                  title: l.unmatchedEmpty)),
            for (final line in items)
              SurfaceCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const ToneIcon(Icons.south_west_rounded, tone: JiraniTone.warning,
                        size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        MoneyText(line.amount, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text([line.valueDate, line.narration,
                          if (line.fromMpesa) l.fromMpesa,
                          if (line.typedIn) l.typedIn].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                  ]),
                  if (bundle != null && bundle.chama.iAmTreasurer) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                          onPressed: () async {
                            final done = await showDialog<bool>(
                              context: context,
                              builder: (_) => _AssignDialog(line: line, bundle: bundle),
                            );
                            if (done == true) ref.invalidate(unmatchedProvider(chamaId));
                          },
                          child: Text(l.assign),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: l.itsCash,
                        icon: const Icon(Icons.payments_outlined),
                        onPressed: () async {
                          final done = await showDialog<bool>(
                            context: context,
                            builder: (_) => _BankCashDialog(line: line, chamaId: chamaId),
                          );
                          if (done == true) {
                            ref.invalidate(unmatchedProvider(chamaId));
                            ref.invalidate(cashProvider(chamaId));
                          }
                        },
                      ),
                    ]),
                  ],
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssignDialog extends ConsumerStatefulWidget {
  const _AssignDialog({required this.line, required this.bundle});

  final BankLine line;
  final ChamaBundle bundle;

  @override
  ConsumerState<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<_AssignDialog> {
  final _reason = TextEditingController();
  final _key = newIdempotencyKey();
  String? _memberId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    if (_memberId == null || _reason.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(chamaRepositoryProvider).assign(widget.line.id,
          membershipId: _memberId!, reason: _reason.text.trim(), idempotencyKey: _key);
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
      title: Text(l.assignTo),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          initialValue: _memberId,
          isExpanded: true,
          items: [
            for (final m in widget.bundle.members)
              DropdownMenuItem(value: m.id, child: Text('${m.name} (${m.memberCode})')),
          ],
          onChanged: (v) => setState(() => _memberId = v),
        ),
        const SizedBox(height: JiraniSpace.s),
        TextField(controller: _reason, decoration: InputDecoration(labelText: l.reasonLabel)),
        if (_error != null) ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(_error!, tone: NoticeTone.critical),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
        FilledButton(onPressed: _busy ? null : _assign, child: Text(l.assign)),
      ],
    );
  }
}

/// Links a deposit to the confirmed cash receipts it carries (5.4 step 4). The selected
/// receipts must add up to the deposit exactly.
class _BankCashDialog extends ConsumerStatefulWidget {
  const _BankCashDialog({required this.line, required this.chamaId});

  final BankLine line;
  final String chamaId;

  @override
  ConsumerState<_BankCashDialog> createState() => _BankCashDialogState();
}

class _BankCashDialogState extends ConsumerState<_BankCashDialog> {
  final _picked = <String>{};
  final _key = newIdempotencyKey();
  String? _error;
  bool _busy = false;

  Future<void> _bank() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(chamaRepositoryProvider).bankCash(widget.line.id,
          receiptIds: _picked.toList(), idempotencyKey: _key);
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
    final waiting = (ref.watch(cashProvider(widget.chamaId)).value ?? const [])
        .where((r) => r.state == 'member_confirmed')
        .toList();
    final total = Kes(waiting.where((r) => _picked.contains(r.id))
        .fold<int>(0, (sum, r) => sum + r.amount.cents));
    final matches = total == widget.line.amount;
    return AlertDialog(
      title: Text(l.pickCashReceipts),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (waiting.isEmpty) Notice(l.noConfirmedCash),
          for (final r in waiting)
            CheckboxListTile(
              value: _picked.contains(r.id),
              title: Text('${r.memberCode} · ${r.receivedOn}'),
              secondary: MoneyText(r.amount),
              onChanged: (v) => setState(() => v == true ? _picked.add(r.id) : _picked.remove(r.id)),
            ),
          const SizedBox(height: JiraniSpace.s),
          Text(l.cashTotal(total.format(), widget.line.amount.format()),
              style: TextStyle(color: matches ? null : Theme.of(context).colorScheme.error)),
          if (_error != null) ...[
            const SizedBox(height: JiraniSpace.s),
            Notice(_error!, tone: NoticeTone.critical),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
        FilledButton(onPressed: _busy || !matches ? null : _bank, child: Text(l.bankIt)),
      ],
    );
  }
}
