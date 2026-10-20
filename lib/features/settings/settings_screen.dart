import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../config.dart';
import '../../core/locale.dart';
import '../../core/prefs.dart';
import '../../core/providers.dart';
import '../../core/tours.dart';
import '../../l10n/app_localizations.dart';
import '../auth/application/session.dart';
import '../auth/presentation/problem_text.dart';
import 'accessibility_sheet.dart';
import 'data/account_repository.dart';

final profileProvider = FutureProvider.autoDispose<Profile>((ref) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(accountRepositoryProvider).profile();
});

final _signerReadyProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    return await ref.watch(phoneSignerProvider).ready();
  } catch (_) {
    return false;
  }
});

/// Settings: the person's profile, their ID check, language and country, "Easy to read",
/// this phone, privacy, help and signing out. One place for everything about *me*, not
/// about a chama.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l.settingsTitle),
        actions: const [AccessibilityButton(), SizedBox(width: 4)],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(profileProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(JiraniSpace.m, JiraniSpace.s, JiraniSpace.m,
              JiraniSpace.xl),
          children: [
            switch (profile) {
              AsyncData(:final value) => _ProfileCard(profile: value),
              AsyncError(:final error) => Notice(problemText(l, error),
                  tone: NoticeTone.critical, onTap: () => ref.invalidate(profileProvider)),
              _ => const SizedBox(height: 160, child: LoadingView()),
            },
            const SizedBox(height: JiraniSpace.m),
            _KycCard(status: profile.value?.kycStatus ?? 'not_started'),
            const SizedBox(height: JiraniSpace.m),
            _Section(l.settingsPrefs, [
              _LanguageTile(profile: profile.value),
              _CountryTile(profile: profile.value),
              _A11yTile(),
            ]),
            _Section(l.settingsPhone, [
              _SignerTile(),
              ListTile(
                leading: const Icon(Icons.replay_rounded),
                title: Text(l.settingsTours),
                subtitle: Text(l.settingsToursSub),
                onTap: () async {
                  await replayTours(ref);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.settingsToursDone)));
                  }
                },
              ),
            ]),
            _Section(l.settingsTrust, [
              _InfoTile(Icons.lock_outline_rounded, l.settingsPrivacy, l.settingsPrivacyBody),
              _InfoTile(Icons.account_balance_wallet_outlined, l.settingsMoney,
                  l.settingsMoneyBody),
              _InfoTile(Icons.link_rounded, l.settingsChain, l.settingsChainBody),
            ]),
            _Section(l.settingsAbout, [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(l.appName),
                subtitle: Text(l.settingsVersion(AppConfig.flavor)),
              ),
            ]),
            const SizedBox(height: JiraniSpace.s),
            OutlinedButton.icon(
              key: const ValueKey('settings-sign-out'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => ref.read(sessionProvider.notifier).signOut(),
              icon: const Icon(Icons.logout_rounded),
              label: Text(l.signOut),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.profile});

  final Profile profile;

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final c = TextEditingController(text: profile.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.settingsEditName),
        content: TextField(
          key: const ValueKey('settings-name'),
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l.nameLabel),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()),
              child: Text(l.save)),
        ],
      ),
    );
    if (name == null || name.length < 2 || name == profile.name) return;
    try {
      await ref.read(accountRepositoryProvider).updateProfile(name: name);
      ref.invalidate(profileProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(problemText(l, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final country = countryByCode(profile.country);
    final status = JiraniStatus.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [status.heroStart, status.heroEnd]),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
          child: Avatar(profile.name.isEmpty ? '?' : profile.name, size: 64),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(profile.name.isEmpty ? l.settingsNoName : profile.name,
                key: const ValueKey('settings-profile-name'),
                style: text.titleLarge?.copyWith(color: Colors.white)),
            const SizedBox(height: 4),
            Text([
              if (profile.phoneHint.isNotEmpty) profile.phoneHint,
              '${country.flag} ${country.name}',
            ].join(' · '), style: text.bodyMedium?.copyWith(color: Colors.white70)),
            if (profile.joined.isNotEmpty)
              Text(l.settingsJoined(profile.joined),
                  style: text.bodySmall?.copyWith(color: Colors.white60)),
          ]),
        ),
        IconButton.filledTonal(
          key: const ValueKey('settings-edit-name'),
          tooltip: l.settingsEditName,
          onPressed: () => _editName(context, ref),
          icon: const Icon(Icons.edit_outlined),
        ),
      ]),
    );
  }
}

