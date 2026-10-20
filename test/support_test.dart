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

void main() {
  testWidgets('officials give support read access and every member sees it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final repo = FakeChamaRepository(myRole: 'treasurer');
    await tester.pumpWidget(ProviderScope(overrides: [
      authRepositoryProvider.overrideWithValue(_SignedIn()),
      chamaRepositoryProvider.overrideWithValue(repo),
    ], child: const JiraniApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Umoja Women Group'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('governance-card')));
    await tester.tap(find.byKey(const ValueKey('governance-card')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('get-help')));
    await tester.tap(find.byKey(const ValueKey('get-help')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('area-ledger')));
    await tester.enterText(find.byKey(const ValueKey('support-reason')), 'Statement will not load');
    await tester.tap(find.byKey(const ValueKey('support-ask')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('support:statements,ledger:72:Statement will not load'));
    expect(find.textContaining('Waiting for a second official'), findsOneWidget); // asked by another official in this fake

    await tester.tap(find.byKey(const ValueKey('support-confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('JiraniChama support can read bank statements, records'),
        findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('JiraniChama support can read'), findsOneWidget);
  });
}
