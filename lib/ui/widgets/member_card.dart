import 'package:flutter/material.dart';

import '../../data/models.dart';

class MemberCard extends StatelessWidget {
  final Member member;
  final bool showStatus;
  final bool dense;
  final VoidCallback? onDoubleTap;
  final int? taskCount;

  const MemberCard({
    super.key,
    required this.member,
    this.showStatus = false,
    this.dense = false,
    this.onDoubleTap,
    this.taskCount,
  });

  @override
  Widget build(BuildContext context) {
    final parts =
        member.name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first[0]
            : '${parts.first[0]}${parts.last[0]}';

    final avatarBackgroundColor = member.gender == 'M'
        ? const Color(0xFFE8F0FF)
        : const Color(0xFFFFE7F3);
    final avatarTextColor = member.gender == 'M'
        ? const Color(0xFF1D4ED8)
        : const Color(0xFFBE185D);

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: EdgeInsets.all(dense ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1E4EA)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: dense ? 18 : 20,
            backgroundColor: avatarBackgroundColor,
            child: Text(
              initials.toUpperCase(),
              style: TextStyle(
                color: avatarTextColor,
                fontWeight: FontWeight.w600,
                fontSize: dense ? 12 : 14,
              ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: TextStyle(
                      fontSize: dense ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${member.age}, ${member.church}',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: dense ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
            if (taskCount != null)
              Text(
                taskCount.toString(),
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: dense ? 12 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (showStatus)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDFF7E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Ativo',
                  style: TextStyle(
                    color: Color(0xFF118C4F),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
