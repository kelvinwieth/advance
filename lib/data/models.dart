class Member {
  final int id;
  final String name;
  final int age;
  final String gender;

  const Member({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
  });

  factory Member.fromRow(Map<String, Object?> row) {
    return Member(
      id: row['id'] as int,
      name: row['name'] as String,
      age: row['age'] as int,
      gender: row['gender'] as String,
    );
  }
}

class Task {
  final int id;
  final String name;
  final String? genderConstraint;

  const Task({
    required this.id,
    required this.name,
    required this.genderConstraint,
  });

  factory Task.fromRow(Map<String, Object?> row) {
    return Task(
      id: row['id'] as int,
      name: row['name'] as String,
      genderConstraint: row['gender_constraint'] as String?,
    );
  }
}

class TaskAssignment {
  final int assignmentId;
  final int taskId;
  final Member member;

  const TaskAssignment({
    required this.assignmentId,
    required this.taskId,
    required this.member,
  });

  factory TaskAssignment.fromRow(Map<String, Object?> row) {
    return TaskAssignment(
      assignmentId: row['assignment_id'] as int,
      taskId: row['task_id'] as int,
      member: Member(
        id: row['member_id'] as int,
        name: row['member_name'] as String,
        age: row['member_age'] as int,
        gender: row['member_gender'] as String,
      ),
    );
  }
}
