import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// MarkFit Design System centralizzato.
/// Accesso rapido: context.mfc  |  Utility: context.isDarkMode
@immutable
class MarkFitColors extends ThemeExtension<MarkFitColors> {

  // ── Accent costanti (identici in entrambi i temi) ─────────
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

  final Color scaffoldBg;
  final List<Color> bgGradient;

  final Color glassCard;
  final Color glassCardStrong;
  final Color glassCardInset;
  final Color glassBorder;
  final Color glassBorderAccent;
  final double glassBlur;
  final double glassBlurStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnAccent;
  final Color textDisabled;

  final Color divider;
  final bool showElevation;
  final Color elevationColor;
  final double elevationBlur;

  final Color navBg;
  final Color navBorder;
  final Color navUnselected;
  final List<Color> navPillGradient;
  final Color navSpecular;
  final Color navShadow;

  final Color inputBg;
  final Color inputBorder;
  final Color inputBorderFocus;
  final Color inputHint;
  final Color inputText;

  final Color iconPrimary;
  final Color iconSecondary;
  final Color iconOnAccent;

  final Color sheetBg;
  final Color sheetHandle;

  const MarkFitColors({
    required this.scaffoldBg,
    required this.bgGradient,
    required this.glassCard,
    required this.glassCardStrong,
    required this.glassCardInset,
    required this.glassBorder,
    required this.glassBorderAccent,
    required this.glassBlur,
    required this.glassBlurStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAccent,
    required this.textDisabled,
    required this.divider,
    required this.showElevation,
    required this.elevationColor,
    required this.elevationBlur,
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
    required this.iconOnAccent,
    required this.sheetBg,
    required this.sheetHandle,
  });

  // ════════════════════════════════════════════════════════════
  // DARK — Jarvis / Iron Man HUD (INVARIATO)
  // ════════════════════════════════════════════════════════════

  static const dark = MarkFitColors(
    scaffoldBg:  Color(0xFF060810),
    bgGradient:  [Color(0xFF060810), Color(0xFF0A0D18), Color(0xFF040712)],

    glassCard:        Color(0x10FFFFFF),
    glassCardStrong:  Color(0x1AFFFFFF),
    glassCardInset:   Color(0x0DFFFFFF),
    glassBorder:      Color(0x1FFFFFFF),
    glassBorderAccent: Color(0x4D00E5FF),
    glassBlur:        10.0,
    glassBlurStrong:  20.0,

    textPrimary:   Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
    textTertiary:  Color(0x73FFFFFF),
    textOnAccent:  Color(0xFFFFFFFF),
    textDisabled:  Color(0x40FFFFFF),

    divider:         Color(0x14FFFFFF),
    showElevation:   false,
    elevationColor:  Color(0x00000000),
    elevationBlur:   0.0,

    navBg:           Color(0x5E111827),
    navBorder:       Color(0x1EFFFFFF),
    navUnselected:   Color(0x80FFFFFF),
    navPillGradient: [Color(0xFF00D4AA), Color(0xFF00A880)],
    navSpecular:     Color(0x5CFFFFFF),
    navShadow:       Color(0x99000000),

    inputBg:          Color(0x0DFFFFFF),
    inputBorder:      Color(0x26FFFFFF),
    inputBorderFocus: Color(0x8000D4AA),
    inputHint:        Color(0x4DFFFFFF),
    inputText:        Color(0xFFFFFFFF),

    iconPrimary:   Color(0xFFFFFFFF),
    iconSecondary: Color(0x99FFFFFF),
    iconOnAccent:  Color(0xFFFFFFFF),

    sheetBg:     Color(0xFF080E18),
    sheetHandle: Color(0x33FFFFFF),
  );

