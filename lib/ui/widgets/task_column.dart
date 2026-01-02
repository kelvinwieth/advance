import 'package:flutter/material.dart';

import '../../data/models.dart';
import 'member_card.dart';

class TaskColumn extends StatefulWidget {
  final Task task;
  final Color accentColor;
  final List<TaskAssignment> assignments;
  final void Function(Member member) onMemberDropped;
  final void Function(Member member)? onMemberDoubleTap;
  final VoidCallback? onTaskDoubleTap;
  final void Function(int memberId, int taskId)? onRemoveAssignment;

  const TaskColumn({
    super.key,
    required this.task,
    required this.accentColor,
    required this.assignments,
    required this.onMemberDropped,
    this.onMemberDoubleTap,
    this.onTaskDoubleTap,
    this.onRemoveAssignment,
  });

  @override
  State<TaskColumn> createState() => _TaskColumnState();
}

class _TaskColumnState extends State<TaskColumn> {
  bool _showRemoveZone = false;

  void _setRemoveZoneVisible(bool visible) {
    if (_showRemoveZone == visible) return;
    setState(() {
      _showRemoveZone = visible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final genderTint = widget.task.genderConstraint == 'M'
        ? const Color(0xFFF5F9FF)
        : widget.task.genderConstraint == 'F'
            ? const Color(0xFFFFF7FB)
            : Colors.white;
    final subtitle = widget.task.genderConstraint == 'M'
        ? 'Somente homens'
        : widget.task.genderConstraint == 'F'
            ? 'Somente mulheres'
            : null;

    return DragTarget<Member>(
      onAcceptWithDetails: (details) => widget.onMemberDropped(details.data),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFF0F6FF) : genderTint,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? widget.accentColor : const Color(0xFFE6E8EF),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onDoubleTap: widget.onTaskDoubleTap,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.task.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F2F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                      widget.assignments.length.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      ),
                    ),
                  ],
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      widget.task.genderConstraint == 'M' ? Icons.male : Icons.female,
                      size: 14,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              if (widget.assignments.isEmpty)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFD6D9E0),
                        style: BorderStyle.solid,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFFFAFBFF),
                    ),
                    child: Center(
                      child: Text(
                        'Arraste membros aqui',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: widget.assignments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final assignment = widget.assignments[index];
                      return Draggable<_AssignmentDragData>(
                        data: _AssignmentDragData(
                          memberId: assignment.member.id,
                          taskId: assignment.taskId,
                        ),
                        onDragStarted: () => _setRemoveZoneVisible(true),
                        onDragEnd: (_) => _setRemoveZoneVisible(false),
                        onDragCompleted: () => _setRemoveZoneVisible(false),
                        onDraggableCanceled: (_, __) => _setRemoveZoneVisible(false),
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 220,
                            child: MemberCard(
                              member: assignment.member,
                              dense: true,
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.5,
                          child: MemberCard(
                            member: assignment.member,
                            dense: true,
                            onDoubleTap: widget.onMemberDoubleTap == null
                                ? null
                                : () => widget.onMemberDoubleTap!(assignment.member),
                          ),
                        ),
                        child: MemberCard(
                          member: assignment.member,
                          dense: true,
                          onDoubleTap: widget.onMemberDoubleTap == null
                              ? null
                              : () => widget.onMemberDoubleTap!(assignment.member),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _showRemoveZone
                    ? DragTarget<_AssignmentDragData>(
                        onAcceptWithDetails: (details) {
                          final data = details.data;
                          if (widget.onRemoveAssignment != null && data.taskId == widget.task.id) {
                            widget.onRemoveAssignment!(data.memberId, data.taskId);
                          }
                        },
                        builder: (context, candidateData, rejectedData) {
                          final isActive = candidateData.isNotEmpty;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 56,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFFEE2E2) : const Color(0xFFF7F8FB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isActive ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB),
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                                SizedBox(width: 8),
                                Text(
                                  'Arraste aqui para remover',
                                  style: TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: null,
                child: const Text('+ Adicionar cartão'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AssignmentDragData {
  final int memberId;
  final int taskId;

  const _AssignmentDragData({
    required this.memberId,
    required this.taskId,
  });
}
