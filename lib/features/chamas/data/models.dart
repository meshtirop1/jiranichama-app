// What the API sends for chamas, rules, members, statements and the ledger.
// Hand-written readers for now; they follow the OpenAPI schema field names exactly.

import 'package:jirani_domain/jirani_domain.dart';

typedef Json = Map<String, dynamic>;

enum ChamaState { setup, awaitingOfficials, awaitingAdoption, active, suspended, closed, expired }

ChamaState _state(String s) => switch (s) {
      'setup' => ChamaState.setup,
      'awaiting_officials' => ChamaState.awaitingOfficials,
      'awaiting_adoption' => ChamaState.awaitingAdoption,
      'active' => ChamaState.active,
      'suspended' => ChamaState.suspended,
      'closed' => ChamaState.closed,
      _ => ChamaState.expired,
    };

const officialRoles = {'chair', 'treasurer', 'secretary'};

class BankAccount {
  BankAccount(this.json);
  final Json json;

  String get bank => json['bank'] as String;
  String get accountName => json['account_name'] as String;
  String get last4 => json['account_no_last4'] as String? ?? '';
  String get paybill => json['paybill'] as String? ?? '';
  String get till => json['till'] as String? ?? '';
  String get statementRoute => json['statement_route'] as String;
}

class AdoptionStatus {
  AdoptionStatus(this.json);
  final Json json;

  int get founding => json['founding'] as int;
  int get confirmed => json['confirmed'] as int;
  int get needed => json['needed'] as int;
  List<String> get officialsWaiting => (json['officials_waiting'] as List).cast<String>();
}

class Chama {
  Chama(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get name => json['name'] as String;
  String get type => json['type'] as String;
  ChamaState get state => _state(json['state'] as String);
  String get mode => json['mode'] as String;
  String get country => json['country'] as String? ?? 'KE';

  /// The currency the chama keeps its records in. Every amount on its screens is shown
  /// in it (see Kes.currency).
  String get currency => json['currency'] as String? ?? 'KES';
  String? get myRole => json['my_role'] as String?;

  /// The chama has told JiraniChama its government registration certificate.
  bool get registered => json['registered'] == true;

  /// The bank's confirmed mandate needs at least two signatures (protection plan).
  bool get mandateSafe => json['mandate_safe'] == true;
  String? get myMemberCode => json['my_member_code'] as String?;
  bool get iAmFounder => json['i_am_founder'] == true;
  String? get statementInbox => json['statement_inbox'] as String?;
  BankAccount? get bankAccount =>
      json['bank_account'] == null ? null : BankAccount(json['bank_account'] as Json);
  AdoptionStatus? get adoption =>
      json['adoption'] == null ? null : AdoptionStatus(json['adoption'] as Json);

  bool get inSetup => state == ChamaState.setup || state == ChamaState.awaitingOfficials;
  bool get iAmOfficial => officialRoles.contains(myRole);
  bool get iAmTreasurer => myRole == 'treasurer';
  bool get loansOn => json['loans_on'] == true;
}

class Clause {
  Clause(this.ref, this.text);
  final String ref;
  final String text;
}

class RuleBook {
  RuleBook(this.json);
  final Json json;

  bool get inForce => json['status'] == 'in_force';
  int? get versionNo => json['version_no'] as int?;
  Json get rules => Map<String, dynamic>.from(json['rules'] as Map);

  List<Clause> clauses(String language) {
    final book = json['book'] as Map;
    final list = (book[language] ?? book['en']) as List;
    return [for (final c in list) Clause(c['ref'] as String, c['text'] as String)];
  }
}

class Member {
  Member(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get memberCode => json['member_code'] as String;
  String get name => (json['name'] as String?)?.trim().isNotEmpty == true
      ? json['name'] as String
      : json['member_code'] as String;
  String get role => json['role'] as String;
  bool get isFounding => json['is_founding'] == true;
  bool get adoptedRules => json['rules_adopted_at'] != null;
}

class Invite {
  Invite(this.json);
  final Json json;

  String get code => json['code'] as String;
  String get role => json['role'] as String;
  String get phoneHint => json['phone_hint'] as String? ?? '';
}

class InviteDetail {
  InviteDetail(this.json);
  final Json json;

