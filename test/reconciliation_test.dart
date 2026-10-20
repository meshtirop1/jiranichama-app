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

Json _rec(String status, {int gap = 0, int unmatched = 0, int days = 0}) => {
      'status': status, 'checked_on': '2026-03-10', 'bank_cents': 1000000 + gap,
      'records_cents': 1000000, 'gap_cents': gap, 'unmatched_cents': unmatched,
      'unexplained_cents': gap - unmatched, 'gap_opened_on': status == 'match' ? null : '2026-03-01',
      'days_open': days, 'breach_after_days': 7, 'history': <Json>[],
    };

void main() {
  testWidgets('every member sees that the records match the bank', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)
      ..reconciliationJson = _rec('match');
    await _open(tester, repo, '');
    expect(find.text('Records match the bank · checked 2026-03-10'), findsOneWidget);
  });

  testWidgets("a balance read from the bank's API says so", (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)
      ..reconciliationJson = {..._rec('match'), 'bank_source': 'bank_api'};
    await _open(tester, repo, '');
    expect(find.text('Balance read straight from the bank.'), findsOneWidget);
  });

  testWidgets('a gap shows what it is made of', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)
      ..reconciliationJson = _rec('open', gap: 50000, unmatched: 30000, days: 2);
    await _open(tester, repo, '');
    expect(find.text('The records and the bank differ by KES 500 since 2026-03-01.'),
        findsOneWidget);
    expect(find.text('KES 300 is payments not yet matched to a member.'), findsOneWidget);
    expect(find.text('KES 200 is not explained by any record.'), findsOneWidget);
    expect(find.textContaining('becomes a breach, and every member is told, after 7 days'),
        findsOneWidget);
    expect(find.text('Bank KES 10,500 · records KES 10,000'), findsOneWidget);
  });

  testWidgets('a breach is shown in red to everyone', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)
      ..reconciliationJson = _rec('breach', gap: 450000, days: 9);
    await _open(tester, repo, '');
    expect(find.textContaining('BREACH: the records and the bank have differed by KES 4,500 '
        'for 9 days'), findsOneWidget);
  });

  testWidgets('before any statement it says the check has not run', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    await _open(tester, repo, '');
    expect(find.textContaining('Not yet checked against the bank'), findsOneWidget);
  });

  testWidgets('an overdue statement shows to the treasurer first', (tester) async {
    final rec = _rec('match')..['statement'] = {'level': 1, 'days_overdue': 3,
        'checked_to': '2026-03-01', 'every_days': 14, 'due_on': '2026-03-15'};
    final treasurer = FakeChamaRepository(myRole: 'treasurer')..reconciliationJson = rec;
    await _open(tester, treasurer, '');
    expect(find.text('The bank statement is 3 day(s) overdue. Upload it from Bank statements.'),
        findsOneWidget);
  });

  testWidgets('a member does not see level 1 or 2', (tester) async {
    final rec = _rec('match')..['statement'] = {'level': 2, 'days_overdue': 9,
        'checked_to': '2026-03-01', 'every_days': 14, 'due_on': '2026-03-15'};
    final repo = FakeChamaRepository(myRole: 'member', founder: false)
      ..reconciliationJson = rec;
    await _open(tester, repo, '');
    expect(find.textContaining('overdue'), findsNothing);
  });

  testWidgets('after 14 more days everyone sees records are not checked', (tester) async {
    final rec = _rec('match')..['statement'] = {'level': 3, 'days_overdue': 15,
        'checked_to': '2026-03-01', 'every_days': 14, 'due_on': '2026-03-15'};
    final repo = FakeChamaRepository(myRole: 'member', founder: false)
      ..reconciliationJson = rec;
    await _open(tester, repo, '');
    expect(find.text('Records not checked against the bank since 2026-03-01.'), findsOneWidget);
  });
}
