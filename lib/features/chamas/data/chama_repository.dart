import '../../../core/api/api_client.dart';
import '../../../core/providers.dart' show PickedFile;
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
  Future<Invite> invite(String id, {required String role, String? phone, bool bySms,
      String language});
  Future<Chama> submit(String id);
  Future<ChallengeSent> startAdoption(String id);
  Future<Chama> confirmAdoption(String id, {required String challengeId, required String code});
  Future<InviteDetail> inviteDetail(String code);
  Future<ChallengeSent> startJoin(String code);
  Future<Member> confirmJoin(String inviteCode, {required String challengeId, required String smsCode});
  Future<List<Member>> members(String id);
  Future<Position> position(String membershipId);
  Future<LedgerPage> ledger(String id, {int afterSeq = 0});
  Future<List<AnchorProof>> anchors(String id);
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
  Future<Reconciliation> reconciliation(String id);
  Future<List<VoteInfo>> votes(String id);
  Future<List<RuleProposal>> ruleProposals(String id);
  Future<List<Meeting>> meetings(String id);
  Future<List<LoanInfo>> loans(String id);
  Future<List<FineInfo>> fines(String id);
  Future<List<SupportGrantInfo>> supportGrants(String id);
  Future<void> requestSupport(String id,
      {required List<String> areas, required int hours, required String reason});
  Future<void> confirmSupport(String grantId);
  Future<void> revokeSupport(String grantId);
  Future<Portfolio> portfolio(String id);
  Future<void> recordInvestment(String id, Json body);
  Future<void> valueInvestment(String investmentId, Json body);
  Future<void> confirmValuation(String valuationId);
  Future<Analytics> analytics(String id);
  Future<List<PartnerInfo>> partners();
  Future<List<ReferralInfo>> referrals(String id);
  Future<void> proposeReferral(String id, String partnerId, String reason);
  Future<void> withdrawReferral(String referralId);
  Future<List<DisputeInfo>> disputes(String id);
  Future<DisputeInfo> raiseDispute(String id, Json body);
  Future<DisputeInfo> respondDispute(String disputeId, String text);
  Future<DisputeInfo> proposeOutcome(String disputeId, Json body);
  Future<ChallengeSent> startAgreeDispute(String disputeId);
  Future<DisputeInfo> agreeDispute(String disputeId,
      {required String challengeId, required String code});
  Future<DisputeInfo> disagreeDispute(String disputeId, String text);
  Future<DisputeInfo> withdrawDispute(String disputeId);
  Future<DisputeInfo> escalateDispute(String disputeId, String text);
  Future<ElectionsInfo> elections(String id);
  Future<void> nominate(String id,
      {required String role, required String candidateId, bool acting});
  Future<void> confirmMandate(String electionId);
  Future<List<WaitingPhone>> newPhones(String id);
  Future<ChallengeSent> startVouch(String deviceId, String chamaId);
  Future<void> vouch(String deviceId, String chamaId,
      {required String challengeId, required String code});
  Future<List<ExitInfo>> exits(String id);
  Future<ExitQuote> exitQuote(String id);
  Future<ChallengeSent> startLeave(String id);
  Future<void> leave(String id, {required String challengeId, required String code});
  Future<void> cancelExit(String exitId);
  Future<void> confirmDeath(String exitId);
  Future<void> recordDeath(String membershipId, {required String diedOn,
      required String nextOfKinName, required String nextOfKinPhone, PickedFile? document});
  Future<FineInfo> requestWaiver(String fineId, String reason);
  Future<ChallengeSent> startWaiverApproval(String waiverId);
  Future<FineInfo> approveWaiver(String waiverId,
      {required String challengeId, required String code});
  Future<FineInfo> declineWaiver(String waiverId, String reason);
  Future<LoanQuote> loanQuote(String id, {required int amountCents, required int termMonths});
  Future<LoanInfo> requestLoan(String id, Json body, {required String idempotencyKey});
  Future<LoanInfo> cancelLoan(String loanId);
  Future<LoanInfo> replaceGuarantor(String loanId,
      {required String guaranteeId, required String membershipId});
  Future<ChallengeSent> startGuarantee(String guaranteeId);
  Future<LoanInfo> acceptGuarantee(String guaranteeId,
      {required String challengeId, required String code});
  Future<LoanInfo> declineGuarantee(String guaranteeId);
  Future<Meeting> scheduleMeeting(String id, Json body, {required String idempotencyKey});
  Future<Meeting> cancelMeeting(String meetingId, String reason);
  Future<Meeting> apologise(String meetingId, String reason);
  Future<Meeting> startMeeting(String meetingId);
  Future<CheckInCode> checkInCode(String meetingId);
  Future<Meeting> checkIn(String meetingId, String code);
  Future<Meeting> markAttendance(String meetingId, String membershipId, {bool? late});
  Future<Meeting> closeAttendance(String meetingId);
  Future<Meeting> postMinutes(String meetingId, {required String text, PickedFile? photo});
  Future<Meeting> objectToMinutes(String minutesId, String reason);
  Future<List<int>> minutesPhoto(String minutesId);
  Future<RuleProposal> proposeRules(String id, Json rules,
      {required String reason, required String idempotencyKey});
  Future<RuleProposal> withdrawRuleProposal(String proposalId);
  Future<ChallengeSent> startBallot(String voteId, String choice);
  Future<VoteInfo> castBallot(String voteId, String choice,
      {required String challengeId, required String code});
  Future<Json> ballotPayload(String voteId, String choice);
  Future<VoteInfo> submitSignedBallot(String voteId, Json body);
  Future<String> attestNonce();
  Future<ChallengeSent> startRegisterDevice(Json body);
  Future<Json> registerDevice(Json body, {required String challengeId, required String code});
  Future<Json> signingPayload(String proposalId);
  Future<Proposal> submitSignature(String proposalId, Json body);
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
  Future<Invite> invite(String id, {required String role, String? phone, bool bySms = false,
          String language = 'en'}) async =>
      Invite(await _api.post('/chamas/$id/invites/', auth: true, body: {
        'role': role, if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (bySms) 'by_sms': true, if (bySms) 'language': language,
      }));

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

  // Phone signing keys
  @override
  Future<String> attestNonce() async =>
      (await _api.post('/devices/attest-nonce/', auth: true, body: {}))['nonce'] as String;

  @override
  Future<ChallengeSent> startRegisterDevice(Json body) async =>
      ChallengeSent(await _api.post('/devices/', auth: true, body: body));

  @override
  Future<Json> registerDevice(Json body,
          {required String challengeId, required String code}) =>
      _api.post('/devices/', auth: true,
          body: {...body, 'challenge_id': challengeId, 'code': code});

  @override
  Future<Json> signingPayload(String proposalId) =>
      _api.post('/proposals/$proposalId/signing-payload/', auth: true, body: {});

  @override
  Future<Proposal> submitSignature(String proposalId, Json body) async =>
      Proposal(await _api.post('/proposals/$proposalId/signatures/', auth: true, body: body));

  @override
  Future<Reconciliation> reconciliation(String id) async =>
      Reconciliation(await _api.get('/chamas/$id/reconciliation/') as Json);

  // Members' votes
  @override
  Future<List<VoteInfo>> votes(String id) async =>
      [for (final v in await _api.get('/chamas/$id/votes/') as List) VoteInfo(v as Json)];

  @override
  Future<List<DisputeInfo>> disputes(String id) async => [
        for (final d in await _api.get('/chamas/$id/disputes/') as List) DisputeInfo(d as Json),
      ];

  @override
  Future<DisputeInfo> raiseDispute(String id, Json body) async =>
      DisputeInfo(await _api.post('/chamas/$id/disputes/', body: body, auth: true));

  @override
  Future<DisputeInfo> respondDispute(String disputeId, String text) async => DisputeInfo(
      await _api.post('/disputes/$disputeId/respond/', body: {'text': text}, auth: true));

  @override
  Future<DisputeInfo> proposeOutcome(String disputeId, Json body) async =>
      DisputeInfo(await _api.post('/disputes/$disputeId/outcome/', body: body, auth: true));

  @override
  Future<ChallengeSent> startAgreeDispute(String disputeId) async => ChallengeSent(
      await _api.post('/disputes/$disputeId/agree/', body: {}, auth: true));

  @override
  Future<DisputeInfo> agreeDispute(String disputeId,
          {required String challengeId, required String code}) async =>
      DisputeInfo(await _api.post('/disputes/$disputeId/agree/', auth: true,
          body: {'challenge_id': challengeId, 'sms_code': code}));

  @override
  Future<DisputeInfo> disagreeDispute(String disputeId, String text) async => DisputeInfo(
      await _api.post('/disputes/$disputeId/disagree/', body: {'text': text}, auth: true));

  @override
  Future<DisputeInfo> withdrawDispute(String disputeId) async => DisputeInfo(
      await _api.post('/disputes/$disputeId/withdraw/', body: {}, auth: true));

  @override
  Future<DisputeInfo> escalateDispute(String disputeId, String text) async => DisputeInfo(
      await _api.post('/disputes/$disputeId/escalate/', body: {'text': text}, auth: true));

  @override
  Future<ElectionsInfo> elections(String id) async =>
      ElectionsInfo(await _api.get('/chamas/$id/elections/') as Json);

  @override
  Future<void> nominate(String id,
      {required String role, required String candidateId, bool acting = false}) async {
    await _api.post('/chamas/$id/elections/', auth: true,
        body: {'role': role, 'candidate_id': candidateId, 'acting': acting});
  }

  @override
  Future<void> confirmMandate(String electionId) async {
    await _api.post('/elections/$electionId/mandate-updated/', body: {}, auth: true);
  }

  @override
  Future<List<WaitingPhone>> newPhones(String id) async => [
        for (final p in await _api.get('/chamas/$id/new-phones/') as List)
          WaitingPhone(p as Json),
      ];

  @override
  Future<ChallengeSent> startVouch(String deviceId, String chamaId) async => ChallengeSent(
      await _api.post('/devices/$deviceId/vouch/', body: {'chama_id': chamaId}, auth: true));

  @override
  Future<void> vouch(String deviceId, String chamaId,
      {required String challengeId, required String code}) async {
    await _api.post('/devices/$deviceId/vouch/', auth: true,
        body: {'chama_id': chamaId, 'challenge_id': challengeId, 'code': code});
  }

  @override
  Future<List<ExitInfo>> exits(String id) async =>
      [for (final e in await _api.get('/chamas/$id/exits/') as List) ExitInfo(e as Json)];

  @override
  Future<ExitQuote> exitQuote(String id) async =>
      ExitQuote(await _api.get('/chamas/$id/exit-quote/') as Json);

  @override
  Future<ChallengeSent> startLeave(String id) async =>
      ChallengeSent(await _api.post('/chamas/$id/leave/', body: {}, auth: true));

  @override
  Future<void> leave(String id, {required String challengeId, required String code}) async {
    await _api.post('/chamas/$id/leave/', auth: true,
        body: {'challenge_id': challengeId, 'sms_code': code});
  }

  @override
  Future<void> confirmDeath(String exitId) async {
    await _api.post('/exits/$exitId/confirm-death/', body: {}, auth: true);
  }

  @override
  Future<void> cancelExit(String exitId) async {
    await _api.post('/exits/$exitId/cancel/', body: {}, auth: true);
  }

  @override
  Future<void> recordDeath(String membershipId, {required String diedOn,
      required String nextOfKinName, required String nextOfKinPhone,
      PickedFile? document}) async {
    await _api.postForm('/memberships/$membershipId/death/', {
      'died_on': diedOn, 'next_of_kin_name': nextOfKinName,
      'next_of_kin_phone': nextOfKinPhone,
    }, fileField: document == null ? null : 'document', filename: document?.name,
        bytes: document?.bytes);
  }

  @override
  Future<Portfolio> portfolio(String id) async =>
      Portfolio(await _api.get('/chamas/$id/investments/') as Json);

  @override
  Future<void> recordInvestment(String id, Json body) async {
    await _api.post('/chamas/$id/investments/', body: body, auth: true);
  }

  @override
  Future<void> valueInvestment(String investmentId, Json body) async {
    await _api.post('/investments/$investmentId/valuations/', body: body, auth: true);
  }

  @override
  Future<void> confirmValuation(String valuationId) async {
    await _api.post('/valuations/$valuationId/confirm/', body: {}, auth: true);
  }

  @override
  Future<Analytics> analytics(String id) async =>
      Analytics(await _api.get('/chamas/$id/analytics/') as Json);

  @override
  Future<List<PartnerInfo>> partners() async =>
      [for (final p in await _api.get('/partners/') as List) PartnerInfo(p as Json)];

  @override
  Future<List<ReferralInfo>> referrals(String id) async => [
        for (final r in await _api.get('/chamas/$id/referrals/') as List)
          ReferralInfo(r as Json),
      ];

  @override
  Future<void> proposeReferral(String id, String partnerId, String reason) async {
    await _api.post('/chamas/$id/referrals/', auth: true,
        body: {'partner_id': partnerId, 'reason': reason});
  }

  @override
  Future<void> withdrawReferral(String referralId) async {
    await _api.post('/referrals/$referralId/withdraw/', body: {}, auth: true);
  }

  @override
  Future<List<SupportGrantInfo>> supportGrants(String id) async => [
        for (final g in await _api.get('/chamas/$id/support/') as List)
          SupportGrantInfo(g as Json),
      ];

  @override
  Future<void> requestSupport(String id,
      {required List<String> areas, required int hours, required String reason}) async {
    await _api.post('/chamas/$id/support/', auth: true,
        body: {'areas': areas, 'hours': hours, 'reason': reason});
  }

  @override
  Future<void> confirmSupport(String grantId) async {
    await _api.post('/support-grants/$grantId/confirm/', body: {}, auth: true);
  }

  @override
  Future<void> revokeSupport(String grantId) async {
    await _api.post('/support-grants/$grantId/revoke/', body: {}, auth: true);
  }

  @override
  Future<List<FineInfo>> fines(String id) async =>
      [for (final f in await _api.get('/chamas/$id/fines/') as List) FineInfo(f as Json)];

  @override
  Future<FineInfo> requestWaiver(String fineId, String reason) async => FineInfo(
      await _api.post('/fines/$fineId/waiver/', body: {'reason': reason}, auth: true));

  @override
  Future<ChallengeSent> startWaiverApproval(String waiverId) async => ChallengeSent(
      await _api.post('/waivers/$waiverId/approve/', body: {}, auth: true));

  @override
  Future<FineInfo> approveWaiver(String waiverId,
          {required String challengeId, required String code}) async =>
      FineInfo(await _api.post('/waivers/$waiverId/approve/', auth: true,
          body: {'challenge_id': challengeId, 'sms_code': code}));

  @override
  Future<FineInfo> declineWaiver(String waiverId, String reason) async => FineInfo(
      await _api.post('/waivers/$waiverId/decline/', body: {'reason': reason}, auth: true));

  @override
  Future<List<LoanInfo>> loans(String id) async =>
      [for (final x in await _api.get('/chamas/$id/loans/') as List) LoanInfo(x as Json)];

  @override
  Future<LoanQuote> loanQuote(String id, {required int amountCents, required int termMonths})
      async => LoanQuote(await _api.get('/chamas/$id/loans/quote/',
          query: {'amount_cents': amountCents, 'term_months': termMonths}) as Json);

  @override
  Future<LoanInfo> requestLoan(String id, Json body, {required String idempotencyKey})
      async => LoanInfo(await _api.post('/chamas/$id/loans/', body: body, auth: true,
          idempotencyKey: idempotencyKey));

  @override
  Future<LoanInfo> cancelLoan(String loanId) async =>
      LoanInfo(await _api.post('/loans/$loanId/cancel/', body: {}, auth: true));

  @override
  Future<LoanInfo> replaceGuarantor(String loanId,
          {required String guaranteeId, required String membershipId}) async =>
      LoanInfo(await _api.post('/loans/$loanId/guarantors/', auth: true,
          body: {'guarantee_id': guaranteeId, 'membership_id': membershipId}));

  @override
  Future<ChallengeSent> startGuarantee(String guaranteeId) async => ChallengeSent(
      await _api.post('/guarantees/$guaranteeId/accept/', body: {}, auth: true));

  @override
  Future<LoanInfo> acceptGuarantee(String guaranteeId,
          {required String challengeId, required String code}) async =>
      LoanInfo(await _api.post('/guarantees/$guaranteeId/accept/', auth: true,
          body: {'challenge_id': challengeId, 'sms_code': code}));

  @override
  Future<LoanInfo> declineGuarantee(String guaranteeId) async =>
      LoanInfo(await _api.post('/guarantees/$guaranteeId/decline/', body: {}, auth: true));

  @override
  Future<List<Meeting>> meetings(String id) async =>
      [for (final m in await _api.get('/chamas/$id/meetings/') as List) Meeting(m as Json)];

  @override
  Future<Meeting> scheduleMeeting(String id, Json body, {required String idempotencyKey})
      async => Meeting(await _api.post('/chamas/$id/meetings/', body: body, auth: true,
          idempotencyKey: idempotencyKey));

  @override
  Future<Meeting> cancelMeeting(String meetingId, String reason) async => Meeting(
      await _api.post('/meetings/$meetingId/cancel/', body: {'reason': reason}, auth: true));

  @override
  Future<Meeting> apologise(String meetingId, String reason) async => Meeting(
      await _api.post('/meetings/$meetingId/apologies/', body: {'reason': reason},
          auth: true));

  @override
  Future<Meeting> startMeeting(String meetingId) async =>
      Meeting(await _api.post('/meetings/$meetingId/start/', body: {}, auth: true));

  @override
  Future<CheckInCode> checkInCode(String meetingId) async =>
      CheckInCode(await _api.get('/meetings/$meetingId/check-in-code/') as Json);

  @override
  Future<Meeting> checkIn(String meetingId, String code) async => Meeting(
      await _api.post('/meetings/$meetingId/check-in/', body: {'code': code}, auth: true));

  @override
  Future<Meeting> markAttendance(String meetingId, String membershipId, {bool? late}) async =>
      Meeting(await _api.post('/meetings/$meetingId/attendance/',
          body: {'membership_id': membershipId, 'late': ?late}, auth: true));

  @override
  Future<Meeting> closeAttendance(String meetingId) async =>
      Meeting(await _api.post('/meetings/$meetingId/close/', body: {}, auth: true));

  @override
  Future<Meeting> postMinutes(String meetingId, {required String text, PickedFile? photo})
      async => Meeting(await _api.postForm('/meetings/$meetingId/minutes/', {'text': text},
          fileField: photo == null ? null : 'photo', filename: photo?.name,
          bytes: photo?.bytes));

  @override
  Future<Meeting> objectToMinutes(String minutesId, String reason) async => Meeting(
      await _api.post('/minutes/$minutesId/objections/', body: {'reason': reason},
          auth: true));

  @override
  Future<List<int>> minutesPhoto(String minutesId) =>
      _api.getBytes('/minutes/$minutesId/photo/');

  @override
  Future<List<RuleProposal>> ruleProposals(String id) async => [
        for (final p in await _api.get('/chamas/$id/rule-proposals/') as List)
          RuleProposal(p as Json),
      ];

  @override
  Future<RuleProposal> proposeRules(String id, Json rules,
          {required String reason, required String idempotencyKey}) async =>
      RuleProposal(await _api.post('/chamas/$id/rule-proposals/',
          body: {'rules': rules, 'reason': reason}, auth: true,
          idempotencyKey: idempotencyKey));

  @override
  Future<RuleProposal> withdrawRuleProposal(String proposalId) async => RuleProposal(
      await _api.post('/rule-proposals/$proposalId/withdraw/', body: {}, auth: true));

  @override
  Future<ChallengeSent> startBallot(String voteId, String choice) async => ChallengeSent(
      await _api.post('/votes/$voteId/ballots/', auth: true, body: {'choice': choice}));

  @override
  Future<VoteInfo> castBallot(String voteId, String choice,
          {required String challengeId, required String code}) async =>
      VoteInfo(await _api.post('/votes/$voteId/ballots/', auth: true,
          body: {'choice': choice, 'challenge_id': challengeId, 'code': code}));

  @override
  Future<Json> ballotPayload(String voteId, String choice) =>
      _api.post('/votes/$voteId/signing-payload/', auth: true, body: {'choice': choice});

  @override
  Future<VoteInfo> submitSignedBallot(String voteId, Json body) async =>
      VoteInfo(await _api.post('/votes/$voteId/signed-ballots/', auth: true, body: body));

  @override
  Future<List<AnchorProof>> anchors(String id) async => [
        for (final a in await _api.get('/chamas/$id/anchors/') as List) AnchorProof(a as Json)
      ];
}
