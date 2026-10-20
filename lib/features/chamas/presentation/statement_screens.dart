import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/labels.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/chama_repository.dart';
import '../data/models.dart';
import 'chama_screen.dart';

/// Which stretch of time a statement covers. `from` is null for "since joining", which
/// the API works out.
enum StatementPeriod { all, year, quarter }

String? periodFrom(StatementPeriod p, DateTime today) => switch (p) {
      StatementPeriod.all => null,
      StatementPeriod.year => '${today.year}-01-01',
      StatementPeriod.quarter =>
        today.subtract(const Duration(days: 90)).toIso8601String().substring(0, 10),
    };

typedef StatementArgs = ({String id, String? from});

final memberStatementProvider =
    FutureProvider.autoDispose.family<MemberStatement, StatementArgs>((ref, a) =>
        ref.watch(chamaRepositoryProvider).memberStatement(a.id, from: a.from));

final chamaStatementProvider =
    FutureProvider.autoDispose.family<ChamaStatement, StatementArgs>((ref, a) =>
        ref.watch(chamaRepositoryProvider).chamaStatement(a.id, from: a.from));

/// A member's statement (4.8): what moved in the period, where they stand today, and
/// every line. The member, an official or the auditor can take it away as a sealed PDF.
class MemberStatementScreen extends ConsumerStatefulWidget {
  const MemberStatementScreen({super.key, required this.chamaId, required this.membershipId});

  final String chamaId;
  final String membershipId;

  @override
  ConsumerState<MemberStatementScreen> createState() => _MemberStatementScreenState();
}

class _MemberStatementScreenState extends ConsumerState<MemberStatementScreen> {
  StatementPeriod _period = StatementPeriod.all;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bundle = ref.watch(chamaBundleProvider(widget.chamaId)).value;
    final isMe = bundle?.me?.id == widget.membershipId;
    final mayPdf = bundle != null &&
        (isMe || bundle.chama.iAmOfficial || bundle.chama.myRole == 'auditor');
    final from = periodFrom(_period, DateTime.now());
    final figures = ref.watch(memberStatementProvider((id: widget.membershipId, from: from)));
    return _StatementScaffold(
      title: isMe ? l.myStatement : l.memberStatement,
      period: _period,
      onPeriod: (p) => setState(() => _period = p),
      mayPdf: mayPdf,
      issue: (repo, language, key) => repo.issueMemberStatementPdf(widget.membershipId,
          from: from, language: language, idempotencyKey: key),
      body: figures.when(
        loading: () => [const LinearProgressIndicator()],
        error: (e, _) => [Notice(problemText(l, e), tone: NoticeTone.critical)],
        data: (s) => _memberBody(context, l, s),
      ),
    );
  }

  List<Widget> _memberBody(BuildContext context, AppLocalizations l, MemberStatement s) {
    final text = Theme.of(context).textTheme;
    final p = s.position;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: JiraniSpace.m),
        child: Row(children: [
          Avatar(s.memberName, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.memberName} (${s.memberCode})', style: text.titleMedium),
              Text(l.periodRange(s.from, s.to), style: text.bodySmall),
            ]),
          ),
        ]),
      ),
      _Section(title: l.inThisPeriod, icon: Icons.date_range_rounded, rows: [
        if (s.total('opening_cents').cents != 0) (l.openingSavings, s.total('opening_cents')),
        (l.contributed, s.total('contributed_cents')),
        if (s.total('fines_raised_cents').cents != 0)
          (l.finesRaised, s.total('fines_raised_cents')),
        if (s.total('fines_paid_cents').cents != 0) (l.finesPaid, s.total('fines_paid_cents')),
        if (s.total('fines_waived_cents').cents != 0)
          (l.finesWaived, s.total('fines_waived_cents')),
      ]),
      _Section(title: l.positionOn(s.positionOn), icon: Icons.account_balance_wallet_outlined,
          tone: JiraniTone.good, rows: [
        (l.totalSavings, p.contributed),
        (l.arrears, p.arrears),
        (l.finesOwed, p.fines),
        if (p.credit.cents > 0) (l.creditLabel, p.credit),
        if (p.pendingCash.cents > 0) (l.pendingCash, p.pendingCash),
      ], footer: p.nextDuePeriod == null ? null : l.nextDue(p.nextDue.format(), p.nextDuePeriod!)),
      SectionHeader(l.tabRecords),
      if (s.lines.isEmpty)
        SurfaceCard(child: EmptyState(icon: Icons.receipt_long_outlined,
            title: l.noLinesInPeriod))
      else
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, line) in s.lines.indexed) ...[
              if (i > 0) const Divider(indent: 66),
              _LineTile(line),
            ],
          ]),
        ),
    ];
  }
}

