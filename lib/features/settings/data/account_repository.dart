import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';

/// The signed-in person as the server knows them (`/auth/me/`).
class Profile {
  const Profile(this.json);

  final Map<String, dynamic> json;

  String get name => json['display_name'] as String? ?? '';
  String get phoneHint => json['phone_hint'] as String? ?? '';
  String get language => json['language'] as String? ?? 'en';
  String get country => json['country'] as String? ?? 'KE';

  /// not_started, pending, verified or failed. Shown in Settings.
  String get kycStatus => json['kyc_status'] as String? ?? 'not_started';
  String get joined => (json['date_joined'] as String? ?? '').split('T').first;
}

/// A chama's way to register with the government, and how far its officials have got.
class ChamaRegistration {
  const ChamaRegistration(this.json);

  final Map<String, dynamic> json;

  RegistrationGuide get guide => RegistrationGuide(json['guide'] as Map<String, dynamic>);
  String get route => json['route'] as String? ?? 'community_group';
  List<String> get ticked => [for (final t in json['ticked'] as List? ?? const []) '$t'];
  List<String> get missing => [for (final t in json['missing'] as List? ?? const []) '$t'];
  String get certificateNo => json['certificate_no'] as String? ?? '';
  String? get registeredOn => json['registered_on'] as String?;
  bool get registered => json['registered'] == true;
  bool get canEdit => json['can_edit'] == true;
  bool get remind => json['remind'] == true;
}

class RegistrationGuide {
  const RegistrationGuide(this.json);

  final Map<String, dynamic> json;

  String get country => json['country'] as String? ?? 'KE';
  bool get detailed => json['detailed'] == true;
  String get disclaimer => json['disclaimer'] as String? ?? '';
  List<RegistrationRoute> get routes =>
      [for (final r in json['routes'] as List? ?? const []) RegistrationRoute(r as Map<String, dynamic>)];
  Map<String, Map<String, dynamic>> get papers => {
        for (final e in (json['papers'] as Map? ?? const {}).entries)
          '${e.key}': (e.value as Map).cast<String, dynamic>(),
      };

  RegistrationRoute routeOf(String id) =>
      routes.firstWhere((r) => r.id == id, orElse: () => routes.first);
}

class RegistrationRoute {
  const RegistrationRoute(this.json);

  final Map<String, dynamic> json;

  String get id => json['id'] as String;
  String get title => json['title'] as String? ?? '';
  String get office => json['office'] as String? ?? '';
  String get law => json['law'] as String? ?? '';
  String get who => json['who'] as String? ?? '';
  String get fee => json['fee'] as String? ?? '';
  String get time => json['time'] as String? ?? '';
  String get renew => json['renew'] as String? ?? '';
  List<String> get steps => [for (final s in json['steps'] as List? ?? const []) '$s'];
  List<String> get papers => [for (final p in json['papers'] as List? ?? const []) '$p'];
}

/// The person's own profile, and registering a chama with the government. Separate from
/// the chama repository: neither belongs to one chama's records.
abstract class AccountRepository {
  Future<Profile> profile();
  Future<Profile> updateProfile({String? name, String? language, String? country});
  Future<RegistrationGuide> guide(String country, String language);
  Future<ChamaRegistration> registration(String chamaId, String language);
  Future<ChamaRegistration> updateRegistration(String chamaId, Map<String, Object?> change,
      String language);
  Future<List<int>> paper(String chamaId, String paper, String language);
}

class HttpAccountRepository implements AccountRepository {
  HttpAccountRepository(this._api);

  final ApiClient _api;

  @override
  Future<Profile> profile() async =>
      Profile((await _api.get('/auth/me/')) as Map<String, dynamic>);

  @override
  Future<Profile> updateProfile({String? name, String? language, String? country}) async =>
      Profile(await _api.patch('/auth/me/',
          {'display_name': ?name, 'language': ?language, 'country': ?country}));

  @override
  Future<RegistrationGuide> guide(String country, String language) async =>
      RegistrationGuide((await _api.get('/registration/guide/',
          query: {'country': country, 'lang': language})) as Map<String, dynamic>);

  @override
  Future<ChamaRegistration> registration(String chamaId, String language) async =>
      ChamaRegistration((await _api.get('/chamas/$chamaId/registration/',
          query: {'lang': language})) as Map<String, dynamic>);

  @override
  Future<ChamaRegistration> updateRegistration(String chamaId, Map<String, Object?> change,
          String language) async =>
      ChamaRegistration(
          await _api.patch('/chamas/$chamaId/registration/?lang=$language', change));

  @override
  Future<List<int>> paper(String chamaId, String paper, String language) =>
      _api.getBytes('/chamas/$chamaId/registration/papers/$paper/?lang=$language');
}

final accountRepositoryProvider = Provider<AccountRepository>(
    (ref) => HttpAccountRepository(ref.watch(apiClientProvider)));