  String get chamaId => (json['chama'] as Map)['id'] as String;
  String get chamaName => (json['chama'] as Map)['name'] as String;
  String get role => json['role'] as String;
  List<Clause> get book =>
      [for (final c in json['book'] as List) Clause(c['ref'] as String, c['text'] as String)];
}

class ChallengeSent {
  ChallengeSent(this.json);
  final Json json;

  String get challengeId => json['challenge_id'] as String;
  String get sentTo => json['sent_to'] as String? ?? '';
}

class Position {
  Position(this.json);
  final Json json;

  Kes get contributed => Kes(json['contributed_cents'] as int);
  Kes get arrears => Kes(json['arrears_cents'] as int);
  Kes get fines => Kes(json['fines_cents'] as int);
  Kes get credit => Kes(json['credit_cents'] as int);
  Kes get opening => Kes(json['opening_cents'] as int? ?? 0);
  Kes get pendingCash => Kes(json['pending_cash_cents'] as int? ?? 0);
  String? get nextDuePeriod => json['next_due_period'] as String?;
  Kes get nextDue => Kes(json['next_due_cents'] as int);

  /// No more fines are added: the member has missed as many months as the rules allow.
  bool get finesStopped => json['fines_stopped'] == true;
}

class LedgerItem {
  LedgerItem(this.json);
  final Json json;

  String get id => json['id'] as String;
  Map<String, Object?> get document => Map<String, Object?>.from(json['document'] as Map);
  String get hash => json['hash'] as String;
  String get receiptCode => json['receipt_code'] as String;
  String? get signature => json['platform_sig'] as String?;
  String? get keyId => json['key_id'] as String?;

  int get seq => document['seq'] as int;
  String get type => document['type'] as String;
  String? get memberCode => document['member_code'] as String?;
  Kes get amount => Kes(document['amount_cents'] as int);
  String? get period => document['period'] as String?;
  String? get reverses => document['reverses'] as String?;
  String? get sourceId => document['source_id'] as String?;
  Map<String, Object?> get decision => Map<String, Object?>.from(document['decision'] as Map);
}

class LedgerPage {
  LedgerPage(this.entries, {required this.more, required this.nextAfterSeq});
  final List<LedgerItem> entries;
  final bool more;
  final int nextAfterSeq;
}

class Statement {
  Statement(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get state => json['state'] as String;
  String get route => json['route'] as String;
  String? get periodFrom => json['period_from'] as String?;
  String? get periodTo => json['period_to'] as String?;
  Kes? get closing => json['closing_cents'] == null ? null : Kes(json['closing_cents'] as int);
  int get lines => json['lines'] as int? ?? 0;
  String? get uploadedBy => json['uploaded_by'] as String?;
  String? get confirmedBy => json['confirmed_by'] as String?;
  List<String> get problems =>
      [for (final p in json['problems'] as List? ?? const []) (p as Map)['message'] as String];
  List<String> get flags =>
      [for (final p in json['flags'] as List? ?? const []) (p as Map)['message'] as String];
  List<UnreadableRow> get unreadableLines => [
        for (final u in json['unreadable_lines'] as List? ?? const []) UnreadableRow(u as Json)
      ];
  List<Json> get typedLines =>
      [for (final t in json['typed_lines'] as List? ?? const []) t as Json];
}

/// A statement row the parser could not read, as the cells in the bank's file.
class UnreadableRow {
  UnreadableRow(this.json);
  final Json json;

  int get lineNo => json['line_no'] as int;
  List<String> get cells => [for (final c in json['cells'] as List) '$c'];

  /// The cell most likely to be the description: the longest one with letters in it.
  String get likelyNarration {
    final words = cells.where((c) => RegExp('[A-Za-z]{3,}').hasMatch(c)).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return words.isEmpty ? '' : words.first;
  }
}

class BankLine {
  BankLine(this.json);
  final Json json;

