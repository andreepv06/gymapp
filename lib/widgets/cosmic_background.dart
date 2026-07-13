import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Sfondo cosmico glass riutilizzabile.
/// Fornisce gradiente spaziale, nebulosa sfocata e campo stellare.
class CosmicBackground extends StatelessWidget {
  final Widget child;

  /// Se true usa una variante leggermente più chiara per sottopagine.
  final bool subtle;

  const CosmicBackground({
    super.key,
    required this.child,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradiente base spaziale
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: subtle
                  ? const [
                      Color(0xFF0C0918),
                      Color(0xFF100B22),
                      Color(0xFF0A0A16),
                    ]
                  : const [
                      Color(0xFF06060F),
                      Color(0xFF0D0820),
                      Color(0xFF130B2A),
                      Color(0xFF080810),
                    ],
            ),
          ),
        ),

        // Nebulosa viola — in alto a sinistra
        Positioned(
          top: -110,
          left: -90,
          child: _NebulaBlob(
            size: 380,
            color: const Color(0xFF7C3AED),
            opacity: subtle ? 0.16 : 0.22,
          ),
        ),

        // Nebulosa blu-indaco — destra centrale
        Positioned(
          top: 200,
          right: -130,
          child: _NebulaBlob(
            size: 290,
            color: const Color(0xFF1D4ED8),
            opacity: subtle ? 0.12 : 0.17,
          ),
        ),

        // Accento teal — basso sinistra
        Positioned(
          bottom: -70,
          left: -50,
          child: _NebulaBlob(
            size: 230,
            color: const Color(0xFF0E7490),
            opacity: subtle ? 0.10 : 0.14,
          ),
        ),

        // Campo stellare statico
        const Positioned.fill(child: _StarField()),

        // Contenuto dell'app
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _NebulaBlob
// ─────────────────────────────────────────────────────────────

class _NebulaBlob extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _NebulaBlob({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(opacity),
              color.withOpacity(opacity * 0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _StarField
// ─────────────────────────────────────────────────────────────

class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _StarPainter());
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint();

    // Stelle base
    for (int i = 0; i < 100; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final radius = rng.nextDouble() * 1.2 + 0.2;
      final opacity = rng.nextDouble() * 0.5 + 0.08;
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Stelle luminose rare
    final rng2 = math.Random(137);
    for (int i = 0; i < 14; i++) {
      final x = rng2.nextDouble() * size.width;
      final y = rng2.nextDouble() * size.height;
      paint.color =
          Colors.white.withOpacity(0.65 + rng2.nextDouble() * 0.35);
      canvas.drawCircle(Offset(x, y), 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}