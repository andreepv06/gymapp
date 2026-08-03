import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// Design System centralizzato MarkFit.
///
/// Accesso: Theme.of(context).extension<MarkFitColors>()!
/// Shortcut: context.mfc
/// Utility: context.isDarkMode
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
  final Color scaffoldBg;
  final List<Color> bgGradient;

  // Glass card
  final Color glassCard;        // fill normale
  final Color glassCardStrong;  // fill prominente / elevato
  final Color glassCardInset;   // fill rientrato (input, tag)
  final Color glassBorder;      // bordo generico
  final Color glassBorderFocus; // bordo focus/accent
  final double glassBlur;       // sigma blur card normale
  final double glassBlurStrong; // sigma blur appbar/navbar

  // Testo
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnAccent;   // testo sopra pulsanti colorati
  final Color textOnGlass;    // testo sopra card glass (può differire da primary)

  // Divider / separatori
  final Color divider;

  // Elevazione (solo light)
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

  // Icon
  final Color iconPrimary;
  final Color iconSecondary;

  // Sheet / dialog
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

  // ── DARK ─ Jarvis / Iron Man HUD ─────────────────────────

  static const dark = MarkFitColors(
    scaffoldBg:   Color(0xFF060810),
    bgGradient:   [Color(0xFF060810), Color(0xFF0A0D18), Color(0xFF040712)],

    glassCard:        Color(0x10FFFFFF),  // white 6%
    glassCardStrong:  Color(0x1AFFFFFF),  // white 10%
    glassCardInset:   Color(0x0DFFFFFF),  // white 5%
    glassBorder:      Color(0x1FFFFFFF),  // white 12%
    glassBorderFocus: Color(0x4D00E5FF),  // cyan 30%
    glassBlur:        10.0,
    glassBlurStrong:  20.0,

    textPrimary:   Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),  // white 70%
    textTertiary:  Color(0x66FFFFFF),  // white 40%
    textOnAccent:  Color(0xFFFFFFFF),
    textOnGlass:   Color(0xFFFFFFFF),

    divider:       Color(0x14FFFFFF),  // white 8%
    showElevation: false,
    elevationColor: Color(0x00000000),

    navBg:           Color(0x5E111827),  // dark 37%
    navBorder:       Color(0x1EFFFFFF),
    navUnselected:   Color(0x73FFFFFF),  // white 45%
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

  // ── LIGHT ─ iOS Liquid Glass / Apple Vision ───────────────
  //
  // Principi:
  //  • Background: grigio ghiaccio caldo, NON bianco puro
  //  • Card: vetro bianco satinato, ombra morbida, bordo sottile
  //  • Testi: quasi-nero / antracite per massimo contrasto
  //  • Icone: grigio scuro o accent saturo
  //  • Accents: stessi del dark ma più saturi su sfondo chiaro
  //  • Navbar: vetro bianco, bordo visibile, icone scure

  static const light = MarkFitColors(
    scaffoldBg:  Color(0xFFF3F5F8),
    bgGradient:  [Color(0xFFF5F6FA), Color(0xFFF0F3F8), Color(0xFFF7F8FC)],

    // Card = vetro bianco satinato con ombra
    glassCard:        Color(0xD9FFFFFF),  // white 85%
    glassCardStrong:  Color(0xF2FFFFFF),  // white 95%
    glassCardInset:   Color(0xBFFFFFFF),  // white 75%
    glassBorder:      Color(0x26000000),  // black 15%
    glassBorderFocus: Color(0x8000897B),  // teal 50%
    glassBlur:        16.0,
    glassBlurStrong:  28.0,

    // Testi: quasi-nero per massimo contrasto su sfondo chiaro
    textPrimary:   Color(0xFF0D1117),   // quasi-nero
    textSecondary: Color(0xFF3D4555),   // antracite medio
    textTertiary:  Color(0xFF7A8499),   // grigio medio (non troppo chiaro)
    textOnAccent:  Color(0xFFFFFFFF),
    textOnGlass:   Color(0xFF0D1117),   // testo su card = nero

    divider:       Color(0x18000000),  // black 10%
    showElevation: true,
    elevationColor: Color(0x22000000), // black 13%

    // Navbar: vetro bianco galleggiante
    navBg:           Color(0xE6FFFFFF),  // white 90%
    navBorder:       Color(0x30000000),  // black 19%
    navUnselected:   Color(0xFF6B7385),  // grigio scuro leggibile
    navPillGradient: [Color(0xFF00897B), Color(0xFF00695C)],
    navSpecular:     Color(0x8CFFFFFF),
    navShadow:       Color(0x28000000),

    // Input: campo bianco con bordo visibile
    inputBg:          Color(0xF2FFFFFF),  // white 95%
    inputBorder:      Color(0x30000000),  // black 19%
    inputBorderFocus: Color(0xCC00897B),  // teal scuro 80%
    inputHint:        Color(0xFF9AA0AD),  // grigio medio
    inputText:        Color(0xFF0D1117),  // quasi-nero

    iconPrimary:   Color(0xFF1A2035),  // quasi-nero
    iconSecondary: Color(0xFF6B7385),  // grigio medio scuro

    // Sheet: bianco con bordo sottile
    sheetBg:     Color(0xFFF8F9FC),
    sheetBorder: Color(0x2000897B),  // teal 12%
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

  // ── lerp ─────────────────────────────────────────────────

  @override
  MarkFitColors lerp(MarkFitColors? other, double t) {
    if (other == null) return this;
    Color lc(Color a, Color b) => Color.lerp(a, b, t)!;
    double ld(double a, double b) => lerpDouble(a, b, t)!;
    return MarkFitColors(
      scaffoldBg:       lc(scaffoldBg,       other.scaffoldBg),
      bgGradient:       List.generate(3, (i) => lc(bgGradient[i], other.bgGradient[i])),
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
      navPillGradient:  List.generate(2, (i) => lc(navPillGradient[i], other.navPillGradient[i])),
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