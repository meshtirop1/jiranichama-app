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
}

Future<void> _sms(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).last, smsCode);
  await tester.tap(find.text('Confirm'));
  await tester.pumpAndSettle();
}

Json _vote({String state = 'open', bool canVote = true, bool secret = false}) => {
      'id': 'vote-1', 'subject': 'payouts.proposal:prop-1',
      'question': 'Pay Mary KES 60,000 for Welfare?', 'state': state,
      'closes_at': '2026-03-13T10:00:00Z', 'secret': secret, 'eligible': 4,
      'quorum_pct': 50, 'pass_pct': 50, 'quorum_needed': 2, 'cast': 1,
      'yes': state == 'open' ? null : 3, 'no': state == 'open' ? null : 1,
      'voted': ['Peter'], 'i_can_vote': canVote, 'i_voted': !canVote, 'my_choice': null,
      'result_receipt': state == 'open' ? null : 'VOTE1234', 'created_at': 'x',
    };

void main() {
  testWidgets('a member is asked to vote and votes yes by SMS code', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)..votesList.add(_vote());
    await _open(tester, repo, FakePhoneSigner(isAvailable: false));
    expect(find.text('Your vote is needed: Pay Mary KES 60,000 for Welfare?'), findsOneWidget);
    await tester.tap(find.textContaining('Your vote is needed'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 4 have voted · 2 needed for it to count'), findsOneWidget);
    expect(find.text('It passes with more than 50% yes.'), findsOneWidget);
    expect(find.textContaining('Yes 3'), findsNothing); // no tally while open
    await tester.tap(find.text('Vote yes'));
    await tester.pumpAndSettle();
    await _sms(tester);
    expect(repo.calls, contains('ballot:vote-1:yes'));
    expect(find.text('You voted yes.'), findsOneWidget);
    expect(find.text('Vote yes'), findsNothing);
  });

  testWidgets('with a phone key the vote is signed, not sent by SMS', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)..votesList.add(_vote());
    final signer = FakePhoneSigner(hasKeyAndId: true);
    await _open(tester, repo, signer);
    await tester.tap(find.textContaining('Your vote is needed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vote no'));
    await tester.pumpAndSettle();
    expect(signer.signed.single, startsWith('Vote NO|{'));
    expect(signer.signed.single, contains('"choice":"no"'));
    expect(repo.calls, contains('signedBallot:vote-1:SIG'));
    expect(find.text('You voted no.'), findsOneWidget);
  });

  testWidgets('a closed vote shows the tally and who voted', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)
      ..votesList.add(_vote(state: 'passed', canVote: false));
    repo.proposalsList.add({
      'id': 'prop-1', 'kind': 'payout', 'state': 'approved', 'state_reason': '',
      'amount_cents': 6000000, 'payee_name': 'Mary', 'payee_member_code': 'JC-4821-009',
      'payee_account': '', 'purpose': 'Welfare', 'proposed_by': 'Jane',
      'proposed_by_code': 'JC-4821-001', 'needs_officials': 2, 'approved': 2,
      'approvals': <Json>[], 'refusal': <String, dynamic>{}, 'deadline_at': null,
      'bank_reference': '', 'paid_at': null, 'can_answer': false, 'seal_receipt': null,
      'needs_vote': true, 'vote_id': 'vote-1', 'vote_state': 'passed',
    });
    repo.moneyOutOn = true;
    await _open(tester, repo, FakePhoneSigner(isAvailable: false));
    await scrollTo(tester, find.text('Money out'));
    await tester.tap(find.text('Money out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mary · Welfare'));
    await tester.pumpAndSettle();
    expect(find.text("Members' vote"), findsOneWidget);
    await tester.tap(find.text("Members' vote"));
    await tester.pumpAndSettle();
    expect(find.text('Yes 3 · No 1'), findsOneWidget);
    expect(find.text('• Peter'), findsOneWidget);
    expect(find.text('Receipt: VOTE1234'), findsOneWidget);
  });
}
