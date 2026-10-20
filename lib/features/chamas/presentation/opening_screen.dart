import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'chama_screen.dart';
import 'widgets/sms_code_sheet.dart';

final openingProvider = FutureProvider.autoDispose.family<OpeningBalances, String>(
    (ref, chamaId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).opening(chamaId);
});

/// Opening balances (5.1 step 10): the treasurer enters what each member had, a different
/// official confirms, and each member may object to their own line for 14 days.
class OpeningScreen extends ConsumerStatefulWidget {
  const OpeningScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends ConsumerState<OpeningScreen> {
  final _savings = <String, TextEditingController>{};
  final _fines = <String, TextEditingController>{};
  final _reason = TextEditingController();
  String? _error;
  String? _info;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [..._savings.values, ..._fines.values, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _field(Map<String, TextEditingController> map, String id, Kes value) =>
      map.putIfAbsent(id, () => TextEditingController(
          text: value.cents == 0 ? '' : (value.cents ~/ 100).toString()));

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
      ref.invalidate(openingProvider(widget.chamaId));
      ref.invalidate(chamaBundleProvider(widget.chamaId));
      if (mounted) setState(() => _info = done);
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _cents(TextEditingController? c) =>
      Kes.shillings(int.tryParse(c?.text.trim() ?? '') ?? 0).cents;

  Future<void> _save(List<Member> members) => _run(() async {
        await ref.read(chamaRepositoryProvider).saveOpening(widget.chamaId, [
          for (final m in members)
            if (_cents(_savings[m.id]) > 0 || _cents(_fines[m.id]) > 0)
              {'membership_id': m.id, 'savings_cents': _cents(_savings[m.id]),
               'fines_cents': _cents(_fines[m.id])},
        ]);
      }, done: AppLocalizations.of(context).draftSaved);

  Future<void> _confirm() async {
    final repo = ref.read(chamaRepositoryProvider);
    ChallengeSent? sent;
    await _run(() async => sent = await repo.startConfirmOpening(widget.chamaId));
    final challenge = sent;
    if (challenge == null || !mounted) return;
    final ok = await confirmWithSmsCode(context, sent: challenge, onCode: (code) async {
      await repo.confirmOpening(widget.chamaId, challengeId: challenge.challengeId, code: code);
    });
    if (ok) {
      ref.invalidate(openingProvider(widget.chamaId));
      ref.invalidate(chamaBundleProvider(widget.chamaId));
    }
  }

  Future<void> _object(OpeningLine line) => _run(() async {
        await ref.read(chamaRepositoryProvider).objectToOpening(line.id, _reason.text.trim());
        _reason.clear();
      }, done: AppLocalizations.of(context).objectionSent);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bundle = ref.watch(chamaBundleProvider(widget.chamaId)).value;
    final opening = ref.watch(openingProvider(widget.chamaId));
    return Scaffold(
      appBar: AppBar(title: Text(l.openingBalances)),
      body: opening.when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (ob) {
          if (bundle == null) return const LoadingView();
          final chama = bundle.chama;
          final editing = chama.iAmTreasurer && ob.state != 'confirmed';
          final byMember = {for (final x in ob.lines) x.membershipId: x};
          final me = bundle.me;
          final myLine = me == null ? null : byMember[me.id];
          return ListView(
            padding: const EdgeInsets.all(JiraniSpace.m),
            children: [
              Notice(tone: ob.state == 'confirmed' ? NoticeTone.good : NoticeTone.info,
                  switch (ob.state) {
                'confirmed' => l.openingConfirmed(ob.confirmedBy ?? '',
                    ob.objectionUntil?.toLocal().toString().substring(0, 10) ?? ''),
                'draft' => l.openingDraftBy(ob.proposedBy ?? ''),
                _ => l.openingIntro,
              }),
              if (_error != null) ...[
                const SizedBox(height: JiraniSpace.s),
                Notice(_error!, tone: NoticeTone.critical),
              ],
              if (_info != null) ...[
                const SizedBox(height: JiraniSpace.s),
                Notice(_info!),
              ],
              SectionHeader(l.tabMembers),
              if (editing)
                // Entering: one card per member, savings and fines side by side.
                for (final m in bundle.members)
                  SurfaceCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Avatar(m.name, size: 36),
                        const SizedBox(width: 12),
                        Expanded(child: Text('${m.name} · ${m.memberCode}',
                            style: Theme.of(context).textTheme.titleSmall)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            key: ValueKey('savings-${m.memberCode}'),
                            controller: _field(_savings, m.id,
                                byMember[m.id]?.savings ?? Kes.zero),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: l.savingsLabel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            key: ValueKey('fines-${m.memberCode}'),
                            controller: _field(_fines, m.id,
                                byMember[m.id]?.fines ?? Kes.zero),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: l.finesLabel),
                          ),
                        ),
                      ]),
                    ]),
                  )
              else
                // Reading: one row per member with what they brought in.
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final (i, m) in bundle.members.indexed) ...[
                      if (i > 0) const Divider(indent: 66),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Row(children: [
                            Avatar(m.name, size: 38),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('${m.name} · ${m.memberCode}',
                                    style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 6),
                                Wrap(spacing: 6, runSpacing: 6, children: [
                                  FigureChip(l.savingsLabel,
                                      (byMember[m.id]?.savings ?? Kes.zero).format()),
                                  FigureChip(l.finesLabel,
                                      (byMember[m.id]?.fines ?? Kes.zero).format(),
                                      tone: (byMember[m.id]?.fines ?? Kes.zero).cents > 0
                                          ? JiraniTone.critical : JiraniTone.neutral),
                                ]),
                              ]),
                            ),
                          ]),
                          if ((byMember[m.id]?.objections ?? const []).isNotEmpty) ...[
                            const SizedBox(height: JiraniSpace.s),
                            Notice(
                              '${l.objectionsCount(byMember[m.id]!.objections.length)}: '
                              '${byMember[m.id]!.objections.join(' · ')}',
                              tone: NoticeTone.warning,
                            ),
                          ],
                        ]),
                      ),
                    ],
                  ]),
                ),
              if (myLine != null && ob.canObject) ...[
                const SizedBox(height: JiraniSpace.m),
                SurfaceCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TextField(controller: _reason,
                        decoration: InputDecoration(labelText: l.objectLabel)),
                    const SizedBox(height: JiraniSpace.s),
                    OutlinedButton(onPressed: _busy ? null : () => _object(myLine),
                        child: Text(l.objectButton)),
                  ]),
                ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: _actionBar(context, l, bundle, opening.value),
    );
  }

  Widget? _actionBar(BuildContext context, AppLocalizations l, ChamaBundle? bundle,
      OpeningBalances? ob) {
    if (bundle == null || ob == null || ob.state == 'confirmed') return null;
    if (bundle.chama.iAmTreasurer) {
      return ActionBar(child: PrimaryButton(label: l.saveDraft, busy: _busy,
          onPressed: () => _save(bundle.members)));
    }
    if (bundle.chama.iAmOfficial && ob.state == 'draft') {
      return ActionBar(child: PrimaryButton(label: l.confirmOpening, busy: _busy,
          onPressed: _confirm));
    }
    return null;
  }
}
