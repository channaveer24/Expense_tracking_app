import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

/// 100% on-device SQLite database. No backend, no cloud.
///
/// Both the main app and the lock-screen quick-voice overlay open this same
/// file, so every write is visible to the other on next refresh.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'expenses.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            amount REAL NOT NULL,
            description TEXT NOT NULL,
            category TEXT NOT NULL,
            payment_method TEXT NOT NULL DEFAULT 'UPI',
            type TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
      },
    );
  }

  Future<List<Expense>> all() async {
    final rows = await (await db).query('expenses', orderBy: 'date DESC, id DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<int> insert(Expense e) async => (await db).insert('expenses', e.toMap()..remove('id'));

  Future<void> insertAll(List<Expense> list) async {
    final d = await db;
    await d.transaction((txn) async {
      final batch = txn.batch();
      for (final e in list) {
        batch.insert('expenses', e.toMap()..remove('id'));
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> update(Expense e) async =>
      (await db).update('expenses', e.toMap(), where: 'id = ?', whereArgs: [e.id]);

  Future<void> delete(int id) async => (await db).delete('expenses', where: 'id = ?', whereArgs: [id]);

  Future<void> deleteAll() async => (await db).delete('expenses');

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
