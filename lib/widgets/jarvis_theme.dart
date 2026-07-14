import 'dart:ui';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// JARVIS GLASS — Design System Unificato
// Combina iOS 26 Glassmorphism + HUD Olografico stile Iron Man
// ─────────────────────────────────────────────────────────────

class JarvisTheme {
  JarvisTheme._();

  // ── Colori base ───────────────────────────────────────────
  static const Color bgPrimary = Color(0xFF03040A);
  static const Color bgSecondary = Color(0xFF060B14);
  static const Color bgTertiary = Color(0xFF0A0F1E);

  // Cyan Neon (bordi HUD)
  static const Color cyan = Color(0xFF00E5FF);
  static const Color cyanDim = Color(0xFF0097A7);
  static const Color cyanGlow = Color(0xFF00B8D4);

  // Teal (azioni primarie)
  static const Color teal = Color(0xFF00D4AA);
  static const Color tealDark = Color(0xFF00A880);

  // Palette sessioni/stato
  static const Color orange = Color(0xFFFF8C00);
  static const Color orangeWarm = Color(0xFFFF6B00);
  static const Color green = Color(0xFF00E676);
  static const Color greenDark = Color(0xFF00C853);
  static const Color red = Color(0xFFFF1744);

  // ── Glass container helpers ───────────────────────────────

  static BoxDecoration glassDecoration({
    Color borderColor = const Color(0xFF00E5FF),
    double borderOpacity = 0.25,
    double borderWidth = 0.8,
    double bgOpacity = 0.06,
    BorderRadius? radius,
    List<BoxShadow>? shadows,
    Gradient? gradient,
  }) {
    return BoxDecoration(
      gradient: gradient ??
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(bgOpacity + 0.02),
              Colors.white.withOpacity(bgOpacity - 0.01),
            ],
          ),
      borderRadius: radius ?? BorderRadius.circular(18),
      border: Border.all(
        color: borderColor.withOpacity(borderOpacity),
        width: borderWidth,
      ),
      boxShadow: shadows,
    );
  }

  static BoxDecoration glassDecorationCyan({
    double borderOpacity = 0.3,
    double glowOpacity = 0.12,
    double bgOpacity = 0.06,
    BorderRadius? radius,
  }) {
    return glassDecoration(
      borderColor: cyan,
      borderOpacity: borderOpacity,
      bgOpacity: bgOpacity,
      radius: radius,
      shadows: [
        BoxShadow(
          color: cyan.withOpacity(glowOpacity),
          blurRadius: 20,
          spreadRadius: 1,
        ),
      ],
    );
  }

  static BoxDecoration glassDecorationTeal({
    double borderOpacity = 0.35,
    double glowOpacity = 0.15,
    BorderRadius? radius,
  }) {
    return glassDecoration(
      borderColor: teal,
      borderOpacity: borderOpacity,
      radius: radius,
      shadows: [
        BoxShadow(
          color: teal.withOpacity(glowOpacity),
          blurRadius: 24,
          spreadRadius: 1,
        ),
      ],
    );
  }

  static BoxDecoration glassDecorationOrange({
    double borderOpacity = 0.4,
    double glowOpacity = 0.18,
    BorderRadius? radius,
  }) {
    return glassDecoration(
      borderColor: orange,
      borderOpacity: borderOpacity,
      radius: radius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          orange.withOpacity(0.15),
          orangeWarm.withOpacity(0.07),
        ],
      ),
      shadows: [
        BoxShadow(
          color: orange.withOpacity(glowOpacity),
          blurRadius: 28,
          spreadRadius: 1,
        ),
      ],
    );
  }

  // ── Icone/colori schede ───────────────────────────────────

  static const List<Color> workoutColors = [
    Color(0xFF00D4AA), // 0 teal
    Color(0xFF6366F1), // 1 indigo
    Color(0xFF22C55E), // 2 green
    Color(0xFFF59E0B), // 3 amber
    Color(0xFFEC4899), // 4 pink
    Color(0xFFEF4444), // 5 red
    Color(0xFF3B82F6), // 6 blue
    Color(0xFF8B5CF6), // 7 purple
    Color(0xFF00E5FF), // 8 cyan
    Color(0xFFFF6B00), // 9 orange
  ];

  static const List<(String, IconData)> workoutIcons = [
    ('dumbbell', Icons.fitness_center_rounded),
    ('bike', Icons.directions_bike_rounded),
    ('run', Icons.directions_run_rounded),
    ('swim', Icons.pool_rounded),
    ('yoga', Icons.self_improvement_rounded),
    ('sports', Icons.sports_rounded),
    ('heart', Icons.favorite_rounded),
    ('star', Icons.star_rounded),
    ('flash', Icons.bolt_rounded),
    ('target', Icons.track_changes_rounded),
    ('mountain', Icons.terrain_rounded),
    ('fire', Icons.local_fire_department_rounded),
  ];

  // ── Testi ─────────────────────────────────────────────────
  static TextStyle labelCyan({double size = 11}) => TextStyle(
        color: cyan,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      );

  static TextStyle titleWhite({double size = 20}) =>
      TextStyle(
        color: Colors.white,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      );

  static TextStyle subtitleDim({double size = 13}) =>
      TextStyle(
        color: Colors.white.withOpacity(0.45),
        fontSize: size,
        fontWeight: FontWeight.w400,
      );
}

