import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Per-app totals for a period.
class AppTotals {
  AppTotals(this.pkg, {this.rawM = 0, this.chargedM = 0});
  final String pkg;
  double rawM;
  double chargedM;
}

class GapRow {
  GapRow(this.start, this.end, this.reason, this.chargedM);
  final DateTime start;
  final DateTime end;
  final String reason;
  final double chargedM;
}

/// SQLite persistence. Writes are batched by the controller (every ~5 s or on
/// app switch), never per scroll event.
class Store {
  Store._(this._db);
  final Database _db;

  static Future<Store> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'doomwalk.db'),
      version: 2,
      onUpgrade: (db, from, _) async {
        if (from < 2) await _createWalkDay(db);
      },
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE kv (k TEXT PRIMARY KEY, v TEXT NOT NULL)');
        await db.execute('CREATE TABLE app_day (day TEXT NOT NULL, pkg TEXT NOT NULL, '
            'raw REAL NOT NULL DEFAULT 0, charged REAL NOT NULL DEFAULT 0, PRIMARY KEY(day, pkg))');
        await db.execute('CREATE TABLE gaps (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'start_ms INTEGER NOT NULL, end_ms INTEGER NOT NULL, reason TEXT NOT NULL, charged REAL NOT NULL)');
        await _createWalkDay(db);
      },
    );
    return Store._(db);
  }

  static Future<void> _createWalkDay(Database db) =>
      db.execute('CREATE TABLE walk_day (day TEXT PRIMARY KEY, walked REAL NOT NULL)');

  Future<Map<String, String>> readKv() async {
    final rows = await _db.query('kv');
    return {for (final r in rows) r['k'] as String: r['v'] as String};
  }

  /// One transaction: key/values + per-app deltas.
  Future<void> flush({
    required Map<String, String> kv,
    required Map<(String, String), AppTotals> appDeltas,
    (String, double)? walkedToday,
  }) async {
    final b = _db.batch();
    if (walkedToday != null) {
      b.insert('walk_day', {'day': walkedToday.$1, 'walked': walkedToday.$2},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    kv.forEach((k, v) => b.insert('kv', {'k': k, 'v': v},
        conflictAlgorithm: ConflictAlgorithm.replace));
    appDeltas.forEach((key, t) {
      b.rawInsert(
        'INSERT INTO app_day(day, pkg, raw, charged) VALUES(?,?,?,?) '
        'ON CONFLICT(day, pkg) DO UPDATE SET raw = raw + excluded.raw, '
        'charged = charged + excluded.charged',
        [key.$1, key.$2, t.rawM, t.chargedM],
      );
    });
    await b.commit(noResult: true);
  }

  Future<Map<String, AppTotals>> appTotals({required String fromDay, required String toDay}) async {
    final rows = await _db.rawQuery(
      'SELECT pkg, SUM(raw) r, SUM(charged) c FROM app_day WHERE day >= ? AND day <= ? GROUP BY pkg',
      [fromDay, toDay],
    );
    return {
      for (final r in rows)
        r['pkg'] as String: AppTotals(r['pkg'] as String,
            rawM: (r['r'] as num).toDouble(), chargedM: (r['c'] as num).toDouble()),
    };
  }

  /// Raw metres per day for the last days before [beforeDay], newest first.
  Future<List<double>> dailyRaw({required String beforeDay, int days = 7}) async {
    final rows = await _db.rawQuery(
      'SELECT day, SUM(raw) r FROM app_day WHERE day < ? GROUP BY day ORDER BY day DESC LIMIT ?',
      [beforeDay, days],
    );
    return [for (final r in rows) (r['r'] as num).toDouble()];
  }

  /// Walked metres per day for the [days] days before [beforeDay], newest first.
  Future<List<(String, double)>> walkHistory({required String beforeDay, int days = 30}) async {
    final rows = await _db.query('walk_day',
        where: 'day < ?', whereArgs: [beforeDay], orderBy: 'day DESC', limit: days);
    return [for (final r in rows) (r['day'] as String, (r['walked'] as num).toDouble())];
  }

  Future<void> addGap(GapRow g) => _db.insert('gaps', {
        'start_ms': g.start.millisecondsSinceEpoch,
        'end_ms': g.end.millisecondsSinceEpoch,
        'reason': g.reason,
        'charged': g.chargedM,
      });

  Future<List<GapRow>> recentGaps({int limit = 10}) async {
    final rows = await _db.query('gaps', orderBy: 'start_ms DESC', limit: limit);
    return [
      for (final r in rows)
        GapRow(
          DateTime.fromMillisecondsSinceEpoch(r['start_ms'] as int),
          DateTime.fromMillisecondsSinceEpoch(r['end_ms'] as int),
          r['reason'] as String,
          (r['charged'] as num).toDouble(),
        ),
    ];
  }

  Future<void> close() => _db.close();

  Future<void> wipe() async {
    await _db.delete('kv');
    await _db.delete('app_day');
    await _db.delete('gaps');
    await _db.delete('walk_day');
  }
}
