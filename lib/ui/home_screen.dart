import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/app_database.dart';
import '../data/models.dart';
import 'widgets/member_card.dart';
import 'widgets/task_column.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase database;

  const HomeScreen({super.key, required this.database});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
  final DateFormat _weekdayFormat = DateFormat('EEEE', 'pt_BR');

  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  bool _showAllMembers = false;
  String _memberSortField = 'name';
  bool _memberSortAsc = true;
  String? _errorMessage;
  List<Member> _members = [];
  List<Task> _tasks = [];
  Map<int, List<TaskAssignment>> _assignments = {};
  Map<int, int> _taskCounts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final members = widget.database.fetchMembers();
      final tasks = widget.database.fetchTasks();
      final assignments =
          widget.database.fetchAssignmentsByTaskForDate(_isoDate(_selectedDate));
      final taskCounts = widget.database.fetchTaskCountsUpTo(_isoDate(_selectedDate));

      if (!mounted) return;
      setState(() {
        _members = members;
        _tasks = tasks;
        _assignments = assignments;
        _taskCounts = taskCounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Falha ao carregar os dados.';
        _loading = false;
      });
    }
  }

  void _changeDate(int offsetDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offsetDays));
    });
    _loadData();
  }

  Future<void> _handleDrop(Task task, Member member) async {
    if (task.genderConstraint != null && task.genderConstraint != member.gender) {
      _showMessage('A restrição de gênero não corresponde a esta tarefa.');
      return;
    }

    final existingForTask = _assignments[task.id] ?? [];
    if (existingForTask.any((entry) => entry.member.id == member.id)) {
      _showMessage('Este membro já está atribuído a esta tarefa.');
      return;
    }

    TaskAssignment? existingAssignment;
    for (final entry in _assignments.values.expand((list) => list)) {
      if (entry.member.id == member.id && entry.taskId != task.id) {
        existingAssignment = entry;
        break;
      }
    }
    if (existingAssignment != null) {
      final proceed = await _confirmMultipleTasks();
      if (!proceed) return;
    }

    try {
      widget.database.assignMemberToTask(
        memberId: member.id,
        taskId: task.id,
        isoDate: _isoDate(_selectedDate),
      );
      _loadData();
    } catch (e) {
      _showMessage('Falha ao atribuir. ${e.toString()}');
    }
  }

  void _handleRemoveAssignment(int memberId, int taskId) {
    try {
      widget.database.removeAssignment(
        memberId: memberId,
        taskId: taskId,
        isoDate: _isoDate(_selectedDate),
      );
      _loadData();
    } catch (e) {
      _showMessage('Falha ao remover a atribuição.');
    }
  }

  void _handleMoveAssignment(int memberId, int fromTaskId, int toTaskId) {
    if (fromTaskId == toTaskId) return;
    Member? member;
    for (final entry in _members) {
      if (entry.id == memberId) {
        member = entry;
        break;
      }
    }
    Task? targetTask;
    for (final entry in _tasks) {
      if (entry.id == toTaskId) {
        targetTask = entry;
        break;
      }
    }

    if (member == null || targetTask == null) {
      _showMessage('Falha ao mover a atribuição.');
      return;
    }

    if (targetTask.genderConstraint != null && targetTask.genderConstraint != member.gender) {
      _showMessage('A restrição de gênero não corresponde a esta tarefa.');
      return;
    }

    final existingForTarget = _assignments[toTaskId] ?? [];
    if (existingForTarget.any((entry) => entry.member.id == memberId)) {
      _showMessage('Este membro já está atribuído a esta tarefa.');
      return;
    }

    try {
      widget.database.moveAssignment(
        memberId: memberId,
        fromTaskId: fromTaskId,
        toTaskId: toTaskId,
        isoDate: _isoDate(_selectedDate),
      );
      _loadData();
    } catch (e) {
      _showMessage('Falha ao mover a atribuição.');
    }
  }

  Future<bool> _confirmMultipleTasks() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Membro já atribuído',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 16),
                const Text(
                  'Este membro já possui uma tarefa neste dia. '
                  'Deseja atribuir mesmo assim?',
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Atribuir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _exportDayPdf() async {
    if (_tasks.isEmpty) {
      _showMessage('Nenhuma tarefa para exportar.');
      return;
    }

    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );
    final pdf = pw.Document(theme: theme);
    final dateLabel = _dateFormat.format(_selectedDate);
    final weekdayLabel = _weekdayFormat.format(_selectedDate);
    final tasksWithAssignments = _tasks
        .where((task) => (_assignments[task.id] ?? []).isNotEmpty)
        .toList();
    if (tasksWithAssignments.isEmpty) {
      _showMessage('Nenhuma tarefa com membros para exportar.');
      return;
    }

    final groups = <List<Task>>[];
    for (var i = 0; i < tasksWithAssignments.length; i += 3) {
      groups.add(
        tasksWithAssignments.sublist(
          i,
          (i + 3).clamp(0, tasksWithAssignments.length),
        ),
      );
    }
    final header = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Distribuição de Tarefas do Dia',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          '$dateLabel (${weekdayLabel[0].toUpperCase()}${weekdayLabel.substring(1)})',
          style: pw.TextStyle(
            fontSize: 14,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 18),
      ],
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            header,
            ...groups.map((group) {
              final headers = group.map((task) => task.name).toList();
              final rows = _buildPdfRows(group);
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
                    columnWidths: {
                      for (var i = 0; i < headers.length; i++)
                        i: const pw.FlexColumnWidth(),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: headers
                            .map(
                              (title) => pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  title,
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      ...rows.map(
                        (row) => pw.TableRow(
                          children: row
                              .map(
                                (cell) => pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text(
                                    cell,
                                    style: const pw.TextStyle(fontSize: 11),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 18),
                ],
              );
            }),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final filename = 'avanco-${DateFormat('yyyy-MM-dd').format(_selectedDate)}.pdf';
    final saveLocation = await getSaveLocation(
      suggestedName: filename,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (saveLocation == null) {
      _showMessage('Exportacao cancelada.');
      return;
    }

    final file = File(saveLocation.path);
    await file.writeAsBytes(bytes);
    await _openFile(file.path);
    _showMessage('PDF salvo em ${file.path}');
  }

  Future<void> _openFile(String path) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {
      // Keep silent; user still has the path in the snackbar.
    }
  }

  List<List<String>> _buildPdfRows(List<Task> tasks) {
    final memberLists = tasks.map((task) {
      final assignments = _assignments[task.id] ?? [];
      return assignments
          .map((assignment) => '${assignment.member.name} - ${assignment.member.church}')
          .toList();
    }).toList();

    final maxRows = memberLists.map((list) => list.length).fold<int>(0, (a, b) => a > b ? a : b);
    if (maxRows == 0) {
      return [
        List.generate(tasks.length, (_) => ''),
      ];
    }

    return List.generate(maxRows, (rowIndex) {
      return List.generate(tasks.length, (colIndex) {
        final list = memberLists[colIndex];
        return rowIndex < list.length ? list[rowIndex] : '';
      });
    });
  }

  Future<void> _openAddMemberDialog() async {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final churchController = TextEditingController();
    String? selectedGender;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Adicionar membro',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    const Text(
                      'Nome completo',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'ex.: João Silva',
                        suffixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Idade',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: ageController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  hintText: 'ex.: 24',
                                  filled: true,
                                  fillColor: const Color(0xFFF7F8FB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Gênero',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Radio<String>(
                                        value: 'M',
                                        groupValue: selectedGender,
                                        onChanged: (value) => setModalState(() {
                                          selectedGender = value;
                                        }),
                                      ),
                                      const Text('Masculino'),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Radio<String>(
                                        value: 'F',
                                        groupValue: selectedGender,
                                        onChanged: (value) => setModalState(() {
                                          selectedGender = value;
                                        }),
                                      ),
                                      const Text('Feminino'),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Igreja',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: churchController,
                      decoration: InputDecoration(
                        hintText: 'ex.: João Pessoa',
                        filled: true,
                        fillColor: const Color(0xFFF7F8FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            final name = nameController.text.trim();
                            final age = int.tryParse(ageController.text.trim());
                            final church = churchController.text.trim();

                            if (name.isEmpty) {
                              setModalState(() {
                                errorText = 'Informe o nome completo.';
                              });
                              return;
                            }
                            if (age == null || age <= 0) {
                              setModalState(() {
                                errorText = 'Informe uma idade válida.';
                              });
                              return;
                            }
                            if (church.isEmpty) {
                              setModalState(() {
                                errorText = 'Informe o nome da igreja.';
                              });
                              return;
                            }
                            if (selectedGender == null) {
                              setModalState(() {
                                errorText = 'Selecione o gênero.';
                              });
                              return;
                            }

                            try {
                              widget.database.insertMember(
                                name: name,
                                age: age,
                                gender: selectedGender!,
                                church: church,
                              );
                              Navigator.of(dialogContext).pop();
                              _loadData();
                            } catch (e) {
                              setModalState(() {
                                errorText = 'Falha ao salvar o membro.';
                              });
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Salvar membro'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    ageController.dispose();
    churchController.dispose();
  }

  Future<void> _openEditMemberDialog(Member member) async {
    final nameController = TextEditingController(text: member.name);
    final ageController = TextEditingController(text: member.age.toString());
    final churchController = TextEditingController(text: member.church);
    String? selectedGender = member.gender;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Editar membro',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    const Text(
                      'Nome completo',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'ex.: João Silva',
                        suffixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Idade',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: ageController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  hintText: 'ex.: 24',
                                  filled: true,
                                  fillColor: const Color(0xFFF7F8FB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Gênero',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Radio<String>(
                                        value: 'M',
                                        groupValue: selectedGender,
                                        onChanged: (value) => setModalState(() {
                                          selectedGender = value;
                                        }),
                                      ),
                                      const Text('Masculino'),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Radio<String>(
                                        value: 'F',
                                        groupValue: selectedGender,
                                        onChanged: (value) => setModalState(() {
                                          selectedGender = value;
                                        }),
                                      ),
                                      const Text('Feminino'),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Igreja',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: churchController,
                      decoration: InputDecoration(
                        hintText: 'ex.: João Pessoa',
                        filled: true,
                        fillColor: const Color(0xFFF7F8FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            final name = nameController.text.trim();
                            final age = int.tryParse(ageController.text.trim());
                            final church = churchController.text.trim();

                            if (name.isEmpty) {
                              setModalState(() {
                                errorText = 'Informe o nome completo.';
                              });
                              return;
                            }
                            if (age == null || age <= 0) {
                              setModalState(() {
                                errorText = 'Informe uma idade válida.';
                              });
                              return;
                            }
                            if (church.isEmpty) {
                              setModalState(() {
                                errorText = 'Informe o nome da igreja.';
                              });
                              return;
                            }
                            if (selectedGender == null) {
                              setModalState(() {
                                errorText = 'Selecione o gênero.';
                              });
                              return;
                            }

                            try {
                              widget.database.updateMember(
                                id: member.id,
                                name: name,
                                age: age,
                                gender: selectedGender!,
                                church: church,
                              );
                              Navigator.of(dialogContext).pop();
                              _loadData();
                            } catch (e) {
                              setModalState(() {
                                errorText = 'Falha ao atualizar o membro.';
                              });
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Salvar alterações'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    ageController.dispose();
    churchController.dispose();
  }

  Future<void> _confirmClearDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Limpar banco',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 16),
                const Text(
                  'Isso vai remover permanentemente membros, tarefas e atribuições. '
                  'Esta ação não pode ser desfeita.',
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Limpar banco'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      try {
        widget.database.clearDatabase();
        await _loadData();
        _showMessage('Banco limpo.');
      } catch (e) {
        _showMessage('Falha ao limpar o banco.');
      }
    }
  }

  Future<void> _confirmMockDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Banco de teste',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 16),
                const Text(
                  'Isso vai adicionar 30 membros e 8 tarefas ao banco.',
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Adicionar dados de teste'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      try {
        widget.database.insertMockData(isoDate: _isoDate(_selectedDate));
        await _loadData();
        _showMessage('Dados de teste adicionados.');
      } catch (e) {
        _showMessage('Falha ao adicionar dados de teste.');
      }
    }
  }

  Future<void> _openAddTaskDialog() async {
    final taskController = TextEditingController();
    bool limitByGender = false;
    String? selectedGender;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Adicionar tarefa',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Crie uma tarefa de apoio para a equipe Avanço.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Descrição da tarefa',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskController,
                      decoration: InputDecoration(
                        hintText: 'ex.: Organizar kits de boas-vindas',
                        filled: true,
                        fillColor: const Color(0xFFF7F8FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: limitByGender,
                                onChanged: (value) {
                                  setModalState(() {
                                    limitByGender = value ?? false;
                                    if (!limitByGender) {
                                      selectedGender = null;
                                    }
                                  });
                                },
                              ),
                              const Text(
                                'Limitar atribuição por gênero',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (limitByGender) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'SELECIONE O GÊNERO',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => setModalState(() {
                                      selectedGender = 'M';
                                    }),
                                    icon: const Icon(Icons.male),
                                    label: const Text('Somente homens'),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: selectedGender == 'M'
                                          ? const Color(0xFFE8F0FF)
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => setModalState(() {
                                      selectedGender = 'F';
                                    }),
                                    icon: const Icon(Icons.female),
                                    label: const Text('Somente mulheres'),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: selectedGender == 'F'
                                          ? const Color(0xFFE8F0FF)
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            final name = taskController.text.trim();
                            if (name.isEmpty) {
                              setModalState(() {
                                errorText = 'Informe a descrição da tarefa.';
                              });
                              return;
                            }
                            if (limitByGender && selectedGender == null) {
                              setModalState(() {
                                errorText = 'Selecione o gênero.';
                              });
                              return;
                            }

                            try {
                              widget.database.insertTask(
                                name: name,
                                genderConstraint: limitByGender ? selectedGender : null,
                              );
                              Navigator.of(dialogContext).pop();
                              _loadData();
                            } catch (e) {
                              setModalState(() {
                                errorText = 'Falha ao salvar a tarefa.';
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F5BFF),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Salvar tarefa'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    taskController.dispose();
  }

  Future<void> _openEditTaskDialog(Task task) async {
    final taskController = TextEditingController(text: task.name);
    bool limitByGender = task.genderConstraint != null;
    String? selectedGender = task.genderConstraint;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Editar tarefa',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Atualize os detalhes da tarefa de apoio.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Descrição da tarefa',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskController,
                      decoration: InputDecoration(
                        hintText: 'ex.: Organizar kits de boas-vindas',
                        filled: true,
                        fillColor: const Color(0xFFF7F8FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: limitByGender,
                                onChanged: (value) {
                                  setModalState(() {
                                    limitByGender = value ?? false;
                                    if (!limitByGender) {
                                      selectedGender = null;
                                    }
                                  });
                                },
                              ),
                              const Text(
                                'Limitar atribuição por gênero',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (limitByGender) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'SELECIONE O GÊNERO',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => setModalState(() {
                                      selectedGender = 'M';
                                    }),
                                    icon: const Icon(Icons.male),
                                    label: const Text('Somente homens'),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: selectedGender == 'M'
                                          ? const Color(0xFFE8F0FF)
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => setModalState(() {
                                      selectedGender = 'F';
                                    }),
                                    icon: const Icon(Icons.female),
                                    label: const Text('Somente mulheres'),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: selectedGender == 'F'
                                          ? const Color(0xFFE8F0FF)
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            final name = taskController.text.trim();
                            if (name.isEmpty) {
                              setModalState(() {
                                errorText = 'Informe a descrição da tarefa.';
                              });
                              return;
                            }
                            if (limitByGender && selectedGender == null) {
                              setModalState(() {
                                errorText = 'Selecione o gênero.';
                              });
                              return;
                            }

                            try {
                              widget.database.updateTask(
                                id: task.id,
                                name: name,
                                genderConstraint: limitByGender ? selectedGender : null,
                              );
                              Navigator.of(dialogContext).pop();
                              _loadData();
                            } catch (e) {
                              setModalState(() {
                                errorText = 'Falha ao atualizar a tarefa.';
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F5BFF),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Salvar alterações'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    taskController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avanço'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (value) {
              if (value == 'clear') {
                _confirmClearDatabase();
              } else if (value == 'mock') {
                _confirmMockDatabase();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Limpar banco'),
              ),
              const PopupMenuItem(
                value: 'mock',
                child: Text('Banco de teste'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildMembersPanel(),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTasksPanel()),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMembersPanel() {
    final query = _searchController.text.trim().toLowerCase();
    final assignments = _assignments.values.expand((list) => list).toList();
    final assignedIds = assignments.map((a) => a.member.id).toSet();

    final filteredMembers = _members.where((member) {
      if (!_showAllMembers && assignedIds.contains(member.id)) return false;
      if (query.isEmpty) return true;
      return member.name.toLowerCase().contains(query);
    }).toList();
    filteredMembers.sort((a, b) {
      int result;
      switch (_memberSortField) {
        case 'church':
          result = a.church.toLowerCase().compareTo(b.church.toLowerCase());
        case 'age':
          result = a.age.compareTo(b.age);
        case 'tasks':
          result = (_taskCounts[a.id] ?? 0).compareTo(_taskCounts[b.id] ?? 0);
        case 'name':
        default:
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _memberSortAsc ? result : -result;
    });

    final availableCount = _members.where((member) => !assignedIds.contains(member.id)).length;

    return DragTarget<AssignmentDragData>(
      onAcceptWithDetails: (details) {
        final data = details.data;
        _handleRemoveAssignment(data.memberId, data.taskId);
      },
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFF0F6FF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFE6E8EF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Membros',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  FilterChip(
                    label: Text('$availableCount disponíveis'),
                    selected: !_showAllMembers,
                    onSelected: (selected) {
                      setState(() {
                        _showAllMembers = !selected;
                      });
                    },
                    backgroundColor: const Color(0xFFF1F2F6),
                    selectedColor: const Color(0xFFE8F0FF),
                    checkmarkColor: const Color(0xFF1D4ED8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide.none,
                    ),
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar membros...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF1F2F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PopupMenuButton<String>(
                      tooltip: 'Ordenar por',
                      onSelected: (value) {
                        setState(() {
                          _memberSortField = value;
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'name',
                          child: Text('Nome'),
                        ),
                        const PopupMenuItem(
                          value: 'church',
                          child: Text('Igreja'),
                        ),
                        const PopupMenuItem(
                          value: 'age',
                          child: Text('Idade'),
                        ),
                        const PopupMenuItem(
                          value: 'tasks',
                          child: Text('Qtd. tarefas'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F2F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sort, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _memberSortField == 'name'
                                    ? 'Nome'
                                    : _memberSortField == 'church'
                                        ? 'Igreja'
                                        : _memberSortField == 'age'
                                            ? 'Idade'
                                            : 'Qtd. tarefas',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: _memberSortAsc ? 'Ordem crescente' : 'Ordem decrescente',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _memberSortAsc = !_memberSortAsc;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F2F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _memberSortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: filteredMembers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final member = filteredMembers[index];
                    return Draggable<Member>(
                      data: member,
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 240,
                          child: MemberCard(
                            member: member,
                            dense: true,
                            taskCount: _taskCounts[member.id] ?? 0,
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.5,
                        child: MemberCard(
                          member: member,
                          dense: true,
                          taskCount: _taskCounts[member.id] ?? 0,
                        ),
                      ),
                      child: MemberCard(
                        member: member,
                        dense: true,
                        taskCount: _taskCounts[member.id] ?? 0,
                        onDoubleTap: () => _openEditMemberDialog(member),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openAddMemberDialog,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar membro'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTasksPanel() {
    final accentColors = [
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFF97316),
      const Color(0xFF10B981),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EF)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFF7F8FB),
              border: Border.all(color: const Color(0xFFE6E8EF)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _changeDate(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _dateFormat.format(_selectedDate),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Text(
                  _weekdayFormat.format(_selectedDate).toUpperCase(),
                  style: const TextStyle(fontSize: 12, letterSpacing: 1.4),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _changeDate(1),
                  icon: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _exportDayPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Salvar PDF'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _openAddTaskDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar tarefa'),
                ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: _tasks.isEmpty
                ? const Center(child: Text('Nenhuma tarefa cadastrada.'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      final assignments = _assignments[task.id] ?? [];
                      final color = accentColors[index % accentColors.length];

                      return SizedBox(
                        width: 280,
                        child: TaskColumn(
                          task: task,
                          accentColor: color,
                          assignments: assignments,
                          onMemberDropped: (member) => _handleDrop(task, member),
                          onMoveAssignment: _handleMoveAssignment,
                          onMemberDoubleTap: _openEditMemberDialog,
                          onTaskDoubleTap: () => _openEditTaskDialog(task),
                          onRemoveAssignment: _handleRemoveAssignment,
                          taskCounts: _taskCounts,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
