import 'package:dio/dio.dart';

import 'problem.dart';
import 'token_store.dart';

/// Thin JSON client for the JiraniChama API.
///
/// Adds the access token, swaps an expired one for a new one once using the refresh
/// token, and turns every failure into an [ApiProblem]. Phase 1 replaces the hand
/// calls with a client generated from the OpenAPI schema; this class stays as its
/// transport.
class ApiClient {
  ApiClient({required String baseUrl, required this.tokens, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            ));

  final Dio _dio;
  final TokenStore tokens;

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
    bool auth = false,
  }) async {
    final response = await _send(() async => _dio.post<Object?>(
          path,
          data: body,
          options: Options(headers: await _headers(auth)),
        ), auth: auth);
    final data = response.data;
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<Map<String, String>> _headers(bool auth) async {
    if (!auth) return const {};
    final t = await tokens.read();
    return t == null ? const {} : {'Authorization': 'Bearer ${t.access}'};
  }

  Future<Response<Object?>> _send(
    Future<Response<Object?>> Function() request, {
    required bool auth,
  }) async {
    try {
      return await request();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (auth && status == 401 && await _refresh()) {
        try {
          return await request();
        } on DioException catch (retry) {
          throw _problem(retry);
        }
      }
      throw _problem(e);
    }
  }

  Future<bool> _refresh() async {
    final current = await tokens.read();
    if (current == null) return false;
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
    return false;
  }

  ApiProblem _problem(DioException e) {
    final response = e.response;
    if (response == null) return ApiProblem.network();
    return ApiProblem.fromBody(response.statusCode, response.data);
  }
}
