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
}
