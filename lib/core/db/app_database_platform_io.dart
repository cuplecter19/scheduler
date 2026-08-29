import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final DatabaseFactory _databaseFactory = _createDatabaseFactory();

Future<Database> openPlatformDatabase(
  String fileName, {
  required OpenDatabaseOptions options,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, fileName);
  return _databaseFactory.openDatabase(path, options: options);
}

DatabaseFactory _createDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }

  return sqflite.databaseFactory;
}
