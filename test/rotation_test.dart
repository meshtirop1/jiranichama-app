import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiranichama/app.dart';
import 'package:jiranichama/core/providers.dart';
import 'package:jiranichama/features/auth/data/auth_repository.dart';
import 'package:jiranichama/features/chamas/data/models.dart';

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

Future<void> _open(WidgetTester tester, FakeChamaRepository repo, String button) async {
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
  if (button.isEmpty) return;
  await scrollTo(tester, find.text(button));
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an official starts a drawn rotation; everyone sees the order', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')..moneyOutOn = true;
    await _open(tester, repo, 'Merry-go-round');
    expect(find.textContaining('drawn by the app from the records'), findsOneWidget);
    expect(find.text('Behind on contributions: moved to the end'), findsOneWidget);
    expect(find.text('No cycle is running.'), findsOneWidget);
    await tester.tap(find.text('Start the rotation'));
    await tester.pumpAndSettle();
    expect(find.textContaining('draw the order from the chama'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start the rotation').last);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('startRotation:draw'));
    expect(find.text('Cycle 1 · each turn receives KES 3,000'), findsOneWidget);
    expect(find.textContaining('seed ab12cd34ef56…, receipt ROT12345'), findsOneWidget);
    expect(find.text('Wanjiru (JC-4821-004)'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('propose next payout fills it in and opens it', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')..moneyOutOn = true;
    await repo.startRotation('c1', idempotencyKey: 'k');
    await _open(tester, repo, 'Merry-go-round');
    await tester.tap(find.text('Propose next payout'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('proposeNextTurn'));
    expect(find.text('Merry-go-round turn 1 of 3, cycle 1'), findsOneWidget);
    expect(find.text('KES 3,000'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Next · Waiting for approvals'), findsOneWidget);
  });

  testWidgets('a fixed order is set by moving members', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')
      ..moneyOutOn = true
      ..rotationJson = {
        'settings': {'order': 'fixed', 'arrears': 'deduct'}, 'cycle_no': null,
        'method': null, 'seed': null, 'receipt': null, 'running': false, 'pot_cents': null,
        'next_position': null, 'turns': <Json>[],
      };
    await _open(tester, repo, 'Merry-go-round');
    expect(find.text('Behind on contributions: paid less what they owe'), findsOneWidget);
    await tester.tap(find.text('Start the rotation'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('order-JC-4821-004')),
        matching: find.byTooltip('Move up')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start the rotation').last);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('startRotation:m1,m4,m2'));
  });

  testWidgets('members see the rotation but cannot start it', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    await _open(tester, repo, 'Merry-go-round');
    expect(find.text('No cycle is running.'), findsOneWidget);
    expect(find.text('Start the rotation'), findsNothing);
  });
}
