import '../../../core/api/api_client.dart';
import '../../../core/api/token_store.dart';

class CodeSent {
  const CodeSent({required this.phoneHint, required this.expiresIn});
  final String phoneHint;
  final int expiresIn;
}

class SignedIn {
  const SignedIn({required this.isNew, required this.hasPin});
  final bool isNew;
  final bool hasPin;
}

/// Phone sign-in against the API (docs/flows/phone-sign-in.md in jiranichama-api).
abstract class AuthRepository {
  Future<bool> hasSession();
  Future<CodeSent> requestCode(String phone, {required String language});
  Future<SignedIn> verifyCode(String phone, String code);
  Future<void> setPin(String pin);
  Future<void> signOut();
}

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  @override
  Future<bool> hasSession() async => await _tokens.read() != null;

  @override
  Future<CodeSent> requestCode(String phone, {required String language}) async {
    final r = await _api.post('/auth/otp/', body: {'phone': phone, 'language': language});
    return CodeSent(
      phoneHint: r['phone_hint'] as String? ?? phone,
      expiresIn: r['expires_in'] as int? ?? 300,
    );
  }

  @override
  Future<SignedIn> verifyCode(String phone, String code) async {
    final r = await _api.post('/auth/verify/', body: {'phone': phone, 'code': code});
    await _tokens.write(Tokens(access: r['access'] as String, refresh: r['refresh'] as String));
    final user = (r['user'] as Map?) ?? const {};
    return SignedIn(isNew: r['is_new'] == true, hasPin: user['has_pin'] == true);
  }

  @override
  Future<void> setPin(String pin) async {
    await _api.post('/auth/pin/', body: {'pin': pin}, auth: true);
  }

  @override
  Future<void> signOut() async {
    final t = await _tokens.read();
    if (t != null) {
      try {
        await _api.post('/auth/logout/', body: {'refresh': t.refresh}, auth: true);
      } catch (_) {
        // Signing out locally must work even offline; the token expires on its own.
      }
    }
    await _tokens.clear();
  }
}
