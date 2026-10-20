import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/locale.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_layout.dart';
import 'problem_text.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phone = TextEditingController();
  String? _fieldError;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final phone = normalisePhone(_phone.text);
    if (phone == null) {
      setState(() => _fieldError = l.phoneInvalid);
      return;
    }
    setState(() {
      _fieldError = null;
      _error = null;
      _busy = true;
    });
    try {
      final language = Localizations.localeOf(context).languageCode;
      final sent = await ref.read(authRepositoryProvider).requestCode(phone, language: language);
      if (!mounted) return;
      context.push('/sign-in/code', extra: (phone: phone, hint: sent.phoneHint));
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
    return AuthLayout(
      actions: const [_LanguageButton()],
      hero: AuthHero(appName: l.appName, tagline: l.tagline),
      title: l.phoneTitle,
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          style: text.titleMedium,
          decoration: InputDecoration(
            labelText: l.phoneLabel,
            hintText: l.phoneHint,
            errorText: _fieldError,
            prefixIcon: const Icon(Icons.phone_iphone_rounded),
          ),
          onSubmitted: (_) => _send(),
        ),
        if (_error != null) ...[
          const SizedBox(height: JiraniSpace.m),
          Notice(_error!, tone: NoticeTone.critical),
        ],
        const SizedBox(height: JiraniSpace.l),
        PrimaryButton(label: l.sendCode, busy: _busy, onPressed: _send),
      ],
    );
  }
}

class _LanguageButton extends ConsumerWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: l.language,
      icon: const Icon(Icons.translate),
      onSelected: (code) => ref.read(localeProvider.notifier).set(Locale(code)),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'sw', child: Text('Kiswahili')),
      ],
    );
  }
}
