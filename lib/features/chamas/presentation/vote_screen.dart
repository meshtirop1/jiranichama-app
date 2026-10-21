import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_secure_keys/jirani_secure_keys.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/api/problem.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../../automation/automation_repository.dart';
import '../data/models.dart';
import 'widgets/sms_code_sheet.dart';

final votesProvider = FutureProvider.autoDispose.family<List<VoteInfo>, String>(
    (ref, chamaId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).votes(chamaId);
});

String voteStateLabel(AppLocalizations l, String state) => switch (state) {
      'open' => l.voteOpen,
      'passed' => l.votePassed,
      'failed' => l.voteFailed,
      _ => l.voteLapsed,
    };

/// How a choice reads: yes, no, abstain, or a poll's option.
String choiceLabel(AppLocalizations l, VoteInfo v, String choice) => switch (choice) {
      'yes' => l.voteYesWord,
      'no' => l.voteNoWord,
      'abstain' => l.voteAbstainWord,
      _ => () {
          final i = int.tryParse(choice);
          return i != null && i >= 1 && i <= v.options.length ? v.options[i - 1] : choice;
        }(),
    };

/// A members' vote (5.11): the question, who has voted, and the choice: yes, no or
/// abstain, or one option of a poll. Cast with the phone key or an SMS code; where the
/// vote allows it a member may change their vote until it closes. Members comment on it
/// while it is open. The tally shows once it closes.
class VoteScreen extends ConsumerStatefulWidget {
  const VoteScreen({super.key, required this.chamaId, required this.voteId});

  final String chamaId;
  final String voteId;

