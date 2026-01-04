class Member {
  final int id;
  final String name;
  final int age;
  final String gender;
  final String church;

  const Member({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.church,
  });

  factory Member.fromRow(Map<String, Object?> row) {
    return Member(
      id: row['id'] as int,
      name: row['name'] as String,
      age: row['age'] as int,
      gender: row['gender'] as String,
      church: row['church'] as String,
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
        church: row['member_church'] as String,
      ),
    );
  }
}

class VisitForm {
  final int id;
  final DateTime visitAt;
  final String names;
  final String address;
  final String referencePoint;
  final String neighborhood;
  final String city;
  final String contacts;
  final bool resultEvangelho;
  final bool resultPonteSalvacao;
  final bool resultAceitouJesus;
  final bool resultReconciliacao;
  final bool resultPrimeiraVez;
  final bool resultNovaVisita;
  final int ageChildren;
  final int ageYouth;
  final int ageAdults;
  final int ageElderly;
  final int religionCatolica;
  final int religionEspirita;
  final int religionAteu;
  final int religionDesviado;
  final int religionOutros;
  final String? religionAllLabel;
  final String notes;
  final String prayerRequests;
  final String team;

  const VisitForm({
    required this.id,
    required this.visitAt,
    required this.names,
    required this.address,
    required this.referencePoint,
    required this.neighborhood,
    required this.city,
    required this.contacts,
    required this.resultEvangelho,
    required this.resultPonteSalvacao,
    required this.resultAceitouJesus,
    required this.resultReconciliacao,
    required this.resultPrimeiraVez,
    required this.resultNovaVisita,
    required this.ageChildren,
    required this.ageYouth,
    required this.ageAdults,
    required this.ageElderly,
    required this.religionCatolica,
    required this.religionEspirita,
    required this.religionAteu,
    required this.religionDesviado,
    required this.religionOutros,
    required this.religionAllLabel,
    required this.notes,
    required this.prayerRequests,
    required this.team,
  });

  factory VisitForm.fromRow(Map<String, Object?> row) {
    return VisitForm(
      id: row['id'] as int,
      visitAt: DateTime.parse(row['visit_at'] as String),
      names: row['names'] as String,
      address: row['address'] as String,
      referencePoint: row['reference_point'] as String,
      neighborhood: row['neighborhood'] as String,
      city: row['city'] as String,
      contacts: row['contacts'] as String,
      resultEvangelho: (row['result_evangelho'] as int) == 1,
      resultPonteSalvacao: (row['result_ponte_salvacao'] as int) == 1,
      resultAceitouJesus: (row['result_aceitou_jesus'] as int) == 1,
      resultReconciliacao: (row['result_reconciliacao'] as int) == 1,
      resultPrimeiraVez: (row['result_primeira_vez'] as int) == 1,
      resultNovaVisita: (row['result_nova_visita'] as int) == 1,
      ageChildren: row['age_children'] as int,
      ageYouth: row['age_youth'] as int,
      ageAdults: row['age_adults'] as int,
      ageElderly: row['age_elderly'] as int,
      religionCatolica: row['religion_catolica'] as int,
      religionEspirita: row['religion_espirita'] as int,
      religionAteu: row['religion_ateu'] as int,
      religionDesviado: row['religion_desviado'] as int,
      religionOutros: row['religion_outros'] as int,
      religionAllLabel: row['religion_all_label'] as String?,
      notes: row['notes'] as String,
      prayerRequests: row['prayer_requests'] as String,
      team: row['team'] as String,
    );
  }
}

class VisitAnalytics {
  final int totalVisits;
  final int totalPeople;
  final int totalAceitouJesus;
  final int totalNovaVisita;
  final int totalEvangelho;
  final int totalPonteSalvacao;
  final int totalReconciliacao;
  final int totalPrimeiraVez;
  final int ageChildren;
  final int ageYouth;
  final int ageAdults;
  final int ageElderly;
  final int religionCatolica;
  final int religionEspirita;
  final int religionAteu;
  final int religionDesviado;
  final int religionOutros;

  const VisitAnalytics({
    required this.totalVisits,
    required this.totalPeople,
    required this.totalAceitouJesus,
    required this.totalNovaVisita,
    required this.totalEvangelho,
    required this.totalPonteSalvacao,
    required this.totalReconciliacao,
    required this.totalPrimeiraVez,
    required this.ageChildren,
    required this.ageYouth,
    required this.ageAdults,
    required this.ageElderly,
    required this.religionCatolica,
    required this.religionEspirita,
    required this.religionAteu,
    required this.religionDesviado,
    required this.religionOutros,
  });
}

class VisitCityCount {
  final String city;
  final int total;

  const VisitCityCount({required this.city, required this.total});
}
