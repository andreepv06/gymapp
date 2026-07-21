import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// MarkFit Design System — Jarvis Glass UI
// ─────────────────────────────────────────────────────────────
//
// Integrazione in main.dart:
//   MaterialApp(
//     theme:     AppTheme.light(),
//     darkTheme: AppTheme.dark(),
//     themeMode: ThemeMode.system,
//   )
//
// Utilizzo:
//   context.mkTheme.accent        → Color
//   context.mkTheme.glassBg       → Color
//   GlassColors.accent(context)   → Color (helper statico)
// ─────────────────────────────────────────────────────────────

// ── Costanti colore raw ───────────────────────────────────────

class MarkFitColors {
  MarkFitColors._();

  // Dark palette — Jarvis HUD
  static const Color dkBackground = Color(0xFF0A0A0E);
  static const Color dkSurface    = Color(0xFF0D0D12);
  static const Color dkCyan       = Color(0xFF00E5FF);
  static const Color dkTeal       = Color(0xFF00D4AA);
  static const Color dkSuccess    = Color(0xFF00FF88);
  static const Color dkError      = Color(0xFFFF3040);
  static const Color dkWarning    = Color(0xFFFF8C00);
  static const Color dkIndigo     = Color(0xFF6366F1);
  static const Color dkPurple     = Color(0xFF8A2BE2);
  static const Color dkText       = Color(0xFFFFFFFF);
  static const Color dkTextSub    = Color(0xB3FFFFFF);
  static const Color dkTextTert   = Color(0x73FFFFFF);

  // Light palette — iOS Frost Glass
  static const Color ltBackground = Color(0xFFF4F6FA);
  static const Color ltSurface    = Color(0xFFFFFFFF);
  static const Color ltBlue       = Color(0xFF007AFF);
  static const Color ltTeal       = Color(0xFF00A884);
  static const Color ltSuccess    = Color(0xFF34C759);
  static const Color ltError      = Color(0xFFFF3B30);
  static const Color ltWarning    = Color(0xFFFF9500);
  static const Color ltIndigo     = Color(0xFF5856D6);
  static const Color ltText       = Color(0xFF1C1C1E);
  static const Color ltTextSub    = Color(0xFF8E8E93);
  static const Color ltTextTert   = Color(0xFFAEAEB2);
}

// ── ThemeExtension — token centralizzati ─────────────────────

@immutable
class MarkFitThemeData extends ThemeExtension<MarkFitThemeData> {
  const MarkFitThemeData({
    required this.background,
    required this.surface,
    required this.accent,
    required this.teal,
    required this.success,
    required this.error,
    required this.warning,
    required this.indigo,
    required this.purple,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.glassBg,
    required this.glassBgStrong,
    required this.glassBorder,
    required this.glassBlur,
    required this.glowOpacity,
  });

  final Color  background;
  final Color  surface;
  final Color  accent;
  final Color  teal;
  final Color  success;
  final Color  error;
  final Color  warning;
  final Color  indigo;
  final Color  purple;
  final Color  textPrimary;
  final Color  textSecondary;
  final Color  textTertiary;
  final Color  glassBg;
  final Color  glassBgStrong;
  final Color  glassBorder;
  final double glassBlur;
  final double glowOpacity;

  // ── Preset dark ─────────────────────────────────────────────

  static const dark = MarkFitThemeData(
    background:    MarkFitColors.dkBackground,
    surface:       MarkFitColors.dkSurface,
    accent:        MarkFitColors.dkCyan,
    teal:          MarkFitColors.dkTeal,
    success:       MarkFitColors.dkSuccess,
    error:         MarkFitColors.dkError,
    warning:       MarkFitColors.dkWarning,
    indigo:        MarkFitColors.dkIndigo,
    purple:        MarkFitColors.dkPurple,
    textPrimary:   MarkFitColors.dkText,
    textSecondary: MarkFitColors.dkTextSub,
    textTertiary:  MarkFitColors.dkTextTert,
    glassBg:       Color(0x0DFFFFFF),
    glassBgStrong: Color(0x14FFFFFF),
    glassBorder:   Color(0x3300E5FF),
    glassBlur:     12,
    glowOpacity:   0.25,
  );

