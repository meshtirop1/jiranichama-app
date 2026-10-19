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
    // No phone key: approvals use SMS codes.
    phoneSignerProvider.overrideWithValue(FakePhoneSigner(isAvailable: false)),
  ], child: const JiraniApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Umoja Women Group'));
  await tester.pumpAndSettle();
  if (button.isEmpty) return;
  await scrollTo(tester, find.text(button));
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
}

Future<void> _sms(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).last, smsCode);
  await tester.tap(find.text('Confirm'));
  await tester.pumpAndSettle();
}

Json _collecting({bool canAnswer = true, String payeeCode = 'JC-4821-004'}) => {
      'id': 'prop-1', 'kind': 'payout', 'state': 'collecting_approvals', 'state_reason': '',
      'amount_cents': 2000000, 'payee_name': 'Wanjiru', 'payee_member_code': payeeCode,
      'payee_account': '', 'purpose': 'Merry-go-round turn', 'proposed_by': 'Jane',
      'proposed_by_code': 'JC-4821-001', 'needs_officials': 2, 'approved': 0,
      'approvals': <Json>[], 'refusal': <String, dynamic>{}, 'deadline_at': null,
      'bank_reference': '', 'paid_at': null, 'can_answer': canAnswer, 'seal_receipt': null,
    };

void main() {
  testWidgets('an official agrees to switch money out on by SMS code', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair');
    await _open(tester, repo, 'Money out');
    expect(find.textContaining('Money out is off'), findsOneWidget);
    expect(find.text('0 of 2 officials have agreed'), findsOneWidget);
    await tester.tap(find.text('Switch on money out'));
    await tester.pumpAndSettle();
    await _sms(tester);
    expect(repo.calls, contains('enableMoneyOut'));
    expect(find.text('1 of 2 officials have agreed'), findsOneWidget);
  });

  testWidgets('an official proposes a payout to a member', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')..moneyOutOn = true;
    await _open(tester, repo, 'Money out');
    expect(find.textContaining('Available after money already promised: KES 100,000'),
        findsOneWidget);
    await tester.tap(find.text('Propose a payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payee-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wanjiru (JC-4821-004)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('propose-amount')), '20000');
    await tester.enterText(find.byKey(const ValueKey('propose-purpose')), 'Turn 3');
    await tester.tap(find.text('Propose'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('propose:payout:2000000'));
    expect(find.text('Wanjiru · Turn 3'), findsOneWidget);
    expect(find.textContaining('Waiting for approvals · 0 of 2 approvals'), findsOneWidget);
  });

  testWidgets('a refusal names the rule', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')..moneyOutOn = true;
    await _open(tester, repo, 'Money out');
    await tester.tap(find.text('Propose a payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('To someone else'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('payee-name')), 'Hardware Ltd');
    await tester.enterText(find.byKey(const ValueKey('propose-amount')), '60000');
    await tester.enterText(find.byKey(const ValueKey('propose-purpose')), 'Water tank');
    await tester.tap(find.text('Propose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hardware Ltd · Water tank'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Rule 4.2: this amount needs a members' vote"), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets('an official approves by SMS code, then marks it paid', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')..moneyOutOn = true;
    repo.proposalsList.add(_collecting()..['approved'] = 1);
    await _open(tester, repo, '');
    expect(find.text('1 payment(s) waiting for your approval'), findsOneWidget);
    await scrollTo(tester, find.text('Money out'));
    await tester.tap(find.text('Money out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wanjiru · Merry-go-round turn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await _sms(tester);
    expect(repo.calls, contains('approve:prop-1'));
    expect(find.text('Approved: pay at the bank'), findsOneWidget);
    expect(find.text('Jane (Chairperson) approved'), findsOneWidget);

    await tester.tap(find.text('Mark as paid at the bank'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ask-text')), 'PL77X');
    await tester.tap(find.widgetWithText(FilledButton, 'Mark as paid at the bank').last);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('paid:prop-1:PL77X'));
    expect(find.text('Paid: waiting for the bank statement'), findsOneWidget);
  });

  testWidgets('an official declines with a reason', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')..moneyOutOn = true;
    repo.proposalsList.add(_collecting());
    await _open(tester, repo, 'Money out');
    await tester.tap(find.text('Wanjiru · Merry-go-round turn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ask-text')), 'Not her turn');
    await tester.tap(find.widgetWithText(FilledButton, 'Decline'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('decline:prop-1:Not her turn'));
    expect(find.text('Jane (Chairperson) declined: Not her turn'), findsOneWidget);
  });

  testWidgets('the member being paid sees it but cannot approve', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)..moneyOutOn = true;
    repo.proposalsList.add(_collecting(canAnswer: false));
    await _open(tester, repo, 'Money out');
    await tester.tap(find.text('Wanjiru · Merry-go-round turn'));
    await tester.pumpAndSettle();
    expect(find.text('You are being paid, so you do not approve this.'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets('money out with no approval is shown to everyone and explained',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')..moneyOutOn = true;
    repo.unapprovedList.add({
      'id': 'ud-1', 'state': 'open', 'amount_cents': 4500000, 'value_date': '2026-03-14',
      'narration': 'CASH WITHDRAWAL', 'receipt': 'AB12CD34', 'explanation': '',
      'resolved_by': null, 'resolved_at': null, 'linked_proposal_id': null, 'alerted': 4,
    });
    await _open(tester, repo, '');
    expect(find.textContaining('KES 45,000 left the bank on 2026-03-14 with no approval'),
        findsOneWidget);
    await tester.tap(find.textContaining('KES 45,000 left the bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explain'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ask-text')), 'Tent for the meeting');
    await tester.tap(find.widgetWithText(FilledButton, 'Explain'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('explain:ud-1:Tent for the meeting'));
    expect(find.text('Explained by Jane: Tent for the meeting'), findsOneWidget);
  });
}
