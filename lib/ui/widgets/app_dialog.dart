import 'package:flutter/material.dart';

class AppDialog extends StatelessWidget {
  static const Color background = Color(0xFFF9FBFD);
  static const Color inputFill = Color(0xFFE9EFF2);
  static const Color sectionFill = Color(0xFFF1F5F7);
  static const Color primaryButton = Color(0xFF0F5BFF);

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final double width;
  final VoidCallback? onClose;

  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.subtitle,
    this.width = 420,
    this.onClose,
  });

  static ButtonStyle outlinedStyle({Color? foreground}) {
    return OutlinedButton.styleFrom(
      foregroundColor: foreground ?? const Color(0xFF1D1D1D),
      side: const BorderSide(color: Color(0xFFB3DFE9)),
      padding: const EdgeInsets.symmetric(vertical: 12),
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  static ButtonStyle primaryStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: primaryButton,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  static ButtonStyle destructiveStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFDC2626),
      side: const BorderSide(color: Color(0xFFF3B4B4)),
      padding: const EdgeInsets.symmetric(vertical: 12),
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: background,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onClose ?? () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 16),
            child,
            const SizedBox(height: 24),
            Row(children: actions),
          ],
        ),
      ),
    );
  }
}
