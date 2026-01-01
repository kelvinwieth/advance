import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avanco'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(onPressed: null, icon: const Icon(Icons.settings)),
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
                  child: MemberCard(member: member, dense: true),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: null,
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
