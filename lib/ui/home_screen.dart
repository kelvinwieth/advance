import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

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
  final DateFormat _dateFormat = DateFormat('MM / dd / yyyy');
  final DateFormat _weekdayFormat = DateFormat('EEEE');

  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  String? _errorMessage;
  List<Member> _members = [];
  List<Task> _tasks = [];
  Map<int, List<TaskAssignment>> _assignments = {};

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

      if (!mounted) return;
      setState(() {
        _members = members;
        _tasks = tasks;
        _assignments = assignments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load data.';
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

  void _handleDrop(Task task, Member member) {
    if (task.genderConstraint != null && task.genderConstraint != member.gender) {
      _showMessage('Gender constraint does not match for this task.');
      return;
    }

    final existingForTask = _assignments[task.id] ?? [];
    if (existingForTask.any((entry) => entry.member.id == member.id)) {
      _showMessage('This member is already assigned to this task.');
      return;
    }

    try {
      widget.database.assignMemberToTask(
        memberId: member.id,
        taskId: task.id,
        isoDate: _isoDate(_selectedDate),
      );
      _loadData();
    } catch (e) {
      _showMessage('Assignment failed. ${e.toString()}');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openAddMemberDialog() async {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
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
                          'Add New Member',
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
                      'Full Name',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. John Doe',
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
                                'Age',
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
                                  hintText: 'e.g. 24',
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
                                'Gender',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'M',
                                    groupValue: selectedGender,
                                    onChanged: (value) => setModalState(() {
                                      selectedGender = value;
                                    }),
                                  ),
                                  const Text('Male'),
                                  const SizedBox(width: 12),
                                  Radio<String>(
                                    value: 'F',
                                    groupValue: selectedGender,
                                    onChanged: (value) => setModalState(() {
                                      selectedGender = value;
                                    }),
                                  ),
                                  const Text('Female'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            final name = nameController.text.trim();
                            final age = int.tryParse(ageController.text.trim());

                            if (name.isEmpty) {
                              setModalState(() {
                                errorText = 'Please enter a full name.';
                              });
                              return;
                            }
                            if (age == null || age <= 0) {
                              setModalState(() {
                                errorText = 'Please enter a valid age.';
                              });
                              return;
                            }
                            if (selectedGender == null) {
                              setModalState(() {
                                errorText = 'Please select a gender.';
                              });
                              return;
                            }

                            try {
                              widget.database.insertMember(
                                name: name,
                                age: age,
                                gender: selectedGender!,
                              );
                              Navigator.of(dialogContext).pop();
                              _loadData();
                            } catch (e) {
                              setModalState(() {
                                errorText = 'Failed to save member.';
                              });
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Save Member'),
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
  }

  Future<void> _openEditMemberDialog(Member member) async {
    final nameController = TextEditingController(text: member.name);
    final ageController = TextEditingController(text: member.age.toString());
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
                          'Edit Member',
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
                      'Full Name',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. John Doe',
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
                                'Age',
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
                                  hintText: 'e.g. 24',
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
                                'Gender',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'M',
                                    groupValue: selectedGender,
                                    onChanged: (value) => setModalState(() {
                                      selectedGender = value;
                                    }),
                                  ),
                                  const Text('Male'),
                                  const SizedBox(width: 12),
                                  Radio<String>(
                                    value: 'F',
                                    groupValue: selectedGender,
                                    onChanged: (value) => setModalState(() {
                                      selectedGender = value;
                                    }),
                                  ),
                                  const Text('Female'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            final name = nameController.text.trim();
                            final age = int.tryParse(ageController.text.trim());

                            if (name.isEmpty) {
                              setModalState(() {
                                errorText = 'Please enter a full name.';
                              });
                              return;
                            }
                            if (age == null || age <= 0) {
                              setModalState(() {
                                errorText = 'Please enter a valid age.';
                              });
                              return;
                            }
                            if (selectedGender == null) {
                              setModalState(() {
                                errorText = 'Please select a gender.';
                              });
                              return;
                            }

                            try {
                              widget.database.updateMember(
                                id: member.id,
                                name: name,
                                age: age,
                                gender: selectedGender!,
                              );
                              Navigator.of(dialogContext).pop();
                              _loadData();
                            } catch (e) {
                              setModalState(() {
                                errorText = 'Failed to update member.';
                              });
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Save Changes'),
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
                      'Clear Database',
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
                  'This will permanently remove members, tasks, and assignments. '
                  'This action cannot be undone.',
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Clear Database'),
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
        _showMessage('Database cleared.');
      } catch (e) {
        _showMessage('Failed to clear database.');
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
                      'Mock Database',
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
                  'This will add 30 members and 8 tasks to the database.',
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Add Mock Data'),
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
        widget.database.insertMockData();
        await _loadData();
        _showMessage('Mock data added.');
      } catch (e) {
        _showMessage('Failed to add mock data.');
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
                          'Add New Task',
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
                      'Create a backstage task for the Avanco team.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Task Description',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Organize welcome kits',
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
                                'Limit assignment by gender',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (limitByGender) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'SELECT GENDER',
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
                                    label: const Text('Male Only'),
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
                                    label: const Text('Female Only'),
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
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            final name = taskController.text.trim();
                            if (name.isEmpty) {
                              setModalState(() {
                                errorText = 'Please enter a task description.';
                              });
                              return;
                            }
                            if (limitByGender && selectedGender == null) {
                              setModalState(() {
                                errorText = 'Please choose a gender.';
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
                                errorText = 'Failed to save task.';
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F5BFF),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Save Task'),
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
                          'Edit Task',
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
                      'Update the backstage task details.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Task Description',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Organize welcome kits',
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
                                'Limit assignment by gender',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (limitByGender) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'SELECT GENDER',
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
                                    label: const Text('Male Only'),
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
                                    label: const Text('Female Only'),
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
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            final name = taskController.text.trim();
                            if (name.isEmpty) {
                              setModalState(() {
                                errorText = 'Please enter a task description.';
                              });
                              return;
                            }
                            if (limitByGender && selectedGender == null) {
                              setModalState(() {
                                errorText = 'Please choose a gender.';
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
                                errorText = 'Failed to update task.';
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F5BFF),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Save Changes'),
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
        title: const Text('Avanco'),
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
                child: Text('Clear Database'),
              ),
              const PopupMenuItem(
                value: 'mock',
                child: Text('Mock Database'),
              ),
            ],
          ),
          IconButton(onPressed: null, icon: const Icon(Icons.help_outline)),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF3B82F6),
            child: Text(
              'AD',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 16),
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
      if (query.isEmpty) return true;
      return member.name.toLowerCase().contains(query);
    }).toList();

    final availableCount = _members.where((member) => !assignedIds.contains(member.id)).length;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EF)),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$availableCount Available',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search members...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF1F2F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
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
                      child: MemberCard(member: member, dense: true),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.5,
                    child: MemberCard(member: member, dense: true),
                  ),
                  child: MemberCard(
                    member: member,
                    dense: true,
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
            label: const Text('Add New Member'),
          ),
        ],
      ),
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
                    onPressed: _openAddTaskDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Task'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: _tasks.isEmpty
                ? const Center(child: Text('No tasks yet.'))
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
                          onMemberDoubleTap: _openEditMemberDialog,
                          onTaskDoubleTap: () => _openEditTaskDialog(task),
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
