import 'dart:convert';
import 'dart:io';

import 'package:jirani_domain/jirani_domain.dart';
import 'package:jiranichama/core/api/problem.dart';
import 'package:jiranichama/core/providers.dart';
import 'package:jiranichama/features/chamas/data/chama_repository.dart';
import 'package:jiranichama/features/chamas/data/models.dart';

const smsCode = '424242';

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
        'mode': 'records_only', 'member_code_prefix': 'JC-4821', 'my_role': myRole,
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
}

class FakeFileSource implements FileSource {
  @override
  Future<PickedFile?> pickStatement() async =>
      PickedFile('march.csv', utf8.encode('Value Date,Narration,Debit,Credit,Balance\n'));
}
