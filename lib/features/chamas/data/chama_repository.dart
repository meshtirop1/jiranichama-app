import '../../../core/api/api_client.dart';
import 'models.dart';

/// Every Phase 1 chama endpoint (jiranichama-api docs/flows: chama-setup, statements,
/// payments). Two-step SMS actions have a `start…` that sends the code and a matching
/// call that takes `challengeId` and `code`.
abstract class ChamaRepository {
  Future<List<Chama>> list();
  Future<Chama> create({required String name, required String type, required String myRole,
      required String idempotencyKey});
  Future<Chama> get(String id);
  Future<void> setBankAccount(String id, {required String bank, required String accountName,
      required String accountNo, String paybill, required String statementRoute});
  Future<RuleBook> rules(String id);
  Future<RuleBook> saveRules(String id, Json rules);
  Future<Invite> invite(String id, {required String role, String? phone});
  Future<Chama> submit(String id);
  Future<ChallengeSent> startAdoption(String id);
  Future<Chama> confirmAdoption(String id, {required String challengeId, required String code});
  Future<InviteDetail> inviteDetail(String code);
  Future<ChallengeSent> startJoin(String code);
  Future<Member> confirmJoin(String inviteCode, {required String challengeId, required String smsCode});
  Future<List<Member>> members(String id);
  Future<Position> position(String membershipId);
  Future<LedgerPage> ledger(String id, {int afterSeq = 0});
  Future<String> platformKeyPem();
  Future<List<Statement>> statements(String id);
  Future<Statement> uploadStatement(String id, {required String filename,
      required List<int> bytes, required String idempotencyKey});
  Future<ChallengeSent> startStatementConfirm(String statementId);
  Future<Statement> confirmStatement(String statementId,
      {required String challengeId, required String code});
  Future<Statement> submitTypedLines(String statementId, List<Json> lines,
      {required String idempotencyKey});
  Future<List<BankLine>> unmatched(String id);
  Future<void> assign(String bankLineId, {required String membershipId, required String reason,
      required String idempotencyKey});
  Future<void> notMe(String bankLineId, {String reason, required String idempotencyKey});

  Future<OpeningBalances> opening(String id);
  Future<OpeningBalances> saveOpening(String id, List<Json> lines);
  Future<ChallengeSent> startConfirmOpening(String id);
  Future<OpeningBalances> confirmOpening(String id,
      {required String challengeId, required String code});
  Future<void> objectToOpening(String lineId, String reason);

  Future<List<CashReceipt>> cashReceipts(String id);
  Future<CashReceipt> recordCash(String id, {required String membershipId,
      required int amountCents, required String idempotencyKey});
  Future<ChallengeSent> startConfirmCash(String receiptId);
  Future<CashReceipt> confirmCash(String receiptId,
      {required String challengeId, required String code});
  Future<CashReceipt> declineCash(String receiptId, {String reason});
  Future<void> bankCash(String bankLineId,
      {required List<String> receiptIds, required String idempotencyKey});

  Future<MoneyOutStatus> moneyOut(String id);
  Future<ChallengeSent> startEnableMoneyOut(String id);
  Future<MoneyOutStatus> enableMoneyOut(String id,
      {required String challengeId, required String code});
  Future<List<Proposal>> proposals(String id);
  Future<Proposal> propose(String id, Json body, {required String idempotencyKey});
  Future<ChallengeSent> startApprove(String proposalId);
  Future<Proposal> approve(String proposalId,
      {required String challengeId, required String code});
  Future<Proposal> declineProposal(String proposalId, String reason);
  Future<Proposal> cancelProposal(String proposalId, String reason);
  Future<Proposal> markPaid(String proposalId, String bankReference,
      {required String idempotencyKey});
  Future<List<UnapprovedDebit>> unapprovedDebits(String id);
  Future<RotationInfo> rotation(String id);
  Future<RotationInfo> startRotation(String id,
      {List<String>? order, required String idempotencyKey});
  Future<Proposal> proposeNextTurn(String id, {required String idempotencyKey});
  Future<UnapprovedDebit> linkDebit(String debitId, String proposalId);
  Future<UnapprovedDebit> explainDebit(String debitId, String explanation);

