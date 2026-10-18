import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/labels.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'widgets/rule_book_list.dart';
import 'widgets/sms_code_sheet.dart';

/// Join with an invite code: read the chama's rules first, then accept them with an SMS
/// code that names the chama (5.2).
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _code = TextEditingController();
  InviteDetail? _invite;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _find() => _run(() async {
        final detail = await ref.read(chamaRepositoryProvider).inviteDetail(_code.text.trim());
        setState(() => _invite = detail);
      });

  Future<void> _accept() async {
    final repo = ref.read(chamaRepositoryProvider);
    final code = _code.text.trim();
    ChallengeSent? sent;
    // Busy only while the code is being sent, not while the member types it.
    await _run(() async => sent = await repo.startJoin(code));
    final challenge = sent;
    if (challenge == null || !mounted) return;
    final ok = await confirmWithSmsCode(context, sent: challenge, onCode: (sms) async {
      await repo.confirmJoin(code, challengeId: challenge.challengeId, smsCode: sms);
    });
    if (ok && mounted) context.pushReplacement('/chamas/${_invite!.chamaId}');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final invite = _invite;
    return Scaffold(
      appBar: AppBar(title: Text(l.joinTitle)),
      bottomNavigationBar: invite == null
          ? null
          : ActionBar(child: PrimaryButton(label: l.joinAccept, busy: _busy, onPressed: _accept)),
      body: ListView(
        padding: const EdgeInsets.all(JiraniSpace.l),
        children: [
          if (invite == null) ...[
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(labelText: l.inviteCodeLabel),
              onSubmitted: (_) => _find(),
            ),
            const SizedBox(height: JiraniSpace.l),
            if (_error != null) ...[
              Notice(_error!, tone: NoticeTone.critical),
              const SizedBox(height: JiraniSpace.m),
            ],
            PrimaryButton(label: l.verify, busy: _busy, onPressed: _find),
          ] else ...[
            Text(l.joinAs(invite.chamaName, roleLabel(l, invite.role)),
                style: Theme.of(context).textTheme.titleMedium),
            if (_error != null) ...[
              const SizedBox(height: JiraniSpace.m),
              Notice(_error!, tone: NoticeTone.critical),
            ],
            const SizedBox(height: JiraniSpace.m),
            RuleBookList(invite.book),
          ],
        ],
      ),
    );
  }
}