  String get id => json['id'] as String;
  Kes get amount => Kes(json['amount_cents'] as int);
  String get valueDate => json['value_date'] as String;
  String get narration => json['narration'] as String? ?? '';
  bool get typedIn => json['typed_in'] == true;
  bool get fromMpesa => json['source'] == 'daraja';
}

class OpeningLine {
  OpeningLine(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get membershipId => json['membership_id'] as String;
  String get memberCode => json['member_code'] as String? ?? '';
  Kes get savings => Kes(json['savings_cents'] as int? ?? 0);
  Kes get fines => Kes(json['fines_cents'] as int? ?? 0);
  List<String> get objections => (json['objections'] as List? ?? const []).cast<String>();
}

class OpeningBalances {
  OpeningBalances(this.json);
  final Json json;

  /// "none", "draft" or "confirmed".
  String get state => json['state'] as String;
  String? get proposedBy => json['proposed_by'] as String?;
  String? get confirmedBy => json['confirmed_by'] as String?;
  DateTime? get objectionUntil => json['objection_until'] == null
      ? null
      : DateTime.parse(json['objection_until'] as String);
  List<OpeningLine> get lines => [for (final l in json['lines'] as List) OpeningLine(l as Json)];
  bool get canObject =>
      state == 'confirmed' && (objectionUntil?.isAfter(DateTime.now()) ?? false);
}

class CashReceipt {
  CashReceipt(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get membershipId => json['membership_id'] as String;
  String get memberCode => json['member_code'] as String? ?? '';
  Kes get amount => Kes(json['amount_cents'] as int);
  String get receivedOn => json['received_on'] as String;

  /// recorded, member_confirmed, banked or declined.
  String get state => json['state'] as String;
  bool get overdue => json['overdue'] == true;
}

/// One line on a member statement (jiranichama-api docs/flows/member-statements.md).
class StatementLine {
  StatementLine(this.json);
  final Json json;

  String get date => json['date'] as String;
  String get receipt => json['receipt'] as String;
  String get type => json['type'] as String;
  String? get period => json['period'] as String?;
  Kes get amount => Kes(json['amount_cents'] as int);
  bool get reversed => json['reversed'] == true;
  String? get reversesReceipt => json['reverses_receipt'] as String?;
}

/// A member's figures over a period. The position part is always as of today.
class MemberStatement {
  MemberStatement(this.json);
  final Json json;

  String get from => json['from'] as String;
  String get to => json['to'] as String;
  String get memberCode => (json['member'] as Json)['code'] as String;
  String get memberName {
    final name = ((json['member'] as Json)['name'] as String?)?.trim() ?? '';
    return name.isEmpty ? memberCode : name;
  }
  List<StatementLine> get lines =>
      [for (final l in json['lines'] as List) StatementLine(l as Json)];
  Kes total(String key) => Kes((json['totals'] as Json)[key] as int? ?? 0);
  Position get position => Position(json['position'] as Json);
  String get positionOn => (json['position'] as Json)['on'] as String;
}

class ChamaStatementRow {
  ChamaStatementRow(this.json);
  final Json json;

  String get code => json['code'] as String;
  String get name => (json['name'] as String?)?.trim().isNotEmpty == true
      ? json['name'] as String
      : code;
  Kes get contributed => Kes(json['contributed_cents'] as int);
  Kes get savings => Kes(json['savings_cents'] as int);
  Kes get arrears => Kes(json['arrears_cents'] as int);
  Kes get fines => Kes(json['fines_cents'] as int);
}

class ChamaStatement {
  ChamaStatement(this.json);
  final Json json;

