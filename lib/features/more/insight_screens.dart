import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../l10n/app_localizations.dart';
import '../auth/presentation/problem_text.dart';
import '../automation/motions.dart';
import '../chamas/data/models.dart';
import '../chamas/presentation/active_view.dart';
import '../chamas/presentation/growth_screen.dart';
import '../chamas/presentation/vote_screen.dart';

/// Every vote in the chama: open ones first (with whether this member still has to vote),
/// then the closed ones with their results.
class VotesScreen extends ConsumerWidget {
  const VotesScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final votes = ref.watch(votesProvider(chamaId));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.vlTitle),
          bottom: TabBar(tabs: [Tab(text: l.vlOpen), Tab(text: l.vlClosed)]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('vl-motion'),
          icon: const Icon(Icons.record_voice_over_outlined),
          label: Text(l.motRaise),
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MotionsScreen(chamaId: chamaId))),
        ),
        body: votes.when(
          loading: () => const LoadingView(),
          error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
              child: Notice(problemText(l, e), tone: NoticeTone.critical)),
          data: (all) => TabBarView(children: [
            _VoteList(chamaId: chamaId, votes: all.where((v) => v.state == 'open').toList()),
            _VoteList(chamaId: chamaId, votes: all.where((v) => v.state != 'open').toList()),
          ]),
        ),
      ),
    );
  }
}

class _VoteList extends StatelessWidget {
  const _VoteList({required this.chamaId, required this.votes});

  final String chamaId;
  final List<VoteInfo> votes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (votes.isEmpty) {
      return ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        SurfaceCard(child: EmptyState(icon: Icons.how_to_vote_outlined, title: l.vlNone)),
      ]);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(JiraniSpace.m, JiraniSpace.m,
        JiraniSpace.m, 96), children: [
      for (final v in votes)
        SurfaceCard(
          key: ValueKey('vl-${v.id}'),
          margin: const EdgeInsets.only(bottom: 10),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => VoteScreen(chamaId: chamaId, voteId: v.id))),
          child: Row(children: [
            ToneIcon(v.isPoll ? Icons.ballot_outlined : Icons.how_to_vote_outlined,
                tone: switch (v.state) {
                  'open' => v.iCanVote ? JiraniTone.warning : JiraniTone.info,
                  'passed' => JiraniTone.good,
                  _ => JiraniTone.neutral,
                }, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.question, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text([
                voteStateLabel(l, v.state),
                l.vlTurnout('${v.cast}', '${v.eligible}'),
                if (v.state == 'open' && v.iCanVote) l.vlYourTurn,
              ].join(' · '), style: Theme.of(context).textTheme.bodySmall),
            ])),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
    ]);
  }
}

/// The chama's numbers as pictures: each month's contributions against what was due,
/// on time against late, fines, who is behind, meeting attendance, and the money.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final status = JiraniStatus.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.repTitle)),
      body: ref.watch(analyticsProvider(chamaId)).when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (a) {
          final top = a.months.fold<int>(1, (m, x) =>
              [m, x.dueCents, x.paidCents].reduce((p, q) => p > q ? p : q));
          return ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
            Row(children: [
              Expanded(child: _Stat(l.repSaved, Kes(a.contributedCents).format())),
              const SizedBox(width: 8),
              Expanded(child: _Stat(l.repBank,
                  a.bankCents == null ? '—' : Kes(a.bankCents!).format())),
              const SizedBox(width: 8),
              Expanded(child: _Stat(l.repWorth,
                  a.netWorthCents == null ? '—' : Kes(a.netWorthCents!).format())),
            ]),
            const SizedBox(height: JiraniSpace.s),
            TitledCard(
              key: const ValueKey('rep-months'),
              icon: Icons.bar_chart_rounded,
              tone: JiraniTone.good,
              title: l.repMonths,
              subtitle: l.repMonthsBody,
              children: [
                SizedBox(
                  height: 170,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (final m in a.months)
                      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                        Text(m.paidPct == null ? '' : '${m.paidPct}%',
                            style: text.labelSmall),
                        const SizedBox(height: 2),
                        Row(crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center, children: [
                          _Bar(height: 120 * m.dueCents / top, color: scheme.outlineVariant),
                          const SizedBox(width: 3),
                          _Bar(height: 120 * m.paidCents / top, color: status.good),
                        ]),
                        const SizedBox(height: 4),
                        Text(m.period.substring(5), style: text.labelSmall),
                      ])),
                  ]),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  _Key(color: scheme.outlineVariant, label: l.repDue),
                  const SizedBox(width: 14),
                  _Key(color: status.good, label: l.repPaid),
                ]),
              ],
            ),
            const SizedBox(height: JiraniSpace.s),
            TitledCard(
              icon: Icons.schedule_rounded,
              tone: JiraniTone.warning,
              title: l.repLate,
              children: [
                for (final m in a.months.where((m) => m.lateCents > 0 || m.finesRaisedCents > 0))
                  InfoRow(m.period, Flexible(child: Text(l.repLateLine(
                      Kes(m.lateCents).format(), Kes(m.finesRaisedCents).format()),
                      textAlign: TextAlign.end))),
                if (!a.months.any((m) => m.lateCents > 0 || m.finesRaisedCents > 0))
                  Text(l.repNoLate, style: text.bodyMedium),
              ],
            ),
            const SizedBox(height: JiraniSpace.s),
            TitledCard(
              icon: Icons.groups_2_outlined,
              tone: JiraniTone.critical,
              title: l.numBehind(a.behindCount),
              children: [
                for (final b in a.behind)
                  InfoRow(b.name, MoneyText(Kes(b.arrearsCents) + Kes(b.finesCents))),
                if (a.behind.isEmpty) Text(l.repNobodyBehind, style: text.bodyMedium),
              ],
            ),
            if (a.meetings.isNotEmpty) ...[
              const SizedBox(height: JiraniSpace.s),
              TitledCard(
                icon: Icons.event_available_outlined,
                tone: JiraniTone.info,
                title: l.numMeetings,
                children: [
                  for (final m in a.meetings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${m.title} · ${m.attended}/${m.expected}',
                            style: text.bodyMedium),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                            value: m.expected == 0 ? 0 : m.attended / m.expected,
                            minHeight: 8, borderRadius: BorderRadius.circular(8)),
                      ]),
                    ),
                ],
              ),
            ],
          ]);
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: text.bodySmall),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(value, style: text.titleMedium)),
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 9, height: height < 2 ? 2 : height,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      );
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color,
            borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

