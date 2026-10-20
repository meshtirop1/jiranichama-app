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

Future<void> _gov(WidgetTester tester, FakeChamaRepository repo) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [
    authRepositoryProvider.overrideWithValue(_SignedIn()),
    chamaRepositoryProvider.overrideWithValue(repo),
    fileSourceProvider.overrideWithValue(FakeFileSource()),
  ], child: const JiraniApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Umoja Women Group'));
  await tester.pumpAndSettle();
  await scrollTo(tester, find.byKey(const ValueKey('governance-card')));
  await tester.tap(find.byKey(const ValueKey('governance-card')));
  await tester.pumpAndSettle();
}

Future<void> _sms(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).last, smsCode);
  await tester.tap(find.text('Confirm'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a member raises a problem and responds', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    await _gov(tester, repo);
    expect(find.byKey(const ValueKey('hold-election')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('raise-dispute')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reason-not_mine')));
    await tester.enterText(find.byKey(const ValueKey('dispute-text')), 'Not my payment');
    await tester.tap(find.text('Raise it'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('raiseDispute:not_mine:Not my payment'));
    expect(find.text('Waiting for responses'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dispute-respond')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('gov-text')), 'Bank slip attached');
    await tester.tap(find.byKey(const ValueKey('gov-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Bank slip attached'), findsOneWidget);
  });

  testWidgets('an official proposes an outcome and another agrees by SMS code',
      (tester) async {
    final repo = FakeChamaRepository()..disputesList.add(FakeChamaRepository()
        .newDispute(iCanDecide: true));
    await _gov(tester, repo);
    await tester.tap(find.text('March cash missing'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dispute-propose')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('outcome-text')), 'Bank shows it');
    await tester.tap(find.text('Propose an outcome').last);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('propose:d1:no_change:Bank shows it'));
    repo.disputesList.first['i_can_decide'] = true;  // as another official
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('March cash missing'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dispute-agree')));
    await tester.pumpAndSettle();
    await _sms(tester);
    expect(find.text('Settled'), findsOneWidget);
    expect(find.text('On the record, receipt DSP12345'), findsOneWidget);
  });

  testWidgets('officials vouch for a new phone and hold an election', (tester) async {
    final repo = FakeChamaRepository()
      ..newPhonesList.add({'id': 'dev-9', 'owner': 'Peter', 'platform': 'android',
          'label': '', 'fingerprint': 'f', 'registered_at': 'x'})
      ..electionsJson = {'elections': <Map<String, dynamic>>[], 'election_needed': [
        {'level': '4.1', 'officials': 2, 'available': 1}]};
    await _gov(tester, repo);
    expect(find.text('Too few officials remain to approve money out. The chama needs an '
        'election.'), findsOneWidget);
    await tester.tap(find.text('Vouch (SMS code)'));
    await tester.pumpAndSettle();
    await _sms(tester);
    expect(repo.calls, contains('vouch:dev-9'));

    await scrollTo(tester, find.byKey(const ValueKey('hold-election')));
    await tester.tap(find.byKey(const ValueKey('hold-election')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Secretary'));
    await tester.tap(find.byKey(const ValueKey('candidate-JC-4821-004')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start the vote'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('nominate:secretary:')), isNotEmpty);
  });

  testWidgets('a member leaves with an SMS code and can change their mind', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    await _gov(tester, repo);
    await scrollTo(tester, find.byKey(const ValueKey('exit-leave')));
    await tester.tap(find.byKey(const ValueKey('exit-leave')));
    await tester.pumpAndSettle();
    expect(find.textContaining('You get back KES 19,800 after 30 days'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('exit-confirm')));
    await tester.pumpAndSettle();
    await _sms(tester);
    expect(repo.calls, contains('leave'));
    await scrollTo(tester, find.byKey(const ValueKey('exit-stay')));
    await tester.tap(find.byKey(const ValueKey('exit-stay')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('cancelExit:x1'));
  });

  testWidgets('an official shows the bank mandate and another official confirms it',
      (tester) async {
    final repo = FakeChamaRepository();
    await _gov(tester, repo);
    await tester.tap(find.byKey(const ValueKey('mandate-tile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mandate-missing')), findsOneWidget);

    // Submit stays off until two signatories and the bank's form are given.
    await tester.tap(find.byKey(const ValueKey('mandate-signer-m1')));
    await tester.tap(find.byKey(const ValueKey('mandate-signer-m2')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('mandate-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mandate-attach')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('mandate-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mandate-submit')));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'proposeMandate:m1,m2:2:false');
    // I uploaded it: I cannot confirm it myself.
    expect(find.byKey(const ValueKey('mandate-confirm')), findsNothing);

    // Another official sees it and confirms with an SMS code.
    repo.mandatePending!['uploaded_by'] = 'JC-4821-002';
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mandate-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mandate-confirm')));
    await tester.pumpAndSettle();
    await _sms(tester);
    expect(repo.calls, contains('confirmBankMandate:mand-1:$smsCode'));
    expect(find.text('What the bank has on file'), findsOneWidget);
  });
}
