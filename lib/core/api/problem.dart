/// An RFC 9457 problem document from the API, or a network failure.
class ApiProblem implements Exception {
  ApiProblem({
    required this.code,
    required this.detail,
    this.status,
    this.extra = const {},
  });

  /// The API's stable code, e.g. "otp_wrong". "network" when the server was not reached.
  final String code;
  final String detail;
  final int? status;
  final Map<String, Object?> extra;

  static ApiProblem network() => ApiProblem(code: 'network', detail: 'network error');

  static ApiProblem fromBody(int? status, Object? body) {
    if (body is Map && body['code'] is String) {
      final extra = Map<String, Object?>.from(body)
        ..removeWhere((k, _) => const {'type', 'title', 'status', 'detail', 'code'}.contains(k));
      return ApiProblem(
        code: body['code'] as String,
        detail: (body['detail'] ?? '').toString(),
        status: status,
        extra: extra,
      );
    }
    return ApiProblem(code: 'error', detail: 'unexpected response', status: status);
  }

  @override
  String toString() => 'ApiProblem($code, $status): $detail';
}
