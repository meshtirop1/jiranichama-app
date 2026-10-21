import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../core/labels.dart';
import '../../l10n/app_localizations.dart';
import '../auth/presentation/problem_text.dart';
import '../chamas/data/models.dart';
import '../chamas/presentation/active_view.dart';
import '../chamas/presentation/chama_screen.dart';
import '../chamas/presentation/records_tab.dart';
import '../chamas/presentation/statement_screens.dart';

/// One member, as every member may see them (the records are open): role, code, ID check,
/// where they stand, their months at a glance and their latest records.
class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key, required this.chamaId, required this.membershipId});

  final String chamaId;
  final String membershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final bundle = ref.watch(chamaBundleProvider(chamaId)).value;
    final m = bundle?.members.where((x) => x.id == membershipId).firstOrNull;
    if (bundle == null || m == null) {
      return Scaffold(appBar: AppBar(), body: const LoadingView());
    }
    final position = ref.watch(positionProvider(m.id)).value;
    final statement =
        ref.watch(memberStatementProvider((id: m.id, from: null))).value;
    final latest = (statement?.lines ?? const <StatementLine>[]).reversed.take(5).toList();
    return Scaffold(
      appBar: AppBar(title: Text(m.name)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        SurfaceCard(
          key: const ValueKey('member-header'),
          child: Row(children: [
            Avatar(m.name, size: 64),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(m.name, style: text.titleLarge)),
                if (m.idChecked) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified_rounded, size: 20,
                      color: JiraniStatus.of(context).good),
                ],
              ]),
              const SizedBox(height: 4),
              Text(m.memberCode, style: text.bodyMedium),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                StatusPill(roleLabel(l, m.role), tone: officialRoles.contains(m.role)
                    ? JiraniTone.brand : JiraniTone.neutral),
                if (m.isFounding) StatusPill(l.memFounding, tone: JiraniTone.info),
                StatusPill(m.idChecked ? l.kycVerified : l.memNotChecked,
                    tone: m.idChecked ? JiraniTone.good : JiraniTone.neutral),
              ]),
            ])),
          ]),
        ),
        if (position != null) ...[
          const SizedBox(height: JiraniSpace.s),
          Row(children: [
            Expanded(child: _Figure(l.contributed, position.contributed)),
            const SizedBox(width: 8),
            Expanded(child: _Figure(l.arrears, position.arrears,
                alert: position.arrears.cents > 0)),
            const SizedBox(width: 8),
            Expanded(child: _Figure(l.finesOwed, position.fines,
                alert: position.fines.cents > 0)),
          ]),
        ],
        const SizedBox(height: JiraniSpace.s),
        NavTile(
          key: const ValueKey('member-calendar'),
          icon: Icons.calendar_month_outlined,
          tone: JiraniTone.good,
          title: l.calTitle,
          subtitle: l.calSubtitle,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) =>
              ContributionCalendarScreen(chamaId: chamaId, membershipId: m.id))),
        ),
        NavTile(
          key: const ValueKey('member-statement'),
          icon: Icons.summarize_outlined,
          tone: JiraniTone.info,
          title: l.memStatement,
          onTap: () => context.push('/chamas/$chamaId/members/${m.id}/statement'),
        ),
        SectionHeader(l.memLatest),
        if (statement == null) const SizedBox(height: 80, child: LoadingView()),
        if (statement != null && latest.isEmpty)
          SurfaceCard(child: EmptyState(icon: Icons.receipt_long_outlined,
              title: l.memNoRecords)),
        for (final line in latest)
          _LineTile(line: line),
      ]),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, {this.alert = false});

  final String label;
  final Kes value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: text.bodySmall),
        const SizedBox(height: 4),
        MoneyText(value, style: text.titleMedium?.copyWith(
            color: alert ? Theme.of(context).colorScheme.error : null)),
      ]),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line});

  final StatementLine line;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final flow = flowOf(line.type);
    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        flow == MoneyFlow.other
            ? const ToneIcon(Icons.receipt_long_outlined, size: 38)
            : FlowArrow(flow, size: 38, muted: line.reversed),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entryLabel(l, line.type), style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(decoration: line.reversed ? TextDecoration.lineThrough : null)),
          Text([line.date, if (line.period != null) line.period!,
            l.receipt(line.receipt)].join(' · '),
              style: Theme.of(context).textTheme.bodySmall),
        ])),
        MoneyText(line.amount.cents < 0 ? -line.amount : line.amount),
      ]),
    );
  }
}

/// A member's months at a glance: each month of the year paid in full, in part, not paid,
/// or still to come, from their own records and the rules' monthly amount.
class ContributionCalendarScreen extends ConsumerStatefulWidget {
  const ContributionCalendarScreen({super.key, required this.chamaId,
      required this.membershipId});

  final String chamaId;
  final String membershipId;

  @override
  ConsumerState<ContributionCalendarScreen> createState() =>
      _ContributionCalendarScreenState();
}

