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
  Future<CodeSent> requestCode(String phone, {required String language}) =>
      throw UnimplementedError();
  @override
  Future<SignedIn> verifyCode(String phone, String code) => throw UnimplementedError();
  @override
  Future<void> setPin(String pin) async {}
  @override
  Future<void> setProfile({required String name, required String language}) async {}
  @override
  Future<void> signOut() async {}
}

Future<void> _open(WidgetTester tester, FakeChamaRepository repo) async {
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
}

void main() {
  testWidgets('loans stay hidden where they are switched off', (tester) async {
    await _open(tester, FakeChamaRepository(myRole: 'member', founder: false));
    expect(find.byKey(const ValueKey('loans-card')), findsNothing);
  });

  testWidgets('a member sees the terms and schedule, then asks two guarantors',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)..loansOn = true;
    await _open(tester, repo);
    await scrollTo(tester, find.byKey(const ValueKey('loans-card')));
    await tester.tap(find.byKey(const ValueKey('loans-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('request-loan')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('loan-amount')), '90000');
    await tester.enterText(find.byKey(const ValueKey('loan-term')), '3');
    await tester.tap(find.text('See the terms'));
    await tester.pumpAndSettle();
    expect(find.text('Rule 12.1: That is more than you can borrow now.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('loan-amount')), '30000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('See the terms'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('quote:3000000:3'));
    expect(find.textContaining('You can borrow up to KES 60,000'), findsOneWidget);
    expect(find.text('2026-11-05'), findsOneWidget);
    expect(find.textContaining('total to repay KES 30,900'), findsOneWidget);

    await scrollTo(tester, find.byKey(const ValueKey('loan-purpose')));
    await tester.enterText(find.byKey(const ValueKey('loan-purpose')), 'Stock');
    await scrollTo(tester, find.byKey(const ValueKey('guarantor-JC-4821-001')));
    await tester.tap(find.byKey(const ValueKey('guarantor-JC-4821-001')));
    await scrollTo(tester, find.byKey(const ValueKey('guarantor-JC-4821-002')));
    await tester.tap(find.byKey(const ValueKey('guarantor-JC-4821-002')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask the guarantors'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('requestLoan:3000000:Stock:m1,m2'));
    expect(find.text('Waiting for guarantors'), findsOneWidget);
    await scrollTo(tester, find.byKey(const ValueKey('loan-cancel')));
    await tester.tap(find.byKey(const ValueKey('loan-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('a guarantor is asked on the overview and accepts with an SMS code',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)
      ..loansOn = true
      ..loansList.add(FakeChamaRepository().newLoan(iGuarantee: true));
    await _open(tester, repo);
    await scrollTo(tester, find.textContaining('asks you to guarantee'));
    await tester.tap(find.textContaining('asks you to guarantee'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your share is KES 15,000'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guarantee-accept')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, smsCode);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('acceptGuarantee:g1'));
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.byKey(const ValueKey('guarantee-accept')), findsNothing);
  });
}