  // ════════════════════════════════════════════════════════════
  // LIGHT — iOS Liquid Glass con CONTRASTO PROFESSIONALE
  //
  // FILOSOFIA:
  //   In dark mode il contrasto viene dalla trasparenza (bianco su nero).
  //   In light mode NON funziona così: bianco su quasi-bianco = invisibile.
  //   In light mode il contrasto viene da:
  //     1. Background CHIARAMENTE BLU-GRIGIO (non bianco)
  //     2. Card BIANCHE SOLIDE (contrasto netto contro il background)
  //     3. Bordi SOLIDI VISIBILI (non trasparenti)
  //     4. Testi QUASI-NERI con gerarchia netta
  //     5. Ombre PRONUNCIATE (la "profondità" in light = ombra, non blur)
  //
  // WCAG AA compliance:
  //   textPrimary su glassCard   → contrasto ≥ 15:1  ✓
  //   textSecondary su glassCard → contrasto ≥ 7:1   ✓
  //   textTertiary su glassCard  → contrasto ≥ 4.5:1 ✓
  //   navUnselected su navBg     → contrasto ≥ 4.5:1 ✓
  // ════════════════════════════════════════════════════════════

  static const light = MarkFitColors(
    // Background: blu-slate medio — CHIARAMENTE distinto dalle card bianche
    // #D8E2EE è abbastanza scuro da far risaltare il bianco ma abbastanza
    // chiaro da non sembrare un'app dark
    scaffoldBg:  Color(0xFFD8E2EE),
    bgGradient:  [Color(0xFFD8E2EE), Color(0xFFD2DCE9), Color(0xFFDDE6F0)],

    // Card: BIANCO SOLIDO — nessuna opacity, contrasto netto con il background
    glassCard:        Color(0xFFFFFFFF),
    glassCardStrong:  Color(0xFFF7FAFD),
    glassCardInset:   Color(0xFFEDF2F8),

    // Bordi: COLORI SOLIDI VISIBILI — non opacity-based
    // #8BA4BE è un blu-grigio medio che si vede su bianco
    glassBorder:      Color(0xFF8BA4BE),
    glassBorderAccent: Color(0xFF00897B),

    glassBlur:        20.0,  // blur maggiore in light per effetto vetro
    glassBlurStrong:  32.0,

    // TESTO — gerarchia netta con contrasti WCAG AA
    textPrimary:   Color(0xFF071525),  // quasi-nero navy (contrasto 19:1 su white)
    textSecondary: Color(0xFF1A3050),  // navy scuro  (contrasto 10:1 su white)
    textTertiary:  Color(0xFF3E5A78),  // slate medio  (contrasto 5.2:1 su white)
    textOnAccent:  Color(0xFFFFFFFF),
    textDisabled:  Color(0xFFA0B4C8),

    // Divider: visible line between elements
    divider:        Color(0xFFB8CBE0),
    showElevation:  true,
    // Ombra FORTE — in light mode la profondità viene principalmente da qui
    elevationColor: Color(0x50071525),
    elevationBlur:  16.0,

    // Navbar: bianco SOLIDO con bordo visibile e ombra forte
    navBg:           Color(0xFFFFFFFF),
    navBorder:       Color(0xFF7A98B8),   // blu-slate — chiaramente visibile
    navUnselected:   Color(0xFF3E5A78),   // contrasto 5.2:1 su white ✓
    navPillGradient: [Color(0xFF00897B), Color(0xFF006B62)],
    navSpecular:     Color(0x70FFFFFF),
    navShadow:       Color(0x60071525),   // ombra forte sotto la navbar

    // Input: sfondo quasi bianco con bordo visibile
    inputBg:          Color(0xFFF0F6FF),
    inputBorder:      Color(0xFF7A98B8),
    inputBorderFocus: Color(0xFF00897B),
    inputHint:        Color(0xFF6B8299),
    inputText:        Color(0xFF071525),

    // Icone: stessa gerarchia del testo
    iconPrimary:   Color(0xFF071525),
    iconSecondary: Color(0xFF3E5A78),
    iconOnAccent:  Color(0xFFFFFFFF),

    // Sheet: leggermente diverso dalla card per distinguerlo
    sheetBg:     Color(0xFFF2F7FC),
    sheetHandle: Color(0xFFB8CBE0),
  );

