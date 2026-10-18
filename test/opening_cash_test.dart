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
  if (button.isNotEmpty) {
    await tester.ensureVisible(find.text(button));
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
  }
}

Future<void> _sms(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).last, smsCode);
  await tester.tap(find.text('Confirm'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the treasurer drafts opening balances; another official confirms',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'treasurer');
    await _open(tester, repo, 'Opening balances');
    expect(find.textContaining('Moving from a notebook'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('savings-JC-4821-004')), '8000');
    await tester.enterText(find.byKey(const ValueKey('fines-JC-4821-004')), '400');
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('saveOpening:1'));
    expect((repo.openingLines.single)['savings_cents'], 800000);
    expect((repo.openingLines.single)['fines_cents'], 40000);
    expect(find.textContaining('Draft saved'), findsOneWidget);
  });

  testWidgets('a different official confirms the opening balances by SMS code',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')
      ..openingState = 'draft'
      ..openingLines = [
        {'id': 'line-m4', 'membership_id': 'm4', 'member_code': 'JC-4821-004',
         'savings_cents': 800000, 'fines_cents': 0, 'objections': <String>[]},
      ];
    await _open(tester, repo, 'Opening balances');
    expect(find.textContaining('waiting for another official'), findsOneWidget);
    await tester.tap(find.text('Confirm these opening balances'));
    await tester.pumpAndSettle();
    await _sms(tester);
    expect(repo.calls, contains('confirmOpening'));
    expect(find.textContaining('Confirmed by Jane'), findsOneWidget);
  });

  testWidgets('a member objects to their own opening balance', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)
      ..openingState = 'confirmed'
      ..openingLines = [
        {'id': 'line-m4', 'membership_id': 'm4', 'member_code': 'JC-4821-004',
         'savings_cents': 800000, 'fines_cents': 0, 'objections': <String>[]},
      ];
    await _open(tester, repo, 'Opening balances');
    await tester.enterText(find.widgetWithText(TextField, 'What is wrong?'), 'It was 9,000');
    await tester.tap(find.text('Object to my opening balance'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('object:line-m4:It was 9,000'));
    expect(find.textContaining('1 objection'), findsOneWidget);
  });

  testWidgets('cash: the treasurer records it, the member confirms it', (tester) async {
    final repo = FakeChamaRepository(myRole: 'treasurer');
    await _open(tester, repo, 'Cash at meetings');
    await tester.tap(find.text('Record cash received'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wanjiru (JC-4821-004)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount (KES)'), '1000');
    await tester.tap(find.widgetWithText(FilledButton, 'Record'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('recordCash:m4:100000'));
    expect(find.text('Waiting for the member to confirm'), findsOneWidget);
  });

  testWidgets('a member is told about cash to confirm, and confirms it', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    repo.cash.add({'id': 'cash-1', 'membership_id': 'm4', 'member_code': 'JC-4821-004',
                   'amount_cents': 100000, 'received_on': '2026-03-04', 'state': 'recorded',
                   'overdue': false});
    await _open(tester, repo, '');
    expect(find.textContaining('1 cash payment is waiting for you'), findsOneWidget);
    await tester.tap(find.textContaining('1 cash payment is waiting for you'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, I paid this'));
    await tester.pumpAndSettle();
    await _sms(tester);
    expect(repo.calls, contains('confirmCash:cash-1'));
    expect(find.text('Waiting for the bank deposit'), findsOneWidget);
  });

  testWidgets('the treasurer links a deposit to confirmed cash; totals must match',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'treasurer');
    repo.cash.addAll([
      {'id': 'cash-1', 'membership_id': 'm4', 'member_code': 'JC-4821-004',
       'amount_cents': 20000, 'received_on': '2026-03-04', 'state': 'member_confirmed',
       'overdue': false},
      {'id': 'cash-2', 'membership_id': 'm2', 'member_code': 'JC-4821-002',
       'amount_cents': 10000, 'received_on': '2026-03-04', 'state': 'member_confirmed',
       'overdue': false},
    ]);
    await _open(tester, repo, 'Unmatched payments');
    await tester.tap(find.byTooltip('This is cash from a meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Selected KES 0 of KES 300'), findsOneWidget);
    await tester.tap(find.text('JC-4821-004 · 2026-03-04'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Link deposit'))
        .onPressed, isNull);
    await tester.tap(find.text('JC-4821-002 · 2026-03-04'));
    await tester.pumpAndSettle();
    expect(find.text('Selected KES 300 of KES 300'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Link deposit'));
    await tester.pumpAndSettle();
    expect(repo.calls.any((c) => c.startsWith('bankCash:txn-1:')), isTrue);
    expect(find.text('Every payment is matched to a member.'), findsOneWidget);
  });
}
