import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/locale.dart';
import '../../../core/providers.dart';
import '../../../core/tours.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/accessibility_sheet.dart';
import 'auth_layout.dart';
import 'problem_text.dart';

/// Sign-in: the country (which reads the phone number and sets the language offered),
/// the language, then the phone number.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phone = TextEditingController();
  final _countryKey = GlobalKey();
  final _languageKey = GlobalKey();
  final _phoneKey = GlobalKey();
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
    final country = countryByCode(ref.read(countryProvider));
    final phone = normalisePhoneIn(_phone.text, country.code);
    if (phone == null) {
      setState(() => _fieldError = l.phoneInvalid(country.name, country.example));
      return;
    }
    setState(() {
      _fieldError = null;
      _error = null;
      _busy = true;
    });
    try {
      final language = Localizations.localeOf(context).languageCode;
      final sent = await ref.read(authRepositoryProvider)
          .requestCode(phone, language: language, country: country.code);
      if (!mounted) return;
      context.push('/sign-in/code', extra: (phone: phone, hint: sent.phoneHint));
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<Country>(
        context: context, isScrollControlled: true, builder: (_) => const _CountrySheet());
    if (picked == null) return;
    ref.read(countryProvider.notifier).set(picked.code);
    // Offer the country's own language first, where the app has it.
    final first = picked.languages.firstWhere(translatedLanguages.contains,
        orElse: () => 'en');
    ref.read(localeProvider.notifier).set(Locale(first));
    setState(() => _fieldError = null);
  }

  List<TourStep> _steps() {
    final l = AppLocalizations.of(context);
    return [
      TourStep(target: _countryKey, icon: Icons.public_rounded, title: l.tourSignCountryTitle,
          body: l.tourSignCountryBody),
      TourStep(target: _languageKey, icon: Icons.translate_rounded, tone: JiraniTone.info,
          title: l.tourSignLanguageTitle, body: l.tourSignLanguageBody),
      TourStep(target: _phoneKey, icon: Icons.sms_outlined, tone: JiraniTone.good,
          title: l.tourSignPhoneTitle, body: l.tourSignPhoneBody),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final country = countryByCode(ref.watch(countryProvider));
    showTourOnce(context, ref, 'sign-in', _steps);
    final language = Localizations.localeOf(context).languageCode;
    return AuthLayout(
      actions: [const AccessibilityButton(), TourButton(steps: _steps)],
      hero: AuthHero(appName: l.appName, tagline: l.tagline),
      title: l.phoneTitle,
      children: [
        Row(children: [
          Expanded(
            key: _countryKey,
            child: _Choice(
              key: const ValueKey('pick-country'),
              label: l.countryLabel,
              value: '${country.flag}  ${country.name}',
              onTap: _pickCountry,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            key: _languageKey,
            child: _Choice(
              key: const ValueKey('pick-language'),
              label: l.language,
              value: languageNames[language] ?? language,
              onTap: () => showModalBottomSheet<void>(
                  context: context, isScrollControlled: true,
                  builder: (_) => _LanguageSheet(country: country)),
            ),
          ),
        ]),
        const SizedBox(height: JiraniSpace.m),
        TextField(
          key: _phoneKey,
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          style: text.titleMedium,
          decoration: InputDecoration(
            labelText: l.phoneLabel,
            hintText: country.example,
            errorText: _fieldError,
            errorMaxLines: 3,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Text(country.dial, style: text.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
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

/// A small labelled box that opens a picker.
class _Choice extends StatelessWidget {
  const _Choice({super.key, required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: text.labelSmall),
            const SizedBox(height: 2),
            Text(value, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        Icon(Icons.expand_more_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ]),
    );
  }
}

class _CountrySheet extends StatelessWidget {
  const _CountrySheet();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(JiraniSpace.m, 0, JiraniSpace.m, JiraniSpace.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.chooseCountry, style: text.titleLarge),
          const SizedBox(height: JiraniSpace.m),
          for (final c in countries)
            ListTile(
              key: ValueKey('country-${c.code}'),
              enabled: c.open,
              leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
              title: Text(c.name),
              subtitle: Text(c.open ? '${c.dial} · ${c.currency}' : l.comingSoon),
              trailing: c.open ? const Icon(Icons.chevron_right_rounded) : null,
              onTap: c.open ? () => Navigator.of(context).pop(c) : null,
            ),
        ]),
      ),
    );
  }
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet({required this.country});

  final Country country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final current = Localizations.localeOf(context).languageCode;
    // The country's languages first, then the others the app has.
    final codes = [...country.languages,
      ...translatedLanguages.where((c) => !country.languages.contains(c))];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(JiraniSpace.m, 0, JiraniSpace.m, JiraniSpace.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.chooseLanguage, style: text.titleLarge),
          const SizedBox(height: JiraniSpace.m),
          for (final code in codes)
            ListTile(
              key: ValueKey('language-$code'),
              enabled: translatedLanguages.contains(code),
              title: Text(languageNames[code] ?? code),
              subtitle: translatedLanguages.contains(code) ? null : Text(l.comingSoon),
              trailing: code == current
                  ? Icon(Icons.check_circle_rounded,
                      color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: translatedLanguages.contains(code)
                  ? () {
                      ref.read(localeProvider.notifier).set(Locale(code));
                      Navigator.of(context).pop();
                    }
                  : null,
            ),
          const SizedBox(height: JiraniSpace.s),
          Notice(l.languageComingSoon),
        ]),
      ),
    );
  }
}
