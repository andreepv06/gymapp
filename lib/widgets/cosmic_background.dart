import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'jarvis_theme.dart';

class CosmicBackground extends StatelessWidget {
  final Widget child;
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
        // Gradiente base OLED
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: subtle
                  ? const [
                      Color(0xFF03040A),
                      Color(0xFF060B14),
                      Color(0xFF03040A),
                    ]
                  : const [
                      Color(0xFF03040A),
                      Color(0xFF060B14),
                      Color(0xFF0A0F1E),
                      Color(0xFF03040A),
                    ],
            ),
          ),
        ),

        // Nebulosa viola — top left
        Positioned(
          top: -120,
          left: -100,
          child: _NebulaBlob(
            size: 380,
            color: const Color(0xFF4A1578),
            opacity: subtle ? 0.14 : 0.20,
          ),
        ),

        // Nebulosa cyan — right center (HUD accent)
        Positioned(
          top: 180,
          right: -120,
          child: _NebulaBlob(
            size: 260,
            color: const Color(0xFF004D5C),
            opacity: subtle ? 0.10 : 0.15,
          ),
        ),

        // Accento teal — bottom left
        Positioned(
          bottom: -80,
          left: -60,
          child: _NebulaBlob(
            size: 220,
            color: const Color(0xFF004D44),
            opacity: subtle ? 0.08 : 0.12,
          ),
        ),

        // Campo stellare
        const Positioned.fill(child: _StarField()),

        // Griglia HUD leggera (linee sottili orizzontali)
        if (!subtle)
          Positioned.fill(
            child: CustomPaint(painter: _HudGridPainter()),
          ),

        // Contenuto
        child,
      ],
    );
  }
}

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
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(opacity),
              color.withOpacity(opacity * 0.35),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _StarPainter());
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rng = math.Random(42);

    for (int i = 0; i < 90; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final radius = rng.nextDouble() * 1.1 + 0.2;
      final opacity = rng.nextDouble() * 0.4 + 0.05;
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Stelle cyan — accento HUD
    final rng2 = math.Random(99);
    for (int i = 0; i < 8; i++) {
      final x = rng2.nextDouble() * size.width;
      final y = rng2.nextDouble() * size.height;
      paint.color =
          JarvisTheme.cyan.withOpacity(0.5 + rng2.nextDouble() * 0.3);
      canvas.drawCircle(Offset(x, y), 1.2, paint);
      // Micro-glow
      paint.color = JarvisTheme.cyan.withOpacity(0.08);
      canvas.drawCircle(Offset(x, y), 4, paint);
    }

    // Stelle luminose bianche
    final rng3 = math.Random(137);
    for (int i = 0; i < 12; i++) {
      final x = rng3.nextDouble() * size.width;
      final y = rng3.nextDouble() * size.height;
      paint.color =
          Colors.white.withOpacity(0.6 + rng3.nextDouble() * 0.35);
      canvas.drawCircle(Offset(x, y), 1.3, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}

class _HudGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JarvisTheme.cyan.withOpacity(0.025)
      ..strokeWidth = 0.5;

    // Linee orizzontali sottili — effetto HUD
    const spacing = 80.0;
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_HudGridPainter old) => false;
}