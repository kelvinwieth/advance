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

  void insertMember({
    required String name,
    required int age,
    required String gender,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'INSERT INTO members (name, age, gender) VALUES (?, ?, ?);',
        [name, age, gender],
      );
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void updateMember({
    required int id,
    required String name,
    required int age,
    required String gender,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'UPDATE members SET name = ?, age = ?, gender = ? WHERE id = ?;',
        [name, age, gender, id],
      );
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void insertTask({
    required String name,
    required String? genderConstraint,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'INSERT INTO tasks (name, gender_constraint) VALUES (?, ?);',
        [name, genderConstraint],
      );
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void updateTask({
    required int id,
    required String name,
    required String? genderConstraint,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'UPDATE tasks SET name = ?, gender_constraint = ? WHERE id = ?;',
        [name, genderConstraint, id],
      );
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void clearDatabase() {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute('DELETE FROM member_tasks;');
      _db.execute('DELETE FROM members;');
      _db.execute('DELETE FROM tasks;');
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void insertMockData() {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute('''
INSERT INTO members (name, age, gender) VALUES
  ('Joao Silva', 24, 'M'),
  ('Maria Souza', 22, 'F'),
  ('Pedro Lima', 28, 'M'),
  ('Ana Costa', 26, 'F'),
  ('Lucas Mendes', 21, 'M'),
  ('Beatriz Ramos', 27, 'F'),
  ('Gabriel Rocha', 23, 'M'),
  ('Larissa Almeida', 25, 'F'),
  ('Rafael Oliveira', 29, 'M'),
  ('Juliana Barros', 24, 'F'),
  ('Matheus Ferreira', 20, 'M'),
  ('Carla Nunes', 31, 'F'),
  ('Bruno Cardoso', 27, 'M'),
  ('Paula Pereira', 23, 'F'),
  ('Diego Martins', 26, 'M'),
  ('Fernanda Dias', 28, 'F'),
  ('Tiago Araujo', 30, 'M'),
  ('Camila Teixeira', 22, 'F'),
  ('Henrique Melo', 25, 'M'),
  ('Mariana Pires', 29, 'F'),
  ('Andre Ribeiro', 24, 'M'),
  ('Patricia Sousa', 33, 'F'),
  ('Felipe Santos', 21, 'M'),
  ('Aline Brito', 27, 'F'),
  ('Eduardo Castro', 32, 'M'),
  ('Renata Farias', 26, 'F'),
  ('Vitor Moreira', 23, 'M'),
  ('Isabela Lopes', 24, 'F'),
  ('Leandro Freitas', 28, 'M'),
  ('Tatiana Cunha', 30, 'F');
''');
      _db.execute('''
INSERT INTO tasks (name, gender_constraint) VALUES
  ('Lavar Louca', NULL),
  ('Limpar Salao', NULL),
  ('Preparar Jantar', NULL),
  ('Recepcao', NULL),
  ('Organizar Materiais', NULL),
  ('Som e Midia', 'M'),
  ('Decoracao', 'F'),
  ('Apoio Logistico', NULL);
''');
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}
