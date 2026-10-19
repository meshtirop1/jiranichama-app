import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jiranichama/core/api/problem.dart';
import 'package:jiranichama/core/providers.dart';
import 'package:jiranichama/features/chamas/data/chama_repository.dart';
import 'package:jiranichama/features/chamas/data/models.dart';

const smsCode = '424242';

/// Scrolls the visible list until [target] is built, then brings it on screen. Lists
/// build lazily, so a button far down the overview is not in the tree until scrolled to.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.dragUntilVisible(target, find.byType(ListView).first, const Offset(0, -300));
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Json _vectors(String name) => jsonDecode(
    File('packages/jirani_domain/test/vectors/$name').readAsStringSync()) as Json;

ApiProblem wrongCode(int left) =>
    ApiProblem(code: 'signing_wrong', detail: '', status: 400, extra: {'attempts_left': left});

/// An in-memory chama service: enough state to walk every Phase 1 screen.
class FakeChamaRepository implements ChamaRepository {
  FakeChamaRepository({this.state = 'active', this.myRole = 'chair', this.founder = true}) {
    useVectorChain();
  }

  String state;
  String myRole;
  bool founder;
  bool myAdopted = false;
  final calls = <String>[];
  final statementsList = <Json>[];
  final unmatchedList = <Json>[
    {'id': 'txn-1', 'amount_cents': 30000, 'value_date': '2026-03-05',
     'narration': 'CASH DEPOSIT', 'state': 'unmatched'},
  ];
  List<Json> ledgerItems = [];
  String keyPem = '';
  int wrongCodesLeft = 4;

  /// The shared server vectors: a real chain with real platform signatures.
  void useVectorChain() {
    final chain = _vectors('ledger_chain.json');
    final sigs = _vectors('platform_signatures.json');
    final byHash = {for (final s in sigs['valid'] as List) s['hash']: s['signature_b64']};
    keyPem = sigs['public_key_pem'] as String;
    ledgerItems = [
      for (final e in chain['entries'] as List)
        {'id': e['entry_id'], 'document': e['document'], 'hash': e['hash'],
         'receipt_code': e['receipt_code'], 'platform_sig': byHash[e['hash']], 'key_id': 't'},
    ];
  }

  /// A chain built here with one contribution the treasurer assigned to me. Correct
  /// hashes, no platform signatures yet.
  void useAssignedChain() {
    final doc = <String, Object?>{
      'v': 1, 'chama_id': 'c1', 'seq': 1, 'type': 'contribution',
      'member_code': 'JC-4821-004', 'amount_cents': 30000, 'period': '2026-03',
      'rule_version_id': null, 'rule_refs': ['3.1'],
      'decision': {'method': 'treasurer', 'outcome': 'on_time'}, 'source': 'bank_txn',
      'source_id': 'txn-9', 'reverses': null, 'signatures_digest': null,
      'at': '2026-03-05T08:00:00.000Z', 'prev_hash': genesisPrevHash,
    };
    final h = entryHash(doc);
    ledgerItems = [
      {'id': 'e1', 'document': doc, 'hash': h, 'receipt_code': receiptCode(h),
       'platform_sig': null, 'key_id': null},
    ];
  }

  /// Appends a correction that reverses the first entry, linked into the chain.
  void addReversalOfFirst() {
    final first = ledgerItems.first;
    final doc = <String, Object?>{
      ...Map<String, Object?>.from(first['document'] as Map),
      'seq': 2, 'type': 'reversal', 'amount_cents': -30000, 'reverses': first['id'],
      'decision': {'reason': 'member says this payment was not theirs'},
      'prev_hash': first['hash'],
    };
    final h = entryHash(doc);
    ledgerItems.add({'id': 'e2', 'document': doc, 'hash': h, 'receipt_code': receiptCode(h),
                     'platform_sig': null, 'key_id': null});
  }

