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

Future<void> _openEditor(WidgetTester tester, FakeChamaRepository repo) async {
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
  await scrollTo(tester, find.text('Edit all rules'));
  await tester.tap(find.text('Edit all rules'));
  await tester.pumpAndSettle();
}

Future<void> _visible(WidgetTester tester, Finder f) async {
  await scrollTo(tester, f);
}

void main() {
  testWidgets('the founder edits every rule setting and saves them all', (tester) async {
    final repo = FakeChamaRepository(state: 'setup');
    await _openEditor(tester, repo);
    expect(find.text('All rules'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('cash_days')), '5');
    // Fines before months behind.
    await _visible(tester, find.byKey(const ValueKey('alloc-fines')));
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('alloc-fines')),
        matching: find.byTooltip('Move up')));
    await tester.pumpAndSettle();
    await _visible(tester, find.byKey(const ValueKey('fine_cap')));
    await tester.enterText(find.byKey(const ValueKey('fine_cap')), '600');
    await _visible(tester, find.byKey(const ValueKey('role-secretary')));
    await tester.tap(find.byKey(const ValueKey('role-secretary')));
    await tester.pumpAndSettle();
    await _visible(tester, find.text('Add a level'));
    await tester.tap(find.text('Add a level'));
    await tester.pumpAndSettle();
    await _visible(tester, find.byKey(const ValueKey('tier-1-upto')));
    await tester.enterText(find.byKey(const ValueKey('tier-1-upto')), '200000');
    await _visible(tester, find.byKey(const ValueKey('entry_fee')));
    await tester.enterText(find.byKey(const ValueKey('entry_fee')), '500');
    await _visible(tester, find.text('Each member pays'));
    await tester.tap(find.text('Each member pays'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save rules'));
    await tester.pumpAndSettle();
    final r = repo.savedRules!;
    final c = r['contributions'] as Map;
    expect(c['cash_banking_days'], 5);
    expect(c['allocation_order'], ['fines', 'arrears', 'current']);
    expect((r['fines'] as Map)['late_contribution'],
        {'enabled': true, 'amount_cents': 20000, 'monthly_cap_cents': 60000});
    expect((r['officials'] as Map)['roles'], ['chair', 'treasurer']);
    final tiers = (r['approvals'] as Map)['tiers'] as List;
    expect(tiers.map((t) => (t as Map)['up_to_cents']), [5000000, 20000000, null]);
    expect((r['membership'] as Map)['entry_fee_cents'], 50000);
    expect((r['kyc'] as Map)['payer'], 'member');
    // Back on setup, told it saved (the note sits above the rules, so scroll up).
    await tester.dragUntilVisible(find.text('Rules saved.'), find.byType(ListView).first,
        const Offset(0, 300));
    expect(find.text('Rules saved.'), findsOneWidget);
  });

  testWidgets("the API's errors show next to the setting", (tester) async {
    final repo = FakeChamaRepository(state: 'setup');
    await _openEditor(tester, repo);
    await tester.enterText(find.byKey(const ValueKey('due_day')), '31');
    await tester.tap(find.text('Save rules'));
    await tester.pumpAndSettle();
    expect(repo.savedRules, isNull);
    expect(find.text('This value is out of range.'), findsOneWidget);
    expect(find.text('All rules'), findsOneWidget); // still editing
  });

  testWidgets('switching the late fine off sends no amount', (tester) async {
    final repo = FakeChamaRepository(state: 'setup');
    await _openEditor(tester, repo);
    await _visible(tester, find.byKey(const ValueKey('fine_on')));
    await tester.tap(find.byKey(const ValueKey('fine_on')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fine_amount')), findsNothing);
    await tester.tap(find.text('Save rules'));
    await tester.pumpAndSettle();
    expect((repo.savedRules!['fines'] as Map)['late_contribution'],
        {'enabled': false, 'amount_cents': 0, 'monthly_cap_cents': null});
  });
}
