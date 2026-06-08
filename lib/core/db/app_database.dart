import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/scheduled_task.dart';
import '../models/sync_change.dart';
import '../models/time_block.dart';

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static Future<AppDatabase> open() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'structured_clone.db');
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tasks(
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              due_date TEXT,
              priority TEXT NOT NULL,
              tags TEXT NOT NULL DEFAULT '',
              is_completed INTEGER NOT NULL DEFAULT 0,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL,
              device_id TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE time_blocks(
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              task_id TEXT,
              note TEXT NOT NULL DEFAULT '',
              start_at TEXT NOT NULL,
              end_at TEXT NOT NULL,
              color_hex TEXT NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL,
              device_id TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE settings(
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    return AppDatabase._(db);
  }

  Future<List<ScheduledTask>> getTasks({bool includeDeleted = false}) async {
    final rows = await _db.query(
      'tasks',
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'is_completed ASC, due_date IS NULL ASC, due_date ASC, updated_at DESC',
    );
    return rows.map(ScheduledTask.fromMap).toList();
  }

  Future<void> upsertTask(ScheduledTask task) async {
    await _db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTask(ScheduledTask task) async {
    await upsertTask(task.copyWith(isDeleted: true, updatedAt: DateTime.now()));
  }

  Future<List<TimeBlock>> getTimeBlocks({bool includeDeleted = false}) async {
    final rows = await _db.query(
      'time_blocks',
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'start_at ASC',
    );
    return rows.map(TimeBlock.fromMap).toList();
  }

  Future<void> upsertTimeBlock(TimeBlock block) async {
    await _db.insert(
      'time_blocks',
      block.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTimeBlock(TimeBlock block) async {
    await upsertTimeBlock(block.copyWith(isDeleted: true, updatedAt: DateTime.now()));
  }

  Future<List<Map<String, Object?>>> getChangedRows(DateTime? since) async {
    final sinceIso = since?.toUtc().toIso8601String();
    final where = sinceIso == null ? null : 'updated_at > ?';
    final whereArgs = sinceIso == null ? null : <Object>[sinceIso];
    final tasks = await _db.query('tasks', where: where, whereArgs: whereArgs);
    final blocks = await _db.query('time_blocks', where: where, whereArgs: whereArgs);
    return <Map<String, Object?>>[
      ...tasks.map((row) => ScheduledTask.fromMap(row).toSyncJson()),
      ...blocks.map((row) => TimeBlock.fromMap(row).toSyncJson()),
    ];
  }

  Future<void> applyRemoteChanges(List<SyncChange> changes) async {
    await _db.transaction((txn) async {
      for (final change in changes) {
        if (change.type == 'task') {
          final local = await txn.query('tasks', where: 'id = ?', whereArgs: <Object>[change.id], limit: 1);
          final localUpdated = local.isEmpty ? null : DateTime.parse(local.first['updated_at'] as String);
          if (localUpdated == null || change.updatedAt.toUtc().isAfter(localUpdated.toUtc())) {
            await txn.insert('tasks', change.data, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        } else if (change.type == 'time_block') {
          final local = await txn.query('time_blocks', where: 'id = ?', whereArgs: <Object>[change.id], limit: 1);
          final localUpdated = local.isEmpty ? null : DateTime.parse(local.first['updated_at'] as String);
          if (localUpdated == null || change.updatedAt.toUtc().isAfter(localUpdated.toUtc())) {
            await txn.insert('time_blocks', change.data, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    });
  }

  Future<String?> getSetting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: <Object>[key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    await _db.insert(
      'settings',
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