/// The whole chama: every member's totals and the bank side.
class ChamaStatementScreen extends ConsumerStatefulWidget {
  const ChamaStatementScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<ChamaStatementScreen> createState() => _ChamaStatementScreenState();
}

class _ChamaStatementScreenState extends ConsumerState<ChamaStatementScreen> {
  StatementPeriod _period = StatementPeriod.all;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final from = periodFrom(_period, DateTime.now());
    final figures = ref.watch(chamaStatementProvider((id: widget.chamaId, from: from)));
    return _StatementScaffold(
      title: l.chamaStatement,
      period: _period,
      onPeriod: (p) => setState(() => _period = p),
      mayPdf: true,
      issue: (repo, language, key) => repo.issueChamaStatementPdf(widget.chamaId,
          from: from, language: language, idempotencyKey: key),
      body: figures.when(
        loading: () => [const LinearProgressIndicator()],
        error: (e, _) => [Notice(problemText(l, e), tone: NoticeTone.critical)],
        data: (s) => [
          HeroCard(
            label: l.periodRange(s.from, s.to),
            value: MoneyText(s.total('savings_cents'),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white)),
            children: [
              HeroFigure(l.contributed, MoneyText(s.total('contributed_cents'),
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: Colors.white))),
              HeroFigure(l.tabMembers, Text('${s.members.length}')),
            ],
          ),
          SectionHeader(l.tabMembers),
          SurfaceCard(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              for (final (i, m) in s.members.indexed) ...[
                if (i > 0) const Divider(indent: 70),
                _MemberRow(m),
              ],
            ]),
          ),
          _Section(
            title: l.bankHeading,
            icon: Icons.account_balance_rounded,
            tone: JiraniTone.info,
            rows: [
              if (s.bankClosing != null) (l.closingOnStatement, s.bankClosing!),
              (l.cashNotBanked, s.cashWaiting),
            ],
            header: s.reconciledTo == null ? l.noBankStatementYet : l.reconciledTo(s.reconciledTo!),
            footer: s.unmatchedCount == 0
                ? null
                : l.unmatchedSummary('${s.unmatchedCount}', s.unmatched.format()),
          ),
        ],
      ),
    );
  }
}

typedef _Issue = Future<IssuedDocument> Function(
    ChamaRepository repo, String language, String idempotencyKey);

/// The parts both statements share: the period picker, and getting the PDF.
class _StatementScaffold extends ConsumerStatefulWidget {
  const _StatementScaffold({
    required this.title,
    required this.period,
    required this.onPeriod,
    required this.mayPdf,
    required this.issue,
    required this.body,
  });

  final String title;
  final StatementPeriod period;
  final ValueChanged<StatementPeriod> onPeriod;
  final bool mayPdf;
  final _Issue issue;
  final List<Widget> body;

  @override
  ConsumerState<_StatementScaffold> createState() => _StatementScaffoldState();
}

