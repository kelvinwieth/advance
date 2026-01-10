import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'models.dart';

class AppDatabase {
  Database _db;
  final String _dbPath;
  bool _closed = false;

  AppDatabase._(this._db, this._dbPath);

  static Future<AppDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'avanco.db');
    final db = sqlite3.open(dbPath);
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA busy_timeout = 2000;');
    try {
      db.execute('PRAGMA journal_mode = WAL;');
    } catch (_) {
      // Ignore if another connection is still releasing the lock.
    }
    _migrate(db);
    return AppDatabase._(db, dbPath);
  }

  String _formatDateTime(DateTime value) {
    final iso = value.toIso8601String().replaceFirst('T', ' ');
    return iso.split('.').first;
  }

  String get dbPath => _dbPath;

  void close() {
    if (_closed) return;
    _closed = true;
    try {
      _db.dispose();
    } catch (_) {}
  }

  Future<void> importDatabase(String sourcePath) async {
    final dbPath = _dbPath;
    _db.dispose();
    await Isolate.run(() {
      _copyDatabaseFiles(sourcePath, dbPath);
    });
    _db = sqlite3.open(_dbPath);
    _db.execute('PRAGMA foreign_keys = ON;');
    _db.execute('PRAGMA busy_timeout = 2000;');
    try {
      _db.execute('PRAGMA journal_mode = WAL;');
    } catch (_) {
      // Ignore if another connection is still releasing the lock.
    }
    _migrate(_db);
  }

  Future<({int inserted, int skipped})> importVisitFormsFromCsv(
    String csvContent, {
    Map<String, String>? headerOverrides,
  }) async {
    final dbPath = _dbPath;
    _db.dispose();
    final result = await Isolate.run(() {
      return _importVisitFormsCsv(csvContent, dbPath, headerOverrides);
    });
    _db = sqlite3.open(dbPath);
    _db.execute('PRAGMA foreign_keys = ON;');
    _db.execute('PRAGMA busy_timeout = 2000;');
    try {
      _db.execute('PRAGMA journal_mode = WAL;');
    } catch (_) {
      // Ignore if another connection is still releasing the lock.
    }
    _migrate(_db);
    return result;
  }

  static void _migrate(Database db) {
    db.execute('BEGIN');
    try {
      db.execute('''
CREATE TABLE IF NOT EXISTS members (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  age INTEGER NOT NULL CHECK (age > 0),
  gender TEXT NOT NULL CHECK (gender IN ('M', 'F')),
  church TEXT NOT NULL CHECK (length(church) > 0)
);
''');
      db.execute('''
CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  gender_constraint TEXT NULL CHECK (gender_constraint IN ('M', 'F')),
  max_members INTEGER NULL CHECK (max_members IS NULL OR max_members > 0)
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
CREATE TABLE IF NOT EXISTS visit_forms (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  visit_at TEXT NOT NULL CHECK (visit_at = datetime(visit_at)),
  names TEXT NOT NULL,
  address TEXT NOT NULL,
  reference_point TEXT NOT NULL,
  neighborhood TEXT NOT NULL,
  city TEXT NOT NULL,
  contacts TEXT NOT NULL,
  literature_count INTEGER NOT NULL DEFAULT 0 CHECK (literature_count >= 0),
  result_evangelho INTEGER NOT NULL DEFAULT 0 CHECK (result_evangelho IN (0, 1)),
  result_ponte_salvacao INTEGER NOT NULL DEFAULT 0 CHECK (result_ponte_salvacao IN (0, 1)),
  result_aceitou_jesus INTEGER NOT NULL DEFAULT 0 CHECK (result_aceitou_jesus IN (0, 1)),
  result_reconciliacao INTEGER NOT NULL DEFAULT 0 CHECK (result_reconciliacao IN (0, 1)),
  result_primeira_vez INTEGER NOT NULL DEFAULT 0 CHECK (result_primeira_vez IN (0, 1)),
  result_nova_visita INTEGER NOT NULL DEFAULT 0 CHECK (result_nova_visita IN (0, 1)),
  age_children INTEGER NOT NULL DEFAULT 0 CHECK (age_children >= 0),
  age_youth INTEGER NOT NULL DEFAULT 0 CHECK (age_youth >= 0),
  age_adults INTEGER NOT NULL DEFAULT 0 CHECK (age_adults >= 0),
  age_elderly INTEGER NOT NULL DEFAULT 0 CHECK (age_elderly >= 0),
  religion_catolica INTEGER NOT NULL DEFAULT 0 CHECK (religion_catolica IN (0, 1)),
  religion_espirita INTEGER NOT NULL DEFAULT 0 CHECK (religion_espirita IN (0, 1)),
  religion_ateu INTEGER NOT NULL DEFAULT 0 CHECK (religion_ateu IN (0, 1)),
  religion_desviado INTEGER NOT NULL DEFAULT 0 CHECK (religion_desviado IN (0, 1)),
  religion_outros INTEGER NOT NULL DEFAULT 0 CHECK (religion_outros IN (0, 1)),
  religion_all_label TEXT NULL CHECK (
    religion_all_label IN ('catolica', 'espirita', 'ateu', 'desviado', 'outros')
  ),
  notes TEXT NOT NULL,
  prayer_requests TEXT NOT NULL,
  team TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
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
CREATE INDEX IF NOT EXISTS idx_visit_forms_visit_at ON visit_forms(visit_at);
''');
      db.execute('''
CREATE INDEX IF NOT EXISTS idx_visit_forms_city ON visit_forms(city);
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
      final columns = db.select('PRAGMA table_info(members);');
      final hasChurch = columns.any((row) => row['name'] == 'church');
      if (!hasChurch) {
        db.execute(
          'ALTER TABLE members ADD COLUMN church TEXT NOT NULL DEFAULT "";',
        );
      }
      final visitColumns = db.select('PRAGMA table_info(visit_forms);');
      final hasLiterature = visitColumns.any(
        (row) => row['name'] == 'literature_count',
      );
      if (!hasLiterature) {
        db.execute(
          'ALTER TABLE visit_forms ADD COLUMN literature_count INTEGER NOT NULL DEFAULT 0;',
        );
      }
      final taskColumns = db.select('PRAGMA table_info(tasks);');
      final hasMaxMembers = taskColumns.any(
        (row) => row['name'] == 'max_members',
      );
      if (!hasMaxMembers) {
        db.execute(
          'ALTER TABLE tasks ADD COLUMN max_members INTEGER NULL;',
        );
      }
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<Member> fetchMembers() {
    final result = _db.select(
      'SELECT id, name, age, gender, church FROM members ORDER BY name;',
    );
    return result.map((row) => Member.fromRow(row)).toList();
  }

  List<Task> fetchTasks() {
    final result = _db.select(
      'SELECT id, name, gender_constraint, max_members FROM tasks ORDER BY id;',
    );
    return result.map((row) => Task.fromRow(row)).toList();
  }

  Map<int, List<TaskAssignment>> fetchAssignmentsByTaskForDate(String isoDate) {
    final result = _db.select(
      '''
SELECT
  mt.id AS assignment_id,
  mt.task_id AS task_id,
  m.id AS member_id,
  m.name AS member_name,
  m.age AS member_age,
  m.gender AS member_gender,
  m.church AS member_church
FROM member_tasks mt
JOIN members m ON m.id = mt.member_id
WHERE mt.date = ?
ORDER BY m.name;
''',
      [isoDate],
    );

    final Map<int, List<TaskAssignment>> grouped = {};
    for (final row in result) {
      final assignment = TaskAssignment.fromRow(row);
      grouped.putIfAbsent(assignment.taskId, () => []).add(assignment);
    }
    return grouped;
  }

  Map<int, int> fetchTaskCountsUpTo(String isoDate) {
    final result = _db.select(
      '''
SELECT member_id, COUNT(*) AS total
FROM member_tasks
WHERE date <= ?
GROUP BY member_id;
''',
      [isoDate],
    );
    final counts = <int, int>{};
    for (final row in result) {
      counts[row['member_id'] as int] = row['total'] as int;
    }
    return counts;
  }

  List<VisitForm> fetchVisitForms() {
    final result = _db.select('''
SELECT
  id,
  visit_at,
  names,
  address,
  reference_point,
  neighborhood,
  city,
  contacts,
  literature_count,
  result_evangelho,
  result_ponte_salvacao,
  result_aceitou_jesus,
  result_reconciliacao,
  result_primeira_vez,
  result_nova_visita,
  age_children,
  age_youth,
  age_adults,
  age_elderly,
  religion_catolica,
  religion_espirita,
  religion_ateu,
  religion_desviado,
  religion_outros,
  religion_all_label,
  notes,
  prayer_requests,
  team
FROM visit_forms
ORDER BY visit_at DESC, id DESC;
''');
    return result.map((row) => VisitForm.fromRow(row)).toList();
  }

  void insertVisitForm({
    required DateTime visitAt,
    required String names,
    required String address,
    required String referencePoint,
    required String neighborhood,
    required String city,
    required String contacts,
    required int literatureCount,
    required bool resultEvangelho,
    required bool resultPonteSalvacao,
    required bool resultAceitouJesus,
    required bool resultReconciliacao,
    required bool resultPrimeiraVez,
    required bool resultNovaVisita,
    required int ageChildren,
    required int ageYouth,
    required int ageAdults,
    required int ageElderly,
    required bool religionCatolica,
    required bool religionEspirita,
    required bool religionAteu,
    required bool religionDesviado,
    required bool religionOutros,
    required String notes,
    required String prayerRequests,
    required String team,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
INSERT INTO visit_forms (
  visit_at,
  names,
  address,
  reference_point,
  neighborhood,
  city,
  contacts,
  literature_count,
  result_evangelho,
  result_ponte_salvacao,
  result_aceitou_jesus,
  result_reconciliacao,
  result_primeira_vez,
  result_nova_visita,
  age_children,
  age_youth,
  age_adults,
  age_elderly,
  religion_catolica,
  religion_espirita,
  religion_ateu,
  religion_desviado,
  religion_outros,
  religion_all_label,
  notes,
  prayer_requests,
  team
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
''',
        [
          _formatDateTime(visitAt),
          names,
          address,
          referencePoint,
          neighborhood,
          city,
          contacts,
          literatureCount,
          resultEvangelho ? 1 : 0,
          resultPonteSalvacao ? 1 : 0,
          resultAceitouJesus ? 1 : 0,
          resultReconciliacao ? 1 : 0,
          resultPrimeiraVez ? 1 : 0,
          resultNovaVisita ? 1 : 0,
          ageChildren,
          ageYouth,
          ageAdults,
          ageElderly,
          religionCatolica ? 1 : 0,
          religionEspirita ? 1 : 0,
          religionAteu ? 1 : 0,
          religionDesviado ? 1 : 0,
          religionOutros ? 1 : 0,
          null,
          notes,
          prayerRequests,
          team,
        ],
      );
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void updateVisitForm({
    required int id,
    required DateTime visitAt,
    required String names,
    required String address,
    required String referencePoint,
    required String neighborhood,
    required String city,
    required String contacts,
    required int literatureCount,
    required bool resultEvangelho,
    required bool resultPonteSalvacao,
    required bool resultAceitouJesus,
    required bool resultReconciliacao,
    required bool resultPrimeiraVez,
    required bool resultNovaVisita,
    required int ageChildren,
    required int ageYouth,
    required int ageAdults,
    required int ageElderly,
    required bool religionCatolica,
    required bool religionEspirita,
    required bool religionAteu,
    required bool religionDesviado,
    required bool religionOutros,
    required String notes,
    required String prayerRequests,
    required String team,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
UPDATE visit_forms
SET
  visit_at = ?,
  names = ?,
  address = ?,
  reference_point = ?,
  neighborhood = ?,
  city = ?,
  contacts = ?,
  literature_count = ?,
  result_evangelho = ?,
  result_ponte_salvacao = ?,
  result_aceitou_jesus = ?,
  result_reconciliacao = ?,
  result_primeira_vez = ?,
  result_nova_visita = ?,
  age_children = ?,
  age_youth = ?,
  age_adults = ?,
  age_elderly = ?,
  religion_catolica = ?,
  religion_espirita = ?,
  religion_ateu = ?,
  religion_desviado = ?,
  religion_outros = ?,
  religion_all_label = ?,
  notes = ?,
  prayer_requests = ?,
  team = ?
WHERE id = ?;
''',
        [
          _formatDateTime(visitAt),
          names,
          address,
          referencePoint,
          neighborhood,
          city,
          contacts,
          literatureCount,
          resultEvangelho ? 1 : 0,
          resultPonteSalvacao ? 1 : 0,
          resultAceitouJesus ? 1 : 0,
          resultReconciliacao ? 1 : 0,
          resultPrimeiraVez ? 1 : 0,
          resultNovaVisita ? 1 : 0,
          ageChildren,
          ageYouth,
          ageAdults,
          ageElderly,
          religionCatolica ? 1 : 0,
          religionEspirita ? 1 : 0,
          religionAteu ? 1 : 0,
          religionDesviado ? 1 : 0,
          religionOutros ? 1 : 0,
          null,
          notes,
          prayerRequests,
          team,
          id,
        ],
      );
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void deleteVisitForm(int id) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute('DELETE FROM visit_forms WHERE id = ?;', [id]);
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  VisitAnalytics fetchVisitAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final args = <Object?>[];
    var whereClause = '';
    if (startDate != null || endDate != null) {
      final start = startDate ?? endDate!;
      final end = endDate ?? startDate!;
      whereClause =
          'WHERE date(visit_at) >= date(?) AND date(visit_at) <= date(?)';
      args.add(_dateOnly(start));
      args.add(_dateOnly(end));
    }
    final result = _db.select('''
SELECT
  COUNT(*) AS total_visits,
  COALESCE(COUNT(DISTINCT CASE WHEN trim(neighborhood) != '' THEN neighborhood END), 0)
    AS total_neighborhoods,
  COALESCE(SUM(literature_count), 0) AS total_literature,
  COALESCE(SUM(result_evangelho), 0) AS total_evangelho,
  COALESCE(SUM(result_ponte_salvacao), 0) AS total_ponte,
  COALESCE(SUM(result_aceitou_jesus), 0) AS total_aceitou,
  COALESCE(SUM(result_reconciliacao), 0) AS total_reconciliacao,
  COALESCE(SUM(result_primeira_vez), 0) AS total_primeira_vez,
  COALESCE(SUM(result_nova_visita), 0) AS total_nova,
  COALESCE(SUM(age_children), 0) AS age_children,
  COALESCE(SUM(age_youth), 0) AS age_youth,
  COALESCE(SUM(age_adults), 0) AS age_adults,
  COALESCE(SUM(age_elderly), 0) AS age_elderly
FROM visit_forms
$whereClause;
''', args);
    final row = result.first;
    final ageChildren = row['age_children'] as int;
    final ageYouth = row['age_youth'] as int;
    final ageAdults = row['age_adults'] as int;
    final ageElderly = row['age_elderly'] as int;
    final totalPeople = ageChildren + ageYouth + ageAdults + ageElderly;

    return VisitAnalytics(
      totalVisits: row['total_visits'] as int,
      totalPeople: totalPeople,
      totalNeighborhoods: row['total_neighborhoods'] as int,
      totalLiterature: row['total_literature'] as int,
      totalEvangelho: row['total_evangelho'] as int,
      totalPonteSalvacao: row['total_ponte'] as int,
      totalAceitouJesus: row['total_aceitou'] as int,
      totalReconciliacao: row['total_reconciliacao'] as int,
      totalPrimeiraVez: row['total_primeira_vez'] as int,
      totalNovaVisita: row['total_nova'] as int,
      ageChildren: ageChildren,
      ageYouth: ageYouth,
      ageAdults: ageAdults,
      ageElderly: ageElderly,
    );
  }

  List<VisitNeighborhoodCount> fetchVisitNeighborhoodCounts({
    int limit = 6,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final args = <Object?>[];
    var dateClause = '';
    if (startDate != null || endDate != null) {
      final start = startDate ?? endDate!;
      final end = endDate ?? startDate!;
      dateClause =
          'AND date(visit_at) >= date(?) AND date(visit_at) <= date(?)';
      args.add(_dateOnly(start));
      args.add(_dateOnly(end));
    }
    final result = _db.select(
      '''
SELECT neighborhood, COUNT(*) AS total
FROM visit_forms
WHERE neighborhood IS NOT NULL AND trim(neighborhood) != ''
$dateClause
GROUP BY neighborhood
ORDER BY total DESC, neighborhood ASC
LIMIT ?;
''',
      [...args, limit],
    );
    return result
        .map(
          (row) => VisitNeighborhoodCount(
            neighborhood: row['neighborhood'] as String,
            total: row['total'] as int,
          ),
        )
        .toList();
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

  void assignMembersToTasksBulk({
    required String isoDate,
    required List<List<int>> assignments,
  }) {
    if (assignments.isEmpty) return;
    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final assignment in assignments) {
        _db.execute(
          'INSERT OR IGNORE INTO member_tasks (member_id, task_id, date) VALUES (?, ?, ?);',
          [assignment[0], assignment[1], isoDate],
        );
      }
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
    required String church,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'INSERT INTO members (name, age, gender, church) VALUES (?, ?, ?, ?);',
        [name, age, gender, church],
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
    required String church,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'UPDATE members SET name = ?, age = ?, gender = ?, church = ? WHERE id = ?;',
        [name, age, gender, church, id],
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
    required int? maxMembers,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'INSERT INTO tasks (name, gender_constraint, max_members) VALUES (?, ?, ?);',
        [name, genderConstraint, maxMembers],
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
    required int? maxMembers,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'UPDATE tasks SET name = ?, gender_constraint = ?, max_members = ? WHERE id = ?;',
        [name, genderConstraint, maxMembers, id],
      );
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void deleteTask(int id) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'DELETE FROM member_tasks WHERE task_id = ?;',
        [id],
      );
      _db.execute(
        'DELETE FROM tasks WHERE id = ?;',
        [id],
      );
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void deleteMember(int id) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'DELETE FROM member_tasks WHERE member_id = ?;',
        [id],
      );
      _db.execute(
        'DELETE FROM members WHERE id = ?;',
        [id],
      );
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void replaceMembers(List<Map<String, Object?>> members) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute('DELETE FROM member_tasks;');
      _db.execute('DELETE FROM members;');
      for (final member in members) {
        _db.execute(
          'INSERT INTO members (name, age, gender, church) VALUES (?, ?, ?, ?);',
          [
            member['name'],
            member['age'],
            member['gender'],
            member['church'],
          ],
        );
      }
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> clearDatabase() async {
    final dbPath = _dbPath;
    _db.dispose();
    await Isolate.run(() {
      final db = sqlite3.open(dbPath);
      db.execute('PRAGMA foreign_keys = ON;');
      db.execute('PRAGMA busy_timeout = 5000;');
      const maxAttempts = 5;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        db.execute('BEGIN EXCLUSIVE;');
        try {
          db.execute('DELETE FROM member_tasks;');
          db.execute('DELETE FROM members;');
          db.execute('DELETE FROM tasks;');
          db.execute('DELETE FROM visit_forms;');
          db.execute('COMMIT;');
          db.dispose();
          return;
        } catch (e) {
          try {
            db.execute('ROLLBACK;');
          } catch (_) {}
          if (attempt == maxAttempts - 1) {
            db.dispose();
            rethrow;
          }
          sleep(const Duration(milliseconds: 250));
        }
      }
    });
    _db = sqlite3.open(dbPath);
    _db.execute('PRAGMA foreign_keys = ON;');
    _db.execute('PRAGMA busy_timeout = 2000;');
    try {
      _db.execute('PRAGMA journal_mode = WAL;');
    } catch (_) {
      // Ignore if another connection is still releasing the lock.
    }
    _migrate(_db);
  }

  void removeAssignment({
    required int memberId,
    required int taskId,
    required String isoDate,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'DELETE FROM member_tasks WHERE member_id = ? AND task_id = ? AND date = ?;',
        [memberId, taskId, isoDate],
      );
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void moveAssignment({
    required int memberId,
    required int fromTaskId,
    required int toTaskId,
    required String isoDate,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'DELETE FROM member_tasks WHERE member_id = ? AND task_id = ? AND date = ?;',
        [memberId, fromTaskId, isoDate],
      );
      _db.execute(
        'INSERT INTO member_tasks (member_id, task_id, date) VALUES (?, ?, ?);',
        [memberId, toTaskId, isoDate],
      );
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void insertMockData({required String isoDate}) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute('''
INSERT INTO members (name, age, gender, church) VALUES
  ('João Silva', 24, 'M', 'João Pessoa'),
  ('Maria Souza', 22, 'F', 'Campina Grande'),
  ('Pedro Lima', 28, 'M', 'Santa Rita'),
  ('Ana Costa', 26, 'F', 'Bayeux'),
  ('Lucas Mendes', 21, 'M', 'Patos'),
  ('Beatriz Ramos', 27, 'F', 'Cabedelo'),
  ('Gabriel Rocha', 23, 'M', 'Sousa'),
  ('Larissa Almeida', 25, 'F', 'Cajazeiras'),
  ('Rafael Oliveira', 29, 'M', 'Guarabira'),
  ('Juliana Barros', 24, 'F', 'Itabaiana'),
  ('Matheus Ferreira', 20, 'M', 'Mamanguape'),
  ('Carla Nunes', 31, 'F', 'Pombal'),
  ('Bruno Cardoso', 27, 'M', 'Sape'),
  ('Paula Pereira', 23, 'F', 'Esperança'),
  ('Diego Martins', 26, 'M', 'Bananeiras'),
  ('Fernanda Dias', 28, 'F', 'Solânea'),
  ('Tiago Araujo', 30, 'M', 'Alagoa Grande'),
  ('Camila Teixeira', 22, 'F', 'Queimadas'),
  ('Henrique Melo', 25, 'M', 'Lagoa Seca'),
  ('Mariana Pires', 29, 'F', 'Alhandra'),
  ('André Ribeiro', 24, 'M', 'Caaporã'),
  ('Patrícia Sousa', 33, 'F', 'Pedras de Fogo'),
  ('Felipe Santos', 21, 'M', 'Conde'),
  ('Aline Brito', 27, 'F', 'Rio Tinto'),
  ('Eduardo Castro', 32, 'M', 'Cruz do Espírito Santo'),
  ('Renata Farias', 26, 'F', 'Areia'),
  ('Vítor Moreira', 23, 'M', 'Arara'),
  ('Isabela Lopes', 24, 'F', 'Catolé do Rocha'),
  ('Leandro Freitas', 28, 'M', 'Itaporanga'),
  ('Tatiana Cunha', 30, 'F', 'Princesa Isabel');
''');
      _db.execute('''
INSERT INTO tasks (name, gender_constraint, max_members) VALUES
  ('Lavar Louça', NULL, 5),
  ('Limpar Salão', NULL, 5),
  ('Preparar Jantar', NULL, 5),
  ('Recepção', NULL, 4),
  ('Organizar Materiais', NULL, 4),
  ('Som e Mídia', 'M', 4),
  ('Decoração', 'F', 4),
  ('Apoio Logístico', NULL, 5);
''');

      final memberRows = _db.select(
        'SELECT id, gender FROM members ORDER BY id DESC LIMIT 30;',
      );
      final taskRows = _db.select(
        'SELECT id, gender_constraint, max_members FROM tasks ORDER BY id DESC LIMIT 8;',
      );
      final maleIds = <int>[];
      final femaleIds = <int>[];
      final allIds = <int>[];

      for (final row in memberRows.reversed) {
        final id = row['id'] as int;
        final gender = row['gender'] as String;
        allIds.add(id);
        if (gender == 'M') {
          maleIds.add(id);
        } else if (gender == 'F') {
          femaleIds.add(id);
        }
      }

      if (allIds.isNotEmpty && taskRows.isNotEmpty) {
        final tasks = taskRows.reversed.toList();
        final used = <int>{};
        for (var t = 0; t < tasks.length; t += 1) {
          final taskId = tasks[t]['id'] as int;
          final constraint = tasks[t]['gender_constraint'] as String?;
          final maxMembers = tasks[t]['max_members'] as int?;
          final pool = constraint == 'M'
              ? maleIds
              : constraint == 'F'
              ? femaleIds
              : allIds;

          if (pool.isEmpty) continue;

          final available = pool.where((id) => !used.contains(id)).toList();
          if (available.isEmpty) continue;
          var count = (2 + (t % 4)).clamp(1, available.length); // up to 5
          if (maxMembers != null) {
            count = count.clamp(1, maxMembers);
          }
          for (var j = 0; j < count; j += 1) {
            final memberId = available[(t * 5 + j) % available.length];
            used.add(memberId);
            _db.execute(
              'INSERT OR IGNORE INTO member_tasks (member_id, task_id, date) VALUES (?, ?, ?);',
              [memberId, taskId, isoDate],
            );
          }
        }
      }

      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void insertMockVisitForms({DateTime? baseDate}) {
    final reference = baseDate ?? DateTime.now();
    final visits = [
      {
        'visitAt': reference.subtract(const Duration(days: 1, hours: 2)),
        'names': 'Ana, João',
        'address': 'Rua do Churu',
        'referencePoint': 'Próximo ao mercado',
        'neighborhood': 'Felinos',
        'city': 'Itaporanga',
        'contacts': '83 99999-0001',
        'literatureCount': 3,
        'results': {
          'evangelho': true,
          'ponte': true,
          'decisao': true,
          'reconciliacao': false,
          'primeira': true,
          'nova': true,
        },
        'ages': {
          'children': 1,
          'youth': 1,
          'adults': 1,
          'elderly': 0,
        },
        'religion': {
          'catolica': true,
          'espirita': false,
          'ateu': false,
          'desviado': true,
          'outros': true,
        },
        'notes': 'Família receptiva e aberta à oração.',
        'prayer': 'Saúde da avó e emprego do pai.',
        'team': 'Lucas, Camila',
      },
      {
        'visitAt': reference.subtract(const Duration(days: 2, hours: 1)),
        'names': 'Maria, Beatriz',
        'address': 'Rua das Flores',
        'referencePoint': 'Casa azul',
        'neighborhood': 'Centro',
        'city': 'Itaporanga',
        'contacts': '83 98888-2211',
        'literatureCount': 2,
        'results': {
          'evangelho': true,
          'ponte': false,
          'decisao': false,
          'reconciliacao': true,
          'primeira': false,
          'nova': true,
        },
        'ages': {
          'children': 0,
          'youth': 1,
          'adults': 1,
          'elderly': 0,
        },
        'religion': {
          'catolica': true,
          'espirita': false,
          'ateu': false,
          'desviado': false,
          'outros': false,
        },
        'notes': '',
        'prayer': 'União da família.',
        'team': 'Pedro, Larissa',
      },
      {
        'visitAt': reference.subtract(const Duration(days: 3, hours: 3)),
        'names': 'Carlos',
        'address': 'Rua Nova Esperança',
        'referencePoint': '',
        'neighborhood': 'Santo Antônio',
        'city': 'Itaporanga',
        'contacts': '',
        'literatureCount': 1,
        'results': {
          'evangelho': true,
          'ponte': true,
          'decisao': true,
          'reconciliacao': false,
          'primeira': true,
          'nova': false,
        },
        'ages': {
          'children': 0,
          'youth': 0,
          'adults': 1,
          'elderly': 0,
        },
        'religion': {
          'catolica': false,
          'espirita': false,
          'ateu': true,
          'desviado': false,
          'outros': false,
        },
        'notes': 'Pediu retorno para conversar mais.',
        'prayer': '',
        'team': 'Rafaela, Tiago',
      },
      {
        'visitAt': reference.subtract(const Duration(days: 4, hours: 4)),
        'names': 'Fernanda, Paula',
        'address': 'Rua São José',
        'referencePoint': 'Ao lado da praça',
        'neighborhood': 'São João',
        'city': 'Itaporanga',
        'contacts': '83 97777-3344',
        'literatureCount': 4,
        'results': {
          'evangelho': true,
          'ponte': true,
          'decisao': true,
          'reconciliacao': true,
          'primeira': false,
          'nova': true,
        },
        'ages': {
          'children': 0,
          'youth': 0,
          'adults': 2,
          'elderly': 0,
        },
        'religion': {
          'catolica': false,
          'espirita': false,
          'ateu': false,
          'desviado': true,
          'outros': false,
        },
        'notes': 'Reconciliação e oração.',
        'prayer': 'Crescimento espiritual.',
        'team': 'Mateus, Bia',
      },
      {
        'visitAt': reference.subtract(const Duration(days: 5, hours: 2)),
        'names': 'Helena, José',
        'address': 'Rua do Rio',
        'referencePoint': 'Próximo ao posto',
        'neighborhood': 'Lagoa',
        'city': 'Itaporanga',
        'contacts': '',
        'literatureCount': 2,
        'results': {
          'evangelho': true,
          'ponte': false,
          'decisao': false,
          'reconciliacao': false,
          'primeira': true,
          'nova': false,
        },
        'ages': {
          'children': 1,
          'youth': 0,
          'adults': 1,
          'elderly': 0,
        },
        'religion': {
          'catolica': true,
          'espirita': false,
          'ateu': false,
          'desviado': false,
          'outros': true,
        },
        'notes': '',
        'prayer': 'Saúde da criança.',
        'team': 'Isabela, André',
      },
    ];

    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final visit in visits) {
        final results = visit['results'] as Map<String, Object?>;
        final ages = visit['ages'] as Map<String, Object?>;
        final religion = visit['religion'] as Map<String, Object?>;
        _db.execute(
          '''
INSERT INTO visit_forms (
  visit_at,
  names,
  address,
  reference_point,
  neighborhood,
  city,
  contacts,
  literature_count,
  result_evangelho,
  result_ponte_salvacao,
  result_aceitou_jesus,
  result_reconciliacao,
  result_primeira_vez,
  result_nova_visita,
  age_children,
  age_youth,
  age_adults,
  age_elderly,
  religion_catolica,
  religion_espirita,
  religion_ateu,
  religion_desviado,
  religion_outros,
  religion_all_label,
  notes,
  prayer_requests,
  team
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
''',
          [
            _formatDateTime(visit['visitAt'] as DateTime),
            visit['names'],
            visit['address'],
            visit['referencePoint'],
            visit['neighborhood'],
            visit['city'],
            visit['contacts'],
            visit['literatureCount'],
            results['evangelho'] == true ? 1 : 0,
            results['ponte'] == true ? 1 : 0,
            results['decisao'] == true ? 1 : 0,
            results['reconciliacao'] == true ? 1 : 0,
            results['primeira'] == true ? 1 : 0,
            results['nova'] == true ? 1 : 0,
            ages['children'],
            ages['youth'],
            ages['adults'],
            ages['elderly'],
            religion['catolica'] == true ? 1 : 0,
            religion['espirita'] == true ? 1 : 0,
            religion['ateu'] == true ? 1 : 0,
            religion['desviado'] == true ? 1 : 0,
            religion['outros'] == true ? 1 : 0,
            null,
            visit['notes'],
            visit['prayer'],
            visit['team'],
          ],
        );
      }
      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void exportDatabase(String targetPath) {
    final dir = p.dirname(_dbPath);
    final tempPath = p.join(dir, 'avanco-export.db');
    final escaped = tempPath.replaceAll("'", "''");
    _db.execute('VACUUM INTO \'$escaped\';');
    final targetFile = File(targetPath);
    if (targetFile.existsSync()) {
      targetFile.deleteSync();
    }
    File(tempPath).copySync(targetPath);
    File(tempPath).deleteSync();
  }
}

void _copyDatabaseFiles(String sourcePath, String dbPath) {
  File(sourcePath).copySync(dbPath);
  final walFile = File('$dbPath-wal');
  final shmFile = File('$dbPath-shm');
  if (walFile.existsSync()) {
    walFile.deleteSync();
  }
  if (shmFile.existsSync()) {
    shmFile.deleteSync();
  }
}

({int inserted, int skipped}) _importVisitFormsCsv(
  String csvContent,
  String dbPath,
  Map<String, String>? headerOverrides,
) {
  final rows = _parseCsv(csvContent);
  if (rows.length <= 1) {
    return (inserted: 0, skipped: 0);
  }

  final headers = rows.first;
  final headerIndex = <String, int>{};
  for (var i = 0; i < headers.length; i++) {
    headerIndex[_normalizeHeader(headers[i])] = i;
  }

  final overrides = <String, String>{};
  headerOverrides?.forEach((key, value) {
    if (value.trim().isEmpty) return;
    overrides[key] = _normalizeHeader(value);
  });

  String valueForKey(
    List<String> row,
    String canonicalKey,
    List<String> fallbackKeys,
  ) {
    final override = overrides[canonicalKey];
    if (override != null) {
      final index = headerIndex[override];
      if (index != null && index < row.length) {
        return row[index].trim();
      }
    }
    for (final key in fallbackKeys) {
      final index = headerIndex[key];
      if (index != null && index < row.length) {
        return row[index].trim();
      }
    }
    return '';
  }

  final db = sqlite3.open(dbPath);
  db.execute('PRAGMA foreign_keys = ON;');
  db.execute('PRAGMA busy_timeout = 5000;');

  var inserted = 0;
  var skipped = 0;

  db.execute('BEGIN IMMEDIATE;');
  try {
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((value) => value.trim().isEmpty)) {
        continue;
      }

      try {
        final timestamp = valueForKey(
          row,
          'carimbodedatahora',
          ['carimbodedatahora'],
        );
        final dateValue = valueForKey(
          row,
          'datadaficha',
          ['datadaficha'],
        );
        final timeValue = valueForKey(
          row,
          'horario',
          ['horario'],
        );
        final visitAt = _parseVisitDateTime(
          dateValue,
          timeValue,
          timestamp,
        );
        if (visitAt == null) {
          skipped++;
          continue;
        }

        final names = valueForKey(row, 'nomes', ['nomes']);
        final address = valueForKey(row, 'endereco', ['endereco']);
        final referencePoint = valueForKey(
          row,
          'pontodereferencia',
          ['pontodereferencia'],
        );
        final neighborhood = valueForKey(row, 'bairro', ['bairro']);
        final city = valueForKey(row, 'cidade', ['cidade']);
        final contacts = valueForKey(row, 'contatos', ['contatos']);
        final literatureText = valueForKey(
          row,
          'literaturasdistribuidas',
          ['literaturasdistribuidas'],
        );
        final literatureCount = _parseFlexibleInt(literatureText);

        final resultsText = valueForKey(
          row,
          'resultadosdavisita',
          ['resultadosdavisita', 'resultadosdavista'],
        );
        final results = _parseResults(resultsText);

        final ageChildren =
            _parseFlexibleInt(valueForKey(row, 'crianca', ['crianca']));
        final ageYouth =
            _parseFlexibleInt(valueForKey(row, 'jovem', ['jovem']));
        final ageAdults =
            _parseFlexibleInt(valueForKey(row, 'adulto', ['adulto']));
        final ageElderly = _parseFlexibleInt(
          valueForKey(row, 'terceiraidade', ['terceiraidade']),
        );

        final religionText =
            valueForKey(row, 'religiao', ['religiao']);
        final religions = _parseReligions(religionText);

        final notes =
            valueForKey(row, 'observacoesdavista', ['observacoesdavista']);
        final prayerRequests =
            valueForKey(row, 'pedidosdeoracao', ['pedidosdeoracao']);
        final team = valueForKey(row, 'equipe', ['equipe']);

        if (literatureText.trim().isEmpty || team.trim().isEmpty) {
          skipped++;
          continue;
        }

        db.execute(
          '''
INSERT INTO visit_forms (
  visit_at,
  names,
  address,
  reference_point,
  neighborhood,
  city,
  contacts,
  literature_count,
  result_evangelho,
  result_ponte_salvacao,
  result_aceitou_jesus,
  result_reconciliacao,
  result_primeira_vez,
  result_nova_visita,
  age_children,
  age_youth,
  age_adults,
  age_elderly,
  religion_catolica,
  religion_espirita,
  religion_ateu,
  religion_desviado,
  religion_outros,
  religion_all_label,
  notes,
  prayer_requests,
  team
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
''',
          [
            _formatDateTimeValue(visitAt),
            names,
            address,
            referencePoint,
            neighborhood,
            city,
            contacts,
            literatureCount,
            results.evangelho ? 1 : 0,
            results.ponte ? 1 : 0,
            results.decisao ? 1 : 0,
            results.reconciliacao ? 1 : 0,
            results.primeira ? 1 : 0,
            results.novaVisita ? 1 : 0,
            ageChildren,
            ageYouth,
            ageAdults,
            ageElderly,
            religions.catolica ? 1 : 0,
            religions.espirita ? 1 : 0,
            religions.ateu ? 1 : 0,
            religions.desviado ? 1 : 0,
            religions.outros ? 1 : 0,
            null,
            notes,
            prayerRequests,
            team,
          ],
        );
        inserted++;
      } catch (_) {
        skipped++;
      }
    }
    db.execute('COMMIT;');
  } catch (_) {
    db.execute('ROLLBACK;');
    skipped = rows.length - 1 - inserted;
  } finally {
    db.dispose();
  }

  return (inserted: inserted, skipped: skipped);
}

class _ParsedResults {
  final bool evangelho;
  final bool ponte;
  final bool decisao;
  final bool reconciliacao;
  final bool primeira;
  final bool novaVisita;

  const _ParsedResults({
    required this.evangelho,
    required this.ponte,
    required this.decisao,
    required this.reconciliacao,
    required this.primeira,
    required this.novaVisita,
  });
}

class _ParsedReligions {
  final bool catolica;
  final bool espirita;
  final bool ateu;
  final bool desviado;
  final bool outros;

  const _ParsedReligions({
    required this.catolica,
    required this.espirita,
    required this.ateu,
    required this.desviado,
    required this.outros,
  });
}

_ParsedResults _parseResults(String raw) {
  final normalized = _normalizeText(raw);
  final parts = normalized.split(',').map((value) => value.trim()).toList();
  bool hasMatch(String key) => parts.any((part) => part.contains(key));

  return _ParsedResults(
    evangelho: hasMatch('passado grafico') || hasMatch('grafico'),
    ponte:
        hasMatch('passado ponte da salvacao') ||
        (hasMatch('ponte') && hasMatch('salvacao')),
    decisao: hasMatch('entregou a vida a jesus') || hasMatch('decisao'),
    reconciliacao: hasMatch('reconciliacao'),
    primeira: hasMatch('primeira vez') || hasMatch('ouviu falar do evangelho'),
    novaVisita: hasMatch('deseja uma nova visita') || hasMatch('nova visita'),
  );
}

_ParsedReligions _parseReligions(String raw) {
  final normalized = _normalizeText(raw);
  final parts = normalized.split(',').map((value) => value.trim()).toList();
  bool hasMatch(String key) => parts.any((part) => part.contains(key));

  return _ParsedReligions(
    catolica: hasMatch('catolica'),
    espirita: hasMatch('espirita'),
    ateu: hasMatch('ateu'),
    desviado: hasMatch('desviado'),
    outros: hasMatch('outros'),
  );
}

String _formatDateTimeValue(DateTime value) {
  final iso = value.toIso8601String().replaceFirst('T', ' ');
  return iso.split('.').first;
}

DateTime? _parseVisitDateTime(
  String dateValue,
  String timeValue,
  String timestampValue,
) {
  final date = _parseDate(dateValue);
  if (date != null) {
    final time = _parseTime(timeValue);
    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
      time?.second ?? 0,
    );
  }
  return _parseDateTime(timestampValue);
}

DateTime? _parseDateTime(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.isEmpty) return null;
  final date = _parseDate(parts.first);
  if (date == null) return null;
  final time = parts.length > 1 ? _parseTime(parts[1]) : null;
  return DateTime(
    date.year,
    date.month,
    date.day,
    time?.hour ?? 0,
    time?.minute ?? 0,
    time?.second ?? 0,
  );
}

DateTime? _parseDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

DateTime? _parseTime(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  if (hour == null || minute == null) return null;
  return DateTime(0, 1, 1, hour, minute, second);
}

int _parseFlexibleInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 0;
  final parsed = int.tryParse(trimmed);
  if (parsed != null) return parsed;
  final normalized = _normalizeText(trimmed);
  const words = {
    'zero': 0,
    'um': 1,
    'uma': 1,
    'dois': 2,
    'duas': 2,
    'tres': 3,
    'quatro': 4,
    'cinco': 5,
    'seis': 6,
    'sete': 7,
    'oito': 8,
    'nove': 9,
    'dez': 10,
  };
  return words[normalized] ?? 0;
}

List<List<String>> _parseCsv(String input) {
  final rows = <List<String>>[];
  final currentRow = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  var i = 0;

  while (i < input.length) {
    final char = input[i];
    if (char == '"') {
      final nextChar = i + 1 < input.length ? input[i + 1] : null;
      if (inQuotes && nextChar == '"') {
        buffer.write('"');
        i += 2;
        continue;
      }
      inQuotes = !inQuotes;
      i++;
      continue;
    }

    if (char == ',' && !inQuotes) {
      currentRow.add(buffer.toString());
      buffer.clear();
      i++;
      continue;
    }

    if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
        i++;
      }
      currentRow.add(buffer.toString());
      buffer.clear();
      rows.add(List<String>.from(currentRow));
      currentRow.clear();
      i++;
      continue;
    }

    buffer.write(char);
    i++;
  }

  if (buffer.length > 0 || currentRow.isNotEmpty) {
    currentRow.add(buffer.toString());
    rows.add(List<String>.from(currentRow));
  }

  return rows;
}

String _normalizeHeader(String value) {
  final lowered = _normalizeText(value);
  return lowered.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _normalizeText(String value) {
  var result = value.trim().toLowerCase();
  const replacements = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'ê': 'e',
    'í': 'i',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ç': 'c',
  };
  replacements.forEach((key, replacement) {
    result = result.replaceAll(key, replacement);
  });
  return result;
}
