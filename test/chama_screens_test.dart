import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiranichama/app.dart';
import 'package:jiranichama/core/providers.dart';
import 'package:jiranichama/features/auth/data/auth_repository.dart';

import 'package:jiranichama/features/chamas/application/chain_check.dart';

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

Map<String, dynamic> _keyVectors() => jsonDecode(
    File('packages/jirani_domain/test/vectors/key_chain.json').readAsStringSync())
    as Map<String, dynamic>;

Future<void> _pump(WidgetTester tester, FakeChamaRepository repo,
    {MemoryTrustStore? trust, FakePhoneSigner? signer}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_SignedIn()),
      chamaRepositoryProvider.overrideWithValue(repo),
      // The chain check runs inline here: the test clock does not wait for isolates.
      chainRunnerProvider.overrideWithValue((work) async => work()),
      trustStoreProvider.overrideWithValue(trust ?? MemoryTrustStore()),
      fileSourceProvider.overrideWithValue(FakeFileSource()),
      if (signer != null) phoneSignerProvider.overrideWithValue(signer),
    ],
    child: const JiraniApp(),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openChama(WidgetTester tester) async {
  await tester.tap(find.text('Umoja Women Group'));
  await tester.pumpAndSettle();
}

Future<void> _enterSmsCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField).last, code);
  await tester.tap(find.text('Confirm'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('founder creates a chama, sets it up and sends the rules', (tester) async {
    final repo = FakeChamaRepository(state: 'none');
    await _pump(tester, repo);
    expect(find.textContaining('You are not in a chama yet'), findsOneWidget);

    await tester.tap(find.text('Create a chama'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Umoja Women Group');
    await tester.tap(find.text('Create chama'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('create'));
    expect(find.textContaining('Add the bank account'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Account number'), '0123456789012');
    await tester.ensureVisible(find.text('Save bank account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save bank account'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('bank:equity:0123456789012'));

    final amount = find.widgetWithText(TextField, 'Contribution each month');
    await tester.ensureVisible(amount);
    await tester.pumpAndSettle();
    await tester.enterText(amount, '1500');
    await tester.ensureVisible(find.text('Save rules'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save rules'));
    await tester.pumpAndSettle();
    expect((repo.savedRules!['contributions'] as Map)['amount_cents'], 150000);

    final phone = find.widgetWithText(TextField, 'Their phone number');
    await tester.ensureVisible(phone);
    await tester.pumpAndSettle();
    await tester.enterText(phone, '0711000002');
    await tester.tap(find.text('Create invite'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('invite:treasurer:0711000002'));
    expect(find.textContaining('Invite code KQWERT'), findsOneWidget);

    await tester.ensureVisible(find.text('Send the rules for confirmation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send the rules for confirmation'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('submit'));
    expect(find.textContaining('Waiting for every office'), findsOneWidget);
  });

  testWidgets('a member joins with an invite code and an SMS code', (tester) async {
    final repo = FakeChamaRepository(state: 'none');
    await _pump(tester, repo);
    await tester.tap(find.text('Join with a code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nope');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('This invite is not valid or has expired.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'kqwert');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('invited to join Umoja Women Group as Member'), findsOneWidget);
    expect(find.text('Each member pays KES 1,000 every month, by the 5th.'), findsOneWidget);

    await tester.tap(find.text('Join and accept these rules'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the code we sent by SMS'), findsOneWidget);
    await _enterSmsCode(tester, '111111');
    expect(find.text('That code is not right. 4 tries left.'), findsOneWidget);
    await _enterSmsCode(tester, smsCode);
    expect(repo.calls, contains('joined'));
  });

  testWidgets('a founding member confirms the rules and the chama goes active',
      (tester) async {
    final repo = FakeChamaRepository(state: 'awaiting_adoption');
    await _pump(tester, repo);
    await _openChama(tester);
    expect(find.textContaining('2 of 4 founding members have confirmed'), findsOneWidget);
    await tester.tap(find.text('Confirm these rules'));
    await tester.pumpAndSettle();
    await _enterSmsCode(tester, smsCode);
    expect(find.text('Overview'), findsOneWidget);
  });

  testWidgets('overview shows my position and how to pay', (tester) async {
    await _pump(tester, FakeChamaRepository());
    await _openChama(tester);
    expect(find.text('KES 2,000'), findsOneWidget);
    expect(find.text('KES 200'), findsOneWidget);
    expect(find.textContaining('member code JC-4821-001'), findsOneWidget);
    expect(find.text('Mobile money: pay to 247247, account JC-4821-001.'), findsOneWidget);
    expect(find.textContaining('records money only'), findsOneWidget);
  });

  testWidgets('records are checked on the phone against the server signatures',
      (tester) async {
    await _pump(tester, FakeChamaRepository());
    await _openChama(tester);
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Checked on this phone: 4 records'), findsOneWidget);
    // Nobody has vouched yet; members are invited to.
    expect(find.byKey(const ValueKey('cs-none')), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.textContaining('Receipt'), findsWidgets);
  });

  testWidgets('a key the pinned key did not endorse is not trusted', (tester) async {
    final repo = FakeChamaRepository();
    final v = _keyVectors();
    // The server now names the forger's key as its only key: not the one this phone pinned.
    repo.keyChain = [Map<String, Object?>.from(v['forged_next'] as Map)
      ..['prev_key_id'] = null];
    final trust = MemoryTrustStore()..pinned = v['pinned_fingerprint'] as String;
    await _pump(tester, repo, trust: trust);
    await _openChama(tester);
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Warning: these records do not match'), findsOneWidget);
  });

  testWidgets('a rotated key endorsed by the old one is still trusted', (tester) async {
    final repo = FakeChamaRepository();
    final v = _keyVectors();
    repo.keyChain = [for (final k in v['chain'] as List) Map<String, Object?>.from(k as Map)];
    final trust = MemoryTrustStore()..pinned = v['pinned_fingerprint'] as String;
    await _pump(tester, repo, trust: trust);
    await _openChama(tester);
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Checked on this phone: 4 records'), findsOneWidget);
  });

  testWidgets('a member vouches for the records with their phone key', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false);
    final signer = FakePhoneSigner(hasKeyAndId: true);
    await _pump(tester, repo, signer: signer);
    await _openChama(tester);
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cs-vouch')));
    await tester.pumpAndSettle();
    final last = repo.ledgerItems.last;
    final seq = (last['document'] as Map)['seq'];
    expect(repo.calls, contains('countersign:$seq'));
    expect(signer.signed.single, contains('"purpose":"countersign_chain"'));
    expect(signer.signed.single, contains('"hash":"${last['hash']}"'));
    // The fake signer's "SIG" is not a real signature: this phone says so, loudly.
    expect(find.byKey(const ValueKey('cs-disagree')), findsOneWidget);
  });

  testWidgets('a changed record is caught on the phone', (tester) async {
    final repo = FakeChamaRepository();
    (repo.ledgerItems[1]['document'] as Map)['amount_cents'] = 999999;
    await _pump(tester, repo);
    await _openChama(tester);
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Warning: these records do not match'), findsOneWidget);
  });

  testWidgets('a forged platform signature is caught on the phone', (tester) async {
    final repo = FakeChamaRepository();
    repo.ledgerItems[2]['platform_sig'] = repo.ledgerItems[0]['platform_sig'];
    await _pump(tester, repo);
    await _openChama(tester);
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Warning: these records do not match'), findsOneWidget);
  });

  testWidgets('a member sends back a payment the treasurer assigned to them',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)..useAssignedChain();
    await _pump(tester, repo);
    await _openChama(tester);
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 new record is waiting'), findsOneWidget);
    await tester.tap(find.byTooltip('This was not me'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('notMe:txn-9'));
    expect(find.text('Sent back to the treasurer.'), findsOneWidget);
  });

  testWidgets('a reversed record is marked, and its correction names the receipt',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair')..useAssignedChain();
    repo.addReversalOfFirst();
    await _pump(tester, repo);
    await _openChama(tester);
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Reversed'), findsOneWidget);
    final receipt = repo.ledgerItems.first['receipt_code'];
    expect(find.textContaining('Corrects receipt $receipt'), findsOneWidget);
    expect(find.textContaining('Checked on this phone: 2 records'), findsOneWidget);
  });

  testWidgets('an official uploads a statement and another confirms it', (tester) async {
    final repo = FakeChamaRepository(myRole: 'secretary');
    await _pump(tester, repo);
    await _openChama(tester);
    await scrollTo(tester, find.text('Bank statements'));
    await tester.tap(find.text('Bank statements'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload a statement (CSV)'));
    await tester.pumpAndSettle();
    expect(repo.calls.any((c) => c.startsWith('upload:march.csv:')), isTrue);
    expect(find.text('Waiting for a second official'), findsOneWidget);
    expect(find.textContaining('214 lines · closing KES 1,284,500'), findsOneWidget);

    await tester.tap(find.text('Confirm this statement'));
    await tester.pumpAndSettle();
    await _enterSmsCode(tester, smsCode);
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Uploaded by Akinyi, confirmed by Jane'), findsOneWidget);
  });

  testWidgets('the treasurer assigns an unmatched payment with a reason', (tester) async {
    final repo = FakeChamaRepository(myRole: 'treasurer');
    await _pump(tester, repo);
    await _openChama(tester);
    await scrollTo(tester, find.text('Unmatched payments'));
    await tester.tap(find.text('Unmatched payments'));
    await tester.pumpAndSettle();
    expect(find.text('KES 300'), findsOneWidget);
    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wanjiru (JC-4821-004)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Why it belongs to them'),
        "paid from her husband's phone");
    await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains("assign:txn-1:m4:paid from her husband's phone"));
    expect(find.text('Every payment is matched to a member.'), findsOneWidget);
  });

  testWidgets('a chair sees the unmatched queue but cannot assign', (tester) async {
    await _pump(tester, FakeChamaRepository(myRole: 'chair'));
    await _openChama(tester);
    await scrollTo(tester, find.text('Unmatched payments'));
    await tester.tap(find.text('Unmatched payments'));
    await tester.pumpAndSettle();
    expect(find.text('KES 300'), findsOneWidget);
    expect(find.text('Assign'), findsNothing);
  });

  testWidgets('a payment straight from M-Pesa is tagged in the unmatched queue',
      (tester) async {
    final repo = FakeChamaRepository(myRole: 'treasurer');
    repo.unmatchedList
      ..clear()
      ..add({'id': 'txn-9', 'amount_cents': 50000, 'value_date': '2026-03-05',
             'narration': 'M-PESA RKTQDM7W6U JANE', 'state': 'unmatched',
             'source': 'daraja'});
    await _pump(tester, repo);
    await _openChama(tester);
    await scrollTo(tester, find.text('Unmatched payments'));
    await tester.tap(find.text('Unmatched payments'));
    await tester.pumpAndSettle();
    expect(find.textContaining('From M-Pesa just now'), findsOneWidget);
  });

  testWidgets('an official invites a member without a smartphone by SMS', (tester) async {
    final repo = FakeChamaRepository(myRole: 'chair');
    await _pump(tester, repo);
    await _openChama(tester);
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite a member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('invite-member-phone')), '0799111222');
    await tester.tap(find.byKey(const ValueKey('invite-by-sms')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiswahili'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send the SMS invite'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('smsInvite:0799111222:sw'));
    expect(find.textContaining('They reply YES with the code'), findsOneWidget);
  });

  testWidgets('the records tab checks the chain against the public anchor', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)..anchorLastEntry();
    await _pump(tester, repo);
    await _openChama(tester);
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Matches the public anchor of 2026-03-10'), findsOneWidget);
  });

  testWidgets('a chain that does not fit the anchor is flagged', (tester) async {
    final repo = FakeChamaRepository(myRole: 'member', founder: false)
      ..anchorLastEntry(tamper: true);
    await _pump(tester, repo);
    await _openChama(tester);
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Does NOT match the public anchor'), findsOneWidget);
  });

  testWidgets("the Rules tab shows what the country's law asks", (tester) async {
    final repo = FakeChamaRepository()
      ..countryRulesJson = {
        'country': 'UG', 'min_members': 10, 'max_members': 30,
        'items': [
          {'key': 'size', 'ok': false, 'level': 'block', 'members': 8, 'min': 10, 'max': 30},
          {'key': 'country_simple_interest', 'ok': false, 'level': 'block',
           'text': "The law here allows simple interest only on members' loans."},
          {'key': 'money_counters', 'ok': null, 'level': 'duty',
           'text': 'The committee has two money counters.'},
        ],
      };
    await _pump(tester, repo);
    await _openChama(tester);
    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The law in'), findsOneWidget);
    expect(find.text('2 things to fix to follow the law here'), findsOneWidget);
    expect(find.text('Members: 8. The law here allows 10 to 30 members.'), findsOneWidget);
    expect(find.text('The committee has two money counters.'), findsOneWidget);
  });
}