  Future<MemberStatement> memberStatement(String membershipId, {String? from});
  Future<ChamaStatement> chamaStatement(String id, {String? from});
  Future<IssuedDocument> issueMemberStatementPdf(String membershipId,
      {String? from, required String language, required String idempotencyKey});
  Future<IssuedDocument> issueChamaStatementPdf(String id,
      {String? from, required String language, required String idempotencyKey});
  Future<List<int>> documentFile(String documentId);
}

class HttpChamaRepository implements ChamaRepository {
  HttpChamaRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<Chama>> list() async =>
      [for (final c in await _api.get('/chamas/') as List) Chama(c as Json)];

  @override
  Future<Chama> create({required String name, required String type, required String myRole,
          required String idempotencyKey}) async =>
      Chama(await _api.post('/chamas/', auth: true, idempotencyKey: idempotencyKey,
          body: {'name': name, 'type': type, 'founder_role': myRole}));

  @override
  Future<Chama> get(String id) async => Chama(await _api.get('/chamas/$id/') as Json);

  @override
  Future<void> setBankAccount(String id, {required String bank, required String accountName,
      required String accountNo, String paybill = '', required String statementRoute}) async {
    await _api.put('/chamas/$id/bank-account/', {
      'bank': bank, 'account_name': accountName, 'account_no': accountNo,
      'paybill': paybill, 'statement_route': statementRoute,
    });
  }

  @override
  Future<RuleBook> rules(String id) async => RuleBook(await _api.get('/chamas/$id/rules/') as Json);

  @override
  Future<RuleBook> saveRules(String id, Json rules) async =>
      RuleBook({...await _api.put('/chamas/$id/rules/', rules), 'status': 'draft'});

  @override
  Future<Invite> invite(String id, {required String role, String? phone}) async =>
      Invite(await _api.post('/chamas/$id/invites/', auth: true,
          body: {'role': role, if (phone != null && phone.isNotEmpty) 'phone': phone}));

  @override
  Future<Chama> submit(String id) async =>
      Chama(await _api.post('/chamas/$id/submit/', auth: true));

  @override
  Future<ChallengeSent> startAdoption(String id) async =>
      ChallengeSent(await _api.post('/chamas/$id/adopt/', auth: true, body: {}));

  @override
  Future<Chama> confirmAdoption(String id,
          {required String challengeId, required String code}) async =>
      Chama(await _api.post('/chamas/$id/adopt/', auth: true,
          body: {'challenge_id': challengeId, 'code': code}));

  @override
  Future<InviteDetail> inviteDetail(String code) async =>
      InviteDetail(await _api.get('/invites/${code.toUpperCase()}/') as Json);

  @override
  Future<ChallengeSent> startJoin(String code) async =>
      ChallengeSent(await _api.post('/invites/${code.toUpperCase()}/', auth: true, body: {}));

  @override
  Future<Member> confirmJoin(String inviteCode,
          {required String challengeId, required String smsCode}) async =>
      Member(await _api.post('/invites/${inviteCode.toUpperCase()}/', auth: true,
          body: {'challenge_id': challengeId, 'code': smsCode}));

  @override
  Future<List<Member>> members(String id) async =>
      [for (final m in await _api.get('/chamas/$id/members/') as List) Member(m as Json)];

  @override
  Future<Position> position(String membershipId) async =>
      Position(await _api.get('/memberships/$membershipId/position/') as Json);

  @override
  Future<LedgerPage> ledger(String id, {int afterSeq = 0}) async {
    final r = await _api.get('/chamas/$id/ledger/', query: {'after_seq': afterSeq}) as Json;
    return LedgerPage([for (final e in r['entries'] as List) LedgerItem(e as Json)],
        more: r['more'] == true, nextAfterSeq: r['next_after_seq'] as int);
  }

  @override
  Future<String> platformKeyPem() async =>
      (await _api.get('/platform-key/') as Json)['public_key_pem'] as String;

  @override
  Future<List<Statement>> statements(String id) async =>
      [for (final s in await _api.get('/chamas/$id/statements/') as List) Statement(s as Json)];

  @override
  Future<Statement> uploadStatement(String id, {required String filename,
          required List<int> bytes, required String idempotencyKey}) async =>
      Statement(await _api.upload('/chamas/$id/statements/',
          filename: filename, bytes: bytes, idempotencyKey: idempotencyKey));