  Json get _chamaJson => {
        'id': 'c1', 'name': 'Umoja Women Group', 'type': 'merry_go_round', 'state': state,
        'mode': moneyOutOn ? 'money_out' : 'records_only', 'member_code_prefix': 'JC-4821',
        'my_role': myRole,
        'my_member_code': myRole == 'member' ? 'JC-4821-004' : 'JC-4821-001',
        'i_am_founder': founder, 'statement_inbox': 'jc-4821-ab12@statements.example',
        'bank_account': {'bank': 'equity', 'account_name': 'UMOJA', 'account_no_last4': '9012',
                         'paybill': '247247', 'till': '', 'statement_route': 'upload'},
        if (state == 'awaiting_adoption')
          'adoption': {'founding': 4, 'confirmed': 2, 'needed': 3, 'officials_waiting': []},
      };

  final _rules = <String, dynamic>{
    'schema_version': 1,
    'contributions': {'amount_cents': 100000, 'frequency': 'monthly', 'due_day': 5,
                      'grace_days': 2, 'allocation_order': ['arrears', 'fines', 'current']},
    'fines': {'late_contribution': {'enabled': true, 'amount_cents': 20000,
                                    'monthly_cap_cents': null}},
    'officials': {'roles': ['chair', 'treasurer', 'secretary']},
    'approvals': {
      'tiers': [
        {'up_to_cents': 5000000, 'officials': 2, 'member_vote': false},
        {'up_to_cents': null, 'officials': 2, 'member_vote': true},
      ],
      'deadline_hours': 72,
    },
    'membership': {'entry_fee_cents': 0, 'new_members_need_vote': false},
    'adoption': {'members_share_pct': 51},
    'statements': {'every_days': 14},
    'kyc': {'payer': 'chama'},
  };
  Json? savedRules;

  Json get _book => {
        'en': [{'ref': '3.1', 'text': 'Each member pays KES 1,000 every month, by the 5th.'}],
        'sw': [{'ref': '3.1', 'text': 'Kila mwanachama analipa KES 1,000 kila mwezi.'}],
      };

  void _codeCheck(String code) {
    if (code != smsCode) throw wrongCode(wrongCodesLeft--);
  }

  ChallengeSent get _sent =>
      ChallengeSent({'challenge_id': 'ch-1', 'sent_to': '+2547••• ••• 678', 'expires_in': 300});

  @override
  Future<List<Chama>> list() async =>
      calls.contains('create') || state != 'none' ? [Chama(_chamaJson)] : [];

  @override
  Future<Chama> create({required String name, required String type, required String myRole,
      required String idempotencyKey}) async {
    calls.add('create');
    state = 'setup';
    this.myRole = myRole;
    return Chama(_chamaJson);
  }

  @override
  Future<Chama> get(String id) async => Chama(_chamaJson);

  @override
  Future<void> setBankAccount(String id, {required String bank, required String accountName,
      required String accountNo, String paybill = '', required String statementRoute}) async {
    calls.add('bank:$bank:$accountNo');
  }

  @override
  Future<RuleBook> rules(String id) async => RuleBook({
        'status': state == 'active' ? 'in_force' : 'draft', 'version_no': 1,
        'rules': savedRules ?? _rules, 'book': _book,
      });

  @override
  Future<RuleBook> saveRules(String id, Json rules) async {
    // A little of the API's validation, enough to show errors coming back per setting.
    final dueDay = (rules['contributions'] as Map)['due_day'] as int;
    if (dueDay < 1 || dueDay > 28) {
      throw ApiProblem(code: 'rules_invalid', detail: '', status: 400, extra: {
        'errors': [
          {'path': 'contributions/due_day', 'code': 'out_of_range', 'message': 'x'},
        ],
      });
    }
    savedRules = rules;
    calls.add('rules');
    return RuleBook({'status': 'draft', 'rules': rules, 'book': _book});
  }

  @override
  Future<Invite> invite(String id, {required String role, String? phone}) async {
    calls.add('invite:$role:${phone ?? ''}');
    return Invite({'code': 'KQWERT', 'role': role, 'phone_hint': '', 'state': 'pending'});
  }

  @override
  Future<Chama> submit(String id) async {
    calls.add('submit');
    state = 'awaiting_officials';
    return Chama(_chamaJson);
  }

  @override
  Future<ChallengeSent> startAdoption(String id) async => _sent;

  @override
  Future<Chama> confirmAdoption(String id,
      {required String challengeId, required String code}) async {
    _codeCheck(code);
    myAdopted = true;
    state = 'active';
    return Chama(_chamaJson);
  }

