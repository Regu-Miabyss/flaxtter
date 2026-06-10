import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String tableAccounts = 'accounts';
const String tableSearchHistory = 'search_history';
const String tableJsonCache = 'json_cache';

class Repository {
  static Database? _database;

  static Future<Database> readOnly() async {
    return _getDatabase();
  }

  static Future<Database> writable() async {
    return _getDatabase();
  }

  static Future<Database> _getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final String dbPath;
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      final dir = await getApplicationSupportDirectory();
      dbPath = join(dir.path, 'flaxtter.db');
    } else {
      dbPath = join(await getDatabasesPath(), 'flaxtter.db');
    }

    _database = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS $tableAccounts (id TEXT PRIMARY KEY, screen_name TEXT, auth_header VARCHAR)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS $tableSearchHistory (query TEXT PRIMARY KEY, created_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS $tableJsonCache (key TEXT PRIMARY KEY, value TEXT, updated_at INTEGER)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS $tableSearchHistory (query TEXT PRIMARY KEY, created_at INTEGER)',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS $tableJsonCache (key TEXT PRIMARY KEY, value TEXT, updated_at INTEGER)',
          );
        }
      },
    );
    return _database!;
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
