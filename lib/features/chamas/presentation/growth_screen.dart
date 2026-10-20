import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';

final portfolioProvider = FutureProvider.autoDispose.family<Portfolio, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).portfolio(id);
});
final analyticsProvider = FutureProvider.autoDispose.family<Analytics, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).analytics(id);
});
final referralsProvider = FutureProvider.autoDispose.family<List<ReferralInfo>, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).referrals(id);
});
final partnersProvider = FutureProvider.autoDispose<List<PartnerInfo>>(
    (ref) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).partners();
});

String _kes(int? cents) => cents == null ? '-' : Kes(cents).format();

/// On the overview: the chama's numbers, what it owns, and partners.
class GrowthCard extends ConsumerWidget {
  const GrowthCard({super.key, required this.chama});

  final Chama chama;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final folio = ref.watch(portfolioProvider(chama.id)).value;
    return Padding(
      padding: const EdgeInsets.only(top: JiraniSpace.s),
      child: NavTile(
        key: const ValueKey('growth-card'),
        icon: Icons.trending_up_rounded,
        tone: JiraniTone.good,
        margin: EdgeInsets.zero,
        title: l.growthTitle,
        subtitle: folio?.netWorthCents == null ? l.growthSubtitle
              : l.growthNetWorth(_kes(folio!.netWorthCents)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => GrowthScreen(chama: chama))),
      ),
    );
  }
}

class GrowthScreen extends ConsumerWidget {
  const GrowthScreen({super.key, required this.chama});

  final Chama chama;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.growthTitle),
          bottom: TabBar(tabs: [
            Tab(text: l.growthNumbers),
            Tab(text: l.growthInvestments),
            Tab(text: l.growthPartners),
          ]),
        ),
        body: TabBarView(children: [
          _Numbers(chamaId: chama.id),
          _Investments(chama: chama),
          _Referrals(chama: chama),
        ]),
      ),
    );
  }
}

