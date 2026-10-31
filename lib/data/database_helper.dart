import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
