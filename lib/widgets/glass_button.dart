import 'dart:ui';
import 'package:flutter/material.dart';

class GlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  const GlassButton({
    super.key,
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    /// 🔥 LOGICA CHIAVE:
    /// - tema scuro → bottone più CHIARO (glass chiaro)
    /// - tema chiaro → bottone più SCURO (glass scuro)
    final baseColor = isDark ? Colors.white : Colors.black;

    final backgroundColor = baseColor.withOpacity(isDark ? 0.12 : 0.08);
    final borderColor = baseColor.withOpacity(isDark ? 0.25 : 0.15);
    final textColor = isDark ? Colors.white : Colors.black;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: textColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}