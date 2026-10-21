import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiranichama/app.dart';
import 'package:jiranichama/core/providers.dart';
import 'package:jiranichama/core/tours.dart';
import 'package:jiranichama/features/auth/data/auth_repository.dart';
import 'package:jiranichama/features/chamas/application/chain_check.dart';
import 'package:jiranichama/features/settings/data/account_repository.dart';

import 'fakes.dart';
import 'settings_registration_test.dart' show FakeAccountRepository;

class _Auth implements AuthRepository {
  _Auth({this.signedIn = true});

  final bool signedIn;

  @override
  Future<bool> hasSession() async => signedIn;
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

Future<void> _app(WidgetTester tester, FakeChamaRepository repo,
    {bool signedIn = true, TourMemory? tours}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [
    authRepositoryProvider.overrideWithValue(_Auth(signedIn: signedIn)),
    chamaRepositoryProvider.overrideWithValue(repo),
    chainRunnerProvider.overrideWithValue((work) async => work()),
    trustStoreProvider.overrideWithValue(MemoryTrustStore()),
    phoneSignerProvider.overrideWithValue(FakePhoneSigner(isAvailable: false)),
    accountRepositoryProvider.overrideWithValue(FakeAccountRepository()),
    if (tours != null) tourMemoryProvider.overrideWithValue(tours),
  ], child: const JiraniApp()));
  await tester.pumpAndSettle();
}

Future<void> _openChama(WidgetTester tester) async {
  await tester.tap(find.text('Umoja Women Group'));
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('chama-menu')));
  await tester.pumpAndSettle();
}

