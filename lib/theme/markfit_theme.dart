import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// MarkFit Design System — Jarvis Glass UI
// ─────────────────────────────────────────────────────────────
// Integrazione in MaterialApp:
//   theme:     AppTheme.light()
//   darkTheme: AppTheme.dark()
//
// Utilizzo nelle schermate:
//   context.mkTheme.accent       → colore accent tema-aware
//   context.mkTheme.glassBg      → sfondo card glass
//   context.isDarkMode           → bool
//
// Fallback sicuro: se il tema non è registrato restituisce dark.
// ─────────────────────────────────────────────────────────────

// ── Costanti colore raw ───────────────────────────────────────

class MarkFitColors {
  MarkFitColors._();

  // Dark palette — Jarvis HUD
  static const Color dkBackground    = Color(0xFF0A0A0E);
  static const Color dkSurface       = Color(0xFF0D0D12);
  static const Color dkCyan          = Color(0xFF00E5FF); // Jarvis accent
  static const Color dkTeal          = Color(0xFF00D4AA); // primary action
  static const Color dkSuccess       = Color(0xFF00FF88);
  static const Color dkError         = Color(0xFFFF3040);
  static const Color dkWarning       = Color(0xFFFF8C00);
  static const Color dkIndigo        = Color(0xFF6366F1);
  static const Color dkText          = Color(0xFFFFFFFF);
  static const Color dkTextSub       = Color(0xB3FFFFFF); // white70
  static const Color dkTextTert      = Color(0x73FFFFFF); // white45

  // Light palette — iOS Glass
  static const Color ltBackground    = Color(0xFFF4F6FA);
  static const Color ltSurface       = Color(0xFFFFFFFF);
  static const Color ltBlue          = Color(0xFF007AFF); // iOS accent
  static const Color ltTeal          = Color(0xFF00A884);
  static const Color ltSuccess       = Color(0xFF34C759);
  static const Color ltError         = Color(0xFFFF3B30);
  static const Color ltWarning       = Color(0xFFFF9500);
  static const Color ltIndigo        = Color(0xFF5856D6);
  static const Color ltText          = Color(0xFF1C1C1E);
  static const Color ltTextSub       = Color(0xFF8E8E93);
  static const Color ltTextTert      = Color(0xFFAEAEB2);
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
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.glassBg,
    required this.glassBorder,
    required this.glassBlur,
  });

  final Color  background;
  final Color  surface;
  final Color  accent;    // Jarvis cyan (dark) / iOS blue (light)
  final Color  teal;      // primary action
  final Color  success;
  final Color  error;
  final Color  warning;
  final Color  indigo;
  final Color  textPrimary;
  final Color  textSecondary;
  final Color  textTertiary;
  final Color  glassBg;     // background glass card
  final Color  glassBorder; // border olografico
  final double glassBlur;   // BackdropFilter sigma

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
    textPrimary:   MarkFitColors.dkText,
    textSecondary: MarkFitColors.dkTextSub,
    textTertiary:  MarkFitColors.dkTextTert,
    glassBg:       Color(0x0DFFFFFF),  // white 5%
    glassBorder:   Color(0x3300E5FF),  // cyan 20%
    glassBlur:     12,
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
    textPrimary:   MarkFitColors.ltText,
    textSecondary: MarkFitColors.ltTextSub,
    textTertiary:  MarkFitColors.ltTextTert,
    glassBg:       Color(0x0A000000),  // black 4%
    glassBorder:   Color(0x33007AFF),  // blue 20%
    glassBlur:     12,
  );

  // ── Helper opacità ─────────────────────────────────────────

  Color accentWith(double o)  => accent.withOpacity(o);
  Color tealWith(double o)    => teal.withOpacity(o);
  Color errorWith(double o)   => error.withOpacity(o);
  Color warningWith(double o) => warning.withOpacity(o);
  Color indigoWith(double o)  => indigo.withOpacity(o);

  // ── ThemeExtension ─────────────────────────────────────────

  @override
  MarkFitThemeData copyWith({
    Color? background, Color? surface, Color? accent, Color? teal,
    Color? success, Color? error, Color? warning, Color? indigo,
    Color? textPrimary, Color? textSecondary, Color? textTertiary,
    Color? glassBg, Color? glassBorder, double? glassBlur,
  }) => MarkFitThemeData(
    background:    background    ?? this.background,
    surface:       surface       ?? this.surface,
    accent:        accent        ?? this.accent,
    teal:          teal          ?? this.teal,
    success:       success       ?? this.success,
    error:         error         ?? this.error,
    warning:       warning       ?? this.warning,
    indigo:        indigo        ?? this.indigo,
    textPrimary:   textPrimary   ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary:  textTertiary  ?? this.textTertiary,
    glassBg:       glassBg       ?? this.glassBg,
    glassBorder:   glassBorder   ?? this.glassBorder,
    glassBlur:     glassBlur     ?? this.glassBlur,
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
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary:  Color.lerp(textTertiary,  other.textTertiary,  t)!,
      glassBg:       Color.lerp(glassBg,       other.glassBg,       t)!,
      glassBorder:   Color.lerp(glassBorder,   other.glassBorder,   t)!,
      glassBlur:     lerpDouble(glassBlur,     other.glassBlur,     t)!,
    );
  }
}

// ── BuildContext extension ────────────────────────────────────

extension MarkFitThemeX on BuildContext {
  /// Design tokens MarkFit. Fallback sicuro a dark se il tema
  /// non è ancora registrato nel MaterialApp.
  MarkFitThemeData get mkTheme =>
      Theme.of(this).extension<MarkFitThemeData>() ??
      MarkFitThemeData.dark;

  bool get isDarkMode =>
      Theme.of(this).brightness == Brightness.dark;
}

// ── AppTheme factory ─────────────────────────────────────────
// Utilizzo in main.dart:
//   MaterialApp(
//     theme:      AppTheme.light(),
//     darkTheme:  AppTheme.dark(),
//     themeMode:  ThemeMode.system,
//   )

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