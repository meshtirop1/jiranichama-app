import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiranichama/app.dart';
import 'package:jiranichama/core/prefs.dart';
import 'package:jiranichama/core/providers.dart';
import 'package:jiranichama/features/auth/data/auth_repository.dart';
import 'package:jiranichama/features/chamas/application/chain_check.dart';
import 'package:jiranichama/features/registration/registration_screen.dart';
import 'package:jiranichama/features/settings/accessibility_sheet.dart';
import 'package:jiranichama/features/settings/data/account_repository.dart';

import 'fakes.dart';

class _SignedIn implements AuthRepository {
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<CodeSent> requestCode(String phone, {required String language, String country = 'KE'}) =>
      throw UnimplementedError();
  @override
  Future<SignedIn> verifyCode(String phone, String code) => throw UnimplementedError();
  @override
  Future<void> setPin(String pin) async {}
  @override
  Future<void> setProfile({required String name, required String language, String? country}) async {}
  @override
  Future<void> signOut() async {}
}

final _guide = <String, dynamic>{
  'country': 'KE',
  'detailed': true,
  'disclaimer': 'This is a guide, not legal advice.',
  'routes': [
    {
      'id': 'community_group', 'title': 'Register as a self-help (community) group',
      'office': 'Sub-County Social Development Office', 'law': 'Department of Social Development',
      'who': 'Most chamas.', 'fee': 'About KES 1,000', 'time': 'Same day', 'renew': 'Every year',
      'steps': ['Hold the founding meeting.', 'Take the papers to the office.'],
      'papers': ['constitution', 'id_copies'],
    },
    {
      'id': 'bank_account', 'title': "Open the chama's bank account", 'office': 'Any bank',
      'law': 'AML', 'who': 'Everyone', 'fee': 'Free', 'time': 'A day', 'renew': '',
      'steps': ['Agree the signatories.'], 'papers': ['bank_resolution'],
    },
  ],
  'papers': {
    'constitution': {'made_by': 'app', 'title': 'Constitution', 'what': 'Your rules.'},
    'id_copies': {'made_by': 'you', 'title': 'Copies of national IDs', 'what': 'Officials.'},
    'bank_resolution': {'made_by': 'app', 'title': 'Resolution', 'what': 'Signatories.'},
  },
};

class FakeAccountRepository implements AccountRepository {
  final calls = <String>[];
  var name = 'Jane Wanjiku';
  final ticked = <String>[];
  var certificate = '';

  Map<String, dynamic> get _reg => {
        'guide': _guide, 'route': 'community_group', 'ticked': [...ticked],
        'missing': [for (final p in ['constitution', 'id_copies']) if (!ticked.contains(p)) p],
        'certificate_no': certificate, 'registered_on': certificate.isEmpty ? null : '2026-10-20',
        'registered': certificate.isNotEmpty, 'can_edit': true, 'remind': certificate.isEmpty,
      };

  @override
  Future<Profile> profile() async => Profile({
        'id': 'u1', 'phone_hint': '+254 7•• ••• 678', 'display_name': name, 'language': 'en',
        'country': 'KE', 'has_pin': true, 'kyc_status': 'not_started',
        'date_joined': '2026-01-05T08:00:00Z',
      });

  @override
  Future<Profile> updateProfile({String? name, String? language, String? country}) async {
    calls.add('profile:${name ?? ''}:${language ?? ''}:${country ?? ''}');
    if (name != null) this.name = name;
    return profile();
  }

  @override
  Future<RegistrationGuide> guide(String country, String language) async {
    calls.add('guide:$country:$language');
    return RegistrationGuide(_guide);
  }

  @override
  Future<ChamaRegistration> registration(String chamaId, String language) async =>
      ChamaRegistration(_reg);

  @override
  Future<ChamaRegistration> updateRegistration(String chamaId, Map<String, Object?> change,
      String language) async {
    calls.add('reg:$change');
    if (change['tick'] case final String t) ticked.add(t);
    if (change['untick'] case final String t) ticked.remove(t);
    if (change['certificate_no'] case final String c) certificate = c;
    return ChamaRegistration(_reg);
  }

  @override
  Future<List<int>> paper(String chamaId, String paper, String language) async {
    calls.add('paper:$paper:$language');
    return [37, 80, 68, 70];
  }
}

