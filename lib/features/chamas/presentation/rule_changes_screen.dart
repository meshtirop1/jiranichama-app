import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'rules_editor_screen.dart';
import 'vote_screen.dart';

final ruleProposalsProvider = FutureProvider.autoDispose.family<List<RuleProposal>, String>(
    (ref, chamaId) => ref.watch(chamaRepositoryProvider).ruleProposals(chamaId));

String ruleProposalStateLabel(AppLocalizations l, String state) => switch (state) {
      'notice' => l.rpNotice,
      'voting' => l.rpVoting,
      'adopted' => l.rpAdopted,
      'in_force' => l.rpInForce,
      'rejected' => l.rpRejected,
      'lapsed' => l.rpLapsed,
      _ => l.rpWithdrawn,
    };

String _day(String iso) => iso.length >= 10 ? iso.substring(0, 10) : iso;

/// On the Rules tab: changes being decided or recently decided, and, for officials, the
/// way to propose one.
class RuleChangesSection extends ConsumerWidget {
  const RuleChangesSection({super.key, required this.chamaId, required this.official});

  final String chamaId;
  final bool official;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final list = ref.watch(ruleProposalsProvider(chamaId)).value ?? const <RuleProposal>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (official)
        OutlinedButton.icon(
          key: const ValueKey('propose-rule-change'),
          icon: const Icon(Icons.edit_note),
          label: Text(l.proposeRuleChange),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => RulesEditorScreen(chamaId: chamaId, propose: true))),
        ),
      for (final p in list)
        Card(
          child: ListTile(
            key: ValueKey('rule-proposal-${p.id}'),
            title: Text(p.reason),
            subtitle: Text(ruleProposalStateLabel(l, p.state)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RuleProposalScreen(chamaId: chamaId, proposalId: p.id))),
          ),
        ),
      if (official || list.isNotEmpty) const SizedBox(height: JiraniSpace.m),
    ]);
  }
}

/// One rule change: why, what changes clause by clause, where it stands, and the vote.
class RuleProposalScreen extends ConsumerStatefulWidget {
  const RuleProposalScreen({super.key, required this.chamaId, required this.proposalId});

  final String chamaId;
  final String proposalId;

  @override
  ConsumerState<RuleProposalScreen> createState() => _RuleProposalScreenState();
}

class _RuleProposalScreenState extends ConsumerState<RuleProposalScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _withdraw() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(chamaRepositoryProvider).withdrawRuleProposal(widget.proposalId);
      ref.invalidate(ruleProposalsProvider(widget.chamaId));
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final text = Theme.of(context).textTheme;
    final list = ref.watch(ruleProposalsProvider(widget.chamaId));
    final p = list.value?.where((p) => p.id == widget.proposalId).firstOrNull;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: list.hasError
            ? Padding(padding: const EdgeInsets.all(JiraniSpace.m),
                child: Notice(problemText(l, list.error!), tone: NoticeTone.critical))
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final status = switch (p.state) {
      'notice' => l.rpNoticeUntil(_day(p.noticeUntil), p.voteDays),
      'adopted' => l.rpStartsOn(_day(p.effectiveFrom ?? '')),
      'in_force' => l.rpInForceSince(_day(p.effectiveFrom ?? '')),
      _ => ruleProposalStateLabel(l, p.state),
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.ruleChangeTitle)),
      body: ListView(
        padding: const EdgeInsets.all(JiraniSpace.m),
        children: [
          Text(p.reason, style: text.titleMedium),
          Text(l.rpProposedBy(p.proposedBy), style: text.bodySmall),
          const SizedBox(height: JiraniSpace.s),
          Notice(status, tone: p.open ? NoticeTone.warning : NoticeTone.info),
          const SizedBox(height: JiraniSpace.s),
          Text(l.rpThresholds(p.quorumPct, p.passPct), style: text.bodySmall),
          if (_error != null) ...[
            const SizedBox(height: JiraniSpace.s),
            Notice(_error!, tone: NoticeTone.critical),
          ],
          const SizedBox(height: JiraniSpace.m),
          for (final c in p.clauses(lang))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(JiraniSpace.m),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(l.rpClause(c.ref), style: text.titleSmall),
                  const SizedBox(height: JiraniSpace.xs),
                  Text(l.rpBefore, style: text.labelSmall),
                  Text(c.before ?? l.rpNone,
                      style: text.bodyMedium?.copyWith(
                          decoration: TextDecoration.lineThrough)),
                  const SizedBox(height: JiraniSpace.xs),
                  Text(l.rpAfter, style: text.labelSmall),
                  Text(c.after ?? l.rpNone, style: text.bodyMedium),
                ]),
              ),
            ),
          const SizedBox(height: JiraniSpace.m),
          if (p.voteId != null)
            FilledButton.icon(
              key: const ValueKey('rule-change-vote'),
              icon: const Icon(Icons.how_to_vote_outlined),
              label: Text(l.rpOpenVote),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VoteScreen(chamaId: widget.chamaId, voteId: p.voteId!))),
            ),
          if (p.state == 'notice')
            OutlinedButton(
              key: const ValueKey('rule-change-withdraw'),
              onPressed: _busy ? null : _withdraw,
              child: Text(l.rpWithdraw),
            ),
        ],
      ),
    );
  }
}