  // ── Preset light ─────────────────────────────────────────────

  static const light = MarkFitThemeData(
    background:    MarkFitColors.ltBackground,
    surface:       MarkFitColors.ltSurface,
    accent:        MarkFitColors.ltBlue,
    teal:          MarkFitColors.ltTeal,
    success:       MarkFitColors.ltSuccess,
    error:         MarkFitColors.ltError,
    warning:       MarkFitColors.ltWarning,
    indigo:        MarkFitColors.ltIndigo,
    purple:        Color(0xFF7C3AED),
    textPrimary:   MarkFitColors.ltText,
    textSecondary: MarkFitColors.ltTextSub,
    textTertiary:  MarkFitColors.ltTextTert,
    glassBg:       Color(0xA6FFFFFF),
    glassBgStrong: Color(0xCCFFFFFF),
    glassBorder:   Color(0x26007AFF),
    glassBlur:     15,
    glowOpacity:   0.12,
  );

  // ── Helper opacità ─────────────────────────────────────────

  Color accentWith(double o)  => accent.withOpacity(o);
  Color tealWith(double o)    => teal.withOpacity(o);
  Color errorWith(double o)   => error.withOpacity(o);
  Color warningWith(double o) => warning.withOpacity(o);
  Color indigoWith(double o)  => indigo.withOpacity(o);
  Color purpleWith(double o)  => purple.withOpacity(o);

  @override
  MarkFitThemeData copyWith({
    Color? background, Color? surface, Color? accent, Color? teal,
    Color? success, Color? error, Color? warning, Color? indigo,
    Color? purple, Color? textPrimary, Color? textSecondary,
    Color? textTertiary, Color? glassBg, Color? glassBgStrong,
    Color? glassBorder, double? glassBlur, double? glowOpacity,
  }) => MarkFitThemeData(
    background:    background    ?? this.background,
    surface:       surface       ?? this.surface,
    accent:        accent        ?? this.accent,
    teal:          teal          ?? this.teal,
    success:       success       ?? this.success,
    error:         error         ?? this.error,
    warning:       warning       ?? this.warning,
    indigo:        indigo        ?? this.indigo,
    purple:        purple        ?? this.purple,
    textPrimary:   textPrimary   ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary:  textTertiary  ?? this.textTertiary,
    glassBg:       glassBg       ?? this.glassBg,
    glassBgStrong: glassBgStrong ?? this.glassBgStrong,
    glassBorder:   glassBorder   ?? this.glassBorder,
    glassBlur:     glassBlur     ?? this.glassBlur,
    glowOpacity:   glowOpacity   ?? this.glowOpacity,
  );

  @override
  MarkFitThemeData lerp(MarkFitThemeData? other, double t) {
    if (other == null) return this;
    return MarkFitThemeData(
      background:    Color.lerp(background,    other.background,    t)!,
      surface:       Color.lerp(surface,       other.surface,       t)!,
      accent:        Color.lerp(accent,        other.accent,        t)!,
      teal:          Color.lerp(teal,          other.teal,          t)!,
      success:       Color.lerp(success,       other.success,       t)!,
      error:         Color.lerp(error,         other.error,         t)!,
      warning:       Color.lerp(warning,       other.warning,       t)!,
      indigo:        Color.lerp(indigo,        other.indigo,        t)!,
      purple:        Color.lerp(purple,        other.purple,        t)!,
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary:  Color.lerp(textTertiary,  other.textTertiary,  t)!,
      glassBg:       Color.lerp(glassBg,       other.glassBg,       t)!,
      glassBgStrong: Color.lerp(glassBgStrong, other.glassBgStrong, t)!,
      glassBorder:   Color.lerp(glassBorder,   other.glassBorder,   t)!,
      glassBlur:     lerpDouble(glassBlur,     other.glassBlur,     t)!,
      glowOpacity:   lerpDouble(glowOpacity,   other.glowOpacity,   t)!,
    );
  }
}