// ─────────────────────────────────────────────────────────────
// JarvisContainer — wrapper glass universale
// ─────────────────────────────────────────────────────────────

class JarvisContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BoxDecoration? decoration;
  final double blurX;
  final double blurY;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double borderOpacity;
  final double glowOpacity;
  final Color? glowColor;

  const JarvisContainer({
    super.key,
    required this.child,
    this.padding,
    this.decoration,
    this.blurX = 14,
    this.blurY = 14,
    this.borderRadius,
    this.borderColor,
    this.borderOpacity = 0.28,
    this.glowOpacity = 0.0,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(18);
    final bc = borderColor ?? JarvisTheme.cyan;

    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
        child: Container(
          padding: padding,
          decoration: decoration ??
              BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.03),
                  ],
                ),
                borderRadius: br,
                border: Border.all(
                  color: bc.withOpacity(borderOpacity),
                  width: 0.8,
                ),
                boxShadow: glowOpacity > 0 && glowColor != null
                    ? [
                        BoxShadow(
                          color: glowColor!.withOpacity(
                              glowOpacity),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// JarvisButton — pulsante glass con glow dinamico
// ─────────────────────────────────────────────────────────────

class JarvisButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final bool outlined;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double glowOpacity;

  const JarvisButton({
    super.key,
    required this.child,
    this.onTap,
    this.color = JarvisTheme.teal,
    this.outlined = false,
    this.padding =
        const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
    this.borderRadius,
    this.glowOpacity = 0.35,
  });

  @override
  State<JarvisButton> createState() => _JarvisButtonState();
}

class _JarvisButtonState extends State<JarvisButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final br =
        widget.borderRadius ?? BorderRadius.circular(14);
    final enabled = widget.onTap != null;
    final color =
        enabled ? widget.color : Colors.white.withOpacity(0.2);

    return GestureDetector(
      onTapDown: (_) {
        if (enabled) _ctrl.forward();
      },
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: ClipRRect(
          borderRadius: br,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                gradient: widget.outlined
                    ? LinearGradient(colors: [
                        color.withOpacity(0.12),
                        color.withOpacity(0.06),
                      ])
                    : LinearGradient(colors: [
                        color,
                        Color.lerp(color,
                            Colors.black, 0.25) ??
                            color,
                      ]),
                borderRadius: br,
                border: Border.all(
                  color: color.withOpacity(
                      widget.outlined ? 0.6 : 0.0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(
                        enabled ? widget.glowOpacity : 0.0),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: widget.outlined ? color : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// JarvisHudLine — linea decorativa HUD orizzontale
// ─────────────────────────────────────────────────────────────

class JarvisHudLine extends StatelessWidget {
  final Color color;
  final double opacity;
  final double height;

  const JarvisHudLine({
    super.key,
    this.color = JarvisTheme.cyan,
    this.opacity = 0.18,
    this.height = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            color.withOpacity(opacity),
            color.withOpacity(opacity * 1.5),
            color.withOpacity(opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// JarvisSheetHandle — handle pill Glass per bottom sheet
// ─────────────────────────────────────────────────────────────

class JarvisSheetHandle extends StatelessWidget {
  const JarvisSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              JarvisTheme.cyan.withOpacity(0.3),
              JarvisTheme.teal.withOpacity(0.5),
              JarvisTheme.cyan.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: JarvisTheme.teal.withOpacity(0.3),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// JarvisStatChip — chip info con icona + label
// ─────────────────────────────────────────────────────────────

class JarvisStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const JarvisStatChip({
    super.key,
    required this.icon,
    required this.label,
    this.color = JarvisTheme.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Utility: showJarvisSheet — wrapper tastiera-safe
// ─────────────────────────────────────────────────────────────

Future<T?> showJarvisSheet<T>(
  BuildContext context, {
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => GestureDetector(
      onTap: () => FocusScope.of(ctx).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: child,
          ),
        ),
      ),
    ),
  );
}