  @override
  Future<InviteDetail> inviteDetail(String code) async {
    if (code.toUpperCase() != 'KQWERT') {
      throw ApiProblem(code: 'invite_invalid', detail: '', status: 404);
    }
    return InviteDetail({'chama': {'id': 'c1', 'name': 'Umoja Women Group'}, 'role': 'member',
                         'book': _book['en']});
  }

  @override
  Future<ChallengeSent> startJoin(String code) async => _sent;

  @override
  Future<Member> confirmJoin(String inviteCode,
      {required String challengeId, required String smsCode}) async {
    _codeCheck(smsCode);
    calls.add('joined');
    myRole = 'member';
    return Member({'id': 'm4', 'member_code': 'JC-4821-004', 'name': 'Wanjiru',
                   'role': 'member', 'is_founding': false});
  }

  @override
  Future<List<Member>> members(String id) async => [
        Member({'id': 'm1', 'member_code': 'JC-4821-001', 'name': 'Jane', 'role': 'chair',
                'is_founding': true, 'rules_adopted_at': myAdopted ? 'x' : null}),
        Member({'id': 'm2', 'member_code': 'JC-4821-002', 'name': 'Peter',
                'role': 'treasurer', 'is_founding': true}),
        Member({'id': 'm4', 'member_code': 'JC-4821-004', 'name': 'Wanjiru', 'role': 'member',
                'is_founding': true}),
      ];

  @override
  Future<Position> position(String membershipId) async => Position({
        'contributed_cents': 200000, 'arrears_cents': 100000, 'fines_cents': 20000,
        'credit_cents': 0, 'next_due_period': '2026-04', 'next_due_cents': 100000,
      });

  @override
  Future<LedgerPage> ledger(String id, {int afterSeq = 0}) async => LedgerPage(
      [for (final e in ledgerItems) LedgerItem(e)], more: false,
      nextAfterSeq: ledgerItems.length);

  @override
  Future<String> platformKeyPem() async => keyPem;

  @override
  Future<List<Statement>> statements(String id) async =>
      [for (final s in statementsList) Statement(s)];

  @override
  Future<Statement> uploadStatement(String id, {required String filename,
      required List<int> bytes, required String idempotencyKey}) async {
    calls.add('upload:$filename:${bytes.length}');
    final s = {'id': 's1', 'state': 'awaiting_confirmation', 'route': 'upload',
               'period_from': '2026-03-01', 'period_to': '2026-03-31',
               'closing_cents': 128450000, 'lines': 214, 'uploaded_by': 'Akinyi',
               'problems': [], 'flags': []};
    statementsList.insert(0, s);
    return Statement(s);
  }

  @override
  Future<ChallengeSent> startStatementConfirm(String statementId) async => _sent;

  @override
  Future<Statement> confirmStatement(String statementId,
      {required String challengeId, required String code}) async {
    _codeCheck(code);
    statementsList.first['state'] = 'accepted';
    statementsList.first['confirmed_by'] = 'Jane';
    return Statement(statementsList.first);
  }

  @override
  Future<List<BankLine>> unmatched(String id) async =>
      [for (final t in unmatchedList) BankLine(t)];

  @override
  Future<void> assign(String bankLineId, {required String membershipId,
      required String reason, required String idempotencyKey}) async {
    calls.add('assign:$bankLineId:$membershipId:$reason');
    unmatchedList.removeWhere((t) => t['id'] == bankLineId);
  }

  @override
  Future<void> notMe(String bankLineId,
      {String reason = '', required String idempotencyKey}) async {
    calls.add('notMe:$bankLineId');
  }

  // Opening balances
  String openingState = 'none';
  List<Json> openingLines = [];

  @override
  Future<OpeningBalances> opening(String id) async => OpeningBalances(_openingJson);

  @override
  Future<OpeningBalances> saveOpening(String id, List<Json> lines) async {
    calls.add('saveOpening:${lines.length}');
    openingState = 'draft';
    openingLines = [
      for (final l in lines)
        {...l, 'id': 'line-${l['membership_id']}', 'member_code': 'JC-4821-00?',
         'objections': <String>[]},
    ];
    return OpeningBalances(_openingJson);
  }

  @override
  Future<ChallengeSent> startConfirmOpening(String id) async {
    if (myRole == 'treasurer') {
      throw ApiProblem(code: 'second_official_required', detail: '', status: 403);
    }
    return _sent;
  }

  @override
  Future<OpeningBalances> confirmOpening(String id,
      {required String challengeId, required String code}) async {
    _codeCheck(code);
    openingState = 'confirmed';
    calls.add('confirmOpening');
    return OpeningBalances(_openingJson);
  }

  @override
  Future<void> objectToOpening(String lineId, String reason) async {
    calls.add('object:$lineId:$reason');
    for (final l in openingLines) {
      if (l['id'] == lineId) (l['objections'] as List).add(reason);
    }
  }

  // Cash
  final cash = <Json>[];

  @override
  Future<List<CashReceipt>> cashReceipts(String id) async => [for (final c in cash) CashReceipt(c)];

  @override
  Future<CashReceipt> recordCash(String id, {required String membershipId,
      required int amountCents, required String idempotencyKey}) async {
    calls.add('recordCash:$membershipId:$amountCents');
    final r = {'id': 'cash-${cash.length + 1}', 'membership_id': membershipId,
               'member_code': 'JC-4821-004', 'amount_cents': amountCents,
               'received_on': '2026-03-04', 'state': 'recorded', 'overdue': false};
    cash.add(r);
    return CashReceipt(r);
  }

  @override
  Future<ChallengeSent> startConfirmCash(String receiptId) async => _sent;

  @override
  Future<CashReceipt> confirmCash(String receiptId,
      {required String challengeId, required String code}) async {
    _codeCheck(code);
    final r = cash.firstWhere((c) => c['id'] == receiptId)..['state'] = 'member_confirmed';
    calls.add('confirmCash:$receiptId');
    return CashReceipt(r);
  }

  @override
  Future<CashReceipt> declineCash(String receiptId, {String reason = ''}) async {
    final r = cash.firstWhere((c) => c['id'] == receiptId)..['state'] = 'declined';
    calls.add('declineCash:$receiptId');
    return CashReceipt(r);
  }

  @override
  Future<void> bankCash(String bankLineId,
      {required List<String> receiptIds, required String idempotencyKey}) async {
    calls.add('bankCash:$bankLineId:${receiptIds.join(",")}');
    for (final c in cash) {
      if (receiptIds.contains(c['id'])) c['state'] = 'banked';
    }
    unmatchedList.removeWhere((t) => t['id'] == bankLineId);
  }

  // Money out
  bool moneyOutOn = false;
  int consents = 0;
  final proposalsList = <Json>[];
  final unapprovedList = <Json>[];

  @override
  Future<MoneyOutStatus> moneyOut(String id) async => MoneyOutStatus({
        'mode': moneyOutOn ? 'money_out' : 'records_only', 'consents': consents,
        'needed': 2, 'available_cents': 10000000});

  @override
  Future<ChallengeSent> startEnableMoneyOut(String id) async => _sent;

  @override
  Future<MoneyOutStatus> enableMoneyOut(String id,
      {required String challengeId, required String code}) async {
    _codeCheck(code);
    consents++;
    moneyOutOn = consents >= 2;
    calls.add('enableMoneyOut');
    return moneyOut(id);
  }

  @override
  Future<List<Proposal>> proposals(String id) async =>
      [for (final p in proposalsList) Proposal(p)];

  Json _proposalJson(Json body) {
    final toMember = body['kind'] == 'payout';
    final refused = body['amount_cents'] as int > 5000000;
    return {
      'id': 'prop-${proposalsList.length + 1}', 'kind': body['kind'],
      'state': refused ? 'refused' : 'collecting_approvals',
      'state_reason': '', 'amount_cents': body['amount_cents'],
      'payee_name': toMember ? 'Wanjiru' : body['payee_name'],
      'payee_member_code': toMember ? 'JC-4821-004' : null,
      'payee_account': body['payee_account'] ?? '', 'purpose': body['purpose'],
      'proposed_by': 'Jane', 'proposed_by_code': 'JC-4821-001',
      'needs_officials': 2, 'approved': 0, 'approvals': <Json>[],
      'refusal': refused ? {'code': 'member_vote_needed', 'rule': '4.2'} : <String, dynamic>{},
      'deadline_at': '2026-03-13T10:00:00Z', 'bank_reference': '', 'paid_at': null,
      'can_answer': !refused && myRole != 'member', 'seal_receipt': null,
    };
  }