  // ── copyWith ─────────────────────────────────────────────

  @override
  MarkFitColors copyWith({
    Color? scaffoldBg, List<Color>? bgGradient,
    Color? glassCard, Color? glassCardStrong, Color? glassCardInset,
    Color? glassBorder, Color? glassBorderAccent,
    double? glassBlur, double? glassBlurStrong,
    Color? textPrimary, Color? textSecondary, Color? textTertiary,
    Color? textOnAccent, Color? textDisabled, Color? divider,
    bool? showElevation, Color? elevationColor, double? elevationBlur,
    Color? navBg, Color? navBorder, Color? navUnselected,
    List<Color>? navPillGradient, Color? navSpecular, Color? navShadow,
    Color? inputBg, Color? inputBorder, Color? inputBorderFocus,
    Color? inputHint, Color? inputText,
    Color? iconPrimary, Color? iconSecondary, Color? iconOnAccent,
    Color? sheetBg, Color? sheetHandle,
  }) => MarkFitColors(
    scaffoldBg:       scaffoldBg       ?? this.scaffoldBg,
    bgGradient:       bgGradient       ?? this.bgGradient,
    glassCard:        glassCard        ?? this.glassCard,
    glassCardStrong:  glassCardStrong  ?? this.glassCardStrong,
    glassCardInset:   glassCardInset   ?? this.glassCardInset,
    glassBorder:      glassBorder      ?? this.glassBorder,
    glassBorderAccent: glassBorderAccent ?? this.glassBorderAccent,
    glassBlur:        glassBlur        ?? this.glassBlur,
    glassBlurStrong:  glassBlurStrong  ?? this.glassBlurStrong,
    textPrimary:      textPrimary      ?? this.textPrimary,
    textSecondary:    textSecondary    ?? this.textSecondary,
    textTertiary:     textTertiary     ?? this.textTertiary,
    textOnAccent:     textOnAccent     ?? this.textOnAccent,
    textDisabled:     textDisabled     ?? this.textDisabled,
    divider:          divider          ?? this.divider,
    showElevation:    showElevation    ?? this.showElevation,
    elevationColor:   elevationColor   ?? this.elevationColor,
    elevationBlur:    elevationBlur    ?? this.elevationBlur,
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
    iconOnAccent:     iconOnAccent     ?? this.iconOnAccent,
    sheetBg:          sheetBg          ?? this.sheetBg,
    sheetHandle:      sheetHandle      ?? this.sheetHandle,
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
      glassBorderAccent: lc(glassBorderAccent, other.glassBorderAccent),
      glassBlur:        ld(glassBlur,        other.glassBlur),
      glassBlurStrong:  ld(glassBlurStrong,  other.glassBlurStrong),
      textPrimary:      lc(textPrimary,      other.textPrimary),
      textSecondary:    lc(textSecondary,    other.textSecondary),
      textTertiary:     lc(textTertiary,     other.textTertiary),
      textOnAccent:     lc(textOnAccent,     other.textOnAccent),
      textDisabled:     lc(textDisabled,     other.textDisabled),
      divider:          lc(divider,          other.divider),
      showElevation:    t < 0.5 ? showElevation : other.showElevation,
      elevationColor:   lc(elevationColor,   other.elevationColor),
      elevationBlur:    ld(elevationBlur,    other.elevationBlur),
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
      iconOnAccent:     lc(iconOnAccent,     other.iconOnAccent),
      sheetBg:          lc(sheetBg,          other.sheetBg),
      sheetHandle:      lc(sheetHandle,      other.sheetHandle),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BuildContext extensions
// ─────────────────────────────────────────────────────────────

extension MarkFitContextX on BuildContext {
  MarkFitColors get mfc {
    final ext = Theme.of(this).extension<MarkFitColors>();
    if (ext != null) return ext;
    return Theme.of(this).brightness == Brightness.dark
        ? MarkFitColors.dark
        : MarkFitColors.light;
  }

  bool get isDarkMode =>
      Theme.of(this).brightness == Brightness.dark;
}