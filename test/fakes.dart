import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_secure_keys/jirani_secure_keys.dart';
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

  bool loansOn = false;

  Json get _chamaJson => {
        'id': 'c1', 'name': 'Umoja Women Group', 'type': 'merry_go_round', 'state': state,
        'mode': moneyOutOn ? 'money_out' : 'records_only', 'member_code_prefix': 'JC-4821',
        'my_role': myRole,
        'my_member_code': myRole == 'member' ? 'JC-4821-004' : 'JC-4821-001',
        'i_am_founder': founder, 'statement_inbox': 'jc-4821-ab12@statements.example',
        'loans_on': loansOn,
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
    'rotation': {'order': 'draw', 'arrears': 'skip'},
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
  Future<Invite> invite(String id, {required String role, String? phone, bool bySms = false,
      String language = 'en'}) async {
    if (bySms) calls.add('smsInvite:$phone:$language');
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

  // Platform key chain and member countersignatures (protection plan 2026-10-20)
  List<Json>? keyChain;
  final countersigned = <Json>[];

  @override
  Future<List<Json>> platformKeyChain() async => keyChain ?? [
        {'key_id': 't', 'fingerprint': keyFingerprint(keyPem), 'public_key_pem': keyPem,
         'prev_key_id': null, 'endorsement_sig': null},
      ];

  @override
  Future<List<Json>> countersignatures(String chamaId) async => [...countersigned];

  @override
  Future<List<Json>> countersign(String chamaId, {required int seq, required String hash,
      required String signature}) async {
    calls.add('countersign:$seq');
    countersigned.add({'member_code': 'JC-4821-004', 'seq': seq, 'hash': hash,
        'signature': signature, 'device_public_key': fakeDevicePublicKey,
        'device_active': true, 'at': '2026-03-10T09:00:00Z'});
    return countersignatures(chamaId);
  }

  /// The phone key the fake signer "uses" (any valid P-256 SPKI); signatures made with
  /// it are not checked here, so countersign tests add real ones from the vectors.
  String fakeDevicePublicKey = '';

  @override
  Future<List<int>> anchorProofFile(String anchorId) async {
    calls.add('ots:$anchorId');
    return [0, 79, 84, 83];
  }

  // JiraniChama's monthly bill
  Json billsJson = {
    'this_month': {'period': '2026-03', 'currency': 'KES', 'active_members': 12,
        'price_per_member_cents': 1500, 'members_cents': 18000, 'id_checks': 0,
        'id_checks_cents': 0, 'total_cents': 18000, 'free_reason': '', 'due_on': '2026-04-15'},
    'bills': [
      {'id': 'b1', 'period': '2026-02', 'currency': 'KES', 'active_members': 11,
       'price_per_member_cents': 1500, 'members_cents': 16500, 'id_checks': 0,
       'id_checks_cents': 0, 'total_cents': 16500, 'free_reason': '', 'state': 'open',
       'due_on': '2026-03-15', 'paid_at': null},
    ],
    'pricing': {'price_usd': 0.1, 'free_months': 3, 'free_up_to_members': 5},
    'pay_to': {'paybill': '', 'account_prefix': 'JC'},
  };

  @override
  Future<Json> bills(String chamaId) async => billsJson;

  // Bank mandate (protection plan 2026-10-20)
  Json? mandateCurrent;
  Json? mandatePending;

  Json get _mandateState => {
        'current': mandateCurrent, 'pending': mandatePending, 'min_signers_required': 2,
        'multi_approval_options': ['Equity Bank: Equitel Multiple Approval'],
        'safe': mandateCurrent != null,
      };

  @override
  Future<Json> bankMandate(String chamaId) async => _mandateState;

  @override
  Future<Json> proposeMandate(String chamaId, {required List<String> signatoryIds,
      required int minSigners, required bool bankAppApprovals, required String filename,
      required List<int> bytes}) async {
    calls.add('proposeMandate:${signatoryIds.join(',')}:$minSigners:$bankAppApprovals');
    mandatePending = {
      'id': 'mand-1', 'state': 'proposed', 'min_signers': minSigners,
      'bank_app_approvals': bankAppApprovals, 'document_sha256': 'ab',
      'signatories': [
        for (final id in signatoryIds)
          {'id': id, 'member_code': 'JC-$id', 'name': 'Member $id', 'role': 'member'},
      ],
      'uploaded_by': 'JC-4821-001', 'confirmed_by': null, 'receipt': null,
    };
    return _mandateState;
  }

  @override
  Future<ChallengeSent> startMandateConfirm(String mandateId) async {
    calls.add('startMandateConfirm:$mandateId');
    return ChallengeSent({'challenge_id': 'ch-m', 'sent_to': '+254 7•• ••• 001',
        'expires_in': 300});
  }

  @override
  Future<Json> confirmBankMandate(String mandateId,
      {required String challengeId, required String code}) async {
    calls.add('confirmBankMandate:$mandateId:$code');
    mandateCurrent = {...?mandatePending, 'state': 'confirmed',
        'confirmed_by': 'JC-4821-002', 'receipt': 'MAND1234'};
    mandatePending = null;
    return _mandateState;
  }

  @override
  Future<Json> rejectMandate(String mandateId) async {
    mandatePending = null;
    return _mandateState;
  }

  // Public anchors
  List<Json> anchorsList = [];

  @override
  Future<List<AnchorProof>> anchors(String id) async =>
      [for (final a in anchorsList) AnchorProof(a)];

  /// An anchor of exactly this chain's last entry: a one-leaf tree, root = leaf.
  void anchorLastEntry({String chamaId = 'c1', bool tamper = false}) {
    final last = ledgerItems.last;
    final seq = (last['document'] as Map)['seq'] as int;
    final hash = last['hash'] as String;
    final leaf = anchorLeaf(chamaId, seq, tamper ? '00' * 32 : hash);
    anchorsList = [
      {'anchor_id': 'a1', 'at': '2026-03-10T00:30:00Z', 'merkle_root': leaf, 'seq': seq,
       'hash': hash, 'leaf': leaf, 'path': <Json>[], 'ots_status': 'submitted',
       'ots_calendar': 'x'},
    ];
  }

  // Members' votes
  final votesList = <Json>[];

  Json _voteJson(String id) => votesList.firstWhere((v) => v['id'] == id);

  void _castFake(String voteId, String choice) {
    final v = _voteJson(voteId);
    v['cast'] = (v['cast'] as int) + 1;
    (v['voted'] as List).add('Jane');
    v['i_can_vote'] = false;
    v['i_voted'] = true;
    v['my_choice'] = v['secret'] == true ? null : choice;
    calls.add('ballot:$voteId:$choice');
  }

  @override
  Future<List<VoteInfo>> votes(String id) async => [for (final v in votesList) VoteInfo(v)];

  @override
  Future<ChallengeSent> startBallot(String voteId, String choice) async => _sent;

  @override
  Future<VoteInfo> castBallot(String voteId, String choice,
      {required String challengeId, required String code}) async {
    _codeCheck(code);
    _castFake(voteId, choice);
    return VoteInfo(_voteJson(voteId));
  }

  @override
  Future<Json> ballotPayload(String voteId, String choice) async {
    final v = _voteJson(voteId);
    final payload = <String, Object?>{'v': 1, 'purpose': 'cast_ballot', 'chama_id': 'c1',
        'vote_id': voteId, 'question': v['question'], 'choice': choice, 'nonce': 'n-vote'};
    return {'device_id': 'dev-1', 'payload': payload,
            'payload_hash': sha256Hex(canonicalJson(payload))};
  }

  @override
  Future<VoteInfo> submitSignedBallot(String voteId, Json body) async {
    calls.add('signedBallot:$voteId:${body['signature']}');
    _castFake(voteId, body['choice'] as String);
    return VoteInfo(_voteJson(voteId));
  }

  // Support access
  final supportList = <Json>[];

  @override
  Future<List<SupportGrantInfo>> supportGrants(String id) async =>
      [for (final g in supportList) SupportGrantInfo(g)];

  @override
  Future<void> requestSupport(String id,
      {required List<String> areas, required int hours, required String reason}) async {
    calls.add('support:${areas.join(',')}:$hours:$reason');
    supportList.insert(0, {'id': 'sg1', 'areas': areas, 'hours': hours, 'reason': reason,
        'requested_by': 'JC-4821-002', 'confirmed_by': null, 'state': 'requested',
        'starts_at': null, 'ends_at': null, 'created_at': 'x'});
  }

  @override
  Future<void> confirmSupport(String grantId) async {
    calls.add('confirmSupport:$grantId');
    supportList.first
      ..['state'] = 'active'
      ..['ends_at'] = '2026-10-22T10:00:00Z';
  }

  @override
  Future<void> revokeSupport(String grantId) async {
    calls.add('revokeSupport:$grantId');
    supportList.first['state'] = 'revoked';
  }

  // Growth: investments, numbers, referrals
  Json portfolioJson = {'held': 0, 'cost_cents': 0, 'value_cents': 0, 'bank_cents': 1000000,
      'net_worth_cents': 1000000, 'investments': <Json>[]};
  final partnersList = <Json>[];
  final referralsList = <Json>[];

  @override
  Future<Portfolio> portfolio(String id) async => Portfolio(portfolioJson);

  @override
  Future<void> recordInvestment(String id, Json body) async {
    calls.add('investment:${body['kind']}:${body['name']}:${body['cost_cents']}');
    (portfolioJson['investments'] as List).add({
      'id': 'i1', 'kind': body['kind'], 'name': body['name'], 'state': 'held',
      'cost_cents': body['cost_cents'], 'value_cents': body['cost_cents'],
      'income_cents': 0, 'valuations': <Json>[]});
    portfolioJson['held'] = 1;
  }

  @override
  Future<void> valueInvestment(String investmentId, Json body) async {
    calls.add('valuation:$investmentId:${body['value_cents']}:${body['source']}');
    for (final i in portfolioJson['investments'] as List) {
      if ((i as Map)['id'] == investmentId) {
        (i['valuations'] as List).add({'id': 'v1', 'value_cents': body['value_cents'],
            'as_of': body['as_of'], 'confirmed_by': null});
      }
    }
  }

  @override
  Future<void> confirmValuation(String valuationId) async {
    calls.add('confirmValuation:$valuationId');
    for (final i in portfolioJson['investments'] as List) {
      for (final v in (i as Map)['valuations'] as List) {
        if ((v as Map)['id'] == valuationId) v['confirmed_by'] = 'JC-4821-002';
      }
    }
  }

  @override
  Future<Analytics> analytics(String id) async => Analytics({
        'months': [
          {'period': '2026-09', 'due_cents': 400000, 'paid_cents': 300000, 'paid_pct': 75,
           'on_time_cents': 200000, 'late_cents': 100000, 'fines_raised_cents': 20000,
           'fines_paid_cents': 0, 'fines_waived_cents': 0},
        ],
        'members': 4,
        'behind': [{'member_code': 'JC-4821-004', 'name': 'Wanjiru', 'arrears_cents': 100000,
                    'fines_cents': 20000}],
        'behind_count': 1,
        'meetings': [{'title': 'AGM', 'starts_at': 'x', 'attended': 3, 'expected': 4,
                      'attendance_pct': 75}],
        'loans': null,
        'money': {'contributed_cents': 300000, 'bank_cents': 1000000,
                  'investments_cents': 0, 'net_worth_cents': 1000000},
      });

  @override
  Future<List<PartnerInfo>> partners() async => [for (final p in partnersList) PartnerInfo(p)];

  @override
  Future<List<ReferralInfo>> referrals(String id) async =>
      [for (final r in referralsList) ReferralInfo(r)];

  @override
  Future<void> proposeReferral(String id, String partnerId, String reason) async {
    calls.add('referral:$partnerId:$reason');
    referralsList.add({'id': 'r1', 'partner': partnersList.first, 'state': 'voting'});
  }

  @override
  Future<void> withdrawReferral(String referralId) async {
    calls.add('withdrawReferral:$referralId');
    referralsList.firstWhere((r) => r['id'] == referralId)['state'] = 'withdrawn';
  }

  // Disputes, elections, phones, exits
  final disputesList = <Json>[];
  Json electionsJson = {'elections': <Json>[], 'election_needed': <Json>[]};
  final newPhonesList = <Json>[];
  final exitsList = <Json>[];

  Json newDispute({String id = 'd1', bool iCanDecide = false, String state =
          'awaiting_response'}) => {
        'id': id, 'raised_by': 'Mary', 'mine': false, 'subject_type': 'other',
        'subject_id': null, 'reason': 'wrong_amount', 'text': 'March cash missing',
        'officials_only': false, 'involved_names': ['Jane'], 'i_am_involved': false,
        'respond_until': 'x', 'state': state, 'round': 0, 'outcome': '', 'outcome_text': '',
        'outcome_member': null, 'outcome_cents': 0, 'vote_id': null,
        'decided_by': 'officials', 'agreed': 0, 'officials_needed': 2,
        'i_can_decide': iCanDecide, 'messages': <Json>[], 'receipt': null, 'created_at': 'x',
      };

  Json _disputeJson(String id) => disputesList.firstWhere((d) => d['id'] == id);

  @override
  Future<List<DisputeInfo>> disputes(String id) async =>
      [for (final d in disputesList) DisputeInfo(d)];

  @override
  Future<DisputeInfo> raiseDispute(String id, Json body) async {
    calls.add('raiseDispute:${body['reason']}:${body['text']}');
    final d = newDispute(id: 'd${disputesList.length + 1}')
      ..['text'] = body['text']
      ..['raised_by'] = 'Me'
      ..['mine'] = true;
    disputesList.insert(0, d);
    return DisputeInfo(d);
  }

  @override
  Future<DisputeInfo> respondDispute(String disputeId, String text) async {
    calls.add('respond:$disputeId:$text');
    (_disputeJson(disputeId)['messages'] as List)
        .add({'by': 'Me', 'kind': 'note', 'text': text, 'round': 0, 'at': 'x'});
    return DisputeInfo(_disputeJson(disputeId));
  }

  @override
  Future<DisputeInfo> proposeOutcome(String disputeId, Json body) async {
    calls.add('propose:$disputeId:${body['outcome']}:${body['text']}');
    return DisputeInfo(_disputeJson(disputeId)
      ..['state'] = 'deciding'
      ..['outcome'] = body['outcome']
      ..['outcome_text'] = body['text']
      ..['agreed'] = 1
      ..['i_can_decide'] = false);
  }

  @override
  Future<ChallengeSent> startAgreeDispute(String disputeId) async => _sent;

  @override
  Future<DisputeInfo> agreeDispute(String disputeId,
      {required String challengeId, required String code}) async {
    _codeCheck(code);
    calls.add('agree:$disputeId');
    return DisputeInfo(_disputeJson(disputeId)
      ..['state'] = 'resolved'
      ..['agreed'] = 2
      ..['receipt'] = 'DSP12345'
      ..['i_can_decide'] = false);
  }

  @override
  Future<DisputeInfo> disagreeDispute(String disputeId, String text) async {
    calls.add('disagree:$disputeId');
    return DisputeInfo(_disputeJson(disputeId));
  }

  @override
  Future<DisputeInfo> withdrawDispute(String disputeId) async =>
      DisputeInfo(_disputeJson(disputeId)..['state'] = 'withdrawn');

  @override
  Future<DisputeInfo> escalateDispute(String disputeId, String text) async =>
      DisputeInfo(_disputeJson(disputeId)..['state'] = 'escalated_outside');

  @override
  Future<ElectionsInfo> elections(String id) async => ElectionsInfo(electionsJson);

  @override
  Future<void> nominate(String id,
      {required String role, required String candidateId, bool acting = false}) async {
    calls.add('nominate:$role:$candidateId:$acting');
    (electionsJson['elections'] as List).add({
      'id': 'e1', 'role': role, 'candidate': 'Mary', 'candidate_id': candidateId,
      'outgoing': null, 'acting': acting, 'term_months': 24, 'vote_id': 'v1',
      'state': 'voting', 'candidate_ready': false, 'mandate_needed': false,
      'mandate_confirmed_at': null, 'receipt': null, 'created_at': 'x'});
  }

  @override
  Future<void> confirmMandate(String electionId) async {
    calls.add('mandate:$electionId');
    for (final e in electionsJson['elections'] as List) {
      if ((e as Map)['id'] == electionId) e['mandate_confirmed_at'] = 'now';
    }
  }

  @override
  Future<List<WaitingPhone>> newPhones(String id) async =>
      [for (final p in newPhonesList) WaitingPhone(p)];

  @override
  Future<ChallengeSent> startVouch(String deviceId, String chamaId) async => _sent;

  @override
  Future<void> vouch(String deviceId, String chamaId,
      {required String challengeId, required String code}) async {
    _codeCheck(code);
    calls.add('vouch:$deviceId');
    newPhonesList.removeWhere((p) => p['id'] == deviceId);
  }

  @override
  Future<List<ExitInfo>> exits(String id) async => [for (final e in exitsList) ExitInfo(e)];

  @override
  Future<ExitQuote> exitQuote(String id) async => ExitQuote({
        'savings_cents': 2000000, 'fines_cents': 20000, 'loan_cents': 0,
        'deduction_pct': 0, 'deduction_cents': 0, 'settlement_cents': 1980000,
        'shortfall_cents': 0, 'notice_days': 30, 'exit_on': '2026-11-18',
        'death_benefit_cents': 0});

  @override
  Future<ChallengeSent> startLeave(String id) async => _sent;

  @override
  Future<void> leave(String id, {required String challengeId, required String code}) async {
    _codeCheck(code);
    calls.add('leave');
    exitsList.add({'id': 'x1', 'member': 'Me', 'member_id': 'm4', 'mine': true,
        'kind': 'leave', 'exit_on': '2026-11-18', 'quote': {'settlement_cents': 1980000},
        'state': 'notice', 'receipt': 'EXT12345', 'created_at': 'x'});
  }

  @override
  Future<void> confirmDeath(String exitId) async {
    calls.add('confirmDeath:$exitId');
    exitsList.firstWhere((e) => e['id'] == exitId)['confirmed'] = true;
  }

  @override
  Future<void> cancelExit(String exitId) async {
    calls.add('cancelExit:$exitId');
    exitsList.firstWhere((e) => e['id'] == exitId)['state'] = 'cancelled';
  }

  @override
  Future<void> recordDeath(String membershipId, {required String diedOn,
      required String nextOfKinName, required String nextOfKinPhone,
      PickedFile? document}) async {
    calls.add('death:$membershipId:$nextOfKinName:${document?.name}');
  }

  // Fines and waivers
  final finesList = <Json>[];

  Json newFine({String id = 'f1', bool mine = true, Json? waiver}) => {
        'id': id, 'member': mine ? 'Me' : 'Mary', 'member_id': mine ? 'm4' : 'm3',
        'mine': mine, 'rule_ref': '3.2', 'period': '2026-09', 'amount_cents': 20000,
        'paid_cents': 0, 'outstanding_cents': 20000, 'state': 'raised',
        'cause': 'late_contribution', 'receipt': 'FINE1234', 'waiver': waiver,
        'created_at': 'x',
      };

  Json _fineJson(String id) => finesList.firstWhere((f) => f['id'] == id);

  Json _fineOfWaiver(String waiverId) =>
      finesList.firstWhere((f) => (f['waiver'] as Map?)?['id'] == waiverId);

  @override
  Future<List<FineInfo>> fines(String id) async => [for (final f in finesList) FineInfo(f)];

  @override
  Future<FineInfo> requestWaiver(String fineId, String reason) async {
    calls.add('requestWaiver:$fineId:$reason');
    return FineInfo(_fineJson(fineId)..['waiver'] = {
      'id': 'w-$fineId', 'reason': reason, 'state': 'requested', 'state_reason': '',
      'needs_officials': 2, 'needs_vote': false, 'deadline_at': 'x', 'approvals': 0,
      'i_can_decide': false, 'created_at': 'x'});
  }

  @override
  Future<ChallengeSent> startWaiverApproval(String waiverId) async => _sent;

  @override
  Future<FineInfo> approveWaiver(String waiverId,
      {required String challengeId, required String code}) async {
    _codeCheck(code);
    calls.add('approveWaiver:$waiverId');
    final f = _fineOfWaiver(waiverId);
    (f['waiver'] as Map)
      ..['approvals'] = 1
      ..['i_can_decide'] = false;
    return FineInfo(f);
  }

  @override
  Future<FineInfo> declineWaiver(String waiverId, String reason) async {
    calls.add('declineWaiver:$waiverId:$reason');
    final f = _fineOfWaiver(waiverId);
    (f['waiver'] as Map)['i_can_decide'] = false;
    return FineInfo(f);
  }

  // Loans
  final loansList = <Json>[];

  Json _loanJson(String id) => loansList.firstWhere((x) => x['id'] == id);

  List<Json> _schedule(int amount, int months) => [
        for (var i = 1; i <= months; i++)
          {'no': i, 'due': '2026-${(10 + i).toString().padLeft(2, '0')}-05',
           'principal_cents': amount ~/ months, 'interest_cents': amount ~/ 100,
           'total_cents': amount ~/ months + amount ~/ 100},
      ];

  Json newLoan({String id = 'loan-1', String state = 'awaiting_guarantors', bool mine = false,
          bool iGuarantee = false}) =>
      {
        'id': id, 'borrower': mine ? 'Me' : 'Mary', 'borrower_id': mine ? 'm4' : 'm3',
        'mine': mine, 'amount_cents': 3000000, 'term_months': 3, 'purpose': 'Stock',
        'terms': {'guarantors': 2, 'interest': 'flat', 'monthly_rate_bp': 100},
        'schedule': _schedule(3000000, 3), 'state': state, 'state_reason': '',
        'proposal_id': null, 'disbursed_on': null, 'expires_at': 'x',
        'guarantees': [
          {'id': 'g1', 'guarantor': 'Jane', 'guarantor_id': 'm1', 'share_cents': 1500000,
           'state': 'requested', 'answered_at': null, 'expires_at': 'x', 'mine': iGuarantee},
          {'id': 'g2', 'guarantor': 'Peter', 'guarantor_id': 'm2', 'share_cents': 1500000,
           'state': 'requested', 'answered_at': null, 'expires_at': 'x', 'mine': false},
        ],
        'balance': {'principal_cents': 0, 'interest_charged_cents': 0, 'repaid_cents': 0,
                    'outstanding_cents': 0, 'due_now_cents': 0, 'next': null},
        'created_at': 'x',
      };

  @override
  Future<List<LoanInfo>> loans(String id) async => [for (final x in loansList) LoanInfo(x)];

  @override
  Future<LoanQuote> loanQuote(String id, {required int amountCents, required int termMonths})
      async {
    calls.add('quote:$amountCents:$termMonths');
    final over = amountCents > 6000000;
    return LoanQuote({
      'eligible': !over,
      'reasons': [if (over) {'code': 'over_limit', 'rule': '12.1', 'message': 'x'}],
      'savings_cents': 2000000, 'limit_cents': 6000000,
      'terms': {'interest': 'flat', 'monthly_rate_bp': 100, 'guarantors': 2},
      'guarantors_needed': 2, 'share_cents': amountCents ~/ 2,
      'schedule': _schedule(amountCents, termMonths),
      'total_interest_cents': termMonths * (amountCents ~/ 100),
      'total_cents': amountCents + termMonths * (amountCents ~/ 100),
    });
  }

  @override
  Future<LoanInfo> requestLoan(String id, Json body, {required String idempotencyKey})
      async {
    calls.add('requestLoan:${body['amount_cents']}:${body['purpose']}:'
        '${(body['guarantor_ids'] as List).join(',')}');
    final x = newLoan(id: 'loan-${loansList.length + 1}', mine: true)
      ..['amount_cents'] = body['amount_cents'];
    loansList.insert(0, x);
    return LoanInfo(x);
  }

  @override
  Future<LoanInfo> cancelLoan(String loanId) async {
    calls.add('cancelLoan:$loanId');
    return LoanInfo(_loanJson(loanId)..['state'] = 'cancelled');
  }

  @override
  Future<LoanInfo> replaceGuarantor(String loanId,
      {required String guaranteeId, required String membershipId}) async {
    calls.add('replace:$guaranteeId:$membershipId');
    return LoanInfo(_loanJson(loanId));
  }

  @override
  Future<ChallengeSent> startGuarantee(String guaranteeId) async => _sent;

  @override
  Future<LoanInfo> acceptGuarantee(String guaranteeId,
      {required String challengeId, required String code}) async {
    _codeCheck(code);
    calls.add('acceptGuarantee:$guaranteeId');
    for (final x in loansList) {
      for (final g in x['guarantees'] as List) {
        if ((g as Map)['id'] == guaranteeId) {
          g['state'] = 'accepted';
          return LoanInfo(x);
        }
      }
    }
    throw StateError('no guarantee');
  }

  @override
  Future<LoanInfo> declineGuarantee(String guaranteeId) async {
    calls.add('declineGuarantee:$guaranteeId');
    for (final x in loansList) {
      for (final g in x['guarantees'] as List) {
        if ((g as Map)['id'] == guaranteeId) {
          g['state'] = 'declined';
          return LoanInfo(x);
        }
      }
    }
    throw StateError('no guarantee');
  }

  // Meetings
  final meetingsList = <Json>[];

  Json _meetingJson(String id) => meetingsList.firstWhere((m) => m['id'] == id);

  Json _meeting(String id, {String? state, String? myStatus}) {
    final m = _meetingJson(id);
    if (state != null) m['state'] = state;
    if (myStatus != null) m['my_status'] = myStatus;
    return m;
  }

  void _person(String meetingId, String membershipId, String status, {String? reason}) {
    for (final p in _meetingJson(meetingId)['people'] as List) {
      if ((p as Map)['membership_id'] == membershipId) {
        p['status'] = status;
        if (reason != null) p['reason'] = reason;
      }
    }
  }

  Json newMeeting({String id = 'meet-1', String state = 'scheduled',
          String myStatus = 'expected', bool iRun = false}) =>
      {
        'id': id, 'title': 'March meeting', 'starts_at': '2026-11-05T11:00:00Z',
        'place': 'Church hall', 'online_link': '', 'agenda': '1. Contributions',
        'state': state, 'cancel_reason': '', 'i_run': iRun, 'my_status': myStatus,
        'people': [
          {'membership_id': 'm1', 'name': 'Jane', 'member_code': 'JC-4821-001',
           'status': 'expected', 'reason': null},
          {'membership_id': 'm2', 'name': 'Peter', 'member_code': 'JC-4821-002',
           'status': 'expected', 'reason': null},
        ],
        'minutes': <Json>[], 'attendance_receipt': null, 'sealed_receipt': null,
        'created_at': 'x',
      };

  @override
  Future<List<Meeting>> meetings(String id) async =>
      [for (final m in meetingsList) Meeting(m)];

  @override
  Future<Meeting> scheduleMeeting(String id, Json body, {required String idempotencyKey})
      async {
    if ((body['place'] as String).isEmpty && (body['online_link'] as String).isEmpty) {
      throw ApiProblem(code: 'place_required', detail: '', status: 400);
    }
    calls.add('scheduleMeeting:${body['title']}:${body['place']}');
    final m = newMeeting(id: 'meet-${meetingsList.length + 1}', iRun: true)
      ..['title'] = body['title']
      ..['starts_at'] = body['starts_at']
      ..['place'] = body['place'];
    meetingsList.insert(0, m);
    return Meeting(m);
  }

  @override
  Future<Meeting> cancelMeeting(String meetingId, String reason) async {
    calls.add('cancelMeeting:$reason');
    return Meeting(_meeting(meetingId, state: 'cancelled')..['cancel_reason'] = reason);
  }

  @override
  Future<Meeting> apologise(String meetingId, String reason) async {
    calls.add('apologise:$reason');
    _person(meetingId, 'm1', 'apology', reason: reason);
    return Meeting(_meeting(meetingId, myStatus: 'apology'));
  }

  @override
  Future<Meeting> startMeeting(String meetingId) async {
    calls.add('startMeeting');
    return Meeting(_meeting(meetingId, state: 'in_progress'));
  }

  @override
  Future<CheckInCode> checkInCode(String meetingId) async => CheckInCode(
      {'code': '482913', 'qr': 'jcmeet:$meetingId:482913', 'changes_in_seconds': 30});

  @override
  Future<Meeting> checkIn(String meetingId, String code) async {
    if (code != '482913') throw ApiProblem(code: 'code_wrong', detail: '', status: 400);
    calls.add('checkIn:$code');
    _person(meetingId, 'm1', 'present');
    return Meeting(_meeting(meetingId, myStatus: 'present'));
  }

  @override
  Future<Meeting> markAttendance(String meetingId, String membershipId, {bool? late}) async {
    calls.add('mark:$membershipId:${late ?? false}');
    _person(meetingId, membershipId, late == true ? 'late' : 'present');
    return Meeting(_meetingJson(meetingId));
  }

  @override
  Future<Meeting> closeAttendance(String meetingId) async {
    calls.add('closeAttendance');
    for (final p in _meetingJson(meetingId)['people'] as List) {
      if ((p as Map)['status'] == 'expected') p['status'] = 'absent';
    }
    return Meeting(_meeting(meetingId, state: 'attendance_closed')
      ..['attendance_receipt'] = 'ATT12345');
  }

  @override
  Future<Meeting> postMinutes(String meetingId, {required String text, PickedFile? photo})
      async {
    calls.add('minutes:$text:${photo?.name}');
    final list = _meetingJson(meetingId)['minutes'] as List;
    list.insert(0, {
      'id': 'min-${list.length + 1}', 'version': list.length + 1, 'text': text,
      'has_photo': false, 'photo_sha256': '', 'hash': 'h', 'written_by': 'Jane',
      'objection_until': '2026-11-12T11:00:00Z', 'objections': <Json>[], 'created_at': 'x',
    });
    return Meeting(_meeting(meetingId, state: 'minutes_pending'));
  }

  @override
  Future<Meeting> objectToMinutes(String minutesId, String reason) async {
    calls.add('object:$minutesId:$reason');
    for (final m in meetingsList) {
      for (final mn in m['minutes'] as List) {
        if ((mn as Map)['id'] == minutesId) {
          (mn['objections'] as List).add({'by': 'Jane', 'reason': reason, 'at': 'x'});
          return Meeting(m);
        }
      }
    }
    throw StateError('no minutes');
  }

  @override
  Future<List<int>> minutesPhoto(String minutesId) async => const [];

  // Rule changes
  final ruleProposalsList = <Json>[];

  @override
  Future<List<RuleProposal>> ruleProposals(String id) async =>
      [for (final p in ruleProposalsList) RuleProposal(p)];

  @override
  Future<RuleProposal> proposeRules(String id, Json rules,
      {required String reason, required String idempotencyKey}) async {
    final before = (_rules['contributions'] as Map)['amount_cents'];
    final after = (rules['contributions'] as Map)['amount_cents'];
    if (before == after) {
      throw ApiProblem(code: 'no_change', detail: '', status: 400);
    }
    calls.add('proposeRules:$reason:$after');
    final p = <String, dynamic>{
      'id': 'rp-${ruleProposalsList.length + 1}', 'state': 'notice', 'reason': reason,
      'proposed_by': 'Jane', 'changed': ['contributions/amount_cents'],
      'clauses': {
        for (final lang in ['en', 'sw'])
          lang: [
            {'ref': '3.1', 'before': 'Each member pays KES ${(before as int) ~/ 100}.',
             'after': 'Each member pays KES ${(after as int) ~/ 100}.'},
          ],
      },
      'rules': rules, 'notice_until': '2026-11-02T09:00:00Z', 'vote_days': 7,
      'quorum_pct': 50, 'pass_pct': 66, 'vote_id': null, 'effective_from': null,
      'created_at': 'x',
    };
    ruleProposalsList.insert(0, p);
    return RuleProposal(p);
  }

  @override
  Future<RuleProposal> withdrawRuleProposal(String proposalId) async {
    final p = ruleProposalsList.firstWhere((p) => p['id'] == proposalId);
    p['state'] = 'withdrawn';
    calls.add('withdrawRule:$proposalId');
    return RuleProposal(p);
  }

  // Daily reconciliation
  Json reconciliationJson = {
    'status': 'no_statement', 'checked_on': null, 'bank_cents': null, 'records_cents': null,
    'gap_cents': 0, 'unmatched_cents': 0, 'unexplained_cents': 0, 'gap_opened_on': null,
    'days_open': 0, 'breach_after_days': 7, 'history': <Json>[],
  };

  @override
  Future<Reconciliation> reconciliation(String id) async => Reconciliation(reconciliationJson);

  // Phone signing keys
  String? tamperAmount;

  @override
  Future<String> attestNonce() async => 'nonce-attest';

  @override
  Future<ChallengeSent> startRegisterDevice(Json body) async {
    calls.add('startRegisterDevice:${body['public_key']}');
    return _sent;
  }

  @override
  Future<Json> registerDevice(Json body,
      {required String challengeId, required String code}) async {
    _codeCheck(code);
    calls.add('registerDevice');
    return {'id': 'dev-1', 'security_level': 'tee'};
  }

  @override
  Future<Json> signingPayload(String proposalId) async {
    final p = _prop(proposalId);
    final payload = <String, Object?>{
      'v': 1, 'purpose': 'approve_proposal', 'chama_id': 'c1', 'proposal_id': proposalId,
      'kind': p['kind'], 'amount_cents': tamperAmount != null ? 1 : p['amount_cents'],
      'deduct_cents': 0, 'payee': p['payee_name'], 'payee_account': p['payee_account'],
      'purpose_text': p['purpose'], 'rule_version_id': null, 'nonce': 'nonce-sign',
    };
    return {'device_id': 'dev-1', 'payload': payload,
            'payload_hash': sha256Hex(canonicalJson(payload))};
  }

  @override
  Future<Proposal> submitSignature(String proposalId, Json body) async {
    calls.add('signature:$proposalId:${body['signature']}');
    final p = _prop(proposalId);
    (p['approvals'] as List).add({'name': 'Jane', 'role': 'chair', 'decision': 'approve',
        'reason': '', 'method': 'device', 'at': 'x'});
    p['approved'] = (p['approved'] as int) + 1;
    p['can_answer'] = false;
    return Proposal(p);
  }

  // Merry-go-round
  Json? rotationJson;

  @override
  Future<RotationInfo> rotation(String id) async => RotationInfo(rotationJson ?? {
        'settings': {'order': 'draw', 'arrears': 'skip'}, 'cycle_no': null, 'method': null,
        'seed': null, 'receipt': null, 'running': false, 'pot_cents': null,
        'next_position': null, 'turns': <Json>[],
      });

  @override
  Future<RotationInfo> startRotation(String id,
      {List<String>? order, required String idempotencyKey}) async {
    calls.add('startRotation:${order?.join(",") ?? "draw"}');
    final ids = order ?? ['m4', 'm1', 'm2'];
    final names = {'m1': ('Jane', 'JC-4821-001'), 'm2': ('Peter', 'JC-4821-002'),
                   'm4': ('Wanjiru', 'JC-4821-004')};
    rotationJson = {
      'settings': {'order': order == null ? 'draw' : 'fixed', 'arrears': 'skip'},
      'cycle_no': 1, 'method': order == null ? 'draw' : 'fixed',
      'seed': order == null ? 'ab12cd34ef56ab12cd34ef56' : '', 'receipt': 'ROT12345',
      'running': true, 'pot_cents': 300000, 'next_position': 1,
      'turns': [
        for (var i = 0; i < ids.length; i++)
          {'position': i + 1, 'membership_id': ids[i], 'member_code': names[ids[i]]!.$2,
           'name': names[ids[i]]!.$1, 'state': 'pending', 'note': '', 'proposal_id': null,
           'proposal_state': null},
      ],
    };
    return RotationInfo(rotationJson!);
  }

  @override
  Future<Proposal> proposeNextTurn(String id, {required String idempotencyKey}) async {
    calls.add('proposeNextTurn');
    final first = ((rotationJson!['turns'] as List).first as Map);
    final p = _proposalJson({'kind': 'payout', 'amount_cents': 300000,
        'purpose': 'Merry-go-round turn 1 of 3, cycle 1'})
      ..['payee_name'] = first['name']
      ..['payee_member_code'] = first['member_code'];
    proposalsList.insert(0, p);
    first['proposal_id'] = p['id'];
    first['proposal_state'] = 'collecting_approvals';
    return Proposal(p);
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
  Future<PickedFile?> pickPhoto() async => const PickedFile('minutes.jpg', [0xff, 0xd8]);

  @override
  Future<PickedFile?> pickStatement() async =>
      PickedFile('march.csv', utf8.encode('Value Date,Narration,Debit,Credit,Balance\n'));
}

/// A phone key without the keystore: records what it was asked to sign.
class FakePhoneSigner implements PhoneSigner {
  FakePhoneSigner({this.isAvailable = true, this.hasKeyAndId = false});

  bool isAvailable;
  bool hasKeyAndId;
  bool cancel = false;
  final signed = <String>[];
  String? remembered;

  @override
  Future<bool> available() async => isAvailable;

  @override
  Future<String?> deviceId() async => hasKeyAndId ? (remembered ?? 'dev-1') : null;

  @override
  Future<bool> ready() async => isAvailable && hasKeyAndId;

  @override
  Future<CreatedKey> create(List<int> challenge) async => const CreatedKey(
      publicKey: 'PUBKEY', chain: ['LEAF', 'ROOT'], strongBox: false);

  @override
  Future<void> remember(String deviceId) async {
    remembered = deviceId;
    hasKeyAndId = true;
  }

  bool forgotten = false;

  @override
  Future<void> forget() async {
    forgotten = true;
    hasKeyAndId = false;
    remembered = null;
  }

  @override
  Future<String> sign(List<int> data, {required String title, required String subtitle}) async {
    if (cancel) throw const SecureKeysCancelled('back');
    signed.add('$title|${utf8.decode(data)}');
    return 'SIG';
  }
}
