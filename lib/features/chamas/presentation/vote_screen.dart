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

/// A members' vote (5.11): the question, who has voted, and Yes / No with the phone key
/// or an SMS code. The tally shows once it closes.
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
              title: choice == 'yes' ? l.voteYesPrompt : l.voteNoPrompt, subtitle: v.question);
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final v = ref.watch(votesProvider(widget.chamaId)).value
        ?.where((x) => x.id == widget.voteId).firstOrNull;
    if (v == null) {
      return Scaffold(appBar: AppBar(),
          body: const LoadingView());
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.membersVote)),
      bottomNavigationBar: v.iCanVote
          ? ActionBar(child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _cast(v, 'no'),
                  child: Text(l.voteNo))),
              const SizedBox(width: JiraniSpace.s),
              Expanded(child: PrimaryButton(label: l.voteYes, busy: _busy,
                  onPressed: () => _cast(v, 'yes'))),
            ]))
          : null,
      body: ListView(
        padding: const EdgeInsets.all(JiraniSpace.m),
        children: [
          Text(v.question, style: text.titleLarge),
          const SizedBox(height: JiraniSpace.s),
          Text(voteStateLabel(l, v.state), style: text.titleSmall),
          if (v.state == 'open') Text(l.voteCloses(v.closesAt.substring(0, 16).replaceFirst('T', ' '))),
          const SizedBox(height: JiraniSpace.s),
          Text(l.voteTurnout('${v.cast}', '${v.eligible}', '${v.quorumNeeded}')),
          Text(l.voteRule('${v.passPct}')),
          if (v.secret) Text(l.voteSecret, style: text.bodySmall),
          if (_error != null) ...[
            const SizedBox(height: JiraniSpace.s),
            Notice(_error!, tone: NoticeTone.critical),
          ],
          if (v.iVoted) ...[
            const SizedBox(height: JiraniSpace.s),
            Notice(v.myChoice == null ? l.youVoted
                : (v.myChoice == 'yes' ? l.youVotedYes : l.youVotedNo)),
          ],
          if (v.yes != null) ...[
            const SizedBox(height: JiraniSpace.m),
            Text(l.voteTally('${v.yes}', '${v.no}'), style: text.titleMedium),
            if (v.receipt != null) Text('${l.receiptLabel}: ${v.receipt}', style: text.bodySmall),
          ],
          const SizedBox(height: JiraniSpace.m),
          Text(l.whoVoted, style: text.titleSmall),
          for (final name in v.voted) Text('• $name'),
        ],
      ),
    );
  }
}
