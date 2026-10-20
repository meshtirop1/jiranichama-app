import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiranichama/app.dart';
import 'package:jiranichama/core/providers.dart';
import 'package:jiranichama/features/auth/data/auth_repository.dart';

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

Future<void> _growth(WidgetTester tester, FakeChamaRepository repo) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [
    authRepositoryProvider.overrideWithValue(_SignedIn()),
    chamaRepositoryProvider.overrideWithValue(repo),
  ], child: const JiraniApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Umoja Women Group'));
  await tester.pumpAndSettle();
  await scrollTo(tester, find.byKey(const ValueKey('growth-card')));
  expect(find.text('Net worth KES 10,000'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('growth-card')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every member sees the numbers', (tester) async {
    await _growth(tester, FakeChamaRepository(myRole: 'member', founder: false));
    expect(find.text('2026-09 · 75%'), findsOneWidget);
    expect(find.text('1 member behind'), findsOneWidget);
    expect(find.text('3 of 4 attended'), findsOneWidget);
  });

  testWidgets('an official records an investment and another confirms its value',
      (tester) async {
    final repo = FakeChamaRepository();
    await _growth(tester, repo);
    await tester.tap(find.widgetWithText(Tab, 'Investments'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('record-investment')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('inv-name')), 'Juja plot');
    await tester.enterText(find.byKey(const ValueKey('inv-cost')), '400000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('investment:land:Juja plot:40000000'));
    await tester.tap(find.byKey(const ValueKey('value-i1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('val-value')), '450000');
    await tester.enterText(find.byKey(const ValueKey('val-source')), 'Valuer report');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('waits for a second official'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-v1')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('confirmValuation:v1'));
    expect(find.textContaining('waits for a second official'), findsNothing);
  });

  testWidgets('an official asks the members to agree to a referral', (tester) async {
    final repo = FakeChamaRepository()
      ..partnersList.add({'id': 'p1', 'name': 'Umoja SACCO', 'regulator': 'sasra',
          'regulator_name': 'SACCO Societies Regulatory Authority',
          'licence_number': 'SASRA/123', 'product': 'group_loan', 'description': ''});
    await _growth(tester, repo);
    await tester.tap(find.text('Partners'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SASRA/123'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('propose-p1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ref-reason')), 'Group loan');
    await tester.tap(find.byKey(const ValueKey('ref-ok')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('referral:p1:Group loan'));
    expect(find.text('Members are voting'), findsOneWidget);
  });
}
