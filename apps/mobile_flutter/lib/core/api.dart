import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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

  Future<dynamic> rpc(String path, [Map<String, dynamic> input = const {}]) =>
      rpcWithTimeout(path,input,const Duration(seconds:15));

  Future<dynamic> rpcWithTimeout(String path, Map<String, dynamic> input,
      Duration timeout) async {
    if (baseUrl.isEmpty) throw const KakaApiException('Connect a server first');
    final response = await _client.post(Uri.parse('$baseUrl/rpc/$path'),
      headers: _headers, body: jsonEncode({'json': input}))
      .timeout(timeout);
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

  Future<KakaThread> thread(String targetId, {bool group = false}) async {
    final data = await rpc('threads/get', group ? {'groupId':targetId} : {'botId':targetId});
    return KakaThread.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> send(String targetId, String message, {bool group = false, String? nonce, List<String> artifactIds = const []}) async {
    await rpc('threads/send', {...(group ? {'groupId':targetId} : {'botId':targetId}), 'text':message,
      if (artifactIds.isNotEmpty) 'artifactIds':artifactIds,
      'clientNonce':nonce ?? 'flutter-${DateTime.now().microsecondsSinceEpoch}'});
  }


  Future<String> createArtifact(String targetId, {
    bool group = false, required String name, required String mimeType,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty || bytes.lengthInBytes > 10*1024*1024) {
      throw const KakaApiException('Attachments must be between 1 byte and 10 MB');
    }
    final data = await rpc('artifacts/create', {
      ...(group ? {'groupId':targetId} : {'botId':targetId}),
      'name':name,
      'mimeType':mimeType,
      'contentBase64':base64Encode(bytes),
    });
    if (data is! Map || data['id'] == null) {
      throw const KakaApiException('Could not upload attachment');
    }
    return data['id'].toString();
  }

  Future<Map<String,dynamic>> readArtifact(String targetId,
    String artifactId, {bool group = false}) async {
    final data = await rpc('artifacts/get', {
      ...(group ? {'groupId':targetId} : {'botId':targetId}),
      'artifactId':artifactId,
    });
    return Map<String,dynamic>.from(data as Map);
  }

  /// Server uses POST + application/json for authenticated SSE.
  /// Each frame wraps the event in {json: ...}; heartbeat frames do not advance cursor.
  // Dedicated SSE client: cancellation releases the socket and decode buffers.
  Stream<KakaThreadEvent> events(String targetId, int fromCursor,
      {bool group = false}) async* {
    final subscribedBase = baseUrl;
    final subscribedToken = token;
    final subscribedSpace = spaceId;
    final headers = Map<String, String>.from(_headers);
    final target = group ? <String,dynamic>{'groupId':targetId}
      : <String,dynamic>{'botId':targetId};
    final streamClient = http.Client();
    int cursor = fromCursor;
    var failures = 0;
    try {
      while (baseUrl == subscribedBase && token == subscribedToken &&
          spaceId == subscribedSpace) {
        try {
          final request = http.Request('POST',
            Uri.parse('$subscribedBase/rpc/threads/subscribe'));
          request.headers.addAll({...headers, 'accept':'text/event-stream'});
          request.body = jsonEncode({'json': {...target, 'cursor':cursor}});
          final response = await streamClient.send(request);
          if (response.statusCode >= 400) {
            throw KakaApiException('Event stream unavailable', response.statusCode);
          }
          failures = 0;
          var frame = StringBuffer();
          await for (final line in response.stream.transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(const Duration(seconds:45))) {
            if (line.length > 262144) {
              throw const KakaApiException('Oversized realtime event');
            }
            if (line.isNotEmpty) {
              if (line.startsWith('data:')) {
                frame.write(line.substring(5).trim());
                if (frame.length > 262144) {
                  throw const KakaApiException('Oversized realtime event');
                }
              }
              continue;
            }
            final data = frame.toString();
            frame = StringBuffer();
            if (data.isEmpty || data == '[DONE]') continue;
            try {
              final decoded = jsonDecode(data);
              if (decoded is! Map || decoded['json'] is! Map) continue;
              final event = KakaThreadEvent(
                Map<String, dynamic>.from(decoded['json'] as Map));
              if (event.type.isEmpty || event.type == 'heartbeat') continue;
              if (event.seq != null && event.seq! <= cursor) continue;
              if (event.seq != null) cursor = event.seq!;
              yield event;
            } on FormatException {
              // Malformed keepalive frame: ignore.
            }
          }
        } catch (error) {
          if (error is KakaApiException && error.status == 401) rethrow;
        }
        failures = (failures + 1).clamp(1, 4);
        await Future<void>.delayed(Duration(seconds: failures * 2));
      }
    } finally {
      streamClient.close();
    }
  }
  void dispose() => _client.close();
}
