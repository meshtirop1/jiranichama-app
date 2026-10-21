import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../chamas/data/models.dart';
import 'models.dart';

/// The endpoints that make the chama run itself (jiranichama-api docs/flows/automation.md,
/// shareout.md, votes.md): notices, paying, payer links, the share-out, members' motions
/// and comments on votes.
abstract class AutomationRepository {
  Future<NoticeList> notices();
  Future<void> readNotices({List<int>? ids});
  Future<PayInfo> pay(String chamaId);
  Future<PayRequest> payNow(String chamaId, {int? amountCents});
  Future<PayRequest> payStatus(String requestId);
  Future<List<PayerLink>> payerLinks(String chamaId);
  Future<PayerLink> answerPayerLink(String id, {required bool yes});
  Future<PayerLink> endPayerLink(String id);
  Future<ShareOutList> shareOuts(String chamaId);
  Future<ShareOutInfo> draftShareOut(String chamaId, Json body);
  Future<ShareOutInfo> shareOut(String id);
  Future<ShareOutInfo> shareOutAction(String id, String action);
  Future<List<MotionInfo>> motions(String chamaId);
  Future<MotionInfo> raiseMotion(String chamaId, Json body);
  Future<MotionInfo> secondMotion(String id);
  Future<MotionInfo> withdrawMotion(String id);
  Future<List<VoteComment>> voteComments(String voteId);
  Future<VoteComment> comment(String voteId, String text);
  Future<String> proposeBill(String billId);
  // Security and checking (more screens, 2026-10-21).
  Future<List<Json>> myDevices();
  Future<void> revokeDevice(String id);
  Future<void> changePin({required String current, required String pin});
  Future<Json> verifyDocument(String code);
}

class HttpAutomationRepository implements AutomationRepository {
  HttpAutomationRepository(this._api);

  final ApiClient _api;

  @override
  Future<NoticeList> notices() async => NoticeList(await _api.get('/me/notices/') as Json);

  @override
  Future<void> readNotices({List<int>? ids}) async {
    await _api.post('/me/notices/read/', auth: true, body: {'ids': ?ids});
  }

  @override
  Future<PayInfo> pay(String chamaId) async =>
      PayInfo(await _api.get('/chamas/$chamaId/pay/') as Json);

  @override
  Future<PayRequest> payNow(String chamaId, {int? amountCents}) async => PayRequest(
      await _api.post('/chamas/$chamaId/pay/', auth: true,
          body: {'amount_cents': ?amountCents}));

  @override
  Future<PayRequest> payStatus(String requestId) async =>
      PayRequest(await _api.get('/pay-requests/$requestId/') as Json);

  @override
  Future<List<PayerLink>> payerLinks(String chamaId) async {
    final body = await _api.get('/chamas/$chamaId/payer-links/') as Json;
    return [for (final x in body['links'] as List) PayerLink(x as Json)];
  }

  @override
  Future<PayerLink> answerPayerLink(String id, {required bool yes}) async =>
      PayerLink(await _api.post('/payer-links/$id/answer/', auth: true, body: {'yes': yes}));

  @override
  Future<PayerLink> endPayerLink(String id) async =>
      PayerLink(await _api.post('/payer-links/$id/end/', auth: true, body: {}));

  @override
  Future<ShareOutList> shareOuts(String chamaId) async =>
      ShareOutList(await _api.get('/chamas/$chamaId/shareouts/') as Json);

  @override
  Future<ShareOutInfo> draftShareOut(String chamaId, Json body) async =>
      ShareOutInfo(await _api.post('/chamas/$chamaId/shareouts/', auth: true, body: body));

  @override
  Future<ShareOutInfo> shareOut(String id) async =>
      ShareOutInfo(await _api.get('/shareouts/$id/') as Json);

  @override
  Future<ShareOutInfo> shareOutAction(String id, String action) async =>
      ShareOutInfo(await _api.post('/shareouts/$id/$action/', auth: true, body: {}));

  @override
  Future<List<MotionInfo>> motions(String chamaId) async =>
      [for (final m in await _api.get('/chamas/$chamaId/motions/') as List) MotionInfo(m as Json)];

  @override
  Future<MotionInfo> raiseMotion(String chamaId, Json body) async =>
      MotionInfo(await _api.post('/chamas/$chamaId/motions/', auth: true, body: body));

  @override
  Future<MotionInfo> secondMotion(String id) async =>
      MotionInfo(await _api.post('/motions/$id/second/', auth: true, body: {}));

  @override
  Future<MotionInfo> withdrawMotion(String id) async =>
      MotionInfo(await _api.post('/motions/$id/withdraw/', auth: true, body: {}));

  @override
  Future<List<VoteComment>> voteComments(String voteId) async =>
      [for (final c in await _api.get('/votes/$voteId/comments/') as List) VoteComment(c as Json)];

  @override
  Future<VoteComment> comment(String voteId, String text) async =>
      VoteComment(await _api.post('/votes/$voteId/comments/', auth: true, body: {'text': text}));

  @override
  Future<String> proposeBill(String billId) async =>
      (await _api.post('/bills/$billId/propose/', auth: true, body: {}))['proposal_id']
          as String;

  @override
  Future<List<Json>> myDevices() async =>
      [for (final d in await _api.get('/devices/') as List) Json.from(d as Map)];

  @override
  Future<void> revokeDevice(String id) async {
    await _api.post('/devices/$id/revoke/', auth: true, body: {});
  }

  @override
  Future<void> changePin({required String current, required String pin}) async {
    await _api.post('/auth/pin/', auth: true, body: {'pin': pin, 'current_pin': current});
  }

  @override
  Future<Json> verifyDocument(String code) async =>
      Json.from(await _api.get('/verify/${Uri.encodeComponent(code)}/') as Map);
}

/// The chama repository's test fake also plays this one, so a test that overrides the
/// chama repository covers these screens too.
final automationRepositoryProvider = Provider<AutomationRepository>((ref) {
  final chamas = ref.watch(chamaRepositoryProvider);
  if (chamas is AutomationRepository) return chamas as AutomationRepository;
  return HttpAutomationRepository(ref.watch(apiClientProvider));
});

final noticesProvider = FutureProvider.autoDispose<NoticeList>((ref) {
  ref.cacheFor(const Duration(minutes: 2));
  return ref.watch(automationRepositoryProvider).notices();
});

final payInfoProvider = FutureProvider.autoDispose.family<PayInfo, String>((ref, chamaId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(automationRepositoryProvider).pay(chamaId);
});

final payerLinksProvider =
    FutureProvider.autoDispose.family<List<PayerLink>, String>((ref, chamaId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(automationRepositoryProvider).payerLinks(chamaId);
});

final shareOutsProvider = FutureProvider.autoDispose.family<ShareOutList, String>(
    (ref, chamaId) => ref.watch(automationRepositoryProvider).shareOuts(chamaId));

final motionsProvider = FutureProvider.autoDispose.family<List<MotionInfo>, String>(
    (ref, chamaId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(automationRepositoryProvider).motions(chamaId);
});

final voteCommentsProvider = FutureProvider.autoDispose.family<List<VoteComment>, String>(
    (ref, voteId) => ref.watch(automationRepositoryProvider).voteComments(voteId));
