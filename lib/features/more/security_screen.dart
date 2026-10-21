import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../l10n/app_localizations.dart';
import '../auth/application/session.dart';
import '../auth/presentation/problem_text.dart';
import '../automation/automation_repository.dart';
import '../chamas/data/models.dart';

final myDevicesProvider = FutureProvider.autoDispose<List<Json>>(
    (ref) => ref.watch(automationRepositoryProvider).myDevices());

/// The account's safety: change the app PIN, see the phones whose keys sign for this
/// account (and retire a lost one), sign out.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _current = TextEditingController();
  final _pin = TextEditingController();
  final _again = TextEditingController();
  String? _message;
  bool _good = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_current, _pin, _again]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _changePin() async {
    final l = AppLocalizations.of(context);
    if (_pin.text.length != 6 || _pin.text != _again.text) {
      setState(() {
        _message = l.secPinMismatch;
        _good = false;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(automationRepositoryProvider)
          .changePin(current: _current.text, pin: _pin.text);
      for (final c in [_current, _pin, _again]) {
        c.clear();
      }
      setState(() {
        _message = l.secPinChanged;
        _good = true;
      });
    } catch (e) {
      setState(() {
        _message = problemText(l, e);
        _good = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(Json d) async {
    final l = AppLocalizations.of(context);
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: Text(l.secRevokeTitle),
          content: Text(l.secRevokeBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.secRevoke)),
          ],
        ));
    if (yes != true) return;
    await ref.read(automationRepositoryProvider).revokeDevice(d['id'] as String);
    ref.invalidate(myDevicesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final devices = ref.watch(myDevicesProvider).value ?? const <Json>[];
    Widget pinField(Key key, TextEditingController c, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(key: key, controller: c, obscureText: true, maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: label, counterText: '')),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.secTitle)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        TitledCard(
          icon: Icons.pin_outlined,
          tone: JiraniTone.brand,
          title: l.secPinTitle,
          subtitle: l.secPinBody,
          children: [
            pinField(const ValueKey('pin-current'), _current, l.secPinCurrent),
            pinField(const ValueKey('pin-new'), _pin, l.secPinNew),
            pinField(const ValueKey('pin-again'), _again, l.secPinAgain),
            if (_message != null)
              Padding(padding: const EdgeInsets.only(bottom: 8),
                  child: Notice(_message!,
                      tone: _good ? NoticeTone.good : NoticeTone.critical)),
            PrimaryButton(key: const ValueKey('pin-change'), label: l.secPinChange,
                busy: _busy, onPressed: _changePin),
          ],
        ),
        const SizedBox(height: JiraniSpace.s),
        TitledCard(
          icon: Icons.phonelink_lock_outlined,
          tone: JiraniTone.info,
          title: l.secPhonesTitle,
          subtitle: l.secPhonesBody,
          children: [
            if (devices.isEmpty) Text(l.secNoPhones, style: text.bodyMedium),
            for (final d in devices)
              ListTile(
                key: ValueKey('device-${d['id']}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(d['state'] == 'active' ? Icons.verified_user_outlined
                    : Icons.phonelink_off_outlined),
                title: Text('${d['label'] ?? d['platform']}'),
                subtitle: Text([
                  switch (d['state']) {
                    'active' => l.secActive,
                    'pending' => l.secPending,
                    _ => l.secRetired,
                  },
                  if (d['security_level'] != null) '${d['security_level']}',
                  if (d['registered_at'] != null)
                    (d['registered_at'] as String).substring(0, 10),
                ].join(' · ')),
                trailing: d['state'] == 'revoked' ? null : TextButton(
                    key: ValueKey('revoke-${d['id']}'),
                    onPressed: () => _revoke(d), child: Text(l.secRevoke)),
              ),
          ],
        ),
        const SizedBox(height: JiraniSpace.m),
        OutlinedButton.icon(
          key: const ValueKey('sign-out'),
          icon: const Icon(Icons.logout_rounded),
          label: Text(l.signOut),
          onPressed: () => ref.read(sessionProvider.notifier).signOut(),
        ),
      ]),
    );
  }
}
