import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiranichama/app.dart';
import 'package:jiranichama/core/api/problem.dart';
import 'package:jiranichama/core/providers.dart';
import 'package:jiranichama/features/auth/data/auth_repository.dart';

import 'fakes.dart';

class FakeAuth implements AuthRepository {
  bool session = false;
  String? sentTo;
  String? pin;
  int wrongTriesLeft = 4;

  @override
  Future<bool> hasSession() async => session;

  @override
  Future<CodeSent> requestCode(String phone, {required String language}) async {
    sentTo = phone;
    return const CodeSent(phoneHint: '+2547••• ••• 678', expiresIn: 300);
  }

  @override
  Future<SignedIn> verifyCode(String phone, String code) async {
    if (code != '424242') {
      throw ApiProblem(code: 'otp_wrong', detail: '', status: 400,
          extra: {'attempts_left': wrongTriesLeft--});
    }
    session = true;
    return const SignedIn(isNew: true, hasPin: false);
  }

  String? name;

  @override
  Future<void> setPin(String pin) async => this.pin = pin;

  @override
  Future<void> setProfile({required String name, required String language}) async =>
      this.name = name;

  @override
  Future<void> signOut() async => session = false;
}

Future<void> _pumpApp(WidgetTester tester, FakeAuth auth) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      chamaRepositoryProvider.overrideWithValue(FakeChamaRepository(state: 'none')),
    ],
    child: const JiraniApp(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('new member signs in, sets a PIN and reaches home', (tester) async {
    final auth = FakeAuth();
    await _pumpApp(tester, auth);

    expect(find.text('Sign in with your phone'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a Kenyan mobile number'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0712 345 678');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(auth.sentTo, '+254712345678');
    expect(find.textContaining('+2547••• ••• 678'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '111111');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('That code is not right. 4 tries left.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '424242');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Set your app PIN'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '482916');
    await tester.enterText(fields.at(2), '482916');
    await tester.tap(find.text('Save PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsOneWidget);

    await tester.enterText(fields.at(0), 'Wanjiru Kamau');
    await tester.enterText(fields.at(2), '482917');
    await tester.tap(find.text('Save PIN'));
    await tester.pumpAndSettle();
    expect(find.text('The two PINs are not the same.'), findsOneWidget);

    await tester.enterText(fields.at(2), '482916');
    await tester.tap(find.text('Save PIN'));
    await tester.pumpAndSettle();
    expect(auth.pin, '482916');
    expect(auth.name, 'Wanjiru Kamau');
    expect(find.text('Your chamas'), findsOneWidget);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with your phone'), findsOneWidget);
  });

  testWidgets('a returning member with a session goes straight home', (tester) async {
    await _pumpApp(tester, FakeAuth()..session = true);
    expect(find.text('Your chamas'), findsOneWidget);
  });

  testWidgets('the sign-in screen switches to Kiswahili', (tester) async {
    await _pumpApp(tester, FakeAuth());
    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiswahili').last);
    await tester.pumpAndSettle();
    expect(find.text('Ingia kwa simu yako'), findsOneWidget);
    expect(find.text('Tuma nambari'), findsOneWidget);
  });
}
