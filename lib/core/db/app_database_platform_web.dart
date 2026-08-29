import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<Database> openPlatformDatabase(
  String fileName, {
  required OpenDatabaseOptions options,
}) async {
  databaseFactory = databaseFactoryFfiWeb;
  return databaseFactory.openDatabase(fileName, options: options);
}