class _Numbers extends ConsumerWidget {
  const _Numbers({required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return ref.watch(analyticsProvider(chamaId)).when(
      loading: () => const LoadingView(),
      error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
          child: Notice(problemText(l, e), tone: NoticeTone.critical)),
      data: (a) => ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        // Net worth needs the bank balance; until a statement is in, lead with what
        // members have put in.
        HeroCard(
          label: a.netWorthCents == null ? l.contributed : l.numMoney,
          value: Text(_kes(a.netWorthCents ?? a.contributedCents)),
          children: [
            if (a.netWorthCents != null)
              HeroFigure(l.contributed, Text(_kes(a.contributedCents))),
            if (a.bankCents != null) HeroFigure(l.bankHeading, Text(_kes(a.bankCents))),
            HeroFigure(l.growthInvestments, Text(_kes(a.investmentsCents))),
          ],
        ),
        SectionHeader(l.numMonths),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, m) in a.months.indexed) ...[
              if (i > 0) const Divider(),
              Padding(
                key: ValueKey('month-${m.period}'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('${m.period} · ${m.paidPct == null ? '-' : '${m.paidPct}%'}',
                      style: text.titleSmall),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: (m.paidPct ?? 0) / 100,
                      color: (m.paidPct ?? 0) >= 90 ? JiraniStatus.of(context).good
                          : (m.paidPct ?? 0) >= 60 ? JiraniStatus.of(context).warning
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l.numMonthLine(_kes(m.paidCents), _kes(m.dueCents),
                      _kes(m.lateCents), _kes(m.finesRaisedCents)), style: text.bodySmall),
                ]),
              ),
            ],
          ]),
        ),
        SectionHeader(l.numBehind(a.behindCount)),
        if (a.behind.isNotEmpty)
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final b in a.behind)
                ListTile(leading: Avatar(b.name, size: 38), title: Text(b.name),
                    subtitle: Text(l.numBehindLine(_kes(b.arrearsCents),
                        _kes(b.finesCents)))),
            ]),
          ),
        if (a.meetings.isNotEmpty) ...[
          SectionHeader(l.numMeetings),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final m in a.meetings)
                ListTile(
                  leading: const ToneIcon(Icons.event_available_outlined,
                      tone: JiraniTone.warning, size: 38),
                  title: Text(m.title),
                  subtitle: Text(l.numAttendance(m.attended, m.expected)),
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _Investments extends ConsumerStatefulWidget {
  const _Investments({required this.chama});

  final Chama chama;

  @override
  ConsumerState<_Investments> createState() => _InvestmentsState();
}

class _InvestmentsState extends ConsumerState<_Investments> {
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    final l = AppLocalizations.of(context);
    setState(() => _error = null);
    try {
      await action();
      ref.invalidate(portfolioProvider(widget.chama.id));
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    }
  }

  Future<void> _record() async {
    final body = await Navigator.of(context).push<Json>(MaterialPageRoute(
        builder: (_) => const _InvestmentForm()));
    if (body == null) return;
    await _run(() => ref.read(chamaRepositoryProvider)
        .recordInvestment(widget.chama.id, body));
  }

  Future<void> _value(InvestmentInfo i) async {
    final body = await Navigator.of(context).push<Json>(MaterialPageRoute(
        builder: (_) => const _ValuationForm()));
    if (body == null) return;
    await _run(() => ref.read(chamaRepositoryProvider).valueInvestment(i.id, body));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final official = widget.chama.iAmOfficial;
    final repo = ref.read(chamaRepositoryProvider);
    return ref.watch(portfolioProvider(widget.chama.id)).when(
      loading: () => const LoadingView(),
      error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
          child: Notice(problemText(l, e), tone: NoticeTone.critical)),
      data: (f) => ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        if (_error != null) Notice(_error!, tone: NoticeTone.critical),
        SurfaceCard(
          margin: const EdgeInsets.only(bottom: JiraniSpace.s),
          child: Row(children: [
            const ToneIcon(Icons.landscape_outlined, tone: JiraniTone.good),
            const SizedBox(width: 12),
            Expanded(child: Text(l.invTotals(f.held, _kes(f.costCents), _kes(f.valueCents)),
                style: text.titleSmall)),
          ]),
        ),
        for (final i in f.investments)
          Card(
            key: ValueKey('inv-${i.id}'),
            child: Padding(
              padding: const EdgeInsets.all(JiraniSpace.m),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(i.name, style: text.titleSmall),
                Text(l.invLine(_kes(i.costCents), _kes(i.valueCents), _kes(i.incomeCents),
                    i.state == 'sold' ? l.invSold : l.invHeld), style: text.bodySmall),
                for (final v in i.valuations.where((v) => v.confirmedBy == null))
                  Row(children: [
                    Expanded(child: Text(l.invValuationWaiting(_kes(v.valueCents), v.asOf),
                        style: text.bodySmall)),
                    if (official)
                      TextButton(key: ValueKey('confirm-${v.id}'),
                          onPressed: () => _run(() => repo.confirmValuation(v.id)),
                          child: Text(l.invConfirm)),
                  ]),
                if (official && i.state == 'held')
                  Align(alignment: Alignment.centerLeft,
                      child: TextButton(key: ValueKey('value-${i.id}'),
                          onPressed: () => _value(i), child: Text(l.invAddValuation))),
              ]),
            ),
          ),
        if (official)
          OutlinedButton.icon(
            key: const ValueKey('record-investment'),
            icon: const Icon(Icons.add),
            label: Text(l.invRecord),
            onPressed: _record,
          ),
      ]),
    );
  }
}

class _InvestmentForm extends StatefulWidget {
  const _InvestmentForm();

  @override
  State<_InvestmentForm> createState() => _InvestmentFormState();
}

class _InvestmentFormState extends State<_InvestmentForm> {
  final _name = TextEditingController();
  final _cost = TextEditingController();
  String _kind = 'land';

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final kinds = {'land': l.kindLand, 'shares': l.kindShares, 'mmf': l.kindMmf,
                   'bond': l.kindBond, 'business': l.kindBusiness, 'other': l.kindOther};
    return Scaffold(
      appBar: AppBar(title: Text(l.invRecord)),
      bottomNavigationBar: ActionBar(child: PrimaryButton(
        label: l.invSave,
        onPressed: () => Navigator.of(context).pop(<String, Object?>{
          'kind': _kind, 'name': _name.text.trim(),
          'bought_on': DateTime.now().toIso8601String().substring(0, 10),
          'cost_cents': Kes.shillings(int.tryParse(_cost.text.trim()) ?? 0).cents,
        }),
      )),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        DropdownButtonFormField<String>(
          initialValue: _kind,
          items: [for (final e in kinds.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _kind = v ?? _kind),
        ),
        TextField(key: const ValueKey('inv-name'), controller: _name,
            decoration: InputDecoration(labelText: l.invName)),
        TextField(key: const ValueKey('inv-cost'), controller: _cost,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.invCost)),
      ]),
    );
  }
}

