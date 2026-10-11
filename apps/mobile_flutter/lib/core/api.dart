import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'models.dart';

class KakaApiException implements Exception {
  final String message;
  final int? status;
  const KakaApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

class KakaApi {
  static const _storage = FlutterSecureStorage();
  static const _urlKey = 'kaka.flutter.server';
  static const _tokenKey = 'kaka.flutter.token';
  static const _spaceKey = 'kaka.flutter.space';
  final http.Client _client;
  String baseUrl = '';
  String token = '';
  String spaceId = '';
  KakaApi({http.Client? client}) : _client = client ?? http.Client();

  Future<void> restore() async {
    baseUrl = await _storage.read(key: _urlKey) ?? '';
    token = await _storage.read(key: _tokenKey) ?? '';
    spaceId = await _storage.read(key: _spaceKey) ?? '';
  }

  static String normalizeEndpoint(String input) {
    String value = input.trim();
    if (value.isEmpty) throw const KakaApiException('Enter your server address');
    if (!value.contains('://')) value = 'https://$value';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty || !['http', 'https'].contains(uri.scheme)) {
      throw const KakaApiException('Invalid server address');
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw const KakaApiException('Use a server origin without credentials or query');
    }
    // Public servers require TLS, following the existing mobile security policy.
    final host = uri.host.toLowerCase();
    final privateV4 = RegExp(r'^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)');
    final local = host == 'localhost' || host == '127.0.0.1' || host == '::1' ||
        host.endsWith('.local') || privateV4.hasMatch(host);
    if (uri.scheme == 'http' && !local) {
      throw const KakaApiException('Public servers must use HTTPS');
    }
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null).toString();
  }

  Future<void> changeServer(String next) async {
    final value = normalizeEndpoint(next);
    if (value == baseUrl) return;
    await probe(value);
    baseUrl = value;
    token = '';
    spaceId = '';
    await _storage.write(key: _urlKey, value: value);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _spaceKey);
  }

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    'origin': 'rakazo://',
    if (token.isNotEmpty) 'authorization': 'Bearer $token',
    if (spaceId.isNotEmpty) 'x-rakazo-space-id': spaceId,
  };

  Future<dynamic> rpc(String path, [Map<String, dynamic> input = const {}]) async {
    if (baseUrl.isEmpty) throw const KakaApiException('Connect a server first');
    final response = await _client.post(Uri.parse('$baseUrl/rpc/$path'),
      headers: _headers, body: jsonEncode({'json': input}))
      .timeout(const Duration(seconds: 15));
    final body = _decode(response.body);
    if (response.statusCode >= 400) {
      final err = body is Map ? body['json'] ?? body['error'] : null;
      throw KakaApiException(
        err is Map ? '${err['message'] ?? 'Request failed'}' :
        'Request failed (${response.statusCode})', response.statusCode);
    }
    if (body is! Map || !body.containsKey('json')) {
      throw const KakaApiException('Unexpected server response');
    }
    return body['json'];
  }

  static dynamic _decode(String data) {
    try { return jsonDecode(data); }
    catch (_) { throw const KakaApiException('Server returned invalid JSON'); }
  }

  Future<void> probe(String endpoint) async {
    final r = await _client.post(Uri.parse('$endpoint/rpc/health'),
      headers: {'content-type': 'application/json','origin':'rakazo://'},
      body: jsonEncode({'json': {}})).timeout(const Duration(seconds: 8));
    final body = _decode(r.body);
    if (r.statusCode != 200 || body is! Map ||
        body['json'] is! Map || body['json']['ok'] != true) {
      throw const KakaApiException('This does not appear to be a Kaka server');
    }
  }

  Future<void> signIn(String email, String password) async {
    if (baseUrl.isEmpty) throw const KakaApiException('Connect a server first');
    final r = await _client.post(Uri.parse('$baseUrl/api/auth/sign-in/email'),
      headers: {'content-type':'application/json','origin':'rakazo://'},
      body: jsonEncode({'email':email, 'password':password}))
        .timeout(const Duration(seconds: 15));
    final data = _decode(r.body);
    if (r.statusCode >= 400) {
      throw KakaApiException(data is Map
        ? '${data['message'] ?? data['error'] ?? 'Could not sign in'}' : 'Could not sign in');
    }
    String next = '';
    if (data is Map) {
      next = data['token']?.toString() ?? '';
      if (next.isEmpty && data['session'] is Map) {
        next = data['session']['token']?.toString() ?? '';
      }
    }
    if (next.isEmpty) {
      final match = RegExp(r'(?:^|,\s*)(?:__Secure-)?better-auth\.session_token=([^;,]*)')
          .firstMatch(r.headers['set-cookie'] ?? '');
      next = match == null ? '' : Uri.decodeComponent(match.group(1)!);
    }
    if (next.isEmpty) throw const KakaApiException('Server did not return a session token');
    token = next;
    spaceId = '';
    await _storage.write(key: _tokenKey, value: next);
    await _storage.delete(key: _spaceKey);
  }

  Future<void> signOut() async {
    token = '';
    spaceId = '';
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _spaceKey);
  }

  Future<void> selectSpace(String id) async {
    spaceId = id;
    await _storage.write(key: _spaceKey, value: id);
  }

  Future<List<KakaSpace>> spaces() async {
    final data = await rpc('spaces/list');
    final list = data is List ? data : (data is Map ? data['spaces'] : null);
    return (list is List ? list : const []).whereType<Map>()
      .map((m) => KakaSpace.fromJson(Map<String, dynamic>.from(m))).toList();
  }

  Future<List<KakaBot>> bots() async {
    final data = await rpc('spaces/list');
    final obj = data is Map ? data : const {};
    final list = obj['bots'] is List ? obj['bots'] as List : const [];
    return list.whereType<Map>().map((e) => KakaBot.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<KakaThread> thread(String botId) async {
    final data = await rpc('threads/get', {'botId':botId});
    return KakaThread.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> send(String botId, String message, {String? nonce}) async {
    await rpc('threads/send', {'botId':botId, 'text':message,
      'clientNonce':nonce ?? 'flutter-${DateTime.now().microsecondsSinceEpoch}'});
  }

  /// Server uses POST + application/json for authenticated SSE.
  /// Each frame wraps the event in {json: ...}; heartbeat frames do not advance cursor.
  Stream<KakaThreadEvent> events(String botId, int fromCursor) async* {
    int cursor = fromCursor;
    while (true) {
      try {
        final request = http.Request('POST', Uri.parse('$baseUrl/rpc/threads/subscribe'));
        request.headers.addAll({..._headers, 'accept':'text/event-stream'});
        request.body = jsonEncode({'json': {'botId':botId, 'cursor':cursor}});
        final response = await _client.send(request);
        if (response.statusCode >= 400) {
          throw KakaApiException('Event stream unavailable', response.statusCode);
        }
        final frame = StringBuffer();
        await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (line.isEmpty) {
            final data = frame.toString();
            frame.clear();
            if (data.isEmpty || data == '[DONE]') continue;
            try {
              final decoded = jsonDecode(data);
              if (decoded is Map && decoded['json'] is Map) {
                final event = KakaThreadEvent(Map<String, dynamic>.from(decoded['json'] as Map));
                if (event.type == 'heartbeat' || event.type.isEmpty) continue;
                if (event.seq != null && event.seq! <= cursor) continue;
                if (event.seq != null) cursor = event.seq!;
                yield event;
              }
            } catch (_) { /* Invalid keepalive frame */ }
          } else if (line.startsWith('data:')) {
            frame.write(line.substring(5).trim());
          }
        }
      } catch (error) {
        // A broken network connection must not kill the thread.
        if (error is KakaApiException && error.status == 401) rethrow;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
  void dispose() => _client.close();
}