  @override
  ConsumerState<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends ConsumerState<VoteScreen> {
  String? _error;
  bool _busy = false;
  String? _picked; // a poll's option, before casting
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _refresh() => ref.invalidate(votesProvider(widget.chamaId));

  Future<void> _cast(VoteInfo v, String choice) async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(chamaRepositoryProvider);
    final signer = ref.read(phoneSignerProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    ChallengeSent? sent;
    try {
      if (await signer.ready()) {
        final body = await repo.ballotPayload(v.id, choice);
        if (body['device_id'] != await signer.deviceId()) {
          throw ApiProblem(code: 'other_phone', detail: '', status: 409);
        }
        final payload = Map<String, Object?>.from(body['payload'] as Map);
        final message = canonicalJson(payload);
        if (sha256Hex(message) != body['payload_hash'] || payload['vote_id'] != v.id ||
            payload['choice'] != choice || payload['question'] != v.question) {
          throw ApiProblem(code: 'payload_changed', detail: '', status: 409);
        }
        try {
          final signature = await signer.sign(utf8.encode(message),
              title: switch (choice) {
                'yes' => l.voteYesPrompt,
                'no' => l.voteNoPrompt,
                _ => l.voteChoicePrompt(choiceLabel(l, v, choice)),
              },
              subtitle: v.question);
          await repo.submitSignedBallot(v.id, {
            'choice': choice, 'device_id': body['device_id'], 'nonce': payload['nonce'],
            'payload_hash': body['payload_hash'], 'signature': signature,
          });
          _refresh();
        } on SecureKeysCancelled {
          return;
        }
      } else {
        sent = await repo.startBallot(v.id, choice);
      }
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final challenge = sent;
    if (challenge == null || !mounted) return;
    final ok = await confirmWithSmsCode(context, sent: challenge, onCode: (code) async {
      await repo.castBallot(v.id, choice, challengeId: challenge.challengeId, code: code);
    });
    if (ok) _refresh();
  }

  Future<void> _send(VoteInfo v) async {
    final l = AppLocalizations.of(context);
    final t = _comment.text.trim();
    if (t.isEmpty) return;
    try {
      await ref.read(automationRepositoryProvider).comment(v.id, t);
      _comment.clear();
      ref.invalidate(voteCommentsProvider(v.id));
      _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    }
  }

  Widget? _actions(VoteInfo v) {
    final l = AppLocalizations.of(context);
    if (!v.iCanVote) return null;
    if (v.isPoll) {
      return ActionBar(child: PrimaryButton(
        key: const ValueKey('cast-choice'),
        label: _picked == null ? l.voteChooseFirst : l.voteCast(choiceLabel(l, v, _picked!)),
        busy: _busy,
        onPressed: _picked == null ? null : () => _cast(v, _picked!),
      ));
    }
    return ActionBar(child: Row(children: [
      Expanded(child: OutlinedButton(key: const ValueKey('vote-no'),
          onPressed: _busy ? null : () => _cast(v, 'no'), child: Text(l.voteNo))),
      const SizedBox(width: JiraniSpace.xs),
      Expanded(child: TextButton(key: const ValueKey('vote-abstain'),
          onPressed: _busy ? null : () => _cast(v, 'abstain'), child: Text(l.voteAbstain))),
      const SizedBox(width: JiraniSpace.xs),
      Expanded(child: PrimaryButton(key: const ValueKey('vote-yes'), label: l.voteYes,
          busy: _busy, onPressed: () => _cast(v, 'yes'))),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final v = ref.watch(votesProvider(widget.chamaId)).value
        ?.where((x) => x.id == widget.voteId).firstOrNull;
    if (v == null) {
      return Scaffold(appBar: AppBar(), body: const LoadingView());
    }
    final comments = ref.watch(voteCommentsProvider(v.id)).value ?? const [];
    final closed = v.state != 'open';
    return Scaffold(
      appBar: AppBar(title: Text(l.membersVote)),
      bottomNavigationBar: _actions(v),
      body: ListView(
        padding: const EdgeInsets.all(JiraniSpace.m),
        children: [
          Text(v.question, style: text.titleLarge),
          if (v.raisedBy != null) Text(l.motBy(v.raisedBy!), style: text.bodySmall),
          if (v.details.isNotEmpty) ...[
            const SizedBox(height: JiraniSpace.s),
            Text(v.details, style: text.bodyMedium),
          ],
          const SizedBox(height: JiraniSpace.s),
          Text(voteStateLabel(l, v.state), style: text.titleSmall),
          if (!closed)
            Text(l.voteCloses(v.closesAt.substring(0, 16).replaceFirst('T', ' '))),
          const SizedBox(height: JiraniSpace.s),
          Text(l.voteTurnout('${v.cast}', '${v.eligible}', '${v.quorumNeeded}')),
          Text(v.isPoll ? l.votePollRule : l.voteRule('${v.passPct}')),
          Text(l.voteAbstainNote, style: text.bodySmall),
          if (v.secret) Text(l.voteSecret, style: text.bodySmall),
          if (_error != null) ...[
            const SizedBox(height: JiraniSpace.s),
            Notice(_error!, tone: NoticeTone.critical),
          ],
          if (v.iVoted) ...[
            const SizedBox(height: JiraniSpace.s),
            Notice(key: const ValueKey('my-vote'), [
              switch (v.myChoice) {
                null => l.youVoted,
                'yes' => l.youVotedYes,
                'no' => l.youVotedNo,
                final c => l.youChose(choiceLabel(l, v, c)),
              },
              if (v.allowChange && !closed) l.voteCanChange,
            ].join(' ')),
          ],
          // A poll: the options to choose from, then the counts once it closes.
          if (v.isPoll) ...[
            const SizedBox(height: JiraniSpace.m),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: RadioGroup<String>(
                groupValue: _picked,
                onChanged: (c) => setState(() => _picked = c),
                child: Column(children: [
                  for (final (i, o) in v.options.indexed)
                    _OptionRow(
                      key: ValueKey('option-${i + 1}'),
                      value: '${i + 1}', label: o, enabled: v.iCanVote,
                      onTap: () => setState(() => _picked = '${i + 1}'),
                      count: closed ? v.optionCounts['${i + 1}'] : null,
                      won: closed && v.winner == i + 1),
                  _OptionRow(key: const ValueKey('option-abstain'), value: 'abstain',
                      label: l.voteAbstainWord, enabled: v.iCanVote,
                      onTap: () => setState(() => _picked = 'abstain'),
                      count: closed ? v.abstain : null),
                ]),
              ),
            ),
          ],
          if (!v.isPoll && v.yes != null) ...[
            const SizedBox(height: JiraniSpace.m),
            Text(l.voteTally('${v.yes}', '${v.no}'), style: text.titleMedium),
            if ((v.abstain ?? 0) > 0) Text(l.voteAbstained('${v.abstain}')),
          ],
          if (closed && v.receipt != null)
            Text('${l.receiptLabel}: ${v.receipt}', style: text.bodySmall),
          const SizedBox(height: JiraniSpace.m),
          Text(l.whoVoted, style: text.titleSmall),
          for (final name in v.voted) Text('• $name'),
          // What members say about it.
          const SizedBox(height: JiraniSpace.m),
          Text(l.voteComments('${comments.length}'), style: text.titleSmall),
          for (final c in comments)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SurfaceCard(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: text.labelLarge),
                  const SizedBox(height: 2),
                  Text(c.text),
                ]),
              ),
            ),
          if (!closed) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(key: const ValueKey('comment-field'),
                  controller: _comment, maxLength: 1000, minLines: 1, maxLines: 4,
                  decoration: InputDecoration(labelText: l.voteCommentHint))),
              IconButton(key: const ValueKey('comment-send'), tooltip: l.voteCommentSend,
                  onPressed: () => _send(v), icon: const Icon(Icons.send_rounded)),
            ]),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({super.key, required this.value, required this.label,
      required this.enabled, required this.onTap, this.count, this.won = false});

  final String value;
  final VoidCallback onTap;
  final String label;
  final bool enabled;
  final int? count;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      leading: enabled ? Radio<String>(value: value)
          : Icon(won ? Icons.emoji_events_rounded : Icons.circle_outlined,
              color: won ? JiraniStatus.of(context).good : null),
      title: Text(label, style: won ? text.titleMedium : null),
      trailing: count == null ? null : Text('$count', style: text.titleMedium),
      onTap: enabled ? onTap : null,
    );
  }
}
