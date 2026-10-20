import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiranichama/core/api/api_client.dart';
import 'package:jiranichama/core/api/token_store.dart';

/// A server like the real one: access tokens expire, refresh tokens are single use.
class _Server implements HttpClientAdapter {
  String validAccess = 'a2';
  final usedRefresh = <String>{};
  int refreshCalls = 0;
  bool refuseRefresh = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (o.path == '/auth/refresh/') {
      refreshCalls++;
      final token = (o.data as Map)['refresh'] as String;
      if (refuseRefresh || !usedRefresh.add(token)) return _json(401, {'code': 'token_not_valid'});
      return _json(200, {'access': validAccess, 'refresh': '$token+'});
    }
    if (o.headers['Authorization'] != 'Bearer $validAccess') {
      return _json(401, {'code': 'token_not_valid'});
    }
    return _json(200, {'ok': o.path});
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body), status, headers: {Headers.contentTypeHeader: ['application/json']});

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Server server;
  late MemoryTokenStore store;
  late ApiClient client;

  setUp(() async {
    server = _Server();
    store = MemoryTokenStore();
    await store.write(const Tokens(access: 'a1', refresh: 'r1'));
    final dio = Dio(BaseOptions(baseUrl: 'https://test', contentType: Headers.jsonContentType))
      ..httpClientAdapter = server;
    client = ApiClient(baseUrl: 'https://test', tokens: store, dio: dio);
  });

  test('screens that hit an expired token together share one refresh', () async {
    final ended = <void>[];
    client.sessionEnded.listen(ended.add);
    final results = await Future.wait(
        [client.get('/chamas/'), client.get('/statements/'), client.get('/unmatched/')]);
    expect(results.map((r) => r['ok']), ['/chamas/', '/statements/', '/unmatched/']);
    expect(server.refreshCalls, 1);
    expect((await store.read())!.access, 'a2');
    expect(ended, isEmpty);
  });

  test('a refused refresh ends the session instead of leaving screens waiting', () async {
    server.refuseRefresh = true;
    var ended = 0;
    client.sessionEnded.listen((_) => ended++);
    await expectLater(client.get('/chamas/'), throwsA(anything));
    await Future<void>.delayed(Duration.zero);
    expect(ended, 1);
    expect(await store.read(), isNull);
  });
}
