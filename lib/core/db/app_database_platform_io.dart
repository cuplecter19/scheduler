import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DatabaseFactory? _databaseFactory;

Future<Database> openPlatformDatabase(
  String fileName, {
  required OpenDatabaseOptions options,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, fileName);
  return _resolveDatabaseFactory().openDatabase(path, options: options);
}

DatabaseFactory _resolveDatabaseFactory() {
  final existingFactory = _databaseFactory;
  if (existingFactory != null) {
    return existingFactory;
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    return _databaseFactory = databaseFactoryFfi;
  }

  return _databaseFactory = sqflite.databaseFactory;
}
