import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// MarkFit Design System — token centralizzati dark/light.
/// Accesso: context.mfc  |  Utility: context.isDarkMode
@immutable
class MarkFitColors extends ThemeExtension<MarkFitColors> {

  // ── Accent fissi (identici in entrambi i temi) ────────────
  static const cyan    = Color(0xFF00E5FF);
  static const teal    = Color(0xFF00D4AA);
  static const tealDk  = Color(0xFF00A880);
  static const indigo  = Color(0xFF6366F1);
  static const orange  = Color(0xFFFF8C00);
  static const red     = Color(0xFFFF3B30);
  static const green   = Color(0xFF22C55E);
  static const blue    = Color(0xFF3B82F6);
  static const purple  = Color(0xFF8A2BE2);

  // ── Token adattativi ─────────────────────────────────────

  // Background
  final Color scaffoldBg;
  final List<Color> bgGradient;

  // Glass card
  final Color glassCard;
  final Color glassCardStrong;
  final Color glassCardInset;
  final Color glassBorder;
  final Color glassBorderFocus;
  final double glassBlur;
  final double glassBlurStrong;

  // Testo
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnAccent;
  final Color textOnGlass;

  // Divider
  final Color divider;

  // Elevazione
  final bool showElevation;
  final Color elevationColor;

  // Navbar
  final Color navBg;
  final Color navBorder;
  final Color navUnselected;
  final List<Color> navPillGradient;
  final Color navSpecular;
  final Color navShadow;

  // Input
  final Color inputBg;
  final Color inputBorder;
  final Color inputBorderFocus;
  final Color inputHint;
  final Color inputText;

  // Icone
  final Color iconPrimary;
  final Color iconSecondary;

  // Sheet / Dialog
  final Color sheetBg;
  final Color sheetBorder;

  const MarkFitColors({
    required this.scaffoldBg,
    required this.bgGradient,
    required this.glassCard,
    required this.glassCardStrong,
    required this.glassCardInset,
    required this.glassBorder,
    required this.glassBorderFocus,
    required this.glassBlur,
    required this.glassBlurStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAccent,
    required this.textOnGlass,
    required this.divider,
    required this.showElevation,
    required this.elevationColor,
    required this.navBg,
    required this.navBorder,
    required this.navUnselected,
    required this.navPillGradient,
    required this.navSpecular,
    required this.navShadow,
    required this.inputBg,
    required this.inputBorder,
    required this.inputBorderFocus,
    required this.inputHint,
    required this.inputText,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.sheetBg,
    required this.sheetBorder,
  });

  // ═══════════════════════════════════════════════════════════
  // DARK — Jarvis / Iron Man HUD (INVARIATO)
  // ═══════════════════════════════════════════════════════════

  static const dark = MarkFitColors(
    scaffoldBg:  Color(0xFF060810),
    bgGradient:  [Color(0xFF060810), Color(0xFF0A0D18), Color(0xFF040712)],

    glassCard:        Color(0x10FFFFFF),
    glassCardStrong:  Color(0x1AFFFFFF),
    glassCardInset:   Color(0x0DFFFFFF),
    glassBorder:      Color(0x1FFFFFFF),
    glassBorderFocus: Color(0x4D00E5FF),
    glassBlur:        10.0,
    glassBlurStrong:  20.0,

    textPrimary:   Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
    textTertiary:  Color(0x66FFFFFF),
    textOnAccent:  Color(0xFFFFFFFF),
    textOnGlass:   Color(0xFFFFFFFF),

    divider:       Color(0x14FFFFFF),
    showElevation: false,
    elevationColor: Color(0x00000000),

    navBg:           Color(0x5E111827),
    navBorder:       Color(0x1EFFFFFF),
    navUnselected:   Color(0x73FFFFFF),
    navPillGradient: [Color(0xFF00D4AA), Color(0xFF00A880)],
    navSpecular:     Color(0x5CFFFFFF),
    navShadow:       Color(0x8C000000),

    inputBg:          Color(0x0DFFFFFF),
    inputBorder:      Color(0x26FFFFFF),
    inputBorderFocus: Color(0x6600D4AA),
    inputHint:        Color(0x4DFFFFFF),
    inputText:        Color(0xFFFFFFFF),

    iconPrimary:   Color(0xFFFFFFFF),
    iconSecondary: Color(0x99FFFFFF),

    sheetBg:     Color(0xFF060B14),
    sheetBorder: Color(0x2600E5FF),
  );

  // ═══════════════════════════════════════════════════════════
  // LIGHT — iOS Liquid Glass con CONTRASTO ACCESSIBILE
  //
  // Principi:
  //  • Background: blu-grigio medio (#E8EDF5) — NON bianco puro
  //  • Card: bianco satinato CHIARAMENTE DISTINTO dal background
  //  • Bordi: scuri e VISIBILI (18-24% near-black)
  //  • Testo primario: quasi-nero (#080D1A)
  //  • Testo secondario: grigio SCURO (#1F2D40) — mai troppo chiaro
  //  • Testo terziario: grigio MEDIO (#4D5E75) — LEGGIBILE
  //  • Navbar: bianco solido con bordo chiaramente visibile
  //  • Ombre: più forti — la PROFONDITÀ in light mode viene dalle ombre
  //  • La trasparenza NON è il meccanismo principale in light mode
  // ═══════════════════════════════════════════════════════════

  static const light = MarkFitColors(
    // Background: grigio-azzurro medio — crea il contrasto necessario
    // con le card bianche. NON è bianco puro.
    scaffoldBg:  Color(0xFFE5EAF2),
    bgGradient:  [Color(0xFFE8EDF5), Color(0xFFE2E8F0), Color(0xFFECF0F7)],

    // Card: chiaramente bianchi contro il background grigio-blu.
    // L'effetto Glass viene da:
    //   1. Il riempimento bianco (chiaramente diverso dal background)
    //   2. Il blur (effetto frosted)
    //   3. L'ombra (profondità — il meccanismo principale in light)
    //   4. Il bordo (definisce chiaramente i bordi)
    glassCard:        Color(0xEAFFFFFF),  // 92% bianco
    glassCardStrong:  Color(0xF7FFFFFF),  // 97% bianco — per dialog/sheet
    glassCardInset:   Color(0xD6FFFFFF),  // 84% bianco — per input/inset

    // Bordi CHIARAMENTE VISIBILI — non quasi-trasparenti
    glassBorder:      Color(0x320A0F23),  // 20% near-black
    glassBorderFocus: Color(0xD400897B),  // 83% teal

    glassBlur:        20.0,  // più forte in light mode
    glassBlurStrong:  32.0,

    // TESTO: massimo contrasto — accessibilità WCAG AA/AAA
    textPrimary:   Color(0xFF080D1A),  // quasi-nero (contrasto > 18:1)
    textSecondary: Color(0xFF1F2D40),  // grigio-navy scuro (contrasto > 8:1)
    textTertiary:  Color(0xFF4D5E75),  // grigio medio LEGGIBILE (contrasto > 4.5:1)
    textOnAccent:  Color(0xFFFFFFFF),
    textOnGlass:   Color(0xFF080D1A),

    divider:       Color(0x280A0F23),  // 16% — linee divisorie visibili
    showElevation: true,
    // Ombra FORTE — la profondità in light mode viene principalmente da qui
    elevationColor: Color(0x3C0A0F23),  // 24% — ombra pronunciata

    // Navbar: vetro bianco CHIARAMENTE VISIBILE con bordo marcato
    navBg:           Color(0xEDFFFFFF),  // 93% bianco
    navBorder:       Color(0x400A0F23),  // 25% near-black — VISIBILE
    navUnselected:   Color(0xFF374152),  // grigio scuro — LEGGIBILE
    navPillGradient: [Color(0xFF00897B), Color(0xFF006B62)],
    navSpecular:     Color(0x80FFFFFF),
    navShadow:       Color(0x4A0A0F23),  // ombra forte sotto la navbar

    // Input: quasi bianchi con bordo chiaramente visibile
    inputBg:          Color(0xF3FFFFFF),  // 95% bianco
    inputBorder:      Color(0x320A0F23),  // 20% — VISIBILE
    inputBorderFocus: Color(0xCC00897B),  // 80% teal
    inputHint:        Color(0xFF7B8CA0),  // grigio medio — leggibile
    inputText:        Color(0xFF080D1A),  // quasi-nero

    iconPrimary:   Color(0xFF080D1A),  // quasi-nero
    iconSecondary: Color(0xFF374152),  // grigio scuro

    sheetBg:     Color(0xFFF2F5FA),  // grigio-blu molto chiaro
    sheetBorder: Color(0x2800897B),  // 16% teal
  );

  // ── copyWith ─────────────────────────────────────────────

  @override
  MarkFitColors copyWith({
    Color? scaffoldBg, List<Color>? bgGradient,
    Color? glassCard, Color? glassCardStrong, Color? glassCardInset,
    Color? glassBorder, Color? glassBorderFocus,
    double? glassBlur, double? glassBlurStrong,
    Color? textPrimary, Color? textSecondary, Color? textTertiary,
    Color? textOnAccent, Color? textOnGlass, Color? divider,
    bool? showElevation, Color? elevationColor,
    Color? navBg, Color? navBorder, Color? navUnselected,
    List<Color>? navPillGradient, Color? navSpecular, Color? navShadow,
    Color? inputBg, Color? inputBorder, Color? inputBorderFocus,
    Color? inputHint, Color? inputText,
    Color? iconPrimary, Color? iconSecondary,
    Color? sheetBg, Color? sheetBorder,
  }) => MarkFitColors(
    scaffoldBg:       scaffoldBg       ?? this.scaffoldBg,
    bgGradient:       bgGradient       ?? this.bgGradient,
    glassCard:        glassCard        ?? this.glassCard,
    glassCardStrong:  glassCardStrong  ?? this.glassCardStrong,
    glassCardInset:   glassCardInset   ?? this.glassCardInset,
    glassBorder:      glassBorder      ?? this.glassBorder,
    glassBorderFocus: glassBorderFocus ?? this.glassBorderFocus,
    glassBlur:        glassBlur        ?? this.glassBlur,
    glassBlurStrong:  glassBlurStrong  ?? this.glassBlurStrong,
    textPrimary:      textPrimary      ?? this.textPrimary,
    textSecondary:    textSecondary    ?? this.textSecondary,
    textTertiary:     textTertiary     ?? this.textTertiary,
    textOnAccent:     textOnAccent     ?? this.textOnAccent,
    textOnGlass:      textOnGlass      ?? this.textOnGlass,
    divider:          divider          ?? this.divider,
    showElevation:    showElevation    ?? this.showElevation,
    elevationColor:   elevationColor   ?? this.elevationColor,
    navBg:            navBg            ?? this.navBg,
    navBorder:        navBorder        ?? this.navBorder,
    navUnselected:    navUnselected    ?? this.navUnselected,
    navPillGradient:  navPillGradient  ?? this.navPillGradient,
    navSpecular:      navSpecular      ?? this.navSpecular,
    navShadow:        navShadow        ?? this.navShadow,
    inputBg:          inputBg          ?? this.inputBg,
    inputBorder:      inputBorder      ?? this.inputBorder,
    inputBorderFocus: inputBorderFocus ?? this.inputBorderFocus,
    inputHint:        inputHint        ?? this.inputHint,
    inputText:        inputText        ?? this.inputText,
    iconPrimary:      iconPrimary      ?? this.iconPrimary,
    iconSecondary:    iconSecondary    ?? this.iconSecondary,
    sheetBg:          sheetBg          ?? this.sheetBg,
    sheetBorder:      sheetBorder      ?? this.sheetBorder,
  );

  @override
  MarkFitColors lerp(MarkFitColors? other, double t) {
    if (other == null) return this;
    Color lc(Color a, Color b) => Color.lerp(a, b, t)!;
    double ld(double a, double b) => lerpDouble(a, b, t)!;
    return MarkFitColors(
      scaffoldBg:       lc(scaffoldBg,       other.scaffoldBg),
      bgGradient:       List.generate(3, (i) =>
          lc(bgGradient[i], other.bgGradient[i])),
      glassCard:        lc(glassCard,        other.glassCard),
      glassCardStrong:  lc(glassCardStrong,  other.glassCardStrong),
      glassCardInset:   lc(glassCardInset,   other.glassCardInset),
      glassBorder:      lc(glassBorder,      other.glassBorder),
      glassBorderFocus: lc(glassBorderFocus, other.glassBorderFocus),
      glassBlur:        ld(glassBlur,        other.glassBlur),
      glassBlurStrong:  ld(glassBlurStrong,  other.glassBlurStrong),
      textPrimary:      lc(textPrimary,      other.textPrimary),
      textSecondary:    lc(textSecondary,    other.textSecondary),
      textTertiary:     lc(textTertiary,     other.textTertiary),
      textOnAccent:     lc(textOnAccent,     other.textOnAccent),
      textOnGlass:      lc(textOnGlass,      other.textOnGlass),
      divider:          lc(divider,          other.divider),
      showElevation:    t < 0.5 ? showElevation : other.showElevation,
      elevationColor:   lc(elevationColor,   other.elevationColor),
      navBg:            lc(navBg,            other.navBg),
      navBorder:        lc(navBorder,        other.navBorder),
      navUnselected:    lc(navUnselected,     other.navUnselected),
      navPillGradient:  List.generate(2, (i) =>
          lc(navPillGradient[i], other.navPillGradient[i])),
      navSpecular:      lc(navSpecular,      other.navSpecular),
      navShadow:        lc(navShadow,        other.navShadow),
      inputBg:          lc(inputBg,          other.inputBg),
      inputBorder:      lc(inputBorder,      other.inputBorder),
      inputBorderFocus: lc(inputBorderFocus, other.inputBorderFocus),
      inputHint:        lc(inputHint,        other.inputHint),
      inputText:        lc(inputText,        other.inputText),
      iconPrimary:      lc(iconPrimary,      other.iconPrimary),
      iconSecondary:    lc(iconSecondary,    other.iconSecondary),
      sheetBg:          lc(sheetBg,          other.sheetBg),
      sheetBorder:      lc(sheetBorder,      other.sheetBorder),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Estensioni BuildContext
// ─────────────────────────────────────────────────────────────

extension MarkFitContextX on BuildContext {
  MarkFitColors get mfc {
    final ext = Theme.of(this).extension<MarkFitColors>();
    if (ext != null) return ext;
    return Theme.of(this).brightness == Brightness.dark
        ? MarkFitColors.dark
        : MarkFitColors.light;
  }

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}