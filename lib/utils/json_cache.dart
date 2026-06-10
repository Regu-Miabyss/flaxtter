import 'dart:convert';

import 'package:flaxtter/database/repository.dart';
import 'package:sqflite/sqflite.dart';

/// Simple persistent JSON cache backed by SQLite. Used to show previously
/// loaded content instantly instead of refetching on every app start.
Future<void> putJsonCache(String key, Object? value) async {
  try {
    final database = await Repository.writable();
    await database.insert(
      tableJsonCache,
      {
        'key': key,
        'value': jsonEncode(value),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  } catch (_) {
    // Caching is best-effort; never break the caller.
  }
}

Future<dynamic> getJsonCache(String key, {Duration? maxAge}) async {
  try {
    final database = await Repository.readOnly();
    final rows = await database.query(
      tableJsonCache,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    if (maxAge != null) {
      final updatedAt = rows.first['updated_at'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - updatedAt;
      if (age > maxAge.inMilliseconds) {
        return null;
      }
    }
    final value = rows.first['value'] as String?;
    return value == null ? null : jsonDecode(value);
  } catch (_) {
    return null;
  }
}

Future<void> clearJsonCache() async {
  try {
    final database = await Repository.writable();
    await database.delete(tableJsonCache);
  } catch (_) {}
}
