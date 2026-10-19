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
    // Lists build lazily: a widget far down the screen is not in the tree until scrolled
    // to. If it is not there yet, scroll the list down looking for it.
    Future<void> reveal(Finder finder) async {
      await tester.pumpAndSettle();
      if (finder.evaluate().isEmpty && find.byType(ListView).evaluate().isNotEmpty) {
        try {
          await tester.dragUntilVisible(finder, find.byType(ListView).first,
              const Offset(0, -300), maxIteration: 12);
        } catch (_) {
          // Not in this list; it may still appear (a network call), so wait after.
        }
      }
    }

    Future<void> tap(Finder finder, {bool last = false}) async {
      debugPrint('E2E tap $finder');
      await reveal(finder);
      await waitFor(finder);
      final target = last ? finder.last : finder.first;
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> type(Finder field, String text, {bool last = false}) async {
      debugPrint('E2E type into $field');
      await reveal(field);
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

    // The founder sets rules beyond the main four in the full editor.
    await tap(find.text('Edit all rules'));
    await waitFor(find.text('All rules'));
    await type(find.byKey(const ValueKey('cash_days')), '4');
    await type(find.byKey(const ValueKey('entry_fee')), '200');
    await tap(find.text('Each member pays'));
    await screenshot('rules_editor');
    await tap(find.text('Save rules'));
    await waitFor(find.text('Edit all rules')); // back on setup: saved and closed

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

    Future<void> signInAgain(String local) async {
      await signOut();
      await type(find.byType(TextField), local);
      await tap(find.text('Send code'));
      await type(find.byType(TextField), await newCode(e164(local)));
      await tap(find.text('Continue'));
      await tap(find.text(chamaName));
    }

    Finder keyEndingWith(String prefix, String suffix) => find.byWidgetPredicate((w) {
          final k = w.key;
          return k is ValueKey<String> && k.value.startsWith(prefix) && k.value.endsWith(suffix);
        });

    // 8. The treasurer drafts an opening balance and records cash from a meeting.
    await signInAgain(treasurer);
    await tap(find.text('Opening balances'));
    await type(keyEndingWith('savings-', '-004'), '5000');
    await tap(find.text('Save draft'));
    await waitFor(find.textContaining('Draft saved'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(find.text('Cash at meetings'));
    await tap(find.text('Record cash received'));
    await tap(find.byType(DropdownButtonFormField<String>));
    await tap(find.textContaining('-004)'), last: true);
    await type(find.widgetWithText(TextField, 'Amount (KES)'), '500');
    await tap(find.widgetWithText(FilledButton, 'Record'));
    await waitFor(find.text('Waiting for the member to confirm'));
    await screenshot('cash_recorded');

    // 9. The chair confirms the opening balances.
    await signInAgain(founder);
    await tap(find.text('Opening balances'));
    await tap(find.text('Confirm these opening balances'));
    await confirmSms(founder);
    await waitFor(find.textContaining('Confirmed by'));
    await screenshot('opening_confirmed');

    // 10. The member confirms the cash they handed over.
    await signInAgain(member);
    await waitFor(find.textContaining('waiting for you to confirm'));
    await tap(find.textContaining('waiting for you to confirm'));
    await tap(find.text('Yes, I paid this'));
    await confirmSms(member);
    await waitFor(find.text('Waiting for the bank deposit'));

    // 11. A later statement repeats today's lines and adds the cash deposit.
    file.bytes = utf8.encode([
      'Account Number:,0123456789012',
      'Opening Balance:,5000.00',
      'Closing Balance:,7800.00',
      '',
      'Value Date,Narration,Reference,Debit,Credit,Balance',
      '${d(today)},MPESA C2B $founder JANE,E2E1$run,,1000.00,6000.00',
      '${d(today)},MPESA DEPOSIT $member WANJIRU,E2E2$run,,1000.00,7000.00',
      '${d(today)},CASH DEPOSIT,E2E3$run,,300.00,7300.00',
      '${d(today)},CASH DEPOSIT MEETING,E2E4$run,,500.00,7800.00',
    ].join('\n'));
    await signInAgain(secretary);
    await tap(find.text('Bank statements'));
    await tap(find.text('Upload a statement (CSV)'));
    await waitFor(find.text('Waiting for a second official'));
    await signInAgain(founder);
    await tap(find.text('Bank statements'));
    await tap(find.text('Confirm this statement'));
    await confirmSms(founder);
    await waitFor(find.text('Accepted'));

    // 12. The treasurer links the deposit to the confirmed cash.
    await signInAgain(treasurer);
    await tap(find.text('Unmatched payments'));
    await waitFor(find.text('KES 500'));
    await tap(find.byTooltip('This is cash from a meeting'), last: true);
    await tap(find.textContaining('-004 ·'));
    await tap(find.widgetWithText(FilledButton, 'Link deposit'));
    await waitFor(find.text('KES 300'));
    await screenshot('cash_banked');

    // 13. The member sees the opening balance in their position.
    await signInAgain(member);
    await waitFor(find.text('Brought in (opening)'));
    await screenshot('member_position_with_opening');

    // 14. The member takes their statement away as a sealed PDF, and anyone holding it
    // can check it without signing in.
    await tap(find.text('See my statement'));
    await waitFor(find.text('My statement'));
    await screenshot('member_statement');
    await tap(find.text('Get PDF statement'));
    await waitFor(find.byKey(const ValueKey('check-code')), seconds: 60);
    await screenshot('member_statement_pdf');
    final shown = tester.widget<Text>(find.byKey(const ValueKey('check-code'))).data!;
    final code = RegExp(r'([0-9A-Z]{5}-[0-9A-Z]{5})').firstMatch(shown)!.group(1)!;
    final check = await (await client.getUrl(Uri.parse('$_host/api/v1/verify/$code/')))
        .close();
    final checked = jsonDecode(await check.transform(utf8.decoder).join()) as Map;
    expect(checked['sealed'], isTrue);
    expect(checked['member_code'] as String, endsWith('-004'));

    // 15. The chama statement: every member, and the bank side.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(find.text('Chama statement'));
    await waitFor(find.textContaining('Bank statement reconciled to'));
    await screenshot('chama_statement');

    // 16. A statement with a line the app cannot read: the secretary types it in from
    // the bank's copy, and the chair confirms.
    file.bytes = utf8.encode([
      'Account Number:,0123456789012',
      'Opening Balance:,5000.00',
      'Closing Balance:,8000.00',
      '',
      'Value Date,Narration,Reference,Debit,Credit,Balance',
      '${d(today)},MPESA C2B $founder JANE,E2E1$run,,1000.00,6000.00',
      '${d(today)},MPESA DEPOSIT $member WANJIRU,E2E2$run,,1000.00,7000.00',
      '${d(today)},CASH DEPOSIT,E2E3$run,,300.00,7300.00',
      '${d(today)},CASH DEPOSIT MEETING,E2E4$run,,500.00,7800.00',
      '##/##/####,CASH DEPOSIT LATE,E2E5$run,,200.00,8000.00',
    ].join('\n'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await signInAgain(secretary);
    await tap(find.text('Bank statements'));
    await tap(find.text('Upload a statement (CSV)'));
    await waitFor(find.text('Type in lines'));
    await screenshot('statement_needs_typing');
    await tap(find.text('Type in lines'));
    await type(keyEndingWith('date-', ''), today.toIso8601String().substring(0, 10));
    await type(keyEndingWith('amount-', ''), '200');
    await type(keyEndingWith('reference-', ''), 'E2E5$run');
    await screenshot('typing_a_line');
    await tap(find.text('Save typed lines'));
    await waitFor(find.textContaining('Another official now confirms'));
    await signInAgain(founder);
    await tap(find.text('Bank statements'));
    await tap(find.text('Confirm this statement'));
    await confirmSms(founder);
    await waitFor(find.textContaining('typed in by'));
    await screenshot('typed_statement_accepted');

    // 17. Money out: two officials switch it on, the treasurer proposes the member's
    // payout, the treasurer and chair approve by SMS code, and the chair marks it paid.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(find.text('Money out'));
    await tap(find.text('Switch on money out'));
    await confirmSms(founder);
    await waitFor(find.text('1 of 2 officials have agreed'));
    await signInAgain(treasurer);
    await tap(find.text('Money out'));
    await tap(find.text('Switch on money out'));
    await confirmSms(treasurer);
    await tap(find.text('Propose a payment'));
    await tap(find.byKey(const ValueKey('payee-member')));
    await tap(find.textContaining('-004)'), last: true);
    await type(find.byKey(const ValueKey('propose-amount')), '1000');
    await type(find.byKey(const ValueKey('propose-purpose')), 'Merry-go-round turn');
    await tap(find.text('Propose'));
    await tap(find.textContaining('Merry-go-round turn'));
    await tap(find.text('Approve'));
    await confirmSms(treasurer);
    await waitFor(find.text('1 of 2 approvals'));
    await screenshot('payout_one_approval');
    await signInAgain(founder);
    await waitFor(find.text('1 payment(s) waiting for your approval'));
    await tap(find.text('Money out'));
    await tap(find.textContaining('Merry-go-round turn'));
    await tap(find.text('Approve'));
    await confirmSms(founder);
    await waitFor(find.text('Approved: pay at the bank'));
    await tap(find.text('Mark as paid at the bank'));
    await type(find.byKey(const ValueKey('ask-text')), 'PL$run');
    await tap(find.widgetWithText(FilledButton, 'Mark as paid at the bank'), last: true);
    await waitFor(find.text('Paid: waiting for the bank statement'));
    await screenshot('payout_paid');

    // 18. The next statement carries the debit; once confirmed, it matches the payout.
    file.bytes = utf8.encode([
      'Account Number:,0123456789012',
      'Opening Balance:,5000.00',
      'Closing Balance:,7000.00',
      '',
      'Value Date,Narration,Reference,Debit,Credit,Balance',
      '${d(today)},MPESA C2B $founder JANE,E2E1$run,,1000.00,6000.00',
      '${d(today)},MPESA DEPOSIT $member WANJIRU,E2E2$run,,1000.00,7000.00',
      '${d(today)},CASH DEPOSIT,E2E3$run,,300.00,7300.00',
      '${d(today)},CASH DEPOSIT MEETING,E2E4$run,,500.00,7800.00',
      '${d(today)},CASH DEPOSIT LATE,E2E5$run,,200.00,8000.00',
      '${d(today)},PESALINK PL$run WANJIRU,E2E6$run,1000.00,,7000.00',
    ].join('\n'));
    await signInAgain(secretary);
    await tap(find.text('Bank statements'));
    await tap(find.text('Upload a statement (CSV)'));
    await waitFor(find.text('Waiting for a second official'));
    await signInAgain(founder);
    await tap(find.text('Bank statements'));
    await tap(find.text('Confirm this statement'));
    await confirmSms(founder);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(find.text('Money out'));
    await waitFor(find.textContaining('Paid and matched to the bank'));
    await screenshot('payout_matched');

    // 19. The merry-go-round: the chair starts a drawn cycle and proposes the first turn.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(find.text('Merry-go-round'));
    await tap(find.text('Start the rotation'));
    await tap(find.widgetWithText(FilledButton, 'Start the rotation'), last: true);
    await waitFor(find.textContaining('Cycle 1 · each turn receives'));
    await screenshot('rotation_drawn');
    await tap(find.text('Propose next payout'));
    await waitFor(find.textContaining('Merry-go-round turn 1 of 4'));
    await screenshot('rotation_first_turn_proposed');
  });
}