class _ValuationForm extends StatefulWidget {
  const _ValuationForm();

  @override
  State<_ValuationForm> createState() => _ValuationFormState();
}

class _ValuationFormState extends State<_ValuationForm> {
  final _value = TextEditingController();
  final _source = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    _source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.invAddValuation)),
      bottomNavigationBar: ActionBar(child: PrimaryButton(
        label: l.invSave,
        onPressed: () => Navigator.of(context).pop(<String, Object?>{
          'value_cents': Kes.shillings(int.tryParse(_value.text.trim()) ?? 0).cents,
          'as_of': DateTime.now().toIso8601String().substring(0, 10),
          'source': _source.text.trim(),
        }),
      )),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Notice(l.invValuationIntro),
        TextField(key: const ValueKey('val-value'), controller: _value,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.invValue)),
        TextField(key: const ValueKey('val-source'), controller: _source,
            decoration: InputDecoration(labelText: l.invSource)),
      ]),
    );
  }
}

class _Referrals extends ConsumerStatefulWidget {
  const _Referrals({required this.chama});

  final Chama chama;

  @override
  ConsumerState<_Referrals> createState() => _ReferralsState();
}

class _ReferralsState extends ConsumerState<_Referrals> {
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    final l = AppLocalizations.of(context);
    setState(() => _error = null);
    try {
      await action();
      ref.invalidate(referralsProvider(widget.chama.id));
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    }
  }

  String _state(AppLocalizations l, String s) => switch (s) {
        'voting' => l.refVoting,
        'consented' => l.refConsented,
        'refused' => l.refRefused,
        'withdrawn' => l.refWithdrawn,
        _ => l.refSent,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final partners = ref.watch(partnersProvider).value ?? const <PartnerInfo>[];
    final list = ref.watch(referralsProvider(widget.chama.id)).value ?? const <ReferralInfo>[];
    final repo = ref.read(chamaRepositoryProvider);
    final official = widget.chama.iAmOfficial;
    return ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
      Notice(l.refIntro),
      if (_error != null) Notice(_error!, tone: NoticeTone.critical),
      for (final r in list)
        ListTile(
          key: ValueKey('referral-${r.id}'),
          contentPadding: EdgeInsets.zero,
          leading: const ToneIcon(Icons.handshake_outlined, size: 38),
          title: Text(r.partnerName),
          subtitle: Text(_state(l, r.state)),
          trailing: official && (r.state == 'voting' || r.state == 'consented')
              ? TextButton(onPressed: () => _run(() => repo.withdrawReferral(r.id)),
                  child: Text(l.refWithdraw))
              : null,
        ),
      SectionHeader(l.refPartners),
      if (partners.isEmpty)
        SurfaceCard(child: EmptyState(icon: Icons.handshake_outlined, title: l.refNoPartners)),
      for (final p in partners)
        Card(
          key: ValueKey('partner-${p.id}'),
          child: Padding(
            padding: const EdgeInsets.all(JiraniSpace.m),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(p.name, style: text.titleSmall),
              Text(l.refLicence(p.regulatorName, p.licenceNumber), style: text.bodySmall),
              if (official)
                Align(alignment: Alignment.centerLeft, child: TextButton(
                  key: ValueKey('propose-${p.id}'),
                  onPressed: () async {
                    final reason = await showDialog<String>(context: context,
                        builder: (_) => _Reason(title: l.refPropose));
                    if (reason == null || reason.isEmpty) return;
                    await _run(() => repo.proposeReferral(widget.chama.id, p.id, reason));
                  },
                  child: Text(l.refPropose),
                )),
            ]),
          ),
        ),
    ]);
  }
}

class _Reason extends StatefulWidget {
  const _Reason({required this.title});

  final String title;

  @override
  State<_Reason> createState() => _ReasonState();
}

class _ReasonState extends State<_Reason> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(key: const ValueKey('ref-reason'), controller: _c, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          FilledButton(key: const ValueKey('ref-ok'),
              onPressed: () => Navigator.pop(context, _c.text.trim()),
              child: Text(MaterialLocalizations.of(context).okButtonLabel)),
        ],
      );
}