class _ContributionCalendarScreenState extends ConsumerState<ContributionCalendarScreen> {
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final status = JiraniStatus.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bundle = ref.watch(chamaBundleProvider(widget.chamaId)).value;
    final statement = ref.watch(memberStatementProvider((id: widget.membershipId, from: null)));
    final contributions = bundle?.rules.rules['contributions'] as Map?;
    final monthly = (contributions?['amount_cents'] as int?) ?? 0;
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l.calTitle)),
      body: statement.when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (s) {
          final paid = <String, int>{};
          for (final line in s.lines) {
            if (line.period == null || line.reversed) continue;
            if (line.type == 'contribution' || line.type == 'correction') {
              paid[line.period!] = (paid[line.period!] ?? 0) + line.amount.cents;
            }
          }
          final joined = s.from.substring(0, 7);
          String label(int month) =>
              locale == 'sw' ? _swMonths[month - 1] : _enMonths[month - 1];
          return ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
            Text(s.memberName, style: text.titleLarge),
            const SizedBox(height: JiraniSpace.s),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(key: const ValueKey('cal-prev'), tooltip: l.calPrevYear,
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left_rounded)),
              Text('$_year', style: text.titleLarge),
              IconButton(key: const ValueKey('cal-next'), tooltip: l.calNextYear,
                  onPressed: _year >= now.year ? null : () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right_rounded)),
            ]),
            const SizedBox(height: JiraniSpace.s),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.25,
              children: [
                for (var month = 1; month <= 12; month++)
                  () {
                    final period = '$_year-${month.toString().padLeft(2, '0')}';
                    final got = paid[period] ?? 0;
                    final future = DateTime(_year, month).isAfter(now);
                    final before = period.compareTo(joined) < 0;
                    final (Color bg, Color fg, IconData icon, String what) =
                        before ? (scheme.surfaceContainerLow, scheme.onSurfaceVariant,
                                Icons.remove_rounded, l.calBefore)
                        : got >= monthly && monthly > 0
                            ? (status.goodContainer, status.onGoodContainer,
                                Icons.check_circle_rounded, l.calPaid)
                        : got > 0
                            ? (status.warningContainer, status.onWarningContainer,
                                Icons.timelapse_rounded, l.calPart)
                        : future
                            ? (scheme.surfaceContainerLow, scheme.onSurfaceVariant,
                                Icons.schedule_rounded, l.calComing)
                            : (scheme.errorContainer, scheme.onErrorContainer,
                                Icons.cancel_rounded, l.calUnpaid);
                    return Container(
                      key: ValueKey('cal-$period'),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: bg,
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [
                          Expanded(child: Text(label(month), style: text.titleSmall
                              ?.copyWith(color: fg))),
                          Icon(icon, size: 18, color: fg),
                        ]),
                        Text(got > 0 ? Kes(got).format() : what,
                            style: text.bodySmall?.copyWith(color: fg),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    );
                  }(),
              ],
            ),
            const SizedBox(height: JiraniSpace.m),
            Text(l.calLegend(Kes(monthly).format()), style: text.bodySmall),
          ]);
        },
      ),
    );
  }
}

const _enMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
    'Nov', 'Dec'];
const _swMonths = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ago', 'Sep', 'Okt',
    'Nov', 'Des'];

/// Every money record of mine, newest first: contributions, fines, payments to me, with
/// receipts to copy. Filter by kind.
class MyPaymentsScreen extends ConsumerStatefulWidget {
  const MyPaymentsScreen({super.key, required this.chamaId, required this.membershipId});

  final String chamaId;
  final String membershipId;

  @override
  ConsumerState<MyPaymentsScreen> createState() => _MyPaymentsScreenState();
}

class _MyPaymentsScreenState extends ConsumerState<MyPaymentsScreen> {
  MoneyFlow? _only;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final statement = ref.watch(memberStatementProvider((id: widget.membershipId, from: null)));
    return Scaffold(
      appBar: AppBar(title: Text(l.payHistTitle)),
      body: statement.when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (s) {
          final lines = s.lines.reversed
              .where((x) => _only == null || flowOf(x.type) == _only).toList();
          return ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
            Wrap(spacing: 8, children: [
              ChoiceChip(label: Text(l.payHistAll), selected: _only == null,
                  onSelected: (_) => setState(() => _only = null)),
              ChoiceChip(key: const ValueKey('only-in'), label: Text(l.payHistIn),
                  selected: _only == MoneyFlow.incoming,
                  onSelected: (_) => setState(() => _only = MoneyFlow.incoming)),
              ChoiceChip(key: const ValueKey('only-fines'), label: Text(l.payHistFines),
                  selected: _only == MoneyFlow.fine,
                  onSelected: (_) => setState(() => _only = MoneyFlow.fine)),
              ChoiceChip(label: Text(l.payHistOut), selected: _only == MoneyFlow.outgoing,
                  onSelected: (_) => setState(() => _only = MoneyFlow.outgoing)),
            ]),
            const SizedBox(height: JiraniSpace.s),
            InfoRow(l.contributed, MoneyText(s.position.contributed), emphasis: true),
            const SizedBox(height: JiraniSpace.s),
            if (lines.isEmpty)
              SurfaceCard(child: EmptyState(icon: Icons.receipt_long_outlined,
                  title: l.memNoRecords)),
            for (final line in lines)
              InkWell(
                key: ValueKey('my-line-${line.receipt}'),
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: line.receipt));
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.copied(line.receipt))));
                },
                child: _LineTile(line: line),
              ),
            Text(l.payHistCopyHint, style: Theme.of(context).textTheme.bodySmall),
          ]);
        },
      ),
    );
  }
}
