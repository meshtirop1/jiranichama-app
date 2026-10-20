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

Future<void> _rulesTab(WidgetTester tester, FakeChamaRepository repo) async {
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
  await tester.ensureVisible(find.text('Rules'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rules'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an official proposes a change and sees it clause by clause', (tester) async {
    final repo = FakeChamaRepository();
    await _rulesTab(tester, repo);
    await tester.tap(find.byKey(const ValueKey('propose-rule-change')));
    await tester.pumpAndSettle();
    expect(find.text('Send to members'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('rule-change-reason')), 'Prices went up');
    await tester.tap(find.text('Send to members'));
    await tester.pumpAndSettle();
    expect(find.text('These are the rules already in force. Change at least one setting.'),
        findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('amount')), '1500');
    await tester.tap(find.text('Send to members'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('proposeRules:Prices went up:150000'));
    expect(find.text('Rule change'), findsOneWidget);
    expect(find.text('Rule 3.1'), findsOneWidget);
    expect(find.text('Each member pays KES 1000.'), findsOneWidget);
    expect(find.text('Each member pays KES 1500.'), findsOneWidget);
    expect(find.textContaining('until 2026-11-02'), findsOneWidget);
    expect(find.text('Passes if 50% of members vote and more than 66% say yes.'),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rule-change-withdraw')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('withdrawRule:rp-1'));
    expect(find.text('Withdrawn'), findsOneWidget);
  });

  testWidgets('a member sees a change being voted on and goes to the vote', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    repo.ruleProposalsList.add({
      'id': 'rp-9', 'state': 'voting', 'reason': 'More grace days', 'proposed_by': 'Jane',
      'changed': ['contributions/grace_days'],
      'clauses': {'en': [{'ref': '3.2', 'before': 'Two days.', 'after': 'Four days.'}],
                  'sw': [{'ref': '3.2', 'before': 'Siku mbili.', 'after': 'Siku nne.'}]},
      'rules': <String, dynamic>{}, 'notice_until': '2026-10-01T09:00:00Z', 'vote_days': 7,
      'quorum_pct': 50, 'pass_pct': 66, 'vote_id': 'vote-1', 'effective_from': null,
      'created_at': 'x',
    });
    repo.votesList.add({
      'id': 'vote-1', 'subject': 'rules.proposal:rp-9', 'question': 'Change the rules?',
      'state': 'open', 'closes_at': '2026-10-25T10:00:00Z', 'secret': false, 'eligible': 4,
      'quorum_pct': 50, 'pass_pct': 66, 'quorum_needed': 2, 'cast': 0, 'yes': null,
      'no': null, 'voted': <String>[], 'i_can_vote': true, 'i_voted': false,
      'my_choice': null, 'result_receipt': null, 'created_at': 'x',
    });
    await _rulesTab(tester, repo);
    expect(find.byKey(const ValueKey('propose-rule-change')), findsNothing);
    await tester.tap(find.text('More grace days'));
    await tester.pumpAndSettle();
    expect(find.text('Members are voting'), findsOneWidget);
    expect(find.byKey(const ValueKey('rule-change-withdraw')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rule-change-vote')));
    await tester.pumpAndSettle();
    expect(find.text('Vote yes'), findsOneWidget);
  });
}
