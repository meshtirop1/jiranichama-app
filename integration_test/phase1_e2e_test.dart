// Phase 1 end to end, on a device, against a real local API (not fakes).
//
// Needs the API running in local development mode with the dev SMS outbox, so the test
// can read the codes the server "sent":
//   DJANGO_DEBUG=1 DJANGO_SECURE_SSL_REDIRECT=0 SMS_BACKENDS=apps.notify.sms.DevFileBackend
//   DEV_SMS_FILE=.dev-sms.log python manage.py runserver 0.0.0.0:8000
// Run:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/phase1_e2e_test.dart -d emulator-5554
//
// Four people sign in and out on one phone: the founder (chair), the treasurer, the
// secretary and a member. Only the statement file is handed in directly instead of
// through the system file picker.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jiranichama/app.dart';
import 'package:jiranichama/core/providers.dart';

// The emulator reaches the host at 10.0.2.2. A USB phone uses `adb reverse tcp:8000
// tcp:8000` and 127.0.0.1; pass --dart-define=E2E_HOST=http://127.0.0.1:8000 and the
// matching API_BASE_URL.
const _host = String.fromEnvironment('E2E_HOST', defaultValue: 'http://10.0.2.2:8000');
const _pin = '482916';

class _StatementFile implements FileSource {
  List<int> bytes = [];

  @override
  Future<PickedFile?> pickStatement() async => PickedFile('statement.csv', bytes);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final file = _StatementFile();
  final run = Random().nextInt(90000) + 10000;
  String phone(int who) => '07$who$run${who}0'.substring(0, 10);
  String e164(String local) => '+254${local.substring(1)}';

