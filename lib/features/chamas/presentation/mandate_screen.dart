import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/labels.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'chama_screen.dart';
import 'widgets/sms_code_sheet.dart';

final mandateProvider = FutureProvider.autoDispose.family<Json, String>(
    (ref, chamaId) => ref.watch(chamaRepositoryProvider).bankMandate(chamaId));

/// The bank mandate (protection plan 2026-10-20): who may sign at the bank and how many
/// must sign each withdrawal. Every member sees it; an official uploads the bank's form,
/// and a DIFFERENT official confirms it with an SMS code. It is then sealed in the records.
class MandateScreen extends ConsumerStatefulWidget {
  const MandateScreen({super.key, required this.chama});

  final Chama chama;

  @override
  ConsumerState<MandateScreen> createState() => _MandateScreenState();
}

class _MandateScreenState extends ConsumerState<MandateScreen> {
  bool _busy = false;
  String? _error;

  String get _id => widget.chama.id;

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
      ref.invalidate(mandateProvider(_id));
      ref.invalidate(chamaBundleProvider(_id));
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(Json pending) async {
    final repo = ref.read(chamaRepositoryProvider);
    ChallengeSent? sent;
    await _run(() async => sent = await repo.startMandateConfirm(pending['id'] as String));
    final challenge = sent;
    if (challenge == null || !mounted) return;
    final ok = await confirmWithSmsCode(context, sent: challenge, onCode: (code) async {
      await repo.confirmBankMandate(pending['id'] as String,
          challengeId: challenge.challengeId, code: code);
    });
    if (ok) {
      ref.invalidate(mandateProvider(_id));
      ref.invalidate(chamaBundleProvider(_id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(mandateProvider(_id));
    final official = widget.chama.iAmOfficial;
    return Scaffold(
      appBar: AppBar(title: Text(l.mandateTitle)),
      body: state.when(
        loading: () => const LoadingView(),
        error: (e, _) => ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
          Notice(problemText(l, e), tone: NoticeTone.critical),
        ]),
        data: (s) {
          final current = s['current'] as Json?;
          final pending = s['pending'] as Json?;
          final options = [for (final o in s['multi_approval_options'] as List? ?? []) '$o'];
          final myCode = widget.chama.myMemberCode;
          return ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
            Notice(l.mandateWhy),
            const SizedBox(height: JiraniSpace.m),
            if (_error != null) ...[
              Notice(_error!, tone: NoticeTone.critical),
              const SizedBox(height: JiraniSpace.s),
            ],
            if (current == null)
              Notice(key: const ValueKey('mandate-missing'), l.mandateMissing,
                  tone: NoticeTone.warning)
            else
              _MandateCard(m: current, title: l.mandateCurrent, tone: JiraniTone.good),
            if (pending != null) ...[
              const SizedBox(height: JiraniSpace.m),
              _MandateCard(m: pending, title: l.mandatePending, tone: JiraniTone.warning,
                  actions: official && pending['uploaded_by'] != myCode
                      ? [
                          FilledButton(key: const ValueKey('mandate-confirm'),
                              onPressed: _busy ? null : () => _confirm(pending),
                              child: Text(l.mandateConfirm)),
                          TextButton(onPressed: _busy ? null : () => _run(() =>
                              ref.read(chamaRepositoryProvider)
                                  .rejectMandate(pending['id'] as String)),
                              child: Text(l.mandateReject)),
                        ]
                      : [Text(l.mandateWaitingOther,
                          style: Theme.of(context).textTheme.bodySmall)]),
            ],
            if (official && pending == null) ...[
              const SizedBox(height: JiraniSpace.m),
              _ProposeForm(chama: widget.chama, busy: _busy,
                  onSubmit: (ids, n, app, file) => _run(() => ref
                      .read(chamaRepositoryProvider)
                      .proposeMandate(_id, signatoryIds: ids, minSigners: n,
                          bankAppApprovals: app, filename: file.name, bytes: file.bytes))),
            ],
            if (options.isNotEmpty) ...[
              const SizedBox(height: JiraniSpace.m),
              TitledCard(
                icon: Icons.phonelink_lock_outlined,
                tone: JiraniTone.info,
                title: l.mandateSafest,
                subtitle: l.mandateSafestSub,
                children: [
                  for (final o in options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(o)),
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

class _MandateCard extends StatelessWidget {
  const _MandateCard({required this.m, required this.title, required this.tone,
      this.actions = const []});

  final Json m;
  final String title;
  final JiraniTone tone;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final signers = [for (final s in m['signatories'] as List) s as Json];
    return TitledCard(
      icon: Icons.draw_outlined,
      tone: tone,
      title: title,
      subtitle: l.mandateRule('${signers.length}', '${m['min_signers']}'),
      trailing: m['bank_app_approvals'] == true
          ? StatusPill(l.mandateAppBadge, tone: JiraniTone.good,
              icon: Icons.phonelink_lock_rounded)
          : null,
      children: [
        for (final s in signers)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Avatar('${s['name'] ?? s['member_code']}', size: 36),
            title: Text('${s['name']}'.isEmpty ? '${s['member_code']}' : '${s['name']}'),
            subtitle: Text('${s['member_code']} · ${roleLabel(l, '${s['role']}')}'),
          ),
        Text(l.mandateBy('${m['confirmed_by'] ?? '—'}', '${m['uploaded_by']}'),
            style: Theme.of(context).textTheme.bodySmall),
        if (m['receipt'] != null)
          Text(l.receipt('${m['receipt']}'), style: Theme.of(context).textTheme.bodySmall),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: JiraniSpace.s),
          Wrap(spacing: JiraniSpace.s, runSpacing: JiraniSpace.s, children: actions),
        ],
      ],
    );
  }
}

class _ProposeForm extends ConsumerStatefulWidget {
  const _ProposeForm({required this.chama, required this.busy, required this.onSubmit});

  final Chama chama;
  final bool busy;
  final void Function(List<String> ids, int minSigners, bool bankApp, PickedFile file)
      onSubmit;

  @override
  ConsumerState<_ProposeForm> createState() => _ProposeFormState();
}

class _ProposeFormState extends ConsumerState<_ProposeForm> {
  final _picked = <String>{};
  int _min = 2;
  bool _bankApp = false;
  PickedFile? _file;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final members = ref.watch(chamaBundleProvider(widget.chama.id)).value?.members
        ?? const <Member>[];
    final can = _picked.length >= 2 && _min >= 2 && _min <= _picked.length && _file != null;
    return TitledCard(
      icon: Icons.upload_file_outlined,
      title: l.mandateAdd,
      subtitle: l.mandateAddSub,
      children: [
        for (final m in members)
          CheckboxListTile(
            key: ValueKey('mandate-signer-${m.id}'),
            contentPadding: EdgeInsets.zero,
            value: _picked.contains(m.id),
            title: Text(m.name),
            subtitle: Text('${m.memberCode} · ${roleLabel(l, m.role)}'),
            onChanged: (v) => setState(() {
              v == true ? _picked.add(m.id) : _picked.remove(m.id);
              if (_min > _picked.length && _picked.length >= 2) _min = _picked.length;
            }),
          ),
        Row(children: [
          Expanded(child: Text(l.mandateMinSigners, style: Theme.of(context).textTheme.titleSmall)),
          IconButton(onPressed: _min > 2 ? () => setState(() => _min--) : null,
              icon: const Icon(Icons.remove_circle_outline)),
          Text('$_min', key: const ValueKey('mandate-min'),
              style: Theme.of(context).textTheme.titleMedium),
          IconButton(onPressed: _min < _picked.length ? () => setState(() => _min++) : null,
              icon: const Icon(Icons.add_circle_outline)),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _bankApp,
          title: Text(l.mandateBankApp),
          subtitle: Text(l.mandateBankAppSub),
          onChanged: (v) => setState(() => _bankApp = v),
        ),
        OutlinedButton.icon(
          key: const ValueKey('mandate-attach'),
          onPressed: () async {
            final f = await ref.read(fileSourceProvider).pickPhoto();
            if (f != null) setState(() => _file = f);
          },
          icon: const Icon(Icons.attach_file_rounded),
          label: Text(_file?.name ?? l.mandateAttach),
        ),
        const SizedBox(height: JiraniSpace.s),
        FilledButton(
          key: const ValueKey('mandate-submit'),
          onPressed: can && !widget.busy
              ? () => widget.onSubmit(_picked.toList(), _min, _bankApp, _file!)
              : null,
          child: Text(l.mandateSubmit),
        ),
      ],
    );
  }
}
