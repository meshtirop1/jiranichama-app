import 'package:jirani_domain/jirani_domain.dart';

import '../chamas/data/models.dart';

/// One message for this person (a reminder, a vote, the monthly pack...). ``data`` says
/// where the app opens it.
class NoticeItem {
  NoticeItem(this.json);
  final Json json;

  int get id => json['id'] as int;
  String get kind => json['kind'] as String;
  String get text => json['text'] as String;
  Json get data => Json.from(json['data'] as Map? ?? const {});
  String? get screen => data['screen'] as String?;
  String? get targetId => data['id'] as String?;
  String? get chamaId => json['chama_id'] as String? ?? data['chama_id'] as String?;
  String? get chama => json['chama'] as String?;
  bool get urgent => json['urgent'] == true;
  bool get read => json['read'] == true;
  String get at => json['at'] as String;
}

class NoticeList {
  NoticeList(this.json);
  final Json json;

  int get unread => json['unread'] as int;
  List<NoticeItem> get items => [for (final n in json['notices'] as List) NoticeItem(n as Json)];
}

/// What the member should pay now, and how.
class PayInfo {
  PayInfo(this.json);
  final Json json;

  Json get _owed => json['owed'] as Json;
  Json get _how => json['how'] as Json;
  Kes get total => Kes(_owed['total_cents'] as int);
  Kes get arrears => Kes(_owed['arrears_cents'] as int);
  Kes get fines => Kes(_owed['fines_cents'] as int);
  Kes get current => Kes(_owed['current_cents'] as int);
  String? get dueOn => _owed['due_on'] as String?;
  String get howText => _how['text'] as String? ?? '';
  String get memberCode => _how['member_code'] as String;
  bool get payNow => _how['pay_now'] == true;
}

class PayRequest {
  PayRequest(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get state => json['state'] as String;
  Kes get amount => Kes(json['amount_cents'] as int);
  String get phoneHint => json['phone_hint'] as String? ?? '';
  String get receipt => json['receipt'] as String? ?? '';
}

/// A phone number that pays for a member (smart matching).
class PayerLink {
  PayerLink(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get membershipId => json['membership_id'] as String;
  String get name => json['name'] as String;
  String get state => json['state'] as String;
  Kes? get fromAmount =>
      json['from_amount_cents'] == null ? null : Kes(json['from_amount_cents'] as int);
}

class ShareLine {
  ShareLine(this.json);
  final Json json;

  String get membershipId => json['membership_id'] as String;
  String get memberCode => json['member_code'] as String;
  String get name => json['name'] as String;
  Kes get savings => Kes(json['savings_cents'] as int);
  Kes get profit => Kes(json['profit_cents'] as int);
  Kes get fines => Kes(json['fines_cents'] as int);
  Kes get loan => Kes(json['loan_cents'] as int);
  Kes get payout => Kes(json['payout_cents'] as int);
  String? get proposalState => json['proposal_state'] as String?;
  bool get mine => json['mine'] == true;
}

class ShareOutInfo {
  ShareOutInfo(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get label => json['label'] as String;
  String get state => json['state'] as String;
  String get from => json['from'] as String;
  String get to => json['to'] as String;
  bool get returnSavings => json['return_savings'] == true;
  int get keepPct => json['keep_pct'] as int;
  String get weight => json['weight'] as String;
  Kes get earned => Kes((json['earned'] as Json)['total_cents'] as int);
  Kes get shared => Kes(json['shared_cents'] as int);
  Kes get reserve => Kes(json['reserve_cents'] as int);
  Kes get savingsBack => Kes(json['savings_back_cents'] as int);
  Kes get payoutTotal => Kes(json['payout_cents'] as int);
  Kes? get short => json['short_cents'] == null ? null : Kes(json['short_cents'] as int);
  String? get voteId => json['vote_id'] as String?;
  String? get receipt => json['receipt'] as String?;
  bool get canManage => json['can_manage'] == true;
  List<ShareLine> get lines => [for (final x in json['lines'] as List) ShareLine(x as Json)];
}

class ShareOutList {
  ShareOutList(this.json);
  final Json json;

  List<ShareOutInfo> get items =>
      [for (final x in json['shareouts'] as List) ShareOutInfo(x as Json)];
  bool get canManage => json['can_manage'] == true;
  String get suggestedFrom => (json['suggested'] as Json)['period_from'] as String;
  String get suggestedTo => (json['suggested'] as Json)['period_to'] as String;
}

/// A question a member put to the chama.
class MotionInfo {
  MotionInfo(this.json);
  final Json json;

  String get id => json['id'] as String;
  String get kind => json['kind'] as String;
  String get question => json['question'] as String;
  String get details => json['details'] as String? ?? '';
  List<String> get options => (json['options'] as List? ?? const []).cast<String>();
  String get state => json['state'] as String;
  int get secondsNeeded => json['seconds_needed'] as int;
  int get seconds => json['seconds'] as int;
  List<String> get secondedBy => (json['seconded_by'] as List? ?? const []).cast<String>();
  bool get iCanSecond => json['i_can_second'] == true;
  bool get mine => json['mine'] == true;
  String get raisedBy => json['raised_by'] as String;
  VoteInfo? get vote => json['vote'] == null ? null : VoteInfo(json['vote'] as Json);
}

class VoteComment {
  VoteComment(this.json);
  final Json json;

  String get name => json['name'] as String;
  String get text => json['text'] as String;
  String get at => json['at'] as String;
}
