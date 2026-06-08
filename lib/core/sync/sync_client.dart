import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sync_change.dart';

class AuthSession {
  const AuthSession({required this.token, required this.email});

  final String token;
  final String email;
}

class SyncPullResult {
  const SyncPullResult({required this.changes, required this.serverTime});

  final List<SyncChange> changes;
  final DateTime serverTime;
}

class SyncClient {
  SyncClient({required this.baseUrl, http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Uri _uri(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Future<AuthSession> register(String email, String password) async {
    return _auth('/auth/register', email, password);
  }

  Future<AuthSession> login(String email, String password) async {
    return _auth('/auth/login', email, password);
  }

  Future<AuthSession> _auth(String path, String email, String password) async {
    final response = await _http.post(
      _uri(path),
      headers: const <String, String>{'content-type': 'application/json'},
      body: jsonEncode(<String, String>{'email': email, 'password': password}),
    );
    if (response.statusCode >= 400) {
      throw SyncException('인증 실패: ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, Object?>;
    return AuthSession(token: body['access_token'] as String, email: email);
  }

  Future<SyncPullResult> pull({required String token, DateTime? since}) async {
    final uri = since == null ? _uri('/sync') : _uri('/sync').replace(queryParameters: <String, String>{'since': since.toUtc().toIso8601String()});
    final response = await _http.get(uri, headers: _headers(token));
    if (response.statusCode >= 400) {
      throw SyncException('동기화 내려받기 실패: ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final changes = (body['changes'] as List<dynamic>? ?? <dynamic>[])
        .map((item) => SyncChange.fromJson(Map<String, Object?>.from(item as Map)))
        .toList();
    return SyncPullResult(
      changes: changes,
      serverTime: DateTime.parse(body['server_time'] as String).toLocal(),
    );
  }

  Future<DateTime> push({required String token, required List<Map<String, Object?>> changes}) async {
    final response = await _http.post(
      _uri('/sync'),
      headers: _headers(token),
      body: jsonEncode(<String, Object?>{'changes': changes}),
    );
    if (response.statusCode >= 400) {
      throw SyncException('동기화 업로드 실패: ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, Object?>;
    return DateTime.parse(body['server_time'] as String).toLocal();
  }

  Map<String, String> _headers(String token) => <String, String>{
        'content-type': 'application/json',
        'authorization': 'Bearer ' + token,
      };
}

class SyncException implements Exception {
  const SyncException(this.message);
  final String message;
  @override
  String toString() => message;
}
