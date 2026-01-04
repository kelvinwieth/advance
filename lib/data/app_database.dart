import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'models.dart';

class AppDatabase {
  final Database _db;
  final String _dbPath;

  AppDatabase._(this._db, this._dbPath);

  static Future<AppDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'avanco.db');
    final db = sqlite3.open(dbPath);
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA journal_mode = WAL;');
    _migrate(db);
    return AppDatabase._(db, dbPath);
  }

  String _formatDateTime(DateTime value) {
    final iso = value.toIso8601String().replaceFirst('T', ' ');
    return iso.split('.').first;
  }

  String get dbPath => _dbPath;

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
CREATE TABLE IF NOT EXISTS visit_forms (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  visit_at TEXT NOT NULL CHECK (visit_at = datetime(visit_at)),
  names TEXT NOT NULL,
  address TEXT NOT NULL,
  reference_point TEXT NOT NULL,
  neighborhood TEXT NOT NULL,
  city TEXT NOT NULL,
  contacts TEXT NOT NULL,
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
  religion_catolica INTEGER NOT NULL DEFAULT 0 CHECK (religion_catolica >= 0),
  religion_espirita INTEGER NOT NULL DEFAULT 0 CHECK (religion_espirita >= 0),
  religion_ateu INTEGER NOT NULL DEFAULT 0 CHECK (religion_ateu >= 0),
  religion_desviado INTEGER NOT NULL DEFAULT 0 CHECK (religion_desviado >= 0),
  religion_outros INTEGER NOT NULL DEFAULT 0 CHECK (religion_outros >= 0),
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
        db.execute('ALTER TABLE members ADD COLUMN church TEXT NOT NULL DEFAULT \"\";');
      }
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<Member> fetchMembers() {
    final result = _db.select('SELECT id, name, age, gender, church FROM members ORDER BY name;');
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
  m.gender AS member_gender,
  m.church AS member_church
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

  Map<int, int> fetchTaskCountsUpTo(String isoDate) {
    final result = _db.select('''
SELECT member_id, COUNT(*) AS total
FROM member_tasks
WHERE date <= ?
GROUP BY member_id;
''', [isoDate]);
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
    required int religionCatolica,
    required int religionEspirita,
    required int religionAteu,
    required int religionDesviado,
    required int religionOutros,
    required String? religionAllLabel,
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
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
''',
        [
          _formatDateTime(visitAt),
          names,
          address,
          referencePoint,
          neighborhood,
          city,
          contacts,
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
          religionCatolica,
          religionEspirita,
          religionAteu,
          religionDesviado,
          religionOutros,
          religionAllLabel,
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
    required int religionCatolica,
    required int religionEspirita,
    required int religionAteu,
    required int religionDesviado,
    required int religionOutros,
    required String? religionAllLabel,
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
          religionCatolica,
          religionEspirita,
          religionAteu,
          religionDesviado,
          religionOutros,
          religionAllLabel,
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

  VisitAnalytics fetchVisitAnalytics() {
    final result = _db.select('''
SELECT
  COUNT(*) AS total_visits,
  COALESCE(SUM(result_aceitou_jesus), 0) AS total_aceitou,
  COALESCE(SUM(result_nova_visita), 0) AS total_nova,
  COALESCE(SUM(age_children), 0) AS age_children,
  COALESCE(SUM(age_youth), 0) AS age_youth,
  COALESCE(SUM(age_adults), 0) AS age_adults,
  COALESCE(SUM(age_elderly), 0) AS age_elderly,
  COALESCE(SUM(religion_catolica), 0) AS religion_catolica,
  COALESCE(SUM(religion_espirita), 0) AS religion_espirita,
  COALESCE(SUM(religion_ateu), 0) AS religion_ateu,
  COALESCE(SUM(religion_desviado), 0) AS religion_desviado,
  COALESCE(SUM(religion_outros), 0) AS religion_outros
FROM visit_forms;
''');
    final row = result.first;
    final ageChildren = row['age_children'] as int;
    final ageYouth = row['age_youth'] as int;
    final ageAdults = row['age_adults'] as int;
    final ageElderly = row['age_elderly'] as int;
    final totalPeople = ageChildren + ageYouth + ageAdults + ageElderly;

    return VisitAnalytics(
      totalVisits: row['total_visits'] as int,
      totalPeople: totalPeople,
      totalAceitouJesus: row['total_aceitou'] as int,
      totalNovaVisita: row['total_nova'] as int,
      ageChildren: ageChildren,
      ageYouth: ageYouth,
      ageAdults: ageAdults,
      ageElderly: ageElderly,
      religionCatolica: row['religion_catolica'] as int,
      religionEspirita: row['religion_espirita'] as int,
      religionAteu: row['religion_ateu'] as int,
      religionDesviado: row['religion_desviado'] as int,
      religionOutros: row['religion_outros'] as int,
    );
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
INSERT INTO tasks (name, gender_constraint) VALUES
  ('Lavar Louça', NULL),
  ('Limpar Salão', NULL),
  ('Preparar Jantar', NULL),
  ('Recepção', NULL),
  ('Organizar Materiais', NULL),
  ('Som e Mídia', 'M'),
  ('Decoração', 'F'),
  ('Apoio Logístico', NULL);
''');

      final memberRows = _db.select(
        'SELECT id, gender FROM members ORDER BY id DESC LIMIT 30;',
      );
      final taskRows = _db.select(
        'SELECT id, gender_constraint FROM tasks ORDER BY id DESC LIMIT 8;',
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
          final pool = constraint == 'M'
              ? maleIds
              : constraint == 'F'
                  ? femaleIds
                  : allIds;

          if (pool.isEmpty) continue;

          final available = pool.where((id) => !used.contains(id)).toList();
          if (available.isEmpty) continue;
          final count = (2 + (t % 4)).clamp(1, available.length); // up to 5
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
}
