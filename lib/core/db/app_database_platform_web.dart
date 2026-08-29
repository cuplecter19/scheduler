import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

bool _databaseFactoryInitialized = false;

Future<Database> openPlatformDatabase(
  String fileName, {
  required OpenDatabaseOptions options,
}) async {
  if (!_databaseFactoryInitialized) {
    databaseFactory = databaseFactoryFfiWeb;
    _databaseFactoryInitialized = true;
  }

  return databaseFactory.openDatabase(fileName, options: options);
}