Future<void> _openFromMenu(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey('menu-$key'));
  await tester.dragUntilVisible(target, find.byKey(const ValueKey('menu-list')),
      const Offset(0, -200));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new phone shows the welcome pages once, before sign-in', (tester) async {
    final tours = MemoryTourMemory()..shown.add('sign-in');
    await _app(tester, FakeChamaRepository(), signedIn: false, tours: tours);
    expect(find.byKey(const ValueKey('welcome')), findsOneWidget);
    expect(find.text('Your money stays in your bank'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('welcome-next')));
    await tester.pumpAndSettle();
    expect(find.text('Records nobody can change'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('welcome-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('welcome')), findsNothing);
    expect(tours.shown, contains('welcome'));
  });

  testWidgets('every screen in the chama menu opens', (tester) async {
    final repo = FakeChamaRepository();
    await _app(tester, repo);
    await _openChama(tester);
    await _menu(tester);
    const titles = {
      'payments': 'My payments', 'calendar': 'Months at a glance',
      'coming': "What's coming", 'payers': 'Phones that pay', 'votes': 'All votes',
      'invite': 'Invite a member', 'search': 'Search', 'reports': 'Reports',
      'bank-check': 'Bank check', 'verify': 'Check a code',
      'trust': 'How your records are protected', 'profile': 'About the chama',
    }; // in the menu's order, top to bottom
    for (final MapEntry(:key, :value) in titles.entries) {
      await _openFromMenu(tester, key);
      if (key != 'search') {
        expect(find.descendant(of: find.byType(AppBar), matching: find.text(value)),
            findsOneWidget, reason: key);
      }
      expect(tester.takeException(), isNull, reason: key);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('a member profile: header, position and the way to the statement',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    await _app(tester, repo);
    await _openChama(tester);
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wanjiru'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('member-header')), findsOneWidget);
    expect(find.text('JC-4821-004'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('member-calendar')));
    await tester.pumpAndSettle();
    expect(find.text('Months at a glance'), findsOneWidget);
    expect(find.byKey(ValueKey('cal-${DateTime.now().year}-01')), findsOneWidget);
  });

  testWidgets('tapping a record shows it in full, with its receipt and fingerprint',
      (tester) async {
    final repo = FakeChamaRepository();
    await _app(tester, repo);
    await _openChama(tester);
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    final first = repo.ledgerItems.last;
    await scrollTo(tester, find.textContaining('Receipt ${first['receipt_code']}').first);
    await tester.tap(find.textContaining('Receipt ${first['receipt_code']}').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rd-checked')), findsOneWidget);
    await scrollTo(tester, find.text('Dispute this record'));
    expect(find.text('${first['hash']}'), findsOneWidget);
  });

  testWidgets('search finds members and records', (tester) async {
    final repo = FakeChamaRepository();
    await _app(tester, repo);
    await _openChama(tester);
    await tester.tap(find.byKey(const ValueKey('chama-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('search-field')), 'wanj');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-member-m4')), findsOneWidget);
    final code = repo.ledgerItems.first['receipt_code'] as String;
    await tester.enterText(find.byKey(const ValueKey('search-field')), code.toLowerCase());
    await tester.pumpAndSettle();
    expect(find.textContaining('Receipt $code'), findsWidgets);
  });

  testWidgets('check a statement code and a receipt', (tester) async {
    final repo = FakeChamaRepository();
    await _app(tester, repo);
    await _openChama(tester);
    await _menu(tester);
    await _openFromMenu(tester, 'verify');
    await tester.enterText(find.byKey(const ValueKey('verify-code')), 'abcde-12345');
    await tester.tap(find.byKey(const ValueKey('verify-check')));
    await tester.pumpAndSettle();
    expect(find.text('Genuine'), findsOneWidget);
    final receipt = repo.ledgerItems.first['receipt_code'] as String;
    await tester.enterText(find.byKey(const ValueKey('verify-code')), receipt);
    await tester.tap(find.byKey(const ValueKey('verify-check')));
    await tester.pumpAndSettle();
    expect(find.text('This receipt is in the records'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('verify-code')), 'ZZZZZZZZZZ');
    await tester.tap(find.byKey(const ValueKey('verify-check')));
    await tester.pumpAndSettle();
    expect(find.text('No statement has this code.'), findsOneWidget);
  });

  testWidgets('security: change the PIN and retire a lost phone', (tester) async {
    final repo = FakeChamaRepository()
      ..devicesList.add({'id': 'd1', 'platform': 'android', 'label': 'Tecno Spark',
                         'state': 'active', 'security_level': 'tee',
                         'registered_at': '2026-10-01T10:00:00Z'});
    await _app(tester, repo);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('settings-security')));
    await tester.tap(find.byKey(const ValueKey('settings-security')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pin-current')), '111111');
    await tester.enterText(find.byKey(const ValueKey('pin-new')), '246802');
    await tester.enterText(find.byKey(const ValueKey('pin-again')), '246802');
    await tester.tap(find.byKey(const ValueKey('pin-change')));
    await tester.pumpAndSettle();
    expect(find.text('That PIN is not right.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pin-current')), '135790');
    await tester.enterText(find.byKey(const ValueKey('pin-new')), '246802');
    await tester.enterText(find.byKey(const ValueKey('pin-again')), '246802');
    await tester.tap(find.byKey(const ValueKey('pin-change')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('pin:246802'));
    expect(find.text('Your PIN is changed.'), findsOneWidget);
    await scrollTo(tester, find.byKey(const ValueKey('revoke-d1')));
    await tester.tap(find.byKey(const ValueKey('revoke-d1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retire'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('revoke:d1'));
    expect(find.text('Retired · tee · 2026-10-01'), findsOneWidget);
  });

  testWidgets('help answers questions and lists the SMS words', (tester) async {
    await _app(tester, FakeChamaRepository());
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('settings-help')));
    await tester.tap(find.byKey(const ValueKey('settings-help')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Does JiraniChama keep our money?'));
    await tester.pumpAndSettle();
    expect(find.textContaining("The money is in the chama's own bank account"), findsOneWidget);
    await scrollTo(tester, find.text('BAL / SALIO'));
    expect(find.text('BAL / SALIO'), findsOneWidget);
  });

  testWidgets('the invite screen makes a code with a QR to share', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair');
    await _app(tester, repo);
    await _openChama(tester);
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite a member'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inv-make')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inv-code')), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });
}