  @override
  Future<Proposal> propose(String id, Json body, {required String idempotencyKey}) async {
    calls.add('propose:${body['kind']}:${body['amount_cents']}');
    final p = _proposalJson(body);
    proposalsList.insert(0, p);
    return Proposal(p);
  }

  @override
  Future<ChallengeSent> startApprove(String proposalId) async => _sent;

  Json _prop(String id) => proposalsList.firstWhere((p) => p['id'] == id);

  @override
  Future<Proposal> approve(String proposalId,
      {required String challengeId, required String code}) async {
    _codeCheck(code);
    final p = _prop(proposalId);
    (p['approvals'] as List).add(
        {'name': 'Jane', 'role': 'chair', 'decision': 'approve', 'reason': '', 'at': 'x'});
    p['approved'] = (p['approved'] as int) + 1;
    p['can_answer'] = false;
    if (p['approved'] as int >= 2) p['state'] = 'approved';
    calls.add('approve:$proposalId');
    return Proposal(p);
  }

  @override
  Future<Proposal> declineProposal(String proposalId, String reason) async {
    final p = _prop(proposalId);
    (p['approvals'] as List).add(
        {'name': 'Jane', 'role': 'chair', 'decision': 'decline', 'reason': reason, 'at': 'x'});
    p['can_answer'] = false;
    calls.add('decline:$proposalId:$reason');
    return Proposal(p);
  }

  @override
  Future<Proposal> cancelProposal(String proposalId, String reason) async {
    final p = _prop(proposalId)..['state'] = 'cancelled';
    return Proposal(p);
  }

  @override
  Future<Proposal> markPaid(String proposalId, String bankReference,
      {required String idempotencyKey}) async {
    final p = _prop(proposalId)
      ..['state'] = 'paid_pending_match'
      ..['bank_reference'] = bankReference;
    calls.add('paid:$proposalId:$bankReference');
    return Proposal(p);
  }

  @override
  Future<List<UnapprovedDebit>> unapprovedDebits(String id) async =>
      [for (final d in unapprovedList) UnapprovedDebit(d)];

  @override
  Future<UnapprovedDebit> linkDebit(String debitId, String proposalId) async {
    final d = unapprovedList.firstWhere((d) => d['id'] == debitId)
      ..['state'] = 'linked'
      ..['resolved_by'] = 'Peter';
    return UnapprovedDebit(d);
  }

  @override
  Future<UnapprovedDebit> explainDebit(String debitId, String explanation) async {
    final d = unapprovedList.firstWhere((d) => d['id'] == debitId)
      ..['state'] = 'explained'
      ..['explanation'] = explanation
      ..['resolved_by'] = 'Jane';
    calls.add('explain:$debitId:$explanation');
    return UnapprovedDebit(d);
  }

  // Typed-in statement lines
  List<Json>? typedSubmitted;

  @override
  Future<Statement> submitTypedLines(String statementId, List<Json> lines,
      {required String idempotencyKey}) async {
    if (lines.any((l) => l['credit_cents'] != 30000)) {
      throw ApiProblem(code: 'typed_lines_do_not_add_up', detail: '', status: 400);
    }
    typedSubmitted = lines;
    final st = statementsList.firstWhere((x) => x['id'] == statementId)
      ..['state'] = 'awaiting_confirmation'
      ..['typed_lines'] = [
        for (final l in lines) {...l, 'typed_by': 'Akinyi'},
      ];
    return Statement(st);
  }

  // Member and chama statements
  final statementFroms = <String?>[];
  int documentsIssued = 0;

