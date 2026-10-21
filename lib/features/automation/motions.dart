import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../l10n/app_localizations.dart';
import '../auth/presentation/problem_text.dart';
import '../chamas/presentation/vote_screen.dart';
import 'automation_repository.dart';
import 'models.dart';

String motionStateLabel(AppLocalizations l, MotionInfo m) => switch (m.state) {
      'seconding' => l.motSeconding('${m.seconds}', '${m.secondsNeeded}'),
      'voting' => l.voteOpen,
      'passed' => l.votePassed,
      'failed' => l.voteFailed,
      'lapsed' => l.voteLapsed,
      'withdrawn' => l.motWithdrawn,
      _ => l.motExpired,
    };

/// The way in from "Running the chama": how many motions wait for this member.
class MotionsCard extends ConsumerWidget {
  const MotionsCard({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final motions = ref.watch(motionsProvider(chamaId)).value ?? const <MotionInfo>[];
    final waiting = motions.where((m) => m.iCanSecond || (m.vote?.iCanVote ?? false)).length;
    return NavTile(
      key: const ValueKey('motions-card'),
      icon: Icons.record_voice_over_outlined,
      tone: JiraniTone.info,
      title: l.motTitle,
      subtitle: l.motSubtitle,
      badge: waiting > 0 ? '$waiting' : null,
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MotionsScreen(chamaId: chamaId))),
    );
  }
}

/// Questions members put to the chama. Any member raises one; once enough others second
/// it, everyone votes: yes or no, or one of several options.
class MotionsScreen extends ConsumerStatefulWidget {
  const MotionsScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<MotionsScreen> createState() => _MotionsScreenState();
}

class _MotionsScreenState extends ConsumerState<MotionsScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(motionsProvider(widget.chamaId));
    } catch (e) {
      setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final repo = ref.read(automationRepositoryProvider);
    final motions = ref.watch(motionsProvider(widget.chamaId));
    return Scaffold(
      appBar: AppBar(title: Text(l.motTitle)),
      bottomNavigationBar: ActionBar(child: PrimaryButton(
        key: const ValueKey('raise-motion'),
        label: l.motRaise,
        onPressed: () async {
          final made = await Navigator.of(context).push<bool>(MaterialPageRoute(
              builder: (_) => RaiseMotionScreen(chamaId: widget.chamaId)));
          if (made == true) ref.invalidate(motionsProvider(widget.chamaId));
        },
      )),
      body: motions.when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (items) => ListView(
          padding: const EdgeInsets.all(JiraniSpace.m),
          children: [
            Notice(l.motIntro),
            if (_error != null) ...[
              const SizedBox(height: JiraniSpace.s),
              Notice(_error!, tone: NoticeTone.critical),
            ],
            const SizedBox(height: JiraniSpace.s),
            if (items.isEmpty)
              SurfaceCard(child: EmptyState(icon: Icons.record_voice_over_outlined,
                  title: l.motEmpty)),
            for (final m in items)
              SurfaceCard(
                key: ValueKey('motion-${m.id}'),
                margin: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    ToneIcon(m.kind == 'choice' ? Icons.ballot_outlined
                        : Icons.how_to_vote_outlined, tone: JiraniTone.info, size: 38),
                    const SizedBox(width: 12),
                    Expanded(child: Text(m.question, style: text.titleMedium)),
                  ]),
                  const SizedBox(height: 8),
                  Text('${l.motBy(m.raisedBy)} · ${motionStateLabel(l, m)}',
                      style: text.bodySmall),
                  if (m.details.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(m.details, style: text.bodyMedium),
                  ],
                  if (m.options.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (final (i, o) in m.options.indexed) Text('${i + 1}. $o'),
                  ],
                  if (m.secondedBy.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(l.motSecondedBy(m.secondedBy.join(', ')), style: text.bodySmall),
                  ],
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (m.iCanSecond)
                      FilledButton.tonal(
                        key: ValueKey('second-${m.id}'),
                        onPressed: _busy ? null : () => _run(() => repo.secondMotion(m.id)),
                        child: Text(l.motSecond)),
                    if (m.mine && m.state == 'seconding')
                      TextButton(
                        key: ValueKey('withdraw-${m.id}'),
                        onPressed: _busy ? null : () => _run(() => repo.withdrawMotion(m.id)),
                        child: Text(l.motWithdraw)),
                    if (m.vote != null)
                      OutlinedButton(
                        key: ValueKey('motion-vote-${m.id}'),
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => VoteScreen(chamaId: widget.chamaId,
                                  voteId: m.vote!.id)));
                          ref.invalidate(motionsProvider(widget.chamaId));
                        },
                        child: Text(m.vote!.iCanVote ? l.motVoteNow : l.motSeeVote)),
                  ]),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

/// Raising a motion: the question, why, and either yes/no or two to six options.
class RaiseMotionScreen extends ConsumerStatefulWidget {
  const RaiseMotionScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<RaiseMotionScreen> createState() => _RaiseMotionScreenState();
}

class _RaiseMotionScreenState extends ConsumerState<RaiseMotionScreen> {
  final _question = TextEditingController();
  final _details = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  bool _poll = false;
  int _days = 7;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_question, _details, ..._options]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(automationRepositoryProvider).raiseMotion(widget.chamaId, {
        'kind': _poll ? 'choice' : 'yes_no',
        'question': _question.text.trim(),
        'details': _details.text.trim(),
        if (_poll) 'options': [for (final o in _options) o.text.trim()]
            .where((o) => o.isNotEmpty).toList(),
        'vote_days': _days,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.motRaise)),
      bottomNavigationBar: ActionBar(child: PrimaryButton(
          key: const ValueKey('send-motion'), label: l.motSend, busy: _busy,
          onPressed: _send)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        TextField(key: const ValueKey('motion-question'), controller: _question,
            maxLength: 300, decoration: InputDecoration(labelText: l.motQuestion)),
        TextField(key: const ValueKey('motion-details'), controller: _details, maxLines: 4,
            decoration: InputDecoration(labelText: l.motDetails)),
        const SizedBox(height: JiraniSpace.m),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l.motYesNo)),
            ButtonSegment(value: true, label: Text(l.motPoll)),
          ],
          selected: {_poll},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _poll = s.first),
        ),
        if (_poll) ...[
          const SizedBox(height: JiraniSpace.s),
          for (final (i, c) in _options.indexed)
            TextField(key: ValueKey('motion-option-$i'), controller: c, maxLength: 80,
                decoration: InputDecoration(labelText: l.motOption('${i + 1}'))),
          if (_options.length < 6)
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(
              key: const ValueKey('add-option'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.motAddOption),
              onPressed: () => setState(() => _options.add(TextEditingController())),
            )),
        ],
        const SizedBox(height: JiraniSpace.s),
        Text(l.motDays('$_days')),
        Slider(value: _days.toDouble(), min: 1, max: 14, divisions: 13,
            label: '$_days', onChanged: (v) => setState(() => _days = v.round())),
        Text(l.motHowItWorks, style: Theme.of(context).textTheme.bodySmall),
        if (_error != null) ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(_error!, tone: NoticeTone.critical),
        ],
      ]),
    );
  }
}
