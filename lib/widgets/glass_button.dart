import 'dart:ui';
import 'package:flutter/material.dart';

class GlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final double? minWidth;

  const GlassButton({
    super.key,
    required this.onTap,
    required this.icon,
    required this.label,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Usa cs.primary come base — garantisce sempre contrasto con cs.onPrimary
    final baseColor = cs.primary;
    final fgColor = cs.onPrimary;
    final borderColor = Colors.white.withOpacity(isDark ? 0.15 : 0.35);
    final glassOverlay = Colors.white.withOpacity(isDark ? 0.08 : 0.18);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: minWidth ?? double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1.2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [glassOverlay, Colors.transparent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: fgColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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