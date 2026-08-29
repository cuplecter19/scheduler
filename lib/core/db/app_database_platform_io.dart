import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openPlatformDatabase(
  String fileName, {
  required OpenDatabaseOptions options,
}) async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, fileName);
  return databaseFactory.openDatabase(path, options: options);
}
