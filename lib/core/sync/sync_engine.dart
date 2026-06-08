import 'dart:async';

import '../db/app_database.dart';
import 'sync_client.dart';

class SyncEngine {
  SyncEngine({required AppDatabase database}) : _database = database;

  static const _serverUrlKey = 'server_url';
  static const _tokenKey = 'auth_token';
  static const _emailKey = 'auth_email';
  static const _lastSyncKey = 'last_sync_at';

  final AppDatabase _database;
  bool _isSyncing = false;

  Future<String> get serverUrl async => await _database.getSetting(_serverUrlKey) ?? '';
  Future<String?> get email async => _database.getSetting(_emailKey);
  Future<DateTime?> get lastSyncAt async {
    final value = await _database.getSetting(_lastSyncKey);
    return value == null ? null : DateTime.parse(value).toLocal();
  }

  Future<void> setServerUrl(String url) async => _database.setSetting(_serverUrlKey, url.trim());

  Future<void> register(String email, String password) async {
    final url = await serverUrl;
    if (url.isEmpty) throw const SyncException('서버 URL을 먼저 설정하세요.');
    final client = SyncClient(baseUrl: url);
    final session = await client.register(email, password);
    await _saveSession(session);
  }

  Future<void> login(String email, String password) async {
    final url = await serverUrl;
    if (url.isEmpty) throw const SyncException('서버 URL을 먼저 설정하세요.');
    final client = SyncClient(baseUrl: url);
    final session = await client.login(email, password);
    await _saveSession(session);
  }

  Future<void> _saveSession(AuthSession session) async {
    await _database.setSetting(_tokenKey, session.token);
    await _database.setSetting(_emailKey, session.email);
  }

  Future<String> syncNow() async {
    if (_isSyncing) return '이미 동기화 중입니다.';
    _isSyncing = true;
    try {
      final token = await _database.getSetting(_tokenKey);
      if (token == null || token.isEmpty) return '로그인이 필요합니다.';
      final url = await serverUrl;
      if (url.isEmpty) return '서버 URL을 먼저 설정하세요.';
      final client = SyncClient(baseUrl: url);
      final since = await lastSyncAt;
      final changes = await _database.getChangedRows(since);
      final pushedAt = await client.push(token: token, changes: changes);
      final pullResult = await client.pull(token: token, since: since);
      await _database.applyRemoteChanges(pullResult.changes);
      final serverTime = pullResult.serverTime.isAfter(pushedAt) ? pullResult.serverTime : pushedAt;
      await _database.setSetting(_lastSyncKey, serverTime.toUtc().toIso8601String());
      return '동기화 완료 (${changes.length}개 업로드, ${pullResult.changes.length}개 다운로드)';
    } finally {
      _isSyncing = false;
    }
  }
}
