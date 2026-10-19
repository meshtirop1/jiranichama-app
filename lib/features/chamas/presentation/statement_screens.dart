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
      Text('${s.memberName} (${s.memberCode})', style: text.titleMedium),
      Text(l.periodRange(s.from, s.to)),
      const SizedBox(height: JiraniSpace.s),
      _Section(title: l.inThisPeriod, rows: [
        if (s.total('opening_cents').cents != 0) (l.openingSavings, s.total('opening_cents')),
        (l.contributed, s.total('contributed_cents')),
        if (s.total('fines_raised_cents').cents != 0)
          (l.finesRaised, s.total('fines_raised_cents')),
        if (s.total('fines_paid_cents').cents != 0) (l.finesPaid, s.total('fines_paid_cents')),
        if (s.total('fines_waived_cents').cents != 0)
          (l.finesWaived, s.total('fines_waived_cents')),
      ]),
      _Section(title: l.positionOn(s.positionOn), rows: [
        (l.totalSavings, p.contributed),
        (l.arrears, p.arrears),
        (l.finesOwed, p.fines),
        if (p.credit.cents > 0) (l.creditLabel, p.credit),
        if (p.pendingCash.cents > 0) (l.pendingCash, p.pendingCash),
      ], footer: p.nextDuePeriod == null ? null : l.nextDue(p.nextDue.format(), p.nextDuePeriod!)),
      if (s.lines.isEmpty)
        Padding(padding: const EdgeInsets.all(JiraniSpace.m), child: Text(l.noLinesInPeriod))
      else
        Card(child: Column(children: [for (final line in s.lines) _LineTile(line)])),
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
          Text(l.periodRange(s.from, s.to)),
          const SizedBox(height: JiraniSpace.s),
          Card(
            child: Column(children: [
              for (final m in s.members)
                ListTile(
                  title: Text('${m.name} (${m.code})'),
                  subtitle: Text('${l.contributed}: ${m.contributed.format()} · '
                      '${l.arrears}: ${m.arrears.format()} · ${l.finesOwed}: ${m.fines.format()}'),
                  trailing: MoneyText(m.savings),
                ),
              ListTile(
                title: Text(l.totalLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${l.contributed}: ${s.total('contributed_cents').format()}'),
                trailing: MoneyText(s.total('savings_cents')),
              ),
            ]),
          ),
          _Section(
            title: l.bankHeading,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(JiraniSpace.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.pdfReady, style: text.titleMedium),
          const SizedBox(height: JiraniSpace.xs),
          Text(l.checkCode(doc.spokenCode), key: const ValueKey('check-code'),
              style: text.bodyLarge),
          const SizedBox(height: JiraniSpace.xs),
          Text(l.anyoneCanCheck(doc.verifyUrl), style: text.bodySmall),
          const SizedBox(height: JiraniSpace.s),
          FilledButton.icon(icon: const Icon(Icons.share_outlined), label: Text(l.sharePdf),
              onPressed: onShare),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, this.header, this.footer});

  final String title;
  final List<(String, Kes)> rows;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(JiraniSpace.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: text.titleMedium),
          if (header != null) ...[const SizedBox(height: JiraniSpace.xs), Text(header!)],
          const SizedBox(height: JiraniSpace.xs),
          for (final (label, amount) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: JiraniSpace.xs),
              child: Row(children: [Expanded(child: Text(label)), MoneyText(amount)]),
            ),
          if (footer != null) ...[const SizedBox(height: JiraniSpace.xs), Text(footer!)],
        ]),
      ),
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
    return ListTile(
      dense: true,
      title: Text(line.period == null ? what : '$what · ${line.period}', style: struck),
      subtitle: Text([line.date, line.receipt, if (line.reversed) l.reversedLabel].join(' · ')),
      trailing: MoneyText(line.amount, style: struck),
    );
  }
}
