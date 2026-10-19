import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'chama_screen.dart';

final unmatchedProvider = FutureProvider.autoDispose.family<List<BankLine>, String>(
    (ref, chamaId) => ref.watch(chamaRepositoryProvider).unmatched(chamaId));

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (items) => ListView(
          padding: const EdgeInsets.all(JiraniSpace.m),
          children: [
            if (items.isEmpty) Notice(l.unmatchedEmpty),
            for (final line in items)
              Card(
                child: ListTile(
                  title: MoneyText(line.amount),
                  subtitle: Text('${line.valueDate} · ${line.narration}'),
                  trailing: bundle != null && bundle.chama.iAmTreasurer
                      ? TextButton(
                          onPressed: () async {
                            final done = await showDialog<bool>(
                              context: context,
                              builder: (_) => _AssignDialog(line: line, bundle: bundle),
                            );
                            if (done == true) ref.invalidate(unmatchedProvider(chamaId));
                          },
                          child: Text(l.assign),
                        )
                      : null,
                ),
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
