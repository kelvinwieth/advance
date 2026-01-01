import 'package:flutter/material.dart';

import '../../data/models.dart';
import 'member_card.dart';

class TaskColumn extends StatelessWidget {
  final Task task;
  final Color accentColor;
  final List<TaskAssignment> assignments;
  final void Function(Member member) onMemberDropped;

  const TaskColumn({
    super.key,
    required this.task,
    required this.accentColor,
    required this.assignments,
    required this.onMemberDropped,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Member>(
      onAcceptWithDetails: (details) => onMemberDropped(details.data),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFF0F6FF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? accentColor : const Color(0xFFE6E8EF),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.name,
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
                      assignments.length.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (assignments.isEmpty)
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
                        'Drag members here',
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
                    itemCount: assignments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final assignment = assignments[index];
                      return MemberCard(
                        member: assignment.member,
                        showStatus: true,
                        dense: true,
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: null,
                child: const Text('+ Add card'),
              ),
            ],
          ),
        );
      },
    );
  }
}
