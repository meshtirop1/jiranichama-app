import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jirani_ui/jirani_ui.dart';
import 'package:jiranichama/app.dart';
import 'package:jiranichama/core/providers.dart';
import 'package:jiranichama/core/tours.dart';
import 'package:jiranichama/features/auth/data/auth_repository.dart';

import 'fakes.dart';

class _SignedIn implements AuthRepository {
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<CodeSent> requestCode(String phone,
          {required String language, String country = 'KE'}) =>
      throw UnimplementedError();
  @override
  Future<SignedIn> verifyCode(String phone, String code) => throw UnimplementedError();
  @override
  Future<void> setPin(String pin) async {}
  @override
  Future<void> setProfile(
      {required String name, required String language, String? country}) async {}
  @override
  Future<void> signOut() async {}
}

/// The tour's ring pulses for ever, so these tests pump time instead of settling.
Future<void> _wait(WidgetTester tester, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('the home tour plays once, step by step, and the help button replays it',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final memory = MemoryTourMemory();
    await tester.pumpWidget(ProviderScope(overrides: [
      authRepositoryProvider.overrideWithValue(_SignedIn()),
      chamaRepositoryProvider.overrideWithValue(FakeChamaRepository()),
      tourMemoryProvider.overrideWithValue(memory),
    ], child: const JiraniApp()));
    await _wait(tester, 2500);

    // Step 1 of 3 points at the chama list.
    expect(find.text('Every chama you belong to is here, with your role and whether it is '
        'active. Tap one to open it.'), findsOneWidget);
    expect(memory.shown, contains('home'));
    await tester.tap(find.byKey(const ValueKey('tour-next')));
    await _wait(tester);
    expect(find.text('Start a chama'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tour-next')));
    await _wait(tester);
    expect(find.text('Join with a code'), findsNWidgets(2)); // the card and the tour
    expect(find.text('Got it'), findsOneWidget); // the last step
    await tester.tap(find.byKey(const ValueKey('tour-next')));
    await _wait(tester);
    expect(find.text('Start a chama'), findsNothing);

    // Seen: it does not come back by itself, but the "?" plays it again.
    await tester.tap(find.byKey(const ValueKey('tour-help')));
    await _wait(tester);
    expect(find.text('Got it'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tour-skip')));
    await _wait(tester);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('a step whose part is not on screen is shown in the middle', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: JiraniTheme.light(),
      home: Builder(builder: (context) => Scaffold(
        body: Center(child: FilledButton(
          onPressed: () => showTour(context, [
            TourStep(target: GlobalKey(), title: 'Nowhere', body: 'Not built yet.'),
          ], labels: const TourLabels(next: 'Next', done: 'Done', skip: 'Skip')),
          child: const Text('Start'),
        )),
      )),
    ));
    await tester.tap(find.text('Start'));
    await _wait(tester);
    expect(find.text('Nowhere'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await _wait(tester);
    expect(find.text('Nowhere'), findsNothing);
  });
}