Future<(FakeAccountRepository, FakeDocumentSaver, MemoryPrefsStore)> _pump(
    WidgetTester tester, {FakeChamaRepository? repo}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final account = FakeAccountRepository();
  final saver = FakeDocumentSaver();
  final prefs = MemoryPrefsStore();
  await tester.pumpWidget(ProviderScope(overrides: [
    authRepositoryProvider.overrideWithValue(_SignedIn()),
    chamaRepositoryProvider.overrideWithValue(repo ?? FakeChamaRepository()),
    accountRepositoryProvider.overrideWithValue(account),
    documentSaverProvider.overrideWithValue(saver),
    prefsStoreProvider.overrideWithValue(prefs),
    phoneSignerProvider.overrideWithValue(FakePhoneSigner()),
    chainRunnerProvider.overrideWithValue((work) async => work()),
    trustStoreProvider.overrideWithValue(MemoryTrustStore()),
  ], child: const JiraniApp()));
  await tester.pumpAndSettle();
  return (account, saver, prefs);
}

void main() {
  testWidgets('"Easy to read" makes the text bigger and bolder, and remembers it',
      (tester) async {
    final (_, _, prefs) = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('a11y-button')));
    await tester.pumpAndSettle();
    expect(find.text('Easy to read'), findsWidgets);
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('a11y-bigger')), warnIfMissed: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('a11y-bigger')));
    await tester.pumpAndSettle();
    expect(find.text('130%'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('a11y-bold')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('a11y-contrast')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('a11y-contrast')));
    await tester.pumpAndSettle();

    final media = MediaQuery.of(tester.element(find.byKey(const ValueKey('a11y-contrast'))));
    expect(media.textScaler.scale(10), closeTo(13, .01));
    expect(media.boldText, isTrue);
    expect(media.highContrast, isTrue);
    expect(prefs.values['a11y'], contains('"text":1.3'));
    expect(prefs.values['a11y'], contains('"contrast":true'));

    await tester.dragUntilVisible(find.byKey(const ValueKey('a11y-reset')),
        find.byType(AccessibilitySheet), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('a11y-reset')));
    await tester.pumpAndSettle();
    expect(prefs.values['a11y'], contains('"text":1.0'));
    expect(MediaQuery.of(tester.element(find.byKey(const ValueKey('a11y-reset'))))
        .boldText, isFalse);
  });

  testWidgets('Settings shows my profile and ID check, and I change my name', (tester) async {
    final (account, _, _) = await _pump(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Jane Wanjiku'), findsOneWidget);
    expect(find.text('ID check'), findsOneWidget);
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.text('Your chama pays for the check; you pay nothing.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-edit-name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('settings-name')), 'Jane W. Kamau');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(account.calls, contains('profile:Jane W. Kamau::'));
    expect(find.text('Jane W. Kamau'), findsOneWidget);
  });

  testWidgets('an official prepares the registration papers and ticks them off',
      (tester) async {
    final (account, saver, _) = await _pump(tester);
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.text('Make your chama official'), findsOneWidget);
    expect(find.text('0 of 4 ready'), findsOneWidget);
    expect(find.text('Sub-County Social Development Office'), findsOneWidget);
    expect(find.text('We prepare this'), findsOneWidget);
    expect(find.text('You bring this'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('reg-make-constitution')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reg-make-constitution')));
    await tester.pumpAndSettle();
    expect(account.calls, contains('paper:constitution:en'));
    expect(saver.saved.keys, contains('JiraniChama-constitution.pdf'));
    expect(saver.shared.single, contains('Constitution'));

    await tester.tap(find.byKey(const ValueKey('reg-tick-constitution')));
    await tester.pumpAndSettle();
    expect(account.calls, contains('reg:{tick: constitution}'));
    expect(find.text('1 of 4 ready'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('reg-cert-no')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('reg-cert-no')), 'SDO/123/2026');
    await tester.tap(find.byKey(const ValueKey('reg-cert-save')));
    await tester.pumpAndSettle();
    expect(account.calls.last, contains('certificate_no: SDO/123/2026'));
    await tester.dragUntilVisible(find.byKey(const ValueKey('reg-done')),
        find.byType(RegistrationScreen), const Offset(0, 400));
    final notice = tester.widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('reg-done')), matching: find.byType(Text)).first);
    expect(notice.data, contains('Certificate SDO/123/2026'));
  });

  testWidgets('records show money in, out and fines, and filter by them', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Umoja Women Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flow-incoming')), findsOneWidget);
    expect(find.byKey(const ValueKey('flow-outgoing')), findsOneWidget);
    expect(find.byKey(const ValueKey('flow-fine')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('flow-fine')));
    await tester.pumpAndSettle();
    expect(find.text('Showing only: Fines'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('flow-fine')));
    await tester.pumpAndSettle();
    expect(find.text('Showing only: Fines'), findsNothing);
  });
}