  @override
  Future<MemberStatement> memberStatement(String membershipId, {String? from}) async {
    statementFroms.add(from);
    return MemberStatement({
      'from': from ?? '2026-01-01', 'to': '2026-03-10',
      'member': {'code': 'JC-4821-004', 'name': 'Wanjiru', 'role': 'member'},
      'lines': from != null ? <Json>[] : [
        {'date': '2026-01-08', 'seq': 3, 'receipt': 'K7Q2M9AB', 'type': 'fine_raised',
         'period': '2026-01', 'amount_cents': 20000, 'reversed': false,
         'reverses_receipt': null},
        {'date': '2026-02-03', 'seq': 5, 'receipt': 'P3XW8RT2', 'type': 'contribution',
         'period': '2026-01', 'amount_cents': 100000, 'reversed': true,
         'reverses_receipt': null},
        {'date': '2026-02-04', 'seq': 6, 'receipt': 'ZZ4Q8M1C', 'type': 'reversal',
         'period': '2026-01', 'amount_cents': -100000, 'reversed': false,
         'reverses_receipt': 'P3XW8RT2'},
      ],
      'totals': {'opening_cents': 0, 'contributed_cents': 0, 'fines_raised_cents': 20000,
                 'fines_paid_cents': 0, 'fines_waived_cents': 0},
      'position': {'on': '2026-03-10', 'contributed_cents': 200000, 'opening_cents': 0,
                   'pending_cash_cents': 0, 'arrears_cents': 100000, 'fines_cents': 20000,
                   'credit_cents': 0, 'next_due_period': '2026-04', 'next_due_cents': 100000},
      'records_to_seq': 6,
    });
  }

  @override
  Future<ChamaStatement> chamaStatement(String id, {String? from}) async => ChamaStatement({
        'from': from ?? '2026-01-01', 'to': '2026-03-10',
        'members': [
          {'code': 'JC-4821-001', 'name': 'Jane', 'role': 'chair', 'contributed_cents': 300000,
           'savings_cents': 300000, 'arrears_cents': 0, 'fines_cents': 0},
          {'code': 'JC-4821-004', 'name': 'Wanjiru', 'role': 'member',
           'contributed_cents': 200000, 'savings_cents': 200000, 'arrears_cents': 100000,
           'fines_cents': 20000},
        ],
        'totals': {'contributed_cents': 500000, 'savings_cents': 500000,
                   'arrears_cents': 100000, 'fines_cents': 20000},
        'bank': {'reconciled_to': '2026-03-05', 'closing_cents': 530000,
                 'unmatched_count': 1, 'unmatched_cents': 30000, 'cash_waiting_cents': 0},
      });

  IssuedDocument _doc(String kind, String language) {
    documentsIssued++;
    return IssuedDocument({
      'id': 'doc-$documentsIssued', 'kind': kind, 'language': language,
      'verify_code': '7KQ2M9XB4D', 'verify_url': 'https://api.jiranichama.co.ke/verify/7KQ2M9XB4D/',
      'fingerprint': 'ab' * 32, 'sha256': 'cd' * 32, 'seal_receipt': 'SEAL1234',
    });
  }

  @override
  Future<IssuedDocument> issueMemberStatementPdf(String membershipId,
      {String? from, required String language, required String idempotencyKey}) async {
    calls.add('memberPdf:$membershipId:$language');
    return _doc('member_statement', language);
  }

  @override
  Future<IssuedDocument> issueChamaStatementPdf(String id,
      {String? from, required String language, required String idempotencyKey}) async {
    calls.add('chamaPdf:$id:$language');
    return _doc('chama_statement', language);
  }

  @override
  Future<List<int>> documentFile(String documentId) async {
    calls.add('download:$documentId');
    return utf8.encode('%PDF-1.4 fake');
  }
}

/// Keeps "saved" PDFs in memory and records what was shared.
class FakeDocumentSaver implements DocumentSaver {
  final saved = <String, List<int>>{};
  final shared = <String>[];

  @override
  Future<String> save(String filename, List<int> bytes) async {
    saved[filename] = bytes;
    return '/fake/$filename';
  }

  @override
  Future<void> share(String path, {required String text}) async => shared.add('$path|$text');
}

extension on FakeChamaRepository {
  Json get _openingJson => {
        'state': openingState,
        'proposed_by': openingState == 'none' ? null : 'Peter',
        'confirmed_by': openingState == 'confirmed' ? 'Jane' : null,
        'objection_until': openingState == 'confirmed'
            ? DateTime.now().add(const Duration(days: 14)).toIso8601String()
            : null,
        'lines': openingLines,
      };
}

class FakeFileSource implements FileSource {
  @override
  Future<PickedFile?> pickStatement() async =>
      PickedFile('march.csv', utf8.encode('Value Date,Narration,Debit,Credit,Balance\n'));
}
