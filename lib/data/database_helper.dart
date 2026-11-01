import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/focus_preset.dart';
import '../models/session_log.dart';

class DatabaseHelper {
  static final instance = DatabaseHelper();

  final String databaseName;
  Future<Database>? _opening;
  Future<void>? _closing;

  DatabaseHelper({this.databaseName = 'adaptive_focus.db'});

  Future<Database> get database async {
    if (_closing != null) {
      await _closing;
    }
    if (_opening != null) {
      return _opening!;
    }
    _opening = _openDatabase();
    try {
      return await _opening!;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final path = join(await getDatabasesPath(), databaseName);
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE focus_presets (
            id INTEGER PRIMARY KEY AUTOINCREMENT CHECK(id > 0),
            label TEXT NOT NULL
              CHECK(length(label) BETWEEN 1 AND 40 AND label = trim(label)),
            mood_tag TEXT NOT NULL
              CHECK(mood_tag IN ('Calm', 'Focused', 'Low energy')),
            planned_seconds INTEGER NOT NULL
              CHECK(typeof(planned_seconds) = 'integer'
                AND planned_seconds BETWEEN 60 AND 7200)
          )
        ''');
        await db.execute('''
          CREATE TABLE session_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT CHECK(id > 0),
            preset_id INTEGER NOT NULL
              CHECK(typeof(preset_id) = 'integer' AND preset_id > 0)
              REFERENCES focus_presets(id) ON DELETE RESTRICT,
            started_at_ms INTEGER NOT NULL
              CHECK(typeof(started_at_ms) = 'integer' AND started_at_ms >= 0),
            planned_seconds_snapshot INTEGER NOT NULL
              CHECK(typeof(planned_seconds_snapshot) = 'integer'
                AND planned_seconds_snapshot BETWEEN 60 AND 7200),
            completed_seconds INTEGER NOT NULL
              CHECK(typeof(completed_seconds) = 'integer'
                AND completed_seconds BETWEEN 0 AND 7200),
            mood_tag_snapshot TEXT NOT NULL
              CHECK(mood_tag_snapshot IN ('Calm', 'Focused', 'Low energy')),
            status TEXT NOT NULL CHECK(status IN ('finished', 'cancelled')),
            source TEXT NOT NULL CHECK(source IN ('timer', 'manual', 'edited_timer')),
            note TEXT NOT NULL DEFAULT ''
              CHECK(length(note) <= 240 AND note = trim(note))
          )
        ''');
        await db.execute('''
          CREATE INDEX session_logs_preset_id_idx ON session_logs(preset_id)
        ''');
      },
    );
  }

  Future<int> insertPreset(FocusPreset preset) async {
    if (preset.id != null) {
      throw ArgumentError.value(
        preset.id,
        'id',
        'New presets cannot have an ID.',
      );
    }
    final db = await database;
    return db.insert(
      'focus_presets',
      preset.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<FocusPreset>> getPresets() async {
    final db = await database;
    final rows = await db.query('focus_presets', orderBy: 'id ASC');
    return rows.map((row) => FocusPreset.fromMap(row)).toList();
  }

  Future<FocusPreset?> getPreset(int id) async {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', 'Use a positive saved ID.');
    }
    final db = await database;
    final rows = await db.query(
      'focus_presets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return FocusPreset.fromMap(rows.single);
  }

  Future<int> updatePreset(FocusPreset preset) async {
    final id = preset.id;
    if (id == null) {
      throw ArgumentError('Choose a saved preset to update.');
    }
    final values = preset.toMap();
    values.remove('id');
    final db = await database;
    return db.update('focus_presets', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deletePreset(int id) async {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', 'Use a positive saved ID.');
    }
    final db = await database;
    return db.delete('focus_presets', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> presetHasLogs(int id) async {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', 'Use a positive saved ID.');
    }
    final db = await database;
    final rows = await db.query(
      'session_logs',
      columns: ['id'],
      where: 'preset_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> insertSessionLog(SessionLog log) async {
    if (log.id != null) {
      throw ArgumentError.value(
        log.id,
        'id',
        'New sessions cannot have an ID.',
      );
    }
    if (log.source == 'edited_timer') {
      throw ArgumentError('Only an existing timer session can be corrected.');
    }
    if (log.source == 'manual') {
      final error = SessionLog.validateManualStartedAt(
        log.startedAt,
        now: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      if (error != null) {
        throw ArgumentError.value(log.startedAt, 'startedAt', error);
      }
    }
    final db = await database;
    return db.insert(
      'session_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<SessionLog>> getSessionLogs({String? moodTag}) async {
    if (moodTag != null && FocusPreset.validateMoodTag(moodTag) != null) {
      throw ArgumentError.value(moodTag, 'moodTag', 'Choose a valid mood.');
    }
    final db = await database;
    final rows = await db.query(
      'session_logs',
      where: moodTag == null ? null : 'mood_tag_snapshot = ?',
      whereArgs: moodTag == null ? null : [moodTag],
      orderBy: 'started_at_ms DESC, id DESC',
    );
    return rows.map((row) => SessionLog.fromMap(row)).toList();
  }

  Future<SessionLog?> getSessionLog(int id) async {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', 'Use a positive saved ID.');
    }
    final db = await database;
    final rows = await db.query(
      'session_logs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SessionLog.fromMap(rows.single);
  }

  Future<int> updateSessionLog(SessionLog log) async {
    final id = log.id;
    if (id == null) throw ArgumentError('Choose a saved session to update.');
    final db = await database;
    return db.transaction((transaction) async {
      final rows = await transaction.query(
        'session_logs',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return 0;
      final saved = SessionLog.fromMap(rows.single);
      if (log.presetId != saved.presetId) {
        throw ArgumentError('A saved session must keep its original preset.');
      }
      if (log.plannedSecondsSnapshot != saved.plannedSecondsSnapshot) {
        throw ArgumentError('A saved session must keep its planned duration.');
      }
      if (log.startedAt != saved.startedAt) {
        final error = SessionLog.validateManualStartedAt(
          log.startedAt,
          now: DateTime.now().toUtc().millisecondsSinceEpoch,
        );
        if (error != null) {
          throw ArgumentError.value(log.startedAt, 'startedAt', error);
        }
      }
      final values = log.toMap();
      values.remove('id');
      values['source'] = saved.source == 'manual' ? 'manual' : 'edited_timer';
      return transaction.update(
        'session_logs',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> deleteSessionLog(int id) async {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', 'Use a positive saved ID.');
    }
    final db = await database;
    return db.delete('session_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, Object?>> getSessionSummary({String? moodTag}) async {
    if (moodTag != null && FocusPreset.validateMoodTag(moodTag) != null) {
      throw ArgumentError.value(moodTag, 'moodTag', 'Choose a valid mood.');
    }
    final db = await database;
    final arguments = <Object?>['finished', 0, 7200];
    if (moodTag != null) arguments.add(moodTag);
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS count, AVG(completed_seconds) AS average_seconds
      FROM session_logs
      WHERE status = ? AND typeof(completed_seconds) = 'integer'
        AND completed_seconds BETWEEN ? AND ?
        ${moodTag == null ? '' : 'AND mood_tag_snapshot = ?'}
      ''', arguments);
    final row = rows.single;
    return {
      'count': row['count'] as int,
      'averageSeconds': (row['average_seconds'] as num?)?.toDouble(),
    };
  }

  // The app owner closes after pending work; screens share the connection.
  Future<void> close() async {
    if (_closing != null) {
      await _closing;
      return;
    }
    final opening = _opening;
    if (opening == null) {
      return;
    }
    _closing = _closeDatabase(opening);
    try {
      await _closing;
    } finally {
      _closing = null;
    }
  }

  Future<void> _closeDatabase(Future<Database> opening) async {
    final db = await opening;
    await db.close();
    _opening = null;
  }
}
