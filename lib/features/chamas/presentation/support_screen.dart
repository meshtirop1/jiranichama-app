import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';

final supportGrantsProvider = FutureProvider.autoDispose.family<List<SupportGrantInfo>, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).supportGrants(id);
});

String supportAreaLabel(AppLocalizations l, String a) => switch (a) {
      'statements' => l.areaStatements,
      'rules' => l.areaRules,
      'ledger' => l.areaLedger,
      'members' => l.areaMembers,
      _ => l.areaDisputes,
    };

String _when(BuildContext context, String iso) {
  final t = DateTime.parse(iso).toLocal();
  final loc = MaterialLocalizations.of(context);
  return '${loc.formatMediumDate(t)} ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(t))}';
}

/// Shown to every member while support can read the chama's records (5.16).
class SupportNotice extends ConsumerWidget {
  const SupportNotice({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final active = (ref.watch(supportGrantsProvider(chamaId)).value ?? const [])
        .where((g) => g.state == 'active').firstOrNull;
    if (active == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: JiraniSpace.xs),
      child: Notice(l.supportActive(active.areas.map((a) => supportAreaLabel(l, a)).join(', '),
          _when(context, active.endsAt!)), tone: NoticeTone.warning),
    );
  }
}

/// Officials ask JiraniChama support for help: what support may read, and for how long.
/// A second official confirms; every member is told; any official can end it.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key, required this.chama});

  final Chama chama;

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _reason = TextEditingController();
  final Set<String> _areas = {'statements'};
  int _hours = 72;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(supportGrantsProvider(widget.chama.id));
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final repo = ref.read(chamaRepositoryProvider);
    final grants = ref.watch(supportGrantsProvider(widget.chama.id)).value ?? const [];
    final open = grants.where((g) => g.state == 'requested' || g.state == 'active')
        .firstOrNull;
    final myCode = widget.chama.myMemberCode;
    return Scaffold(
      appBar: AppBar(title: Text(l.supportTitle)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Notice(l.supportIntro),
        if (_error != null) ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(_error!, tone: NoticeTone.critical),
        ],
        const SizedBox(height: JiraniSpace.m),
        if (open != null) ...[
          Text(open.state == 'active'
              ? l.supportActive(open.areas.map((a) => supportAreaLabel(l, a)).join(', '),
                  _when(context, open.endsAt!))
              : l.supportWaiting(open.requestedBy), style: text.titleSmall),
          Text(open.reason, style: text.bodySmall),
          const SizedBox(height: JiraniSpace.s),
          if (open.state == 'requested' && open.requestedBy != myCode)
            FilledButton(key: const ValueKey('support-confirm'),
                onPressed: _busy ? null : () => _run(() => repo.confirmSupport(open.id)),
                child: Text(l.supportConfirm)),
          OutlinedButton(key: const ValueKey('support-revoke'),
              onPressed: _busy ? null : () => _run(() => repo.revokeSupport(open.id)),
              child: Text(l.supportRevoke)),
        ] else ...[
          Text(l.supportWhat, style: text.titleSmall),
          for (final a in const ['statements', 'rules', 'ledger', 'members', 'disputes'])
            CheckboxListTile(
              key: ValueKey('area-$a'),
              contentPadding: EdgeInsets.zero,
              title: Text(supportAreaLabel(l, a)),
              value: _areas.contains(a),
              onChanged: (v) => setState(() => v == true ? _areas.add(a) : _areas.remove(a)),
            ),
          Text(l.supportHowLong, style: text.titleSmall),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 24, label: Text(l.hoursN(24))),
              ButtonSegment(value: 72, label: Text(l.hoursN(72))),
              ButtonSegment(value: 168, label: Text(l.daysN(7))),
            ],
            selected: {_hours},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _hours = s.first),
          ),
          TextField(key: const ValueKey('support-reason'), controller: _reason, maxLines: 2,
              decoration: InputDecoration(labelText: l.supportReason)),
          const SizedBox(height: JiraniSpace.s),
          FilledButton(
            key: const ValueKey('support-ask'),
            onPressed: _busy || _areas.isEmpty ? null : () => _run(() => repo.requestSupport(
                widget.chama.id, areas: _areas.toList(), hours: _hours,
                reason: _reason.text.trim())),
            child: Text(l.supportAsk),
          ),
        ],
      ]),
    );
  }
}