/// The morning bank check in full: what the bank says against the records, the gap and
/// what explains it, the last two weeks, and how fresh the bank statement is.
class BankCheckScreen extends ConsumerWidget {
  const BankCheckScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final status = JiraniStatus.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.bcTitle)),
      body: ref.watch(reconciliationProvider(chamaId)).when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (r) {
          final history = [
            for (final h in (r.json['history'] as List? ?? const []))
              (on: (h as Map)['on'] as String, gap: h['gap_cents'] as int),
          ].reversed.toList();
          final worst = history.fold<int>(1, (m, h) => h.gap.abs() > m ? h.gap.abs() : m);
          final (String headline, NoticeTone tone) = switch (r.status) {
            'match' => (l.bcMatch, NoticeTone.good),
            'open' => (l.bcGap(r.gap.format()), NoticeTone.warning),
            'breach' => (l.bcBreach, NoticeTone.critical),
            _ => (l.bcNoStatement, NoticeTone.info),
          };
          return ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
            Notice(key: const ValueKey('bc-status'), headline, tone: tone),
            const SizedBox(height: JiraniSpace.s),
            TitledCard(
              icon: Icons.account_balance_rounded,
              tone: JiraniTone.info,
              title: l.bcFigures,
              subtitle: r.checkedOn == null ? null : l.bcCheckedOn(r.checkedOn!),
              children: [
                InfoRow(r.fromBankApi ? l.bcBankFeed : l.bcBankStatement,
                    r.bank == null ? const Text('—') : MoneyText(r.bank!)),
                InfoRow(l.bcRecords, r.records == null ? const Text('—')
                    : MoneyText(r.records!)),
                InfoRow(l.bcGapLabel, MoneyText(r.gap), emphasis: true),
                if (r.unmatched.cents != 0) ...[
                  InfoRow(l.bcUnmatched, MoneyText(r.unmatched)),
                  Align(alignment: Alignment.centerLeft, child: TextButton(
                      onPressed: () => context.push('/chamas/$chamaId/unmatched'),
                      child: Text(l.bcSeeUnmatched))),
                ],
                if (r.unexplained.cents != 0) InfoRow(l.bcUnexplained, MoneyText(r.unexplained)),
                if (r.gapOpenedOn != null)
                  Text(l.bcOpenFor('${r.daysOpen}', '${r.breachAfterDays}'),
                      style: text.bodySmall),
              ],
            ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: JiraniSpace.s),
              TitledCard(
                key: const ValueKey('bc-history'),
                icon: Icons.timeline_rounded,
                tone: JiraniTone.neutral,
                title: l.bcHistory,
                children: [
                  SizedBox(
                    height: 90,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (final h in history)
                        Expanded(child: Tooltip(
                          message: '${h.on}: ${Kes(h.gap).format()}',
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: h.gap == 0 ? 6 : 6 + 70 * h.gap.abs() / worst,
                            decoration: BoxDecoration(
                              color: h.gap == 0 ? status.good : status.warning,
                              borderRadius: BorderRadius.circular(4)),
                          ),
                        )),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Text(l.bcHistoryKey, style: text.bodySmall),
                ],
              ),
            ],
            const SizedBox(height: JiraniSpace.s),
            TitledCard(
              icon: Icons.description_outlined,
              tone: r.statementLevel > 0 ? JiraniTone.warning : JiraniTone.good,
              title: l.bcFreshness,
              children: [
                Text(r.statementLevel == 0
                    ? l.bcFresh(r.statementCheckedTo ?? '—')
                    : l.bcStale('${r.statementDaysOverdue}'), style: text.bodyMedium),
              ],
            ),
            const SizedBox(height: JiraniSpace.s),
            Text(l.bcHow, style: text.bodySmall),
          ]);
        },
      ),
    );
  }
}
