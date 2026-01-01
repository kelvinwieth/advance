import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'models.dart';

class AppDatabase {
  final Database _db;

  AppDatabase._(this._db);

  static Future<AppDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'avanco.db');
    final db = sqlite3.open(dbPath);
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA journal_mode = WAL;');
    _migrate(db);
    return AppDatabase._(db);
  }

  static void _migrate(Database db) {
    db.execute('BEGIN');
    try {
      db.execute('''
CREATE TABLE IF NOT EXISTS members (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  age INTEGER NOT NULL CHECK (age > 0),
  gender TEXT NOT NULL CHECK (gender IN ('M', 'F'))
);
''');
      db.execute('''
CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  gender_constraint TEXT NULL CHECK (gender_constraint IN ('M', 'F'))
);
''');
      db.execute('''
CREATE TABLE IF NOT EXISTS member_tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id INTEGER NOT NULL,
  task_id INTEGER NOT NULL,
  date TEXT NOT NULL CHECK (date = date(date)),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (member_id, task_id, date),
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
''');
      db.execute('''
CREATE INDEX IF NOT EXISTS idx_member_tasks_date ON member_tasks(date);
''');
      db.execute('''
CREATE INDEX IF NOT EXISTS idx_member_tasks_task_date ON member_tasks(task_id, date);
''');
      db.execute('''
CREATE INDEX IF NOT EXISTS idx_member_tasks_member_date ON member_tasks(member_id, date);
''');
      db.execute('''
CREATE TRIGGER IF NOT EXISTS member_tasks_gender_check
BEFORE INSERT ON member_tasks
BEGIN
  SELECT
    CASE
      WHEN (
        SELECT gender_constraint FROM tasks WHERE id = NEW.task_id
      ) IS NOT NULL
      AND (
        SELECT gender FROM members WHERE id = NEW.member_id
      ) != (
        SELECT gender_constraint FROM tasks WHERE id = NEW.task_id
      )
      THEN RAISE(ABORT, 'gender constraint mismatch')
    END;
END;
''');
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }

    final memberCount = db.select('SELECT COUNT(*) AS count FROM members;').first['count'] as int;
    final taskCount = db.select('SELECT COUNT(*) AS count FROM tasks;').first['count'] as int;

    if (memberCount == 0 && taskCount == 0) {
      db.execute('BEGIN');
      try {
        db.execute('''
INSERT INTO members (name, age, gender) VALUES
  ('Lucas', 20, 'M'),
  ('Mateus', 30, 'M'),
  ('Bia', 23, 'F'),
  ('Joao', 25, 'M');
''');
        db.execute('''
INSERT INTO tasks (name, gender_constraint) VALUES
  ('Lavar Louca', NULL),
  ('Limpar Salao', NULL),
  ('Preparar Jantar', NULL);
''');
        db.execute('COMMIT');
      } catch (e) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
  }

  List<Member> fetchMembers() {
    final result = _db.select('SELECT id, name, age, gender FROM members ORDER BY name;');
    return result.map((row) => Member.fromRow(row)).toList();
  }

  List<Task> fetchTasks() {
    final result = _db.select('SELECT id, name, gender_constraint FROM tasks ORDER BY id;');
    return result.map((row) => Task.fromRow(row)).toList();
  }

  Map<int, List<TaskAssignment>> fetchAssignmentsByTaskForDate(String isoDate) {
    final result = _db.select('''
SELECT
  mt.id AS assignment_id,
  mt.task_id AS task_id,
  m.id AS member_id,
  m.name AS member_name,
  m.age AS member_age,
  m.gender AS member_gender
FROM member_tasks mt
JOIN members m ON m.id = mt.member_id
WHERE mt.date = ?
ORDER BY m.name;
''', [isoDate]);

    final Map<int, List<TaskAssignment>> grouped = {};
    for (final row in result) {
      final assignment = TaskAssignment.fromRow(row);
      grouped.putIfAbsent(assignment.taskId, () => []).add(assignment);
    }
    return grouped;
  }

  void assignMemberToTask({
    required int memberId,
    required int taskId,
    required String isoDate,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'INSERT INTO member_tasks (member_id, task_id, date) VALUES (?, ?, ?);',
        [memberId, taskId, isoDate],
      );
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}