  @override
  Future<Statement> submitTypedLines(String statementId, List<Json> lines,
          {required String idempotencyKey}) async =>
      Statement(await _api.post('/statements/$statementId/typed-lines/',
          body: {'lines': lines}, auth: true, idempotencyKey: idempotencyKey));

  @override
  Future<ChallengeSent> startStatementConfirm(String statementId) async =>
      ChallengeSent(await _api.post('/statements/$statementId/confirm/', auth: true, body: {}));

  @override
  Future<Statement> confirmStatement(String statementId,
          {required String challengeId, required String code}) async =>
      Statement(await _api.post('/statements/$statementId/confirm/', auth: true,
          body: {'challenge_id': challengeId, 'code': code}));

  @override
  Future<List<BankLine>> unmatched(String id) async =>
      [for (final t in await _api.get('/chamas/$id/unmatched/') as List) BankLine(t as Json)];

  @override
  Future<void> assign(String bankLineId, {required String membershipId,
      required String reason, required String idempotencyKey}) async {
    await _api.post('/bank-transactions/$bankLineId/assign/', auth: true,
        idempotencyKey: idempotencyKey,
        body: {'membership_id': membershipId, 'reason': reason});
  }

  @override
  Future<void> notMe(String bankLineId,
      {String reason = '', required String idempotencyKey}) async {
    await _api.post('/bank-transactions/$bankLineId/not-me/', auth: true,
        idempotencyKey: idempotencyKey, body: {'reason': reason});
  }

  @override
  Future<OpeningBalances> opening(String id) async =>
      OpeningBalances(await _api.get('/chamas/$id/opening-balances/') as Json);

  @override
  Future<OpeningBalances> saveOpening(String id, List<Json> lines) async =>
      OpeningBalances(await _api.put('/chamas/$id/opening-balances/', {'lines': lines}));

  @override
  Future<ChallengeSent> startConfirmOpening(String id) async => ChallengeSent(
      await _api.post('/chamas/$id/opening-balances/confirm/', auth: true, body: {}));

  @override
  Future<OpeningBalances> confirmOpening(String id,
          {required String challengeId, required String code}) async =>
      OpeningBalances(await _api.post('/chamas/$id/opening-balances/confirm/', auth: true,
          body: {'challenge_id': challengeId, 'code': code}));

  @override
  Future<void> objectToOpening(String lineId, String reason) async {
    await _api.post('/opening-balance-lines/$lineId/object/', auth: true,
        body: {'reason': reason});
  }

  @override
  Future<List<CashReceipt>> cashReceipts(String id) async => [
        for (final r in await _api.get('/chamas/$id/cash-receipts/') as List)
          CashReceipt(r as Json),
      ];

  @override
  Future<CashReceipt> recordCash(String id, {required String membershipId,
          required int amountCents, required String idempotencyKey}) async =>
      CashReceipt(await _api.post('/chamas/$id/cash-receipts/', auth: true,
          idempotencyKey: idempotencyKey,
          body: {'membership_id': membershipId, 'amount_cents': amountCents}));

  @override
  Future<ChallengeSent> startConfirmCash(String receiptId) async => ChallengeSent(
      await _api.post('/cash-receipts/$receiptId/confirm/', auth: true, body: {}));

  @override
  Future<CashReceipt> confirmCash(String receiptId,
          {required String challengeId, required String code}) async =>
      CashReceipt(await _api.post('/cash-receipts/$receiptId/confirm/', auth: true,
          body: {'challenge_id': challengeId, 'code': code}));

  @override
  Future<CashReceipt> declineCash(String receiptId, {String reason = ''}) async =>
      CashReceipt(await _api.post('/cash-receipts/$receiptId/decline/', auth: true,
          body: {'reason': reason}));

  @override
  Future<void> bankCash(String bankLineId,
      {required List<String> receiptIds, required String idempotencyKey}) async {
    await _api.post('/bank-transactions/$bankLineId/bank-cash/', auth: true,
        idempotencyKey: idempotencyKey, body: {'receipt_ids': receiptIds});
  }

  @override
  Future<MemberStatement> memberStatement(String membershipId, {String? from}) async =>
      MemberStatement(await _api.get('/memberships/$membershipId/statement/',
          query: {'from': ?from}) as Json);

  @override
  Future<ChamaStatement> chamaStatement(String id, {String? from}) async =>
      ChamaStatement(await _api.get('/chamas/$id/statement/', query: {'from': ?from}) as Json);

