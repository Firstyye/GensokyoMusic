import 'package:flutter/material.dart';
import '../constant/my_constant.dart';

class ModernSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDestructive;
  final VoidCallback? onTap;
  final Widget? trailing; // Useful for Switches or custom indicators

  const ModernSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.isDestructive = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final Color itemColor = isDestructive ? dangerDarkColor : Colors.white;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.02),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: itemColor.withValues(alpha: 0.9), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: bodyTextStyle.copyWith(
                  color: itemColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (!isDestructive)
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
