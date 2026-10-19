import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiranichama/app.dart';
import 'package:jiranichama/core/providers.dart';
import 'package:jiranichama/features/auth/data/auth_repository.dart';
import 'package:jiranichama/features/chamas/presentation/meetings_screen.dart';

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

class _Scanner implements CodeScanner {
  @override
  Future<String?> scan(BuildContext context) async => 'jcmeet:meet-1:482913';
}

Future<void> _meetings(WidgetTester tester, FakeChamaRepository repo) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [
    authRepositoryProvider.overrideWithValue(_SignedIn()),
    chamaRepositoryProvider.overrideWithValue(repo),
    fileSourceProvider.overrideWithValue(FakeFileSource()),
    codeScannerProvider.overrideWithValue(_Scanner()),
  ], child: const JiraniApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Umoja Women Group'));
  await tester.pumpAndSettle();
  await scrollTo(tester, find.byKey(const ValueKey('meetings-card')));
  await tester.tap(find.byKey(const ValueKey('meetings-card')));
  await tester.pumpAndSettle();
}

Future<void> _answer(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('ask-text')), text);
  await tester.tap(find.byKey(const ValueKey('ask-ok')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the secretary schedules, runs and closes a meeting, then sends minutes',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'secretary', founder: false);
    await _meetings(tester, repo);
    expect(find.text('No meetings yet.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('schedule-meeting')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('meet-title')), 'March meeting');
    await tester.tap(find.text('Schedule a meeting').last);
    await tester.pumpAndSettle();
    expect(find.text('Say where the meeting is, or give the online link.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('meet-place')), 'Church hall');
    await tester.tap(find.text('Schedule a meeting').last);
    await tester.pumpAndSettle();
    expect(repo.calls, contains('scheduleMeeting:March meeting:Church hall'));
    expect(find.text('Scheduled'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('meet-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('meet-show-code')));
    await tester.pumpAndSettle();
    expect(find.text('482913'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byKey(const ValueKey('mark-JC-4821-002')));
    await tester.tap(find.byKey(const ValueKey('mark-JC-4821-002')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('mark:m2:false'));
    await scrollTo(tester, find.byKey(const ValueKey('meet-close')));
    await tester.tap(find.byKey(const ValueKey('meet-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close attendance').last);
    await tester.pumpAndSettle();
    expect(find.text('Absent'), findsOneWidget);
    expect(find.text('Attendance on the record, receipt ATT12345'), findsOneWidget);

    await scrollTo(tester, find.byKey(const ValueKey('meet-write-minutes')));
    await tester.tap(find.byKey(const ValueKey('meet-write-minutes')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('minutes-text')), 'Agreed on tables.');
    await tester.tap(find.byKey(const ValueKey('minutes-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send to members'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('minutes:Agreed on tables.:minutes.jpg'));
    expect(find.text('Minutes out: members may object'), findsOneWidget);
  });

  testWidgets('a member apologises, checks in by scanning, and objects to the minutes',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    repo.meetingsList.add(repo.newMeeting());
    await _meetings(tester, repo);
    await tester.tap(find.text('March meeting'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meet-start')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('meet-apology')));
    await tester.pumpAndSettle();
    await _answer(tester, 'Sick child');
    expect(repo.calls, contains('apologise:Sick child'));
    expect(find.text('You: Sent an apology'), findsOneWidget);

    // The meeting goes ahead and the member makes it after all.
    repo.meetingsList.first
      ..['state'] = 'in_progress'
      ..['my_status'] = 'expected';
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('March meeting'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('meet-scan')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('checkIn:482913'));
    expect(find.text('You: Present'), findsOneWidget);

    await repo.postMinutes('meet-1', text: 'Agreed on chairs.');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('March meeting'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('meet-object')));
    await tester.tap(find.byKey(const ValueKey('meet-object')));
    await tester.pumpAndSettle();
    await _answer(tester, 'We agreed on tables.');
    expect(find.text('Jane objects: We agreed on tables.'), findsOneWidget);
  });
}
