import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// Design System centralizzato MarkFit.
/// Accesso: Theme.of(context).extension<MarkFitColors>()!
/// Shortcut: context.mfc
@immutable
class MarkFitColors extends ThemeExtension<MarkFitColors> {
  // ── Accents fissi (leggibili in entrambe le mode) ──────────
  static const cyan    = Color(0xFF00E5FF);
  static const teal    = Color(0xFF00D4AA);
  static const tealDk  = Color(0xFF00A880);
  static const indigo  = Color(0xFF6366F1);
  static const orange  = Color(0xFFFF8C00);
  static const red     = Color(0xFFFF3B30);
  static const green   = Color(0xFF22C55E);
  static const blue    = Color(0xFF3B82F6);
  static const purple  = Color(0xFF8A2BE2);

  // ── Token adattativi ───────────────────────────────────────
  final Color scaffoldBg;
  final List<Color> bgGradient;

  // Glass card
  final Color glassCard;        // card fill normale
  final Color glassCardStrong;  // card fill prominente
  final Color glassBorder;      // bordo generico
  final Color glassBorderFocus; // bordo con focus/accent

  // Testo
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnAccent;

  final Color divider;
  final double blur;
  final double blurStrong;
  final bool showElevation;
  final Color elevationColor;

  // Navbar
  final Color navBg;
  final Color navBorder;
  final Color navUnselected;
  final List<Color> navPillGradient;
  final Color navSpecular;

  // Input
  final Color inputBg;
  final Color inputBorder;
  final Color inputHint;

  const MarkFitColors({
    required this.scaffoldBg,
    required this.bgGradient,
    required this.glassCard,
    required this.glassCardStrong,
    required this.glassBorder,
    required this.glassBorderFocus,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAccent,
    required this.divider,
    required this.blur,
    required this.blurStrong,
    required this.showElevation,
    required this.elevationColor,
    required this.navBg,
    required this.navBorder,
    required this.navUnselected,
    required this.navPillGradient,
    required this.navSpecular,
    required this.inputBg,
    required this.inputBorder,
    required this.inputHint,
  });

  // ── DARK — Jarvis / Iron Man HUD ─────────────────────────
  static const dark = MarkFitColors(
    scaffoldBg:      Color(0xFF0A0A0E),
    bgGradient:      [Color(0xFF080A12), Color(0xFF0D1117), Color(0xFF060B14)],

    glassCard:        Color(0x0DFFFFFF),    // white 5%
    glassCardStrong:  Color(0x1AFFFFFF),    // white 10%
    glassBorder:      Color(0x1FFFFFFF),    // white 12%
    glassBorderFocus: Color(0x3300E5FF),    // cyan 20%

    textPrimary:   Color(0xFFFFFFFF),
    textSecondary: Color(0x99FFFFFF),       // white 60%
    textTertiary:  Color(0x66FFFFFF),       // white 40%
    textOnAccent:  Color(0xFFFFFFFF),

    divider:       Color(0x14FFFFFF),       // white 8%
    blur:          10.0,
    blurStrong:    16.0,
    showElevation: false,
    elevationColor: Color(0x00000000),

    navBg:            Color(0x61111827),    // dark ~38%
    navBorder:        Color(0x1EFFFFFF),    // white 12%
    navUnselected:    Color(0x6BFFFFFF),    // white 42%
    navPillGradient:  [Color(0xFF00D4AA), Color(0xFF00A880)],
    navSpecular:      Color(0x61FFFFFF),    // white 38%

    inputBg:     Color(0x0DFFFFFF),
    inputBorder: Color(0x26FFFFFF),
    inputHint:   Color(0x4DFFFFFF),
  );

  // ── LIGHT — iOS Frost Glass / Apple Vision ───────────────
  static const light = MarkFitColors(
    scaffoldBg:      Color(0xFFF0F4FA),
    bgGradient:      [Color(0xFFF5F7FC), Color(0xFFFFFFFF), Color(0xFFEDF2FA)],

    glassCard:        Color(0xBFFFFFFF),    // white 75%
    glassCardStrong:  Color(0xE6FFFFFF),    // white 90%
    glassBorder:      Color(0x18000000),    // black 10%
    glassBorderFocus: Color(0x5500897B),    // teal 33%

    textPrimary:   Color(0xFF0F172A),       // slate-900
    textSecondary: Color(0xFF475569),       // slate-600
    textTertiary:  Color(0xFF94A3B8),       // slate-400
    textOnAccent:  Color(0xFFFFFFFF),

    divider:       Color(0x14000000),       // black 8%
    blur:          16.0,
    blurStrong:    24.0,
    showElevation: true,
    elevationColor: Color(0x18000000),

    navBg:            Color(0xCCFFFFFF),    // white 80%
    navBorder:        Color(0x26000000),    // black 15%
    navUnselected:    Color(0x99475569),    // slate 60%
    navPillGradient:  [Color(0xFF00897B), Color(0xFF00695C)],
    navSpecular:      Color(0xA3FFFFFF),    // white 64%

    inputBg:     Color(0x99FFFFFF),
    inputBorder: Color(0x26000000),
    inputHint:   Color(0x80475569),
  );

  @override
  MarkFitColors copyWith({
    Color? scaffoldBg, List<Color>? bgGradient,
    Color? glassCard, Color? glassCardStrong,
    Color? glassBorder, Color? glassBorderFocus,
    Color? textPrimary, Color? textSecondary,
    Color? textTertiary, Color? textOnAccent,
    Color? divider, double? blur, double? blurStrong,
    bool? showElevation, Color? elevationColor,
    Color? navBg, Color? navBorder, Color? navUnselected,
    List<Color>? navPillGradient, Color? navSpecular,
    Color? inputBg, Color? inputBorder, Color? inputHint,
  }) => MarkFitColors(
    scaffoldBg:      scaffoldBg      ?? this.scaffoldBg,
    bgGradient:      bgGradient      ?? this.bgGradient,
    glassCard:       glassCard       ?? this.glassCard,
    glassCardStrong: glassCardStrong ?? this.glassCardStrong,
    glassBorder:     glassBorder     ?? this.glassBorder,
    glassBorderFocus: glassBorderFocus ?? this.glassBorderFocus,
    textPrimary:     textPrimary     ?? this.textPrimary,
    textSecondary:   textSecondary   ?? this.textSecondary,
    textTertiary:    textTertiary    ?? this.textTertiary,
    textOnAccent:    textOnAccent    ?? this.textOnAccent,
    divider:         divider         ?? this.divider,
    blur:            blur            ?? this.blur,
    blurStrong:      blurStrong      ?? this.blurStrong,
    showElevation:   showElevation   ?? this.showElevation,
    elevationColor:  elevationColor  ?? this.elevationColor,
    navBg:           navBg           ?? this.navBg,
    navBorder:       navBorder       ?? this.navBorder,
    navUnselected:   navUnselected   ?? this.navUnselected,
    navPillGradient: navPillGradient ?? this.navPillGradient,
    navSpecular:     navSpecular     ?? this.navSpecular,
    inputBg:         inputBg         ?? this.inputBg,
    inputBorder:     inputBorder     ?? this.inputBorder,
    inputHint:       inputHint       ?? this.inputHint,
  );

  @override
  MarkFitColors lerp(MarkFitColors? other, double t) {
    if (other == null) return this;
    Color lc(Color a, Color b) => Color.lerp(a, b, t)!;
    double ld(double a, double b) => lerpDouble(a, b, t)!;
    return MarkFitColors(
      scaffoldBg:      lc(scaffoldBg,      other.scaffoldBg),
      bgGradient:      List.generate(3, (i) =>
          lc(bgGradient[i],  other.bgGradient[i])),
      glassCard:       lc(glassCard,       other.glassCard),
      glassCardStrong: lc(glassCardStrong, other.glassCardStrong),
      glassBorder:     lc(glassBorder,     other.glassBorder),
      glassBorderFocus: lc(glassBorderFocus, other.glassBorderFocus),
      textPrimary:     lc(textPrimary,     other.textPrimary),
      textSecondary:   lc(textSecondary,   other.textSecondary),
      textTertiary:    lc(textTertiary,    other.textTertiary),
      textOnAccent:    lc(textOnAccent,    other.textOnAccent),
      divider:         lc(divider,         other.divider),
      blur:            ld(blur,            other.blur),
      blurStrong:      ld(blurStrong,      other.blurStrong),
      showElevation:   t < 0.5 ? showElevation : other.showElevation,
      elevationColor:  lc(elevationColor,  other.elevationColor),
      navBg:           lc(navBg,           other.navBg),
      navBorder:       lc(navBorder,       other.navBorder),
      navUnselected:   lc(navUnselected,   other.navUnselected),
      navPillGradient: List.generate(2, (i) =>
          lc(navPillGradient[i], other.navPillGradient[i])),
      navSpecular:     lc(navSpecular,     other.navSpecular),
      inputBg:         lc(inputBg,         other.inputBg),
      inputBorder:     lc(inputBorder,     other.inputBorder),
      inputHint:       lc(inputHint,       other.inputHint),
    );
  }
}

/// Shortcut: context.mfc → MarkFitColors
extension MarkFitContextX on BuildContext {
  MarkFitColors get mfc {
    final ext = Theme.of(this).extension<MarkFitColors>();
    if (ext != null) return ext;
    return Theme.of(this).brightness == Brightness.dark
        ? MarkFitColors.dark : MarkFitColors.light;
  }
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}