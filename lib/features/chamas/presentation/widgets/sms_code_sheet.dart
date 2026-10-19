import 'package:flutter/material.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/problem_text.dart';
import '../../data/models.dart';

/// Asks for the SMS code the server just sent, and runs [onCode] with it. Wrong codes
/// are shown in the sheet with the tries left. Returns true once [onCode] succeeds.
Future<bool> confirmWithSmsCode(
  BuildContext context, {
  required ChallengeSent sent,
  required Future<void> Function(String code) onCode,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SmsCodeSheet(sent: sent, onCode: onCode),
  );
  return ok ?? false;
}

class _SmsCodeSheet extends StatefulWidget {
  const _SmsCodeSheet({required this.sent, required this.onCode});

  final ChallengeSent sent;
  final Future<void> Function(String code) onCode;

  @override
  State<_SmsCodeSheet> createState() => _SmsCodeSheetState();
}

class _SmsCodeSheetState extends State<_SmsCodeSheet> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onCode(_code.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: JiraniSpace.l,
        right: JiraniSpace.l,
        top: JiraniSpace.l,
        bottom: MediaQuery.viewInsetsOf(context).bottom + JiraniSpace.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.smsSheetTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: JiraniSpace.s),
          Text(l.smsSentTo(widget.sent.sentTo)),
          const SizedBox(height: JiraniSpace.m),
          DigitsField(controller: _code, label: l.codeLabel, onSubmitted: (_) => _submit()),
          if (_error != null) ...[
            const SizedBox(height: JiraniSpace.m),
            Notice(_error!, tone: NoticeTone.critical),
          ],
          const SizedBox(height: JiraniSpace.l),
          PrimaryButton(label: l.confirm, busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}
