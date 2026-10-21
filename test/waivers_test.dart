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

Future<void> _fines(WidgetTester tester, FakeChamaRepository repo) async {
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
  await scrollTo(tester, find.byKey(const ValueKey('fines-card')));
  await tester.tap(find.byKey(const ValueKey('fines-card')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a member asks for a waiver of their own fine', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    repo.finesList.add(repo.newFine());
    await _fines(tester, repo);
    expect(find.text('Rule 3.2 · 2026-09 · receipt FINE1234'), findsOneWidget);
    expect(find.text('Owed'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('ask-waiver-f1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('reason-text')), 'I was in hospital');
    await tester.tap(find.byKey(const ValueKey('reason-ok')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('requestWaiver:f1:I was in hospital'));
    expect(find.text('Waiver asked: I was in hospital (0 of 2 officials)'), findsOneWidget);
    expect(find.byKey(const ValueKey('ask-waiver-f1')), findsNothing);
  });

  testWidgets('an official approves another member\'s waiver with an SMS code',
      (tester) async {
    final repo = FakeChamaRepository();
    repo.finesList.add(repo.newFine(mine: false, waiver: {
      'id': 'w1', 'reason': 'Sick child', 'state': 'requested', 'state_reason': '',
      'needs_officials': 2, 'needs_vote': false, 'deadline_at': 'x', 'approvals': 0,
      'i_can_decide': true, 'created_at': 'x'}));
    await _fines(tester, repo);
    expect(find.byKey(const ValueKey('ask-waiver-f1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('approve-waiver-f1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, smsCode);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('approveWaiver:w1'));
    expect(find.text('Waiver asked: Sick child (1 of 2 officials)'), findsOneWidget);
    expect(find.byKey(const ValueKey('approve-waiver-f1')), findsNothing);
  });
}
