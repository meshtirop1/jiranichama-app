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

Future<void> _open(WidgetTester tester, FakeChamaRepository repo, FakeDocumentSaver saver,
    String button) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [
    authRepositoryProvider.overrideWithValue(_SignedIn()),
    chamaRepositoryProvider.overrideWithValue(repo),
    documentSaverProvider.overrideWithValue(saver),
  ], child: const JiraniApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Umoja Women Group'));
  await tester.pumpAndSettle();
  await scrollTo(tester, find.text(button));
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a member reads their statement and takes away a sealed PDF', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    final saver = FakeDocumentSaver();
    await _open(tester, repo, saver, 'See my statement');

    expect(find.text('My statement'), findsOneWidget);
    expect(find.text('Wanjiru (JC-4821-004)'), findsOneWidget);
    expect(find.text('Position on 2026-03-10'), findsOneWidget);
    expect(find.text('Reversal of P3XW8RT2 · 2026-01'), findsOneWidget);
    expect(find.text('2026-02-03 · P3XW8RT2 · Reversed'), findsOneWidget);

    await tester.tap(find.text('Get PDF statement'));
    await tester.pumpAndSettle();
    expect(repo.calls, containsAllInOrder(['memberPdf:m4:en', 'download:doc-1']));
    expect(saver.saved.keys, ['JiraniChama-member-statement-7KQ2M9XB4D.pdf']);
    expect(find.text('Check code: 7KQ2M-9XB4D'), findsOneWidget);

    await tester.tap(find.text('Share PDF'));
    await tester.pumpAndSettle();
    expect(saver.shared.single, contains('7KQ2M-9XB4D'));
    expect(saver.shared.single, startsWith('/fake/JiraniChama-member-statement'));
  });

  testWidgets('choosing a period asks for that period', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    await _open(tester, repo, FakeDocumentSaver(), 'See my statement');
    await tester.tap(find.text('This year'));
    await tester.pumpAndSettle();
    expect(repo.statementFroms.last, '${DateTime.now().year}-01-01');
    expect(find.text('Nothing was recorded in this period.'), findsOneWidget);
  });

  testWidgets("another member's figures are open, but not their PDF", (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    await _open(tester, repo, FakeDocumentSaver(), 'Members');
    await tester.tap(find.text('Jane'));
    await tester.pumpAndSettle();
    expect(find.text('Member statement'), findsOneWidget);
    expect(find.text('Get PDF statement'), findsNothing);
    expect(find.textContaining('Only the member or an official'), findsOneWidget);
  });

  testWidgets('an official can take any member\'s PDF', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair');
    await _open(tester, repo, FakeDocumentSaver(), 'Members');
    await tester.tap(find.text('Wanjiru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get PDF statement'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('memberPdf:m4:en'));
  });

  testWidgets('the chama statement shows every member and the bank side', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    await _open(tester, repo, FakeDocumentSaver(), 'Chama statement');
    expect(find.text('Jane (JC-4821-001)'), findsOneWidget);
    expect(find.text('Wanjiru (JC-4821-004)'), findsOneWidget);
    expect(find.text('Bank statement reconciled to 2026-03-05'), findsOneWidget);
    expect(find.text('1 payment(s) not yet matched: KES 300'), findsOneWidget);
    await tester.tap(find.text('Get PDF statement'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('chamaPdf:c1:en'));
    expect(find.text('The PDF statement is ready.'), findsOneWidget);
  });
}
