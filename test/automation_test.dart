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

Future<void> _app(WidgetTester tester, FakeChamaRepository repo, {bool open = true}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [
    authRepositoryProvider.overrideWithValue(_SignedIn()),
    chamaRepositoryProvider.overrideWithValue(repo),
    phoneSignerProvider.overrideWithValue(FakePhoneSigner(isAvailable: false)),
  ], child: const JiraniApp()));
  await tester.pumpAndSettle();
  if (open) {
    await tester.tap(find.text('Umoja Women Group'));
    await tester.pumpAndSettle();
  }
}

Future<void> _sms(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).last, smsCode);
  await tester.tap(find.text('Confirm'));
  await tester.pumpAndSettle();
}

Json _poll({bool allowChange = true}) => {
      'id': 'vote-2', 'subject': 'votes.motion:mo-1', 'kind': 'choice',
      'question': 'Where shall the AGM be?', 'details': 'We need more room.',
      'options': ['Church hall', 'School'], 'state': 'open', 'allow_change': allowChange,
      'closes_at': '2026-03-13T10:00:00Z', 'secret': false, 'eligible': 7, 'quorum_pct': 50,
      'pass_pct': 50, 'quorum_needed': 4, 'cast': 2, 'yes': null, 'no': null,
      'abstain': null, 'option_counts': null, 'winner': null, 'voted': ['Peter', 'Ann'],
      'i_can_vote': true, 'i_voted': false, 'my_choice': null, 'raised_by': 'Ann',
      'comments': 0, 'result_receipt': null, 'created_at': 'x',
    };

