import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../application/session.dart';
import 'auth_layout.dart';
import 'problem_text.dart';

class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key, required this.phone, required this.phoneHint});

  final String phone;
  final String phoneHint;

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(authRepositoryProvider).verifyCode(widget.phone, _code.text);
      ref.read(sessionProvider.notifier).signedIn(hasPin: result.hasPin);
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final l = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    setState(() => _error = null);
    try {
      await ref.read(authRepositoryProvider).requestCode(widget.phone, language: language);
      _code.clear();
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthLayout(
      icon: Icons.sms_outlined,
      title: l.codeTitle,
      subtitle: l.codeSentTo(widget.phoneHint),
      children: [
        DigitsField(controller: _code, label: l.codeLabel, onSubmitted: (_) => _verify()),
        if (_error != null) ...[
          const SizedBox(height: JiraniSpace.m),
          Notice(_error!, tone: NoticeTone.critical),
        ],
        const SizedBox(height: JiraniSpace.l),
        PrimaryButton(label: l.verify, busy: _busy, onPressed: _verify),
        const SizedBox(height: JiraniSpace.s),
        TextButton(onPressed: _busy ? null : _resend, child: Text(l.resendCode)),
      ],
    );
  }
}
