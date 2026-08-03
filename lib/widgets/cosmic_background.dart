import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../core/theme/markfit_colors.dart';

// ─────────────────────────────────────────────────────────────
// CosmicBackground — sfondo adattivo light/dark.
//
// DARK:  stelle animate (Jarvis HUD)
// LIGHT: frost blobs radiali (iOS Liquid Glass)
//
// subtle = true → intensità ridotta (schermate secondary pushed)
// ─────────────────────────────────────────────────────────────

class CosmicBackground extends StatefulWidget {
  final Widget child;
  final bool   subtle;

  const CosmicBackground({
    super.key,
    required this.child,
    this.subtle = false,
  });

  @override
  State<CosmicBackground> createState() => _CosmicBackgroundState();
}

class _CosmicBackgroundState extends State<CosmicBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Star>          _stars;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 18))
      ..repeat();
    final count = widget.subtle ? 40 : 70;
    _stars = List.generate(count, (_) => _Star.random());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;

    return Stack(children: [

      // Base gradient
      Positioned.fill(child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: c.bgGradient)))),

      // Dark: stelle animate
      if (isDark)
        Positioned.fill(child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _StarPainter(
                stars: _stars, progress: _ctrl.value,
                subtle: widget.subtle)))),

      // Light: frost blobs colorati
      if (!isDark) ...[
        Positioned(right: -80, top: -80,
          child: _FrostBlob(
              size:    widget.subtle ? 200 : 280,
              color:   MarkFitColors.teal,
              opacity: widget.subtle ? 0.05 : 0.08)),
        Positioned(left: -60, bottom: 160,
          child: _FrostBlob(
              size:    widget.subtle ? 160 : 220,
              color:   MarkFitColors.blue,
              opacity: widget.subtle ? 0.04 : 0.07)),
        Positioned(right: 40, bottom: -40,
          child: _FrostBlob(
              size:    widget.subtle ? 130 : 180,
              color:   MarkFitColors.indigo,
              opacity: widget.subtle ? 0.03 : 0.06)),
      ],

      // Content
      Positioned.fill(child: widget.child),
    ]);
  }
}

class _Star {
  final double x, y, r, op, speed, phase;
  const _Star({required this.x, required this.y, required this.r,
      required this.op, required this.speed, required this.phase});
  factory _Star.random() {
    final rnd = math.Random();
    return _Star(
      x:     rnd.nextDouble(), y:  rnd.nextDouble(),
      r:     rnd.nextDouble() * 1.3 + 0.3,
      op:    rnd.nextDouble() * 0.55 + 0.1,
      speed: rnd.nextDouble() * 0.5 + 0.15,
      phase: rnd.nextDouble() * math.pi * 2);
  }
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double      progress;
  final bool        subtle;
  const _StarPainter({required this.stars, required this.progress,
      this.subtle = false});
  @override
  void paint(Canvas canvas, Size size) {
    final opFactor = subtle ? 0.6 : 1.0;
    for (final s in stars) {
      final twinkle = 0.45 + 0.55 * math.sin(
          progress * math.pi * 2 * s.speed + s.phase);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height), s.r,
        Paint()..color = Color.fromRGBO(255, 255, 255,
            (s.op * twinkle * opFactor).clamp(0.0, 1.0)));
    }
  }
  @override
  bool shouldRepaint(_StarPainter old) =>
      old.progress != progress || old.subtle != subtle;
}

class _FrostBlob extends StatelessWidget {
  final double size, opacity;
  final Color  color;
  const _FrostBlob({required this.size, required this.color,
      required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [
        color.withOpacity(opacity),
        color.withOpacity(0.0)])));
}