import 'package:flaxtter/database/repository.dart';
import 'package:sqflite/sqflite.dart';

const _maxSearchHistory = 20;

Future<List<String>> getSearchHistory() async {
  final db = await Repository.readOnly();
  final rows = await db.query(
    tableSearchHistory,
    orderBy: 'created_at DESC',
    limit: _maxSearchHistory,
  );
  return rows.map((row) => row['query'] as String).toList();
}

Future<void> addSearchHistory(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return;
  }
  final db = await Repository.writable();
  await db.insert(
    tableSearchHistory,
    {'query': trimmed, 'created_at': DateTime.now().millisecondsSinceEpoch},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  await db.execute(
    'DELETE FROM $tableSearchHistory WHERE query NOT IN '
    '(SELECT query FROM $tableSearchHistory ORDER BY created_at DESC LIMIT $_maxSearchHistory)',
  );
}

Future<void> removeSearchHistory(String query) async {
  final db = await Repository.writable();
  await db.delete(tableSearchHistory, where: 'query = ?', whereArgs: [query]);
}

Future<void> clearSearchHistory() async {
  final db = await Repository.writable();
  await db.delete(tableSearchHistory);
}