  testWidgets('Phase 1: set up a chama, adopt rules, bring in a statement, match',
      (tester) async {
    var shot = 0;
    var converted = false;
    Future<void> screenshot(String name) async {
      if (!converted) {
        await binding.convertFlutterSurfaceToImage();
        converted = true;
      }
      await tester.pumpAndSettle();
      await binding.takeScreenshot('${(++shot).toString().padLeft(2, '0')}_$name');
    }

    Future<void> waitFor(Finder finder, {int seconds = 30}) async {
      for (var i = 0; i < seconds * 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        try {
          if (finder.evaluate().isNotEmpty) return;
        } on StateError {
          // A .first/.last finder over nothing, mid-rebuild: look again.
        }
        // Lists build lazily: messages appear at the top, which may be scrolled away.
        if (i == 8 && find.byType(Scrollable).evaluate().isNotEmpty) {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, 20000));
          await tester.pumpAndSettle();
        }
      }
      debugPrint('E2E TIMEOUT waiting for $finder');
      if (find.byType(Scrollable).evaluate().isNotEmpty) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 20000));
        await tester.pumpAndSettle();
      }
      for (final e in find.byWidgetPredicate((w) => w.runtimeType.toString() == 'Notice')
          .evaluate()) {
        debugPrint('E2E notice: ${(e.widget as dynamic).message}');
      }
      await screenshot('failed_waiting');
      throw TestFailure('Timed out waiting for $finder');
    }

    // Wait on the plain finder; pick the first or last match only when acting, because a
    // first/last finder over no matches throws even when printed.
    Future<void> tap(Finder finder, {bool last = false}) async {
      debugPrint('E2E tap $finder');
      await waitFor(finder);
      final target = last ? finder.last : finder.first;
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> type(Finder field, String text, {bool last = false}) async {
      debugPrint('E2E type into $field');
      await waitFor(field);
      final target = last ? field.last : field.first;
      for (var attempt = 0; attempt < 3; attempt++) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        // Focus the field first: on a real phone, text sent while focus is still with a
        // closing menu is lost.
        await tester.tap(target);
        await tester.pumpAndSettle();
        await tester.enterText(target, text);
        await tester.pumpAndSettle();
        final typed = tester.widget<TextField>(target).controller?.text;
        if (typed == null || typed == text) return;
        debugPrint('E2E retyping: field had "$typed"');
      }
      throw TestFailure('Could not type into $field');
    }

    Future<String> latestCode(String toE164) async {
      final client = HttpClient();
      for (var i = 0; i < 20; i++) {
        final req = await client.getUrl(Uri.parse(
            '$_host/dev/sms/?to=${Uri.encodeQueryComponent(toE164)}'));
        final body = await (await req.close()).transform(utf8.decoder).join();
        final messages = (jsonDecode(body) as Map)['messages'] as List;
        if (messages.isNotEmpty) {
          final m = RegExp(r'\b(\d{6})\b').firstMatch(messages.last['text'] as String);
          if (m != null) return m.group(1)!;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      throw TestFailure('No SMS for $toE164');
    }

    var lastCodeFor = <String, String>{};
    Future<String> newCode(String toE164) async {
      for (var i = 0; i < 20; i++) {
        final c = await latestCode(toE164);
        if (c != lastCodeFor[toE164]) return lastCodeFor[toE164] = c;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      throw TestFailure('No new SMS for $toE164');
    }

    Future<void> signIn(String local) async {
      await type(find.byType(TextField), local);
      await tap(find.text('Send code'));
      await waitFor(find.text('Enter the code'));
      await type(find.byType(TextField), await newCode(e164(local)));
      await tap(find.text('Continue'));
      await waitFor(find.text('Set your app PIN'));
      final fields = find.byType(TextField);
      await type(fields.at(0), 'Person $local');
      await type(fields.at(1), _pin);
      await type(fields.at(2), _pin);
      await tap(find.text('Save PIN'));
      await waitFor(find.text('Your chamas'));
    }

    Future<void> signOut() async {
      while (find.byTooltip('Sign out').evaluate().isEmpty) {
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tap(find.byTooltip('Sign out'));
      await waitFor(find.text('Sign in with your phone'));
    }

    Future<void> confirmSms(String local) async {
      await waitFor(find.text('Enter the code we sent by SMS'));
      await type(find.byType(TextField), await newCode(e164(local)), last: true);
      await tap(find.text('Confirm'));
    }

    String inviteCodeOnScreen() {
      final s = tester.widgetList<Text>(find.textContaining('Invite code ')).first.data!;
      return RegExp(r'Invite code ([A-Z]{6})').firstMatch(s)!.group(1)!;
    }

    final founder = phone(1), treasurer = phone(2), secretary = phone(3), member = phone(4);
    final chamaName = 'Umoja E2E $run';

    await tester.pumpWidget(ProviderScope(
      overrides: [fileSourceProvider.overrideWithValue(file)],
      child: const JiraniApp(),
    ));
    await waitFor(find.text('Sign in with your phone'));
    await screenshot('sign_in');

    // 1. The founder signs in and creates the chama.
    await signIn(founder);
    await tap(find.text('Create a chama'));
    await type(find.widgetWithText(TextField, 'Chama name'), chamaName);
    await tap(find.text('Create chama'));
    await waitFor(find.textContaining('Add the bank account'));

    await type(find.widgetWithText(TextField, 'Account name'), 'UMOJA E2E');
    await type(find.widgetWithText(TextField, 'Account number'), '0123456789012');
    await tap(find.text('Officials upload them'));
    await tap(find.text('Save bank account'));
    await waitFor(find.textContaining('account ending 9012'));

    final invites = <String, String>{};
    for (final (role, local) in [('Treasurer', treasurer), ('Secretary', secretary),
      ('Member', member)]) {
      // The invite section is far down a lazily built list: scroll to it first.
      await tester.scrollUntilVisible(find.byKey(const ValueKey('invite-phone')), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('invite-role')));
      await tap(find.text(role), last: true);
      await type(find.byKey(const ValueKey('invite-phone')), local);
      await tap(find.text('Create invite'));
      await waitFor(find.textContaining('Invite code '));
      invites[role] = inviteCodeOnScreen();
    }
    await screenshot('setup_with_invites');
    await tap(find.text('Send the rules for confirmation'));
    await waitFor(find.textContaining('Waiting for every office'));
    await signOut();

    // 2. Each official and the member joins with their invite and an SMS code.
    Future<void> join(String local, String code) async {
      await signIn(local);
      await tap(find.text('Join with a code'));
      await type(find.byType(TextField), code);
      await tap(find.text('Continue'));
      await waitFor(find.text('Join and accept these rules'));
      await tap(find.text('Join and accept these rules'));
      await confirmSms(local);
      await waitFor(find.text(chamaName));
    }

    await join(treasurer, invites['Treasurer']!);
    await signOut();
    await join(secretary, invites['Secretary']!);
    // Every office is now filled, so the chama is confirming its rules.
    await waitFor(find.text('Confirm these rules'));
    await screenshot('adoption_open');
    await tap(find.text('Confirm these rules'));
    await confirmSms(secretary);
    await waitFor(find.text('You have confirmed the rules.'));
    await signOut();
    await join(member, invites['Member']!);
    await signOut();

    // 3. The founder and the treasurer confirm: the chama goes live.
    for (final local in [founder, treasurer]) {
      await type(find.byType(TextField), local);
      await tap(find.text('Send code'));
      await type(find.byType(TextField), await newCode(e164(local)));
      await tap(find.text('Continue'));
      await waitFor(find.text('Your chamas'));
      await tap(find.text(chamaName));
      await tap(find.text('Confirm these rules'));
      await confirmSms(local);
      await waitFor(local == founder ? find.text('You have confirmed the rules.')
          : find.text('Overview'));
      if (local == treasurer) await screenshot('chama_active_overview');
      await signOut();
    }

    // 4. The secretary uploads today's bank statement; the treasurer could not.
    // Use the server's date (Africa/Nairobi), not the device clock, which can differ.
    final client = HttpClient();
    final res = await (await client.getUrl(Uri.parse('$_host/healthz'))).close();
    await res.drain<void>();
    final today = HttpDate.parse(res.headers.value('date')!).add(const Duration(hours: 3));
    String d(DateTime t) => '${t.day.toString().padLeft(2, '0')}/'
        '${t.month.toString().padLeft(2, '0')}/${t.year}';
    file.bytes = utf8.encode([
      'Account Number:,0123456789012',
      'Opening Balance:,5000.00',
      'Closing Balance:,7300.00',
      '',
      'Value Date,Narration,Reference,Debit,Credit,Balance',
      '${d(today)},MPESA C2B $founder JANE,E2E1$run,,1000.00,6000.00',
      '${d(today)},MPESA DEPOSIT $member WANJIRU,E2E2$run,,1000.00,7000.00',
      '${d(today)},CASH DEPOSIT,E2E3$run,,300.00,7300.00',
    ].join('\n'));

    await type(find.byType(TextField), secretary);
    await tap(find.text('Send code'));
    await type(find.byType(TextField), await newCode(e164(secretary)));
    await tap(find.text('Continue'));
    await tap(find.text(chamaName));
    await tap(find.text('Bank statements'));
    await tap(find.text('Upload a statement (CSV)'));
    await waitFor(find.text('Waiting for a second official'));
    await screenshot('statement_uploaded');
    await tap(find.text('Confirm this statement'));
    await waitFor(find.textContaining('A different official must confirm'));
    await signOut();

    // 5. The founder (chair) confirms it, and sees the payments matched and the
    //    records checked on the phone.
    await type(find.byType(TextField), founder);
    await tap(find.text('Send code'));
    await type(find.byType(TextField), await newCode(e164(founder)));
    await tap(find.text('Continue'));
    await tap(find.text(chamaName));
    await tap(find.text('Bank statements'));
    await tap(find.text('Confirm this statement'));
    await confirmSms(founder);
    await waitFor(find.text('Accepted'));
    await screenshot('statement_accepted');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(find.text('Records'));
    await waitFor(find.textContaining('Checked on this phone'));
    await screenshot('records_checked');
    await signOut();

    // 6. The treasurer assigns the unmatched cash deposit to the member.
    await type(find.byType(TextField), treasurer);
    await tap(find.text('Send code'));
    await type(find.byType(TextField), await newCode(e164(treasurer)));
    await tap(find.text('Continue'));
    await tap(find.text(chamaName));
    await tap(find.text('Unmatched payments'));
    await waitFor(find.text('KES 300'));
    await screenshot('unmatched_queue');
    await tap(find.text('Assign'));
    await tap(find.byType(DropdownButtonFormField<String>));
    await tap(find.textContaining('-004)'), last: true);
    await type(find.widgetWithText(TextField, 'Why it belongs to them'),
        'Paid in cash at the meeting');
    await tap(find.widgetWithText(FilledButton, 'Assign'));
    await waitFor(find.text('Every payment is matched to a member.'));
    await signOut();

    // 7. The member says it was not theirs; it goes back to the queue.
    await type(find.byType(TextField), member);
    await tap(find.text('Send code'));
    await type(find.byType(TextField), await newCode(e164(member)));
    await tap(find.text('Continue'));
    await tap(find.text(chamaName));
    await tap(find.text('Records'));
    await waitFor(find.byTooltip('This was not me'));
    await screenshot('member_records');
    await tap(find.byTooltip('This was not me'));
    await waitFor(find.text('Sent back to the treasurer.'));
    await waitFor(find.textContaining('Checked on this phone'));
    await screenshot('after_not_me');
  });
}