void main() {
  testWidgets('the bell counts unread notices and opening them marks them read',
      (tester) async {
    final repo = FakeChamaRepository()
      ..noticesList.addAll([
        {'id': 1, 'kind': 'due', 'text': 'Reminder: KES 1,000 is due on 2026-11-05.',
         'data': {'screen': 'pay'}, 'urgent': false, 'chama_id': 'chama-1',
         'chama': 'Umoja Women Group', 'read': false, 'at': '2026-11-02T08:00:00Z'},
        {'id': 2, 'kind': 'vote', 'text': 'New vote: Buy chairs?', 'data': {},
         'urgent': false, 'chama_id': 'chama-1', 'chama': 'Umoja Women Group',
         'read': true, 'at': '2026-11-01T08:00:00Z'},
      ]);
    await _app(tester, repo, open: false);
    expect(find.descendant(of: find.byKey(const ValueKey('notices-button')),
        matching: find.text('1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notices-button')));
    await tester.pumpAndSettle();
    expect(find.text('Reminder: KES 1,000 is due on 2026-11-05.'), findsOneWidget);
    expect(repo.calls, contains('notices-read'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('notices-button')),
        matching: find.text('1')), findsNothing);
  });

  testWidgets('pay now sends the M-Pesa prompt and shows the receipt', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)
      ..payJson = {
        'owed': {'total_cents': 120000, 'arrears_cents': 100000, 'fines_cents': 20000,
                 'current_cents': 0, 'current_period': '2026-11', 'due_on': '2026-11-05'},
        'how': {'member_code': 'JC-4821-002', 'text': 'Pay to Paybill 600638.',
                'pay_now': true},
      };
    await _app(tester, repo);
    await scrollTo(tester, find.byKey(const ValueKey('pay-now')));
    expect(find.text('To pay now'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pay-now')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4)); // the first status check
    await tester.pump();
    expect(repo.calls, contains('pay-now:120000'));
    expect(find.textContaining('QKL1234567'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pay-now-done')));
    await tester.pumpAndSettle();
  });

  testWidgets('a member answers whether another phone pays for them', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    final me = (await repo.members('chama-1')).firstWhere((m) => m.role == 'member');
    repo.payerLinksList.add({'id': 'pl-1', 'membership_id': me.id, 'name': me.name,
        'state': 'suggested', 'from_amount_cents': 50000});
    await _app(tester, repo);
    await scrollTo(tester, find.byKey(const ValueKey('payer-yes-pl-1')));
    expect(find.textContaining('KES 500 from a phone that is not yours'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payer-yes-pl-1')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('payer:pl-1:true'));
    expect(find.byKey(const ValueKey('payer-yes-pl-1')), findsNothing);
  });

  testWidgets('a poll: pick an option, vote by SMS code, change it, and comment',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)
      ..votesList.add(_poll());
    await _app(tester, repo);
    await tester.tap(find.textContaining('Your vote is needed'));
    await tester.pumpAndSettle();
    expect(find.text('We need more room.'), findsOneWidget);
    expect(find.text('Raised by Ann'), findsOneWidget);
    expect(find.text('The option with the most votes wins. A tie decides nothing.'),
        findsOneWidget);
    await tester.tap(find.text('School'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vote: School'));
    await tester.pumpAndSettle();
    await _sms(tester);
    expect(repo.calls, contains('ballot:vote-2:2'));
    expect(find.textContaining('You voted: School.'), findsOneWidget);
    expect(find.textContaining('You can change your vote'), findsOneWidget);
    await tester.tap(find.text('Abstain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vote: Abstain'));
    await tester.pumpAndSettle();
    await _sms(tester);
    expect(repo.calls, contains('ballot:vote-2:abstain'));
    await scrollTo(tester, find.byKey(const ValueKey('comment-field')));
    await tester.enterText(find.byKey(const ValueKey('comment-field')), 'The hall is free');
    await tester.tap(find.byKey(const ValueKey('comment-send')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('comment:vote-2:The hall is free'));
    expect(find.text('The hall is free'), findsOneWidget);
  });

  testWidgets('a yes or no vote can be abstained from', (tester) async {
    final v = _poll(allowChange: false)
      ..['kind'] = 'yes_no'
      ..['options'] = <String>[];
    final repo = FakeChamaRepository(myRole: 'member', founder: false)..votesList.add(v);
    await _app(tester, repo);
    await tester.tap(find.textContaining('Your vote is needed'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vote-abstain')));
    await tester.pumpAndSettle();
    await _sms(tester);
    expect(repo.calls, contains('ballot:vote-2:abstain'));
    expect(find.byKey(const ValueKey('vote-yes')), findsNothing);
  });

  testWidgets('a member raises a poll motion and another seconds one', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)
      ..motionsList.add({
        'id': 'mo-9', 'kind': 'yes_no', 'question': 'Buy a tent?', 'details': '',
        'options': [], 'vote_days': 7, 'state': 'seconding', 'seconds_needed': 2,
        'seconds': 0, 'seconded_by': <String>[], 'i_can_second': true, 'mine': false,
        'raised_by': 'Peter', 'vote': null});
    await _app(tester, repo);
    await scrollTo(tester, find.byKey(const ValueKey('motions-card')));
    await tester.tap(find.byKey(const ValueKey('motions-card')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Waiting for seconds: 0 of 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('second-mo-9')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('second:mo-9'));
    expect(find.textContaining('Waiting for seconds: 1 of 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('raise-motion')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('motion-question')),
        'Where shall the AGM be?');
    await tester.tap(find.text('Choose between options'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('motion-option-0')), 'Church hall');
    await tester.enterText(find.byKey(const ValueKey('motion-option-1')), 'School');
    await tester.tap(find.byKey(const ValueKey('send-motion')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('motion:choice:Where shall the AGM be?:[Church hall, School]'));
    expect(find.text('Where shall the AGM be?'), findsOneWidget);
  });

  testWidgets('an official prepares the share-out and sends it to the vote', (tester) async {
    final repo = FakeChamaRepository();
    await _app(tester, repo);
    await scrollTo(tester, find.text('Share-out'));
    await tester.tap(find.text('Share-out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Savings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shareout-draft')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('shareout-draft:savings:0'));
    expect(find.text('Share-out 2025'), findsOneWidget);
    expect(find.textContaining('fines −KES 200'), findsOneWidget);
    await scrollTo(tester, find.byKey(const ValueKey('shareout-submit')));
    await tester.tap(find.byKey(const ValueKey('shareout-submit')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('shareout-submit'));
    expect(find.textContaining('The members are voting'), findsOneWidget);
  });

  testWidgets('the treasurer assigns a suggested member with one tap', (tester) async {
    final repo = FakeChamaRepository(myRole: 'treasurer');
    final members = await repo.members('chama-1');
    final mary = members.last;
    repo.unmatchedList.first['suggestions'] = [
      {'membership_id': mary.id, 'member_code': mary.memberCode, 'name': mary.name,
       'score': 75, 'reasons': ['code', 'name'], 'reason_text': 'x'},
    ];
    await _app(tester, repo);
    await scrollTo(tester, find.text('Unmatched payments'));
    await tester.tap(find.text('Unmatched payments'));
    await tester.pumpAndSettle();
    expect(find.text('Likely members'), findsOneWidget);
    await tester.tap(find.text('${mary.name} · ${mary.memberCode}'));
    await tester.pumpAndSettle();
    expect(find.text("member code with a slip, the payer's name"), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
    await tester.pumpAndSettle();
    expect(repo.calls.any((c) => c.startsWith('assign:txn-1:${mary.id}')), isTrue);
  });
}
