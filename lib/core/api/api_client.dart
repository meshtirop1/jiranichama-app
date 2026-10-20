import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import 'problem.dart';
import 'token_store.dart';

/// A fresh key for one logical write. Create it once per user action and reuse it on
/// retries, so a dropped connection never records the same thing twice.
String newIdempotencyKey() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Thin JSON client for the JiraniChama API.
///
/// Adds the access token, swaps an expired one for a new one once using the refresh
/// token, and turns every failure into an [ApiProblem].
///
/// Refresh tokens are single use (the server rotates them), so when several screens hit
/// an expired token at once only one refresh is sent and the others wait for it. Without
/// that, the second refresh used the old token, was refused, and ended the session while
/// the screens kept spinning. When the session really is over, [sessionEnded] fires so
/// the app can go back to sign-in. A client generated from the
/// OpenAPI schema can replace the hand calls later; this class stays as its transport.
class ApiClient {
  ApiClient({required String baseUrl, required this.tokens, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            ));

  final Dio _dio;
  final TokenStore tokens;
  final _ended = StreamController<void>.broadcast();
  Future<bool>? _refreshing;

  /// Fires when the session cannot be renewed (signed out elsewhere, or expired).
  Stream<void> get sessionEnded => _ended.stream;

  Future<dynamic> get(String path, {Map<String, Object?>? query}) =>
      _send('GET', path, query: query, auth: true);

  /// A file (a statement PDF), as raw bytes.
  Future<List<int>> getBytes(String path) async {
    final data = await _send('GET', path, auth: true, bytes: true);
    return data is List<int> ? data : const [];
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
    bool auth = false,
    String? idempotencyKey,
  }) async {
    final data = await _send('POST', path, body: body, auth: auth, idempotencyKey: idempotencyKey);
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<Map<String, dynamic>> put(String path, Map<String, Object?> body) async {
    final data = await _send('PUT', path, body: body, auth: true);
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, Object?> body) async {
    final data = await _send('PATCH', path, body: body, auth: true);
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<Map<String, dynamic>> upload(
    String path, {
    required String filename,
    required List<int> bytes,
    required String idempotencyKey,
  }) async {
    final data = await _send('POST', path,
        formData: () => FormData.fromMap(
            {'file': MultipartFile.fromBytes(bytes, filename: filename)}),
        auth: true,
        idempotencyKey: idempotencyKey);
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<Map<String, dynamic>> postForm(String path, Map<String, Object?> fields,
      {String? fileField, String? filename, List<int>? bytes}) async {
    final data = await _send('POST', path,
        formData: () => FormData.fromMap({
              ...fields,
              if (fileField != null && bytes != null)
                fileField: MultipartFile.fromBytes(bytes, filename: filename),
            }),
        auth: true);
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    FormData Function()? formData,
    Map<String, Object?>? query,
    required bool auth,
    String? idempotencyKey,
    bool bytes = false,
  }) async {
    String? sentAccess;
    Future<Response<Object?>> request() async {
      final headers = <String, String>{'Idempotency-Key': ?idempotencyKey};
      if (auth) {
        final t = await tokens.read();
        sentAccess = t?.access;
        if (t != null) headers['Authorization'] = 'Bearer ${t.access}';
      }
      return _dio.request<Object?>(
        path,
        data: formData != null ? formData() : body,
        queryParameters: query,
        options: Options(method: method, headers: headers,
            responseType: bytes ? ResponseType.bytes : null),
      );
    }

    try {
      return (await request()).data;
    } on DioException catch (e) {
      if (auth && e.response?.statusCode == 401 && await _renew(sentAccess)) {
        try {
          return (await request()).data;
        } on DioException catch (retry) {
          throw _problem(retry);
        }
      }
      throw _problem(e);
    }
  }

  /// A fresh access token after a 401: someone else's new one if another request has
  /// already refreshed, else the one refresh in flight (started here if none is).
  Future<bool> _renew(String? sentAccess) async {
    final current = await tokens.read();
    if (current == null) {
      _ended.add(null);
      return false;
    }
    if (current.access != sentAccess) return true;
    return _refreshing ??= _refresh(current).whenComplete(() => _refreshing = null);
  }

  Future<bool> _refresh(Tokens current) async {
    try {
      final r = await _dio.post<Object?>('/auth/refresh/', data: {'refresh': current.refresh});
      final data = r.data;
      if (data is Map && data['access'] is String) {
        await tokens.write(Tokens(
          access: data['access'] as String,
          refresh: (data['refresh'] as String?) ?? current.refresh,
        ));
        return true;
      }
    } on DioException {
      // Fall through: the session is over.
    }
    await tokens.clear();
    _ended.add(null);
    return false;
  }

  ApiProblem _problem(DioException e) {
    final response = e.response;
    if (response == null) return ApiProblem.network();
    var body = response.data;
    if (body is List<int>) {
      // A file download that failed: the error is still JSON, just undecoded.
      try {
        body = jsonDecode(utf8.decode(body));
      } catch (_) {
        body = null;
      }
    }
    return ApiProblem.fromBody(response.statusCode, body);
  }
}