  String get from => json['from'] as String;
  String get to => json['to'] as String;
  List<ChamaStatementRow> get members =>
      [for (final m in json['members'] as List) ChamaStatementRow(m as Json)];
  Kes total(String key) => Kes((json['totals'] as Json)[key] as int? ?? 0);
  Json get _bank => json['bank'] as Json;
  String? get reconciledTo => _bank['reconciled_to'] as String?;
  Kes? get bankClosing =>
      _bank['closing_cents'] == null ? null : Kes(_bank['closing_cents'] as int);
  int get unmatchedCount => _bank['unmatched_count'] as int;
  Kes get unmatched => Kes(_bank['unmatched_cents'] as int);
  Kes get cashWaiting => Kes(_bank['cash_waiting_cents'] as int);
}

/// A sealed PDF statement. Anyone holding it can check it by its code.
class IssuedDocument {
  IssuedDocument(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get kind => json['kind'] as String;
  String get verifyCode => json['verify_code'] as String;
  String get verifyUrl => json['verify_url'] as String;
  String get fingerprint => json['fingerprint'] as String;
  String get sealReceipt => json['seal_receipt'] as String;

  /// Read out over the phone as two groups of five.
  String get spokenCode => '${verifyCode.substring(0, 5)}-${verifyCode.substring(5)}';
}

/// Whether money out is on, and what is available to promise (jiranichama-api
/// docs/flows/money-out.md).
class MoneyOutStatus {
  MoneyOutStatus(this.json);
  final Json json;

  bool get on => json['mode'] == 'money_out';
  int get consents => json['consents'] as int;
  int get needed => json['needed'] as int;
  Kes? get available =>
      json['available_cents'] == null ? null : Kes(json['available_cents'] as int);
}

class ProposalAnswer {
  ProposalAnswer(this.json);
  final Json json;

  String get name => json['name'] as String;
  String get role => json['role'] as String;
  bool get approved => json['decision'] == 'approve';
  String get reason => json['reason'] as String? ?? '';
  bool get byPhoneKey => json['method'] == 'device';
}

/// A payout (to a member) or withdrawal (to anyone else) waiting for, or past, approval.
class Proposal {
  Proposal(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get kind => json['kind'] as String;
  String get state => json['state'] as String;
  String get stateReason => json['state_reason'] as String? ?? '';
  Kes get amount => Kes(json['amount_cents'] as int);
  String get payeeName => json['payee_name'] as String;
  String? get payeeMemberCode => json['payee_member_code'] as String?;
  String get payeeAccount => json['payee_account'] as String? ?? '';
  String get purpose => json['purpose'] as String;
  String get proposedBy => json['proposed_by'] as String;
  String? get proposedByCode => json['proposed_by_code'] as String?;
  int get needsOfficials => json['needs_officials'] as int;
  int get approved => json['approved'] as int;
  List<ProposalAnswer> get answers =>
      [for (final a in json['approvals'] as List) ProposalAnswer(a as Json)];
  String? get refusalRule => (json['refusal'] as Map?)?['rule'] as String?;
  String? get refusalCode => (json['refusal'] as Map?)?['code'] as String?;
  String? get deadlineAt => json['deadline_at'] as String?;
  String get bankReference => json['bank_reference'] as String? ?? '';
  bool get canAnswer => json['can_answer'] == true;
  String? get receipt => json['seal_receipt'] as String?;
  bool get needsVote => json['needs_vote'] == true;
  String? get voteId => json['vote_id'] as String?;
  String? get voteState => json['vote_state'] as String?;
}

/// Money that left the bank account with no approval. Every member was told by SMS.
class UnapprovedDebit {
  UnapprovedDebit(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get state => json['state'] as String;
  Kes get amount => Kes(json['amount_cents'] as int);
  String get valueDate => json['value_date'] as String;
  String get narration => json['narration'] as String? ?? '';
  String get explanation => json['explanation'] as String? ?? '';
  String? get resolvedBy => json['resolved_by'] as String?;
  bool get open => state == 'open';
}

class RotationTurnInfo {
  RotationTurnInfo(this.json);
  final Json json;

  int get position => json['position'] as int;
  String get membershipId => json['membership_id'] as String;
  String get memberCode => json['member_code'] as String;
  String get name => json['name'] as String;
  String get state => json['state'] as String;
  String get note => json['note'] as String? ?? '';
  String? get proposalId => json['proposal_id'] as String?;
  String? get proposalState => json['proposal_state'] as String?;
}

/// The merry-go-round: settings from the rules, and the latest cycle (jiranichama-api
/// docs/flows/rotation.md).
class RotationInfo {
  RotationInfo(this.json);
  final Json json;