// ── BuildContext extension ────────────────────────────────────

extension MarkFitThemeX on BuildContext {
  MarkFitThemeData get mkTheme =>
      Theme.of(this).extension<MarkFitThemeData>() ??
      MarkFitThemeData.dark;

  bool get isDarkMode =>
      Theme.of(this).brightness == Brightness.dark;
}

// ── GlassColors — helper statico per le schermate ─────────────
// Utilizzo:
//   color: GlassColors.accent(context)
//   color: GlassColors.card(context)

class GlassColors {
  GlassColors._();

  static Color background(BuildContext context) =>
      context.mkTheme.background;

  static Color surface(BuildContext context) =>
      context.mkTheme.surface;

  static Color card(BuildContext context) =>
      context.mkTheme.glassBg;

  static Color cardStrong(BuildContext context) =>
      context.mkTheme.glassBgStrong;

  static Color border(BuildContext context) =>
      context.mkTheme.glassBorder;

  static Color accent(BuildContext context) =>
      context.mkTheme.accent;

  static Color primary(BuildContext context) =>
      context.mkTheme.teal;

  static Color error(BuildContext context) =>
      context.mkTheme.error;

  static Color warning(BuildContext context) =>
      context.mkTheme.warning;

  static Color success(BuildContext context) =>
      context.mkTheme.success;

  static Color indigo(BuildContext context) =>
      context.mkTheme.indigo;

  static Color purple(BuildContext context) =>
      context.mkTheme.purple;

  static Color text(BuildContext context) =>
      context.mkTheme.textPrimary;

  static Color textSub(BuildContext context) =>
      context.mkTheme.textSecondary;

  static Color textTert(BuildContext context) =>
      context.mkTheme.textTertiary;

  static double blur(BuildContext context) =>
      context.mkTheme.glassBlur;

  static double glow(BuildContext context) =>
      context.mkTheme.glowOpacity;
}

// ── GlassDimensions — spacing e radius coerenti ───────────────

class GlassDimensions {
  GlassDimensions._();

  static const double radiusXS  = 8;
  static const double radiusSM  = 12;
  static const double radiusMD  = 16;
  static const double radiusLG  = 20;
  static const double radiusXL  = 24;
  static const double radius2XL = 28;

  static const double blurLight  = 8;
  static const double blurMedium = 12;
  static const double blurStrong = 16;
  static const double blurXL     = 24;

  static const double spacingXS = 6;
  static const double spacingSM = 10;
  static const double spacingMD = 16;
  static const double spacingLG = 20;
  static const double spacingXL = 28;

  static const double borderThin   = 0.8;
  static const double borderMedium = 1.0;
  static const double borderStrong = 1.5;
}

// ── AppTheme factory ─────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness:   Brightness.dark,
    scaffoldBackgroundColor: MarkFitColors.dkBackground,
    colorScheme: const ColorScheme.dark(
      primary:   MarkFitColors.dkTeal,
      secondary: MarkFitColors.dkCyan,
      error:     MarkFitColors.dkError,
      surface:   MarkFitColors.dkSurface,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      MarkFitThemeData.dark,
    ],
  );

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness:   Brightness.light,
    scaffoldBackgroundColor: MarkFitColors.ltBackground,
    colorScheme: const ColorScheme.light(
      primary:   MarkFitColors.ltTeal,
      secondary: MarkFitColors.ltBlue,
      error:     MarkFitColors.ltError,
      surface:   MarkFitColors.ltSurface,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      MarkFitThemeData.light,
    ],
  );
}