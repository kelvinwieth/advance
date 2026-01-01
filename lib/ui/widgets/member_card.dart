import 'package:flutter/material.dart';

import '../../data/models.dart';

class MemberCard extends StatelessWidget {
  final Member member;
  final bool showStatus;
  final bool dense;
  final VoidCallback? onDoubleTap;

  const MemberCard({
    super.key,
    required this.member,
    this.showStatus = false,
    this.dense = false,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final parts = member.name.trim().split(RegExp(r'\\s+')).where((part) => part.isNotEmpty);
    final initials = parts.isNotEmpty
        ? parts.map((part) => part[0]).take(2).join()
        : '?';

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
              backgroundColor: const Color(0xFFE8F0FF),
              child: Text(
                initials.toUpperCase(),
                style: TextStyle(
                  color: const Color(0xFF1D4ED8),
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
                  const SizedBox(height: 4),
                  Text(
                    'Age: ${member.age}',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: dense ? 12 : 13,
                    ),
                  ),
                ],
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
                  'Active',
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
