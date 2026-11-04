import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

/// 100% on-device SQLite database. No backend, no cloud.
///
/// The main app and the lock-screen quick-voice overlay run in two separate
/// Flutter engines inside the same Android process. sqflite shares one
/// native connection per path by default, so when the overlay closed "its"
/// database it silently closed the main app's connection too and every
/// later save failed. Each engine therefore opens its own connection
/// (`singleInstance: false`), and every call reopens and retries once if
/// it finds the connection closed anyway.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get db async {
    final d = _db;
    if (d != null && d.isOpen) return d;
    return _opening ??= _open().then((v) {
      _db = v;
      _opening = null;
      return v;
    }, onError: (Object e) {
      _opening = null;
      throw e;
    });
  }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'expenses.db');
    return openDatabase(
      path,
      version: 1,
      singleInstance: false,
      onConfigure: (db) async {
        // Wait instead of failing if the other engine is mid-write.
        await db.rawQuery('PRAGMA busy_timeout = 5000');
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            amount REAL NOT NULL,
            description TEXT NOT NULL,
            category TEXT NOT NULL,
            payment_method TEXT NOT NULL DEFAULT 'UPI',
            type TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)');
      },
    );
  }

  /// Runs [op], and if the connection turned out to be closed, reopens it
  /// and tries once more.
  Future<T> _run<T>(Future<T> Function(Database db) op) async {
    try {
      return await op(await db);
    } on DatabaseException catch (e) {
      if (!e.isDatabaseClosedError() && !e.toString().toLowerCase().contains('closed')) rethrow;
    } on StateError {
      // "database_closed" can surface as a StateError on some versions.
    }
    _db = null;
    return op(await db);
  }

  Future<List<Expense>> all() => _run((d) async {
        final rows = await d.query('expenses', orderBy: 'date DESC, id DESC');
        return rows.map(Expense.fromMap).toList();
      });

  Future<int> insert(Expense e) => _run((d) => d.insert('expenses', e.toMap()..remove('id')));

  Future<void> insertAll(List<Expense> list) => _run((d) => d.transaction((txn) async {
        for (final e in list) {
          await txn.insert('expenses', e.toMap()..remove('id'));
        }
      }));

  Future<void> update(Expense e) =>
      _run((d) => d.update('expenses', e.toMap(), where: 'id = ?', whereArgs: [e.id]));

  Future<void> delete(int id) => _run((d) => d.delete('expenses', where: 'id = ?', whereArgs: [id]));

  Future<void> deleteAll() => _run((d) => d.delete('expenses'));

  Future<void> close() async {
    final d = _db;
    _db = null;
    if (d != null && d.isOpen) await d.close();
  }
}