  Json? get settings => json['settings'] as Json?;
  String? get order => settings?['order'] as String?;
  String? get arrears => settings?['arrears'] as String?;
  int? get cycleNo => json['cycle_no'] as int?;
  String? get seed => json['seed'] as String?;
  String? get receipt => json['receipt'] as String?;
  bool get running => json['running'] == true;
  Kes? get pot => json['pot_cents'] == null ? null : Kes(json['pot_cents'] as int);
  int? get nextPosition => json['next_position'] as int?;
  List<RotationTurnInfo> get turns =>
      [for (final t in json['turns'] as List) RotationTurnInfo(t as Json)];
}

/// Does the bank match the records? (jiranichama-api docs/flows/reconciliation.md)
class Reconciliation {
  Reconciliation(this.json);
  final Json json;

  /// no_statement, match, open or breach.
  String get status => json['status'] as String;
  String? get checkedOn => json['checked_on'] as String?;
  /// Where the bank's balance came from: "statement", or "bank_api" (read from the bank).
  bool get fromBankApi => json['bank_source'] == 'bank_api';
  Kes? get bank => json['bank_cents'] == null ? null : Kes(json['bank_cents'] as int);
  Kes? get records => json['records_cents'] == null ? null : Kes(json['records_cents'] as int);
  Kes get gap => Kes(json['gap_cents'] as int);
  Kes get unmatched => Kes(json['unmatched_cents'] as int);
  Kes get unexplained => Kes(json['unexplained_cents'] as int);
  String? get gapOpenedOn => json['gap_opened_on'] as String?;
  int get daysOpen => json['days_open'] as int;
  int get breachAfterDays => json['breach_after_days'] as int;

  Json get _statement => (json['statement'] as Json?) ?? const {};

  /// 0 fresh, 1 the treasurer is told, 2 every official, 3 every member.
  int get statementLevel => _statement['level'] as int? ?? 0;
  int get statementDaysOverdue => _statement['days_overdue'] as int? ?? 0;
  String? get statementCheckedTo => _statement['checked_to'] as String?;
}

/// A members' vote (jiranichama-api docs/flows/votes.md).
class VoteInfo {
  VoteInfo(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get subject => json['subject'] as String;
  String get question => json['question'] as String;
  String get state => json['state'] as String;
  String get closesAt => json['closes_at'] as String;
  bool get secret => json['secret'] == true;
  int get eligible => json['eligible'] as int;
  int get passPct => json['pass_pct'] as int;
  int get quorumNeeded => json['quorum_needed'] as int;
  int get cast => json['cast'] as int;
  int? get yes => json['yes'] as int?;
  int? get no => json['no'] as int?;
  List<String> get voted => (json['voted'] as List).cast<String>();
  bool get iCanVote => json['i_can_vote'] == true;
  bool get iVoted => json['i_voted'] == true;
  String? get myChoice => json['my_choice'] as String?;
  String? get receipt => json['result_receipt'] as String?;
}

/// The chama's place in a nightly public anchor (jiranichama-api docs/flows/anchoring.md).
class AnchorProof {
  AnchorProof(this.json);
  final Json json;

  String get at => json['at'] as String;
  String get anchorId => json['anchor_id'] as String? ?? '';

  /// The OpenTimestamps proof was taken by a public calendar (and lands in Bitcoin).
  bool get hasProof => json['ots_status'] == 'submitted';
  String get merkleRoot => json['merkle_root'] as String;
  int get seq => json['seq'] as int;
  String get hash => json['hash'] as String;
  List<Map<String, Object?>> get path =>
      [for (final p in json['path'] as List) Map<String, Object?>.from(p as Map)];
}

/// A proposed rule change (jiranichama-api docs/flows/rule-changes.md): notice, a
/// members' vote, then a new rule version from the 1st of next month.
class RuleProposal {
  RuleProposal(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get state => json['state'] as String;
  String get reason => json['reason'] as String;
  String get proposedBy => json['proposed_by'] as String;
  String get noticeUntil => json['notice_until'] as String;
  int get voteDays => json['vote_days'] as int;
  int get quorumPct => json['quorum_pct'] as int;
  int get passPct => json['pass_pct'] as int;
  String? get voteId => json['vote_id'] as String?;
  String? get effectiveFrom => json['effective_from'] as String?;
  bool get open => state == 'notice' || state == 'voting';

  /// Changed rule-book clauses, before and after, in the member's language.
  List<({String ref, String? before, String? after})> clauses(String lang) => [
        for (final c in ((json['clauses'] as Map)[lang] ?? (json['clauses'] as Map)['en'])
            as List)
          (
            ref: (c as Map)['ref'] as String,
            before: c['before'] as String?,
            after: c['after'] as String?,
          ),
      ];
}

/// A chama meeting (jiranichama-api docs/flows/meetings.md).
class Meeting {
  Meeting(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get title => json['title'] as String;
  String get startsAt => json['starts_at'] as String;
  String get place => json['place'] as String? ?? '';
  String get onlineLink => json['online_link'] as String? ?? '';
  String get agenda => json['agenda'] as String? ?? '';
  String get state => json['state'] as String;
  String get cancelReason => json['cancel_reason'] as String? ?? '';
  bool get iRun => json['i_run'] == true;
  String? get myStatus => json['my_status'] as String?;
  String? get attendanceReceipt => json['attendance_receipt'] as String?;
  String? get sealedReceipt => json['sealed_receipt'] as String?;
  List<MeetingPerson> get people =>
      [for (final p in json['people'] as List) MeetingPerson(p as Json)];
  List<MeetingMinutes> get minutes =>
      [for (final m in json['minutes'] as List) MeetingMinutes(m as Json)];
}

class MeetingPerson {
  MeetingPerson(this.json);
  final Json json;

  String get membershipId => json['membership_id'] as String;
  String get name => json['name'] as String;
  String get memberCode => json['member_code'] as String;
  String get status => json['status'] as String;
  String? get reason => json['reason'] as String?;
}

class MeetingMinutes {
  MeetingMinutes(this.json);
  final Json json;

  String get id => json['id'] as String;
  int get version => json['version'] as int;
  String get text => json['text'] as String? ?? '';
  bool get hasPhoto => json['has_photo'] == true;
  String get objectionUntil => json['objection_until'] as String;
  List<({String by, String reason})> get objections => [
        for (final o in json['objections'] as List)
          (by: (o as Map)['by'] as String, reason: o['reason'] as String),
      ];
}

class CheckInCode {
  CheckInCode(this.json);
  final Json json;

  String get code => json['code'] as String;
  String get qr => json['qr'] as String;
  int get changesInSeconds => json['changes_in_seconds'] as int;
}

/// A loan (jiranichama-api docs/flows/loans.md). Shown only where loans are switched on.
class LoanInfo {
  LoanInfo(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get borrower => json['borrower'] as String;
  String get borrowerId => json['borrower_id'] as String;
  bool get mine => json['mine'] == true;
  int get amountCents => json['amount_cents'] as int;
  int get termMonths => json['term_months'] as int;
  String get purpose => json['purpose'] as String;
  String get state => json['state'] as String;
  String get stateReason => json['state_reason'] as String? ?? '';
  int get guarantorsNeeded => (json['terms'] as Map)['guarantors'] as int;
  bool get open => const ['awaiting_guarantors', 'awaiting_approval', 'approved', 'repaying',
        'in_arrears', 'defaulted'].contains(state);
  List<Json> get schedule => [for (final r in json['schedule'] as List) r as Json];
  List<LoanGuarantee> get guarantees =>
      [for (final g in json['guarantees'] as List) LoanGuarantee(g as Json)];
  LoanBalance get balance => LoanBalance(json['balance'] as Json);
}

class LoanGuarantee {
  LoanGuarantee(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get guarantor => json['guarantor'] as String;
  String get guarantorId => json['guarantor_id'] as String;
  int get shareCents => json['share_cents'] as int;
  String get state => json['state'] as String;
  bool get mine => json['mine'] == true;
}

class LoanBalance {
  LoanBalance(this.json);
  final Json json;

  int get principalCents => json['principal_cents'] as int;
  int get interestChargedCents => json['interest_charged_cents'] as int;
  int get repaidCents => json['repaid_cents'] as int;
  int get outstandingCents => json['outstanding_cents'] as int;
  int get dueNowCents => json['due_now_cents'] as int;
}

class LoanQuote {
  LoanQuote(this.json);
  final Json json;

  bool get eligible => json['eligible'] == true;
  List<({String code, String rule, String message})> get reasons => [
        for (final r in json['reasons'] as List)
          (code: (r as Map)['code'] as String, rule: r['rule'] as String,
           message: r['message'] as String),
      ];
  int get savingsCents => json['savings_cents'] as int;
  int get limitCents => json['limit_cents'] as int;
  int get guarantorsNeeded => json['guarantors_needed'] as int;
  int get shareCents => json['share_cents'] as int;
  bool get flat => (json['terms'] as Map)['interest'] == 'flat';
  String get ratePct {
    final bp = (json['terms'] as Map)['monthly_rate_bp'] as int;
    return bp % 100 == 0 ? '${bp ~/ 100}' : (bp / 100).toStringAsFixed(2);
  }
  List<Json> get schedule => [for (final r in json['schedule'] as List) r as Json];
  int get totalInterestCents => json['total_interest_cents'] as int;
  int get totalCents => json['total_cents'] as int;
}

/// A fine and its latest waiver (jiranichama-api docs/flows/fine-waivers.md).
class FineInfo {
  FineInfo(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get member => json['member'] as String;
  bool get mine => json['mine'] == true;
  String get ruleRef => json['rule_ref'] as String;
  String get period => json['period'] as String;
  int get amountCents => json['amount_cents'] as int;
  int get outstandingCents => json['outstanding_cents'] as int;
  String get state => json['state'] as String;
  String get receipt => json['receipt'] as String;
  WaiverInfo? get waiver =>
      json['waiver'] == null ? null : WaiverInfo(json['waiver'] as Json);
}

class WaiverInfo {
  WaiverInfo(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get reason => json['reason'] as String;
  String get state => json['state'] as String;
  int get needsOfficials => json['needs_officials'] as int;
  int get approvals => json['approvals'] as int;
  bool get iCanDecide => json['i_can_decide'] == true;
}

/// A dispute (jiranichama-api docs/flows/disputes.md).
class DisputeInfo {
  DisputeInfo(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get raisedBy => json['raised_by'] as String;
  bool get mine => json['mine'] == true;
  String get text => json['text'] as String;
  String get state => json['state'] as String;
  bool get open => state == 'awaiting_response' || state == 'deciding';
  List<String> get involved => (json['involved_names'] as List).cast<String>();
  bool get iAmInvolved => json['i_am_involved'] == true;
  bool get iCanDecide => json['i_can_decide'] == true;
  String get decidedBy => json['decided_by'] as String;
  String get outcome => json['outcome'] as String? ?? '';
  String get outcomeText => json['outcome_text'] as String? ?? '';
  int get agreed => json['agreed'] as int? ?? 0;
  int get officialsNeeded => json['officials_needed'] as int? ?? 2;
  String? get receipt => json['receipt'] as String?;
  List<({String by, String kind, String text})> get messages => [
        for (final m in json['messages'] as List)
          (by: (m as Map)['by'] as String, kind: m['kind'] as String,
           text: m['text'] as String? ?? ''),
      ];
}

class ElectionInfo {
  ElectionInfo(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get role => json['role'] as String;
  String get candidate => json['candidate'] as String;
  String get state => json['state'] as String;
  bool get candidateReady => json['candidate_ready'] == true;
  bool get mandateNeeded => json['mandate_needed'] == true;
  String? get mandateConfirmedAt => json['mandate_confirmed_at'] as String?;
}

class ElectionsInfo {
  ElectionsInfo(this.json);
  final Json json;

  List<ElectionInfo> get elections =>
      [for (final e in json['elections'] as List) ElectionInfo(e as Json)];
  bool get electionNeeded => (json['election_needed'] as List).isNotEmpty;
}

class WaitingPhone {
  WaitingPhone(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get owner => json['owner'] as String;
}

class ExitInfo {
  ExitInfo(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get member => json['member'] as String;
  bool get mine => json['mine'] == true;
  String get kind => json['kind'] as String;
  String get exitOn => json['exit_on'] as String;
  String get state => json['state'] as String;
  int get settlementCents => ((json['quote'] as Map)['settlement_cents'] as int?) ?? 0;
  String get reportedBy => json['reported_by'] as String? ?? '';

  /// A death report a second official has confirmed (it still waits out the objection days).
  bool get confirmed => json['confirmed'] == true;
  bool get isDeathReport => kind == 'death' && state == 'notice';
}

class ExitQuote {
  ExitQuote(this.json);
  final Json json;