/// The ID check: what it is, who pays, why it matters, and where this person stands.
class _KycCard extends StatelessWidget {
  const _KycCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (label, tone, icon) = switch (status) {
      'verified' => (l.kycVerified, JiraniTone.good, Icons.verified_rounded),
      'pending' => (l.kycPending, JiraniTone.info, Icons.hourglass_top_rounded),
      'failed' => (l.kycFailed, JiraniTone.critical, Icons.error_outline_rounded),
      _ => (l.kycNotStarted, JiraniTone.warning, Icons.badge_outlined),
    };
    return TitledCard(
      key: const ValueKey('settings-kyc'),
      icon: Icons.fingerprint_rounded,
      tone: tone,
      title: l.kycTitle,
      trailing: StatusPill(label, tone: tone, icon: icon),
      children: [
        Text(l.kycBody, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: JiraniSpace.s),
        _Bullet(Icons.payments_outlined, l.kycWhoPays),
        _Bullet(Icons.shield_outlined, l.kycWhy),
        _Bullet(Icons.visibility_off_outlined, l.kycPrivacy),
        if (status != 'verified') ...[
          const SizedBox(height: JiraniSpace.s),
          FilledButton.tonalIcon(
            onPressed: null,
            icon: const Icon(Icons.badge_outlined),
            label: Text(l.kycSoon),
          ),
        ],
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: JiraniSpace.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: JiraniSpace.s),
            child: Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          ),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final (i, c) in children.indexed) ...[
                if (i > 0) const Divider(indent: 56),
                c,
              ],
            ]),
          ),
        ]),
      );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(body),
      );
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final now = Localizations.localeOf(context).languageCode;
    return ListTile(
      key: const ValueKey('settings-language'),
      leading: const Icon(Icons.translate_rounded),
      title: Text(l.settingsLanguage),
      subtitle: Text(languageNames[now] ?? now),
      trailing: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'en', label: Text('EN')),
          ButtonSegment(value: 'sw', label: Text('SW')),
        ],
        selected: {now == 'sw' ? 'sw' : 'en'},
        onSelectionChanged: (s) async {
          ref.read(localeProvider.notifier).set(Locale(s.first));
          try {
            await ref.read(accountRepositoryProvider).updateProfile(language: s.first);
          } catch (_) {
            // The phone already shows the language; the server learns it next time.
          }
        },
      ),
    );
  }
}

class _CountryTile extends ConsumerWidget {
  const _CountryTile({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final code = profile?.country ?? ref.watch(countryProvider);
    final c = countryByCode(code);
    return ListTile(
      key: const ValueKey('settings-country'),
      leading: const Icon(Icons.public_rounded),
      title: Text(l.settingsCountry),
      subtitle: Text('${c.flag} ${c.name}'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(shrinkWrap: true, children: [
              for (final x in countries.where((x) => x.open))
                ListTile(
                  leading: Text(x.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(x.name),
                  trailing: x.code == code ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(context, x.code),
                ),
            ]),
          ),
        );
        if (picked == null || picked == code) return;
        try {
          await ref.read(accountRepositoryProvider).updateProfile(country: picked);
          ref.read(countryProvider.notifier).set(picked);
          ref.invalidate(profileProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(problemText(l, e))));
          }
        }
      },
    );
  }
}

class _A11yTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final a = ref.watch(a11yProvider);
    final on = [
      if (a.textScale != 1) l.a11yTextPct((a.textScale * 100).round()),
      if (a.bold) l.a11yBold,
      if (a.highContrast) l.a11yContrast,
      if (a.largeTargets) l.a11yLarge,
      if (a.reduceMotion) l.a11yCalm,
    ];
    return ListTile(
      key: const ValueKey('settings-a11y'),
      leading: const Icon(Icons.accessibility_new_rounded),
      title: Text(l.a11yTitle),
      subtitle: Text(on.isEmpty ? l.a11yOff : on.join(' · ')),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showAccessibilitySheet(context),
    );
  }
}

class _SignerTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ready = ref.watch(_signerReadyProvider).value ?? false;
    return ListTile(
      leading: Icon(ready ? Icons.key_rounded : Icons.key_off_outlined),
      title: Text(l.settingsSigner),
      subtitle: Text(ready ? l.settingsSignerOn : l.settingsSignerOff),
    );
  }
}
