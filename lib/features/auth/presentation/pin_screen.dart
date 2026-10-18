import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../application/session.dart';
import 'problem_text.dart';

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_pin.text.length != 6) return;
    if (_pin.text != _confirm.text) {
      setState(() => _error = l.pinMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).setPin(_pin.text);
      ref.read(sessionProvider.notifier).pinSet();
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(JiraniSpace.l),
          children: [
            Text(l.pinTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: JiraniSpace.s),
            Text(l.pinBody),
            const SizedBox(height: JiraniSpace.l),
            DigitsField(controller: _pin, label: l.pinLabel, obscure: true),
            const SizedBox(height: JiraniSpace.m),
            DigitsField(
              controller: _confirm,
              label: l.pinConfirmLabel,
              obscure: true,
              autofocus: false,
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: JiraniSpace.m),
              Notice(_error!, tone: NoticeTone.critical),
            ],
            const SizedBox(height: JiraniSpace.l),
            PrimaryButton(label: l.savePin, busy: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