  int get savingsCents => json['savings_cents'] as int;
  int get finesCents => json['fines_cents'] as int;
  int get loanCents => json['loan_cents'] as int;
  int get deductionCents => json['deduction_cents'] as int;
  int get settlementCents => json['settlement_cents'] as int;
  int get noticeDays => json['notice_days'] as int;
}

/// What the chama owns (jiranichama-api docs/flows/investments.md).
class Portfolio {
  Portfolio(this.json);
  final Json json;

  int get held => json['held'] as int;
  int get costCents => json['cost_cents'] as int;
  int get valueCents => json['value_cents'] as int;
  int? get netWorthCents => json['net_worth_cents'] as int?;
  List<InvestmentInfo> get investments =>
      [for (final i in json['investments'] as List) InvestmentInfo(i as Json)];
}

class InvestmentInfo {
  InvestmentInfo(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get name => json['name'] as String;
  String get state => json['state'] as String;
  int get costCents => json['cost_cents'] as int;
  int get valueCents => json['value_cents'] as int;
  int get incomeCents => json['income_cents'] as int;
  List<({String id, int valueCents, String asOf, String? confirmedBy})> get valuations => [
        for (final v in json['valuations'] as List)
          (id: (v as Map)['id'] as String, valueCents: v['value_cents'] as int,
           asOf: v['as_of'] as String, confirmedBy: v['confirmed_by'] as String?),
      ];
}

/// The numbers for running the chama (jiranichama-api docs/flows/analytics.md).
class Analytics {
  Analytics(this.json);
  final Json json;

  List<({String period, int dueCents, int paidCents, int? paidPct, int lateCents,
      int finesRaisedCents})> get months => [
        for (final m in json['months'] as List)
          (period: (m as Map)['period'] as String, dueCents: m['due_cents'] as int,
           paidCents: m['paid_cents'] as int, paidPct: m['paid_pct'] as int?,
           lateCents: m['late_cents'] as int,
           finesRaisedCents: m['fines_raised_cents'] as int),
      ];
  List<({String name, int arrearsCents, int finesCents})> get behind => [
        for (final b in json['behind'] as List)
          (name: (b as Map)['name'] as String, arrearsCents: b['arrears_cents'] as int,
           finesCents: b['fines_cents'] as int),
      ];
  int get behindCount => json['behind_count'] as int;
  List<({String title, int attended, int expected})> get meetings => [
        for (final m in json['meetings'] as List)
          (title: ((m as Map)['title'] as String?) ?? '', attended: m['attended'] as int,
           expected: m['expected'] as int),
      ];
  Json get _money => json['money'] as Json;
  int get contributedCents => _money['contributed_cents'] as int;
  int? get bankCents => _money['bank_cents'] as int?;
  int get investmentsCents => _money['investments_cents'] as int;
  int? get netWorthCents => _money['net_worth_cents'] as int?;
}

class PartnerInfo {
  PartnerInfo(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get name => json['name'] as String;
  String get regulatorName => json['regulator_name'] as String;
  String get licenceNumber => json['licence_number'] as String;
}

class ReferralInfo {
  ReferralInfo(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get partnerName => (json['partner'] as Map)['name'] as String;
  String get state => json['state'] as String;
}

/// Support access a chama gave JiraniChama staff (jiranichama-api docs/flows/support-access.md).
class SupportGrantInfo {
  SupportGrantInfo(this.json);
  final Json json;

  String get id => json['id'] as String;
  List<String> get areas => (json['areas'] as List).cast<String>();
  String get reason => json['reason'] as String;
  String get requestedBy => json['requested_by'] as String;
  String get state => json['state'] as String;
  String? get endsAt => json['ends_at'] as String?;
}
