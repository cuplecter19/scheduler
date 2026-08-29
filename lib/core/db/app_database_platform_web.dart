import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

DatabaseFactory? _databaseFactory;

Future<Database> openPlatformDatabase(
  String fileName, {
  required OpenDatabaseOptions options,
}) async {
  return (_databaseFactory ??= databaseFactoryFfiWeb).openDatabase(
    fileName,
    options: options,
  );
}
