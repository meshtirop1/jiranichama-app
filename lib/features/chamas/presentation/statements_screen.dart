import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/labels.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'chama_screen.dart';
import 'type_lines_screen.dart';
import 'widgets/sms_code_sheet.dart';

final statementsProvider = FutureProvider.autoDispose.family<List<Statement>, String>(
    (ref, chamaId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).statements(chamaId);
});

/// Bank statements (5.5): upload one, and confirm one another official uploaded.
class StatementsScreen extends ConsumerStatefulWidget {
  const StatementsScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends ConsumerState<StatementsScreen> {
  String? _error;
  String? _info;
  bool _busy = false;

  Future<void> _typeLines(Statement s) async {
    final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => TypeLinesScreen(statement: s)));
    if (saved == true && mounted) {
      setState(() => _info = AppLocalizations.of(context).typedLinesSaved);
      ref.invalidate(statementsProvider(widget.chamaId));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(statementsProvider(widget.chamaId));
      ref.invalidate(chamaBundleProvider(widget.chamaId));
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() => _run(() async {
        final file = await ref.read(fileSourceProvider).pickStatement();
        if (file == null) return;
        await ref.read(chamaRepositoryProvider).uploadStatement(widget.chamaId,
            filename: file.name, bytes: file.bytes, idempotencyKey: newIdempotencyKey());
      });

  Future<void> _confirm(Statement s) async {
    final repo = ref.read(chamaRepositoryProvider);
    ChallengeSent? sent;
    // Busy only while the code is being sent, not while the official types it.
    await _run(() async => sent = await repo.startStatementConfirm(s.id));
    final challenge = sent;
    if (challenge == null || !mounted) return;
    final ok = await confirmWithSmsCode(context, sent: challenge, onCode: (code) async {
      await repo.confirmStatement(s.id, challengeId: challenge.challengeId, code: code);
    });
    if (ok) {
      ref.invalidate(statementsProvider(widget.chamaId));
      ref.invalidate(chamaBundleProvider(widget.chamaId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(statementsProvider(widget.chamaId));
    return Scaffold(
      appBar: AppBar(title: Text(l.statements)),
      bottomNavigationBar: ActionBar(
          child: PrimaryButton(label: l.uploadStatement, busy: _busy, onPressed: _upload)),
      body: ListView(
        padding: const EdgeInsets.all(JiraniSpace.m),
        children: [
          if (_error != null) ...[
            Notice(_error!, tone: NoticeTone.critical),
            const SizedBox(height: JiraniSpace.m),
          ],
          if (_info != null) ...[
            Notice(_info!),
            const SizedBox(height: JiraniSpace.m),
          ],
          ...list.when(
            loading: () => [const Center(child: CircularProgressIndicator())],
            error: (e, _) => [Notice(problemText(l, e), tone: NoticeTone.critical)],
            data: (items) => [
              if (items.isEmpty)
                SurfaceCard(child: EmptyState(icon: Icons.description_outlined,
                    title: l.statementsNoneTitle, message: l.statementsNoneBody)),
              for (final s in items) _tile(context, l, s),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, AppLocalizations l, Statement s) {
    final who = s.route == 'bank_email'
        ? l.fromTheBank
        : [
            if (s.uploadedBy != null) l.uploadedBy(s.uploadedBy!),
            if (s.confirmedBy != null) l.confirmedBy(s.confirmedBy!),
          ].join(', ');
    final (IconData icon, JiraniTone tone) = switch (s.state) {
      'accepted' => (Icons.verified_outlined, JiraniTone.good),
      'awaiting_confirmation' => (Icons.hourglass_top_rounded, JiraniTone.warning),
      'needs_typing' || 'needs_parser' => (Icons.edit_note_rounded, JiraniTone.warning),
      'held_mail_check' => (Icons.mark_email_unread_outlined, JiraniTone.warning),
      _ => (Icons.block_rounded, JiraniTone.critical),
    };
    return TitledCard(
      title: statementStateLabel(l, s.state),
      icon: icon,
      tone: tone,
      subtitle: who,
      children: [
          if (s.periodFrom != null && s.closing != null)
            Text(l.statementSummary(s.periodFrom!, s.periodTo!, s.lines, s.closing!.format()),
                style: Theme.of(context).textTheme.bodyMedium),
          for (final p in s.problems) ...[
            const SizedBox(height: JiraniSpace.xs),
            Notice(p, tone: NoticeTone.critical),
          ],
          for (final f in s.flags) ...[
            const SizedBox(height: JiraniSpace.xs),
            Notice(f, tone: NoticeTone.warning),
          ],
          if (s.typedLines.isNotEmpty) ...[
            const SizedBox(height: JiraniSpace.xs),
            Notice(l.typedLinesBy('${s.typedLines.length}',
                '${s.typedLines.first['typed_by'] ?? ''}'), tone: NoticeTone.warning),
          ],
          if (s.state == 'needs_typing') ...[
            const SizedBox(height: JiraniSpace.xs),
            Notice(l.typeLinesNotice('${s.unreadableLines.length}'), tone: NoticeTone.warning),
            const SizedBox(height: JiraniSpace.s),
            OutlinedButton(onPressed: _busy ? null : () => _typeLines(s),
                child: Text(l.typeLinesButton)),
          ],
          if (s.state == 'awaiting_confirmation') ...[
            const SizedBox(height: JiraniSpace.s),
            FilledButton(onPressed: _busy ? null : () => _confirm(s),
                child: Text(l.confirmStatement)),
          ],
      ],
    );
  }
}
