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

Json _needsTyping() => {
      'id': 'st-1', 'route': 'upload', 'state': 'needs_typing', 'period_from': '2026-03-04',
      'period_to': '2026-03-06', 'closing_cents': 1149500, 'lines': 2,
      'uploaded_by': 'Akinyi', 'problems': <Json>[], 'flags': <Json>[],
      'unreadable_lines': [
        {'line_no': 9, 'cells': ['##/##/####', 'CASH DEPOSIT', '', '', '300.00', '']},
      ],
      'typed_lines': <Json>[],
    };

void main() {
  testWidgets('an official types in a line the bank file had unreadable', (tester) async {
    final repo = FakeChamaRepository(myRole: 'secretary')..statementsList.add(_needsTyping());
    await _open(tester, repo, FakeDocumentSaver(), 'Bank statements');
    expect(find.text('Lines to type in'), findsOneWidget);
    expect(find.textContaining('1 line(s) could not be read'), findsOneWidget);
    await tester.tap(find.text('Type in lines'));
    await tester.pumpAndSettle();

    expect(find.text('Line 9 in the file'), findsOneWidget);
    expect(find.textContaining('##/##/####  |  CASH DEPOSIT'), findsOneWidget);
    // The description is filled in from the file; the official adds date and amount.
    expect(tester.widget<TextField>(find.byKey(const ValueKey('narration-9')))
        .controller!.text, 'CASH DEPOSIT');

    await tester.tap(find.text('Save typed lines'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check each line'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('date-9')), '2026-03-05');
    await tester.enterText(find.byKey(const ValueKey('amount-9')), '30');
    await tester.tap(find.text('Save typed lines'));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not add up'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('amount-9')), '300.00');
    await tester.tap(find.text('Save typed lines'));
    await tester.pumpAndSettle();
    expect(repo.typedSubmitted!.single, containsPair('credit_cents', 30000));
    expect(repo.typedSubmitted!.single, containsPair('value_date', '2026-03-05'));
    expect(find.textContaining('Another official now confirms'), findsOneWidget);
    expect(find.text('1 line(s) typed in by Akinyi'), findsOneWidget);
  });

  testWidgets('money out is sent as a debit', (tester) async {
    final repo = FakeChamaRepository(myRole: 'secretary')..statementsList.add(_needsTyping());
    await _open(tester, repo, FakeDocumentSaver(), 'Bank statements');
    await tester.tap(find.text('Type in lines'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('date-9')), '2026-03-05');
    await tester.enterText(find.byKey(const ValueKey('amount-9')), '15');
    await tester.tap(find.text('Money out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save typed lines'));
    await tester.pumpAndSettle();
    // The fake refuses anything but 300 in: the request reached it as a debit.
    expect(find.textContaining('does not add up'), findsOneWidget);
    expect(repo.typedSubmitted, isNull);
  });
}
