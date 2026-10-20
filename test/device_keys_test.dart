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

Future<void> _open(WidgetTester tester, FakeChamaRepository repo, FakePhoneSigner signer)
    async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [
    authRepositoryProvider.overrideWithValue(_SignedIn()),
    chamaRepositoryProvider.overrideWithValue(repo),
    phoneSignerProvider.overrideWithValue(signer),
  ], child: const JiraniApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Umoja Women Group'));
  await tester.pumpAndSettle();
  await scrollTo(tester, find.text('Money out'));
  await tester.tap(find.text('Money out'));
  await tester.pumpAndSettle();
}

Json _collecting() => {
      'id': 'prop-1', 'kind': 'payout', 'state': 'collecting_approvals', 'state_reason': '',
      'amount_cents': 2000000, 'payee_name': 'Wanjiru', 'payee_member_code': 'JC-4821-004',
      'payee_account': '', 'purpose': 'Merry-go-round turn', 'proposed_by': 'Jane',
      'proposed_by_code': 'JC-4821-001', 'needs_officials': 2, 'approved': 0,
      'approvals': <Json>[], 'refusal': <String, dynamic>{}, 'deadline_at': null,
      'bank_reference': '', 'paid_at': null, 'can_answer': true, 'seal_receipt': null,
    };

void main() {
  testWidgets('an official sets this phone up for fingerprint approvals', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')..moneyOutOn = true;
    final signer = FakePhoneSigner();
    await _open(tester, repo, signer);
    expect(find.text('Approve with your fingerprint'), findsOneWidget);
    await tester.tap(find.text('Set up this phone'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, smsCode);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(repo.calls, containsAllInOrder(['startRegisterDevice:PUBKEY', 'registerDevice']));
    expect(signer.remembered, 'dev-1');
    expect(find.text('This phone approves payments with your fingerprint.'), findsOneWidget);
  });

  testWidgets('a phone with a key approves with the fingerprint, not an SMS code',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')..moneyOutOn = true;
    repo.proposalsList.add(_collecting());
    final signer = FakePhoneSigner(hasKeyAndId: true);
    await _open(tester, repo, signer);
    await tester.tap(find.text('Wanjiru · Merry-go-round turn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(signer.signed.single, startsWith('Approve KES 20,000 to Wanjiru|{'));
    expect(signer.signed.single, contains('"proposal_id":"prop-1"'));
    expect(repo.calls, contains('signature:prop-1:SIG'));
    expect(find.text('Jane (Chairperson) approved with their phone key'), findsOneWidget);
    expect(find.byType(TextField), findsNothing); // no SMS sheet
  });

  testWidgets('a payload that is not the proposal on screen is never signed', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')
      ..moneyOutOn = true
      ..tamperAmount = 'yes';
    repo.proposalsList.add(_collecting());
    final signer = FakePhoneSigner(hasKeyAndId: true);
    await _open(tester, repo, signer);
    await tester.tap(find.text('Wanjiru · Merry-go-round turn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(signer.signed, isEmpty);
    expect(find.text('What you are approving has changed. Look again.'), findsOneWidget);
  });

  testWidgets('backing out of the fingerprint sends nothing', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')..moneyOutOn = true;
    repo.proposalsList.add(_collecting());
    final signer = FakePhoneSigner(hasKeyAndId: true)..cancel = true;
    await _open(tester, repo, signer);
    await tester.tap(find.text('Wanjiru · Merry-go-round turn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('signature')), isEmpty);
    expect(find.text('Waiting for approvals'), findsOneWidget);
  });

  testWidgets("signing out forgets this phone's key", (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')..moneyOutOn = true;
    final signer = FakePhoneSigner(hasKeyAndId: true);
    await _open(tester, repo, signer);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(signer.forgotten, isTrue);
  });
}