class _StatementScaffoldState extends ConsumerState<_StatementScaffold> {
  IssuedDocument? _doc;
  String? _path;
  String? _error;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _StatementScaffold old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period) {
      _doc = null; // a new period is a different statement
      _path = null;
    }
  }

  Future<void> _getPdf() async {
    final language = Localizations.localeOf(context).languageCode;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(chamaRepositoryProvider);
      final doc = await widget.issue(repo, language, newIdempotencyKey());
      final bytes = await repo.documentFile(doc.id);
      final path = await ref.read(documentSaverProvider)
          .save('JiraniChama-${doc.kind.replaceAll('_', '-')}-${doc.verifyCode}.pdf', bytes);
      if (mounted) {
        setState(() {
          _doc = doc;
          _path = path;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final doc = _doc;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      bottomNavigationBar: widget.mayPdf
          ? ActionBar(child: PrimaryButton(label: l.getPdf, busy: _busy, onPressed: _getPdf))
          : null,
      body: ListView(
        padding: const EdgeInsets.all(JiraniSpace.m),
        children: [
          SegmentedButton<StatementPeriod>(
            segments: [
              ButtonSegment(value: StatementPeriod.all, label: Text(l.periodAll)),
              ButtonSegment(value: StatementPeriod.year, label: Text(l.periodYear)),
              ButtonSegment(value: StatementPeriod.quarter, label: Text(l.periodQuarter)),
            ],
            selected: {widget.period},
            showSelectedIcon: false,
            onSelectionChanged: (s) => widget.onPeriod(s.first),
          ),
          const SizedBox(height: JiraniSpace.m),
          if (_error != null) ...[
            Notice(_error!, tone: NoticeTone.critical),
            const SizedBox(height: JiraniSpace.s),
          ],
          if (doc != null) ...[
            _DocumentReady(doc: doc, onShare: () => ref.read(documentSaverProvider).share(
                _path!, text: '${l.checkCode(doc.spokenCode)}\n${doc.verifyUrl}')),
            const SizedBox(height: JiraniSpace.s),
          ],
          if (!widget.mayPdf) ...[
            Notice(l.pdfOnlyForMember),
            const SizedBox(height: JiraniSpace.s),
          ],
          ...widget.body,
        ],
      ),
    );
  }
}

class _DocumentReady extends StatelessWidget {
  const _DocumentReady({required this.doc, required this.onShare});

  final IssuedDocument doc;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return TitledCard(
      title: l.pdfReady,
      icon: Icons.picture_as_pdf_outlined,
      tone: JiraniTone.good,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(l.checkCode(doc.spokenCode), key: const ValueKey('check-code'),
              style: text.titleMedium?.copyWith(letterSpacing: 1)),
        ),
        const SizedBox(height: JiraniSpace.s),
        Text(l.anyoneCanCheck(doc.verifyUrl), style: text.bodySmall),
        const SizedBox(height: JiraniSpace.m),
        FilledButton.icon(icon: const Icon(Icons.share_outlined), label: Text(l.sharePdf),
            onPressed: onShare),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, this.header, this.footer,
      this.icon, this.tone = JiraniTone.brand});

  final String title;
  final List<(String, Kes)> rows;
  final String? header;
  final String? footer;
  final IconData? icon;
  final JiraniTone tone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TitledCard(
      title: title,
      icon: icon,
      tone: tone,
      subtitle: header,
      children: [
        for (final (i, (label, amount)) in rows.indexed) ...[
          if (i > 0) const Divider(),
          InfoRow(label, MoneyText(amount, style: text.titleSmall)),
        ],
        if (footer != null) ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(footer!, tone: NoticeTone.warning),
        ],
      ],
    );
  }
}

/// One member in the chama statement: who, their savings, and what they owe.
class _MemberRow extends StatelessWidget {
  const _MemberRow(this.m);

  final ChamaStatementRow m;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final arrears = m.arrears;
    final fines = m.fines;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Avatar(m.name, size: 42),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m.name} (${m.code})', style: text.titleSmall),
            const SizedBox(height: 6),
            Text('${l.contributed} ${m.contributed.format()}', style: text.bodySmall),
            if (arrears.cents > 0 || fines.cents > 0) const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (arrears.cents > 0)
                FigureChip(l.arrears, arrears.format(), tone: JiraniTone.warning),
              if (fines.cents > 0)
                FigureChip(l.finesOwed, fines.format(), tone: JiraniTone.critical),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        MoneyText(m.savings, style: text.titleSmall),
      ]),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile(this.line);

  final StatementLine line;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final what = line.type == 'reversal' && line.reversesReceipt != null
        ? l.reversalOf(line.reversesReceipt!)
        : entryLabel(l, line.type);
    final struck = line.reversed
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final incoming = line.type == 'contribution' || line.type == 'fine_paid';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
      child: Row(children: [
        ToneIcon(
          switch (line.type) {
            'contribution' => Icons.south_west_rounded,
            'fine_raised' => Icons.gavel_rounded,
            'fine_paid' => Icons.task_alt_rounded,
            'reversal' || 'correction' => Icons.undo_rounded,
            _ => Icons.receipt_long_outlined,
          },
          tone: line.reversed ? JiraniTone.neutral : incoming ? JiraniTone.good
              : line.type == 'fine_raised' ? JiraniTone.critical : JiraniTone.neutral,
          size: 38,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line.period == null ? what : '$what · ${line.period}',
                style: text.titleSmall?.merge(struck)),
            Text([line.date, line.receipt, if (line.reversed) l.reversedLabel].join(' · '),
                style: text.bodySmall),
          ]),
        ),
        MoneyText(line.amount, style: text.titleSmall?.merge(struck)
            .copyWith(color: line.reversed ? muted : null)),
      ]),
    );
  }
}