  @override
  Future<IssuedDocument> issueMemberStatementPdf(String membershipId,
          {String? from, required String language, required String idempotencyKey}) async =>
      IssuedDocument(await _api.post('/memberships/$membershipId/statement/pdf/',
          body: {'language': language, 'period_from': ?from},
          auth: true, idempotencyKey: idempotencyKey));

  @override
  Future<IssuedDocument> issueChamaStatementPdf(String id,
          {String? from, required String language, required String idempotencyKey}) async =>
      IssuedDocument(await _api.post('/chamas/$id/statement/pdf/',
          body: {'language': language, 'period_from': ?from},
          auth: true, idempotencyKey: idempotencyKey));

  @override
  Future<List<int>> documentFile(String documentId) =>
      _api.getBytes('/documents/$documentId/file/');

  // Money out
  @override
  Future<MoneyOutStatus> moneyOut(String id) async =>
      MoneyOutStatus(await _api.get('/chamas/$id/money-out/') as Json);

  @override
  Future<ChallengeSent> startEnableMoneyOut(String id) async =>
      ChallengeSent(await _api.post('/chamas/$id/money-out/', auth: true, body: {}));

  @override
  Future<MoneyOutStatus> enableMoneyOut(String id,
          {required String challengeId, required String code}) async =>
      MoneyOutStatus(await _api.post('/chamas/$id/money-out/', auth: true,
          body: {'challenge_id': challengeId, 'code': code}));

  @override
  Future<List<Proposal>> proposals(String id) async => [
        for (final p in await _api.get('/chamas/$id/proposals/') as List) Proposal(p as Json)
      ];

  @override
  Future<Proposal> propose(String id, Json body, {required String idempotencyKey}) async =>
      Proposal(await _api.post('/chamas/$id/proposals/', body: body, auth: true,
          idempotencyKey: idempotencyKey));

  @override
  Future<ChallengeSent> startApprove(String proposalId) async => ChallengeSent(
      await _api.post('/proposals/$proposalId/approve/', auth: true, body: {}));

  @override
  Future<Proposal> approve(String proposalId,
          {required String challengeId, required String code}) async =>
      Proposal(await _api.post('/proposals/$proposalId/approve/', auth: true,
          body: {'challenge_id': challengeId, 'code': code}));

  @override
  Future<Proposal> declineProposal(String proposalId, String reason) async => Proposal(
      await _api.post('/proposals/$proposalId/decline/', auth: true, body: {'reason': reason}));

  @override
  Future<Proposal> cancelProposal(String proposalId, String reason) async => Proposal(
      await _api.post('/proposals/$proposalId/cancel/', auth: true, body: {'reason': reason}));

  @override
  Future<Proposal> markPaid(String proposalId, String bankReference,
          {required String idempotencyKey}) async =>
      Proposal(await _api.post('/proposals/$proposalId/paid/', auth: true,
          body: {'bank_reference': bankReference}, idempotencyKey: idempotencyKey));

  @override
  Future<List<UnapprovedDebit>> unapprovedDebits(String id) async => [
        for (final d in await _api.get('/chamas/$id/unapproved-debits/') as List)
          UnapprovedDebit(d as Json)
      ];

  @override
  Future<UnapprovedDebit> linkDebit(String debitId, String proposalId) async =>
      UnapprovedDebit(await _api.post('/unapproved-debits/$debitId/link/', auth: true,
          body: {'proposal_id': proposalId}));

  @override
  Future<UnapprovedDebit> explainDebit(String debitId, String explanation) async =>
      UnapprovedDebit(await _api.post('/unapproved-debits/$debitId/explain/', auth: true,
          body: {'explanation': explanation}));

  // Merry-go-round
  @override
  Future<RotationInfo> rotation(String id) async =>
      RotationInfo(await _api.get('/chamas/$id/rotation/') as Json);

  @override
  Future<RotationInfo> startRotation(String id,
          {List<String>? order, required String idempotencyKey}) async =>
      RotationInfo(await _api.post('/chamas/$id/rotation/',
          body: {'order': ?order}, auth: true, idempotencyKey: idempotencyKey));

  @override
  Future<Proposal> proposeNextTurn(String id, {required String idempotencyKey}) async =>
      Proposal(await _api.post('/chamas/$id/rotation/next/', body: {}, auth: true,
          idempotencyKey: idempotencyKey));
}
