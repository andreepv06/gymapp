import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/markfit_colors.dart';

// ─────────────────────────────────────────────────────────────
// GlassCard — componente condiviso per tutte le card Glass.
//
// SOLUZIONE ARCHITETTURALE:
// Elimina il pattern ClipRRect+BackdropFilter+Container ripetuto
// in ogni widget. Un solo widget, zero codice duplicato.
// Adattivo dark/light tramite context.mfc.
//
// Utilizzo base:
//   GlassCard(child: MyContent())
//
// Con padding:
//   GlassCard(padding: EdgeInsets.all(16), child: MyContent())
//
// Con accent border (card evidenziata):
//   GlassCard(accentColor: MarkFitColors.teal, child: MyContent())
//
// Card prominente (dialogs, profile cards):
//   GlassCard(prominent: true, child: MyContent())
//
// Card inset (input fields, tag containers):
//   GlassCard(inset: true, child: MyContent())
//
// Card tappabile:
//   GlassCard(onTap: () {}, child: MyContent())
//
// Card con fill colorato (QuickWorkoutPanel, tile sport):
//   GlassCard(tintColor: color.withOpacity(0.12), child: MyContent())
// ─────────────────────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  /// Colore accent per il bordo (override glassBorder).
  /// Usato per card tematiche (teal = workout, red = danger, ecc.)
  final Color? accentColor;

  /// Override del colore fill.
  /// Ha precedenza su prominent/inset/glassCard.
  /// Usato da QuickWorkoutPanel per tile colorati.
  final Color? tintColor;

  /// Larghezza bordo accent. Default adattivo (0.8 dark, 1.2 light).
  final double? accentBorderWidth;

  /// Usa glassCardStrong invece di glassCard.
  /// Per: dialog, profile card, elementi prominenti.
  final bool prominent;

  /// Usa glassCardInset invece di glassCard.
  /// Per: input containers, tag, elementi secondari.
  final bool inset;

  /// Override del valore blur. Default: c.glassBlur.
  final double? blurOverride;

  /// Override della forza dell'ombra. Default: c.elevationColor.
  final Color? shadowColorOverride;

  /// Rende la card tappabile con haptic feedback.
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.accentColor,
    this.tintColor,
    this.accentBorderWidth,
    this.prominent = false,
    this.inset = false,
    this.blurOverride,
    this.shadowColorOverride,
    this.onTap,
  }) : assert(!(prominent && inset),
            'GlassCard: prominent e inset non possono essere entrambi true');

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;
    final br     = BorderRadius.circular(borderRadius);

    // Selezione fill: tintColor ha priorità assoluta
    final Color fill = tintColor ??
        (inset
            ? c.glassCardInset
            : prominent
                ? c.glassCardStrong
                : c.glassCard);

    // Bordo: accent se specificato, altrimenti glassBorder
    final Color border = accentColor != null
        ? accentColor!.withOpacity(isDark ? 0.35 : 0.45)
        : c.glassBorder;
    final double bWidth = accentBorderWidth ??
        (accentColor != null
            ? (isDark ? 1.0 : 1.3)
            : (isDark ? 0.8 : 1.1));

    // Blur
    final double blur = blurOverride ?? c.glassBlur;

    // Ombre: solo in light mode + opzionalmente con accent
    List<BoxShadow>? shadows;
    if (c.showElevation) {
      shadows = [
        BoxShadow(
          color: shadowColorOverride ?? c.elevationColor,
          blurRadius: prominent ? 20 : (inset ? 4 : 10),
          offset: const Offset(0, 2),
          spreadRadius: prominent ? 0 : -2,
        ),
      ];
      // Glow aggiuntivo per card accent
      if (accentColor != null) {
        shadows.add(BoxShadow(
          color: accentColor!.withOpacity(0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ));
      }
    } else if (accentColor != null) {
      // In dark mode: solo glow per accent card
      shadows = [
        BoxShadow(
          color: accentColor!.withOpacity(0.08),
          blurRadius: 12,
        ),
      ];
    }

    Widget card = ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: br,
            border: Border.all(color: border, width: bWidth),
            boxShadow: shadows,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: card,
      );
    }
    return card;
  }
}

// ─────────────────────────────────────────────────────────────
// GlassButton — pulsante Ghost/Glass adattivo
// ─────────────────────────────────────────────────────────────

class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final bool filled;
  final EdgeInsetsGeometry padding;

  const GlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.filled = false,
    this.padding = const EdgeInsets.symmetric(
        horizontal: 16, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;
    final accent = color ?? MarkFitColors.teal;

    if (filled) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              accent,
              Color.lerp(accent, Colors.black, 0.15) ?? accent,
            ]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
                color: accent.withOpacity(0.4),
                blurRadius: 12, offset: const Offset(0, 3))]),
          child: DefaultTextStyle(
            style: TextStyle(
                color: c.textOnAccent, fontWeight: FontWeight.w700,
                fontSize: 14),
            child: IconTheme(
                data: IconThemeData(color: c.textOnAccent, size: 16),
                child: child)),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: accent.withOpacity(isDark ? 0.10 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: accent.withOpacity(isDark ? 0.35 : 0.45),
                  width: isDark ? 0.8 : 1.1),
              boxShadow: c.showElevation
                  ? [BoxShadow(
                      color: accent.withOpacity(0.12),
                      blurRadius: 6, offset: const Offset(0, 1))]
                  : null),
            child: DefaultTextStyle(
              style: TextStyle(
                  color: accent, fontWeight: FontWeight.w600,
                  fontSize: 13),
              child: IconTheme(
                  data: IconThemeData(color: accent, size: 16),
                  child: child)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GlassSection — sezione con tiles (settings, lista opzioni)
// ─────────────────────────────────────────────────────────────

class GlassSection extends StatelessWidget {
  final List<Widget> children;
  final double borderRadius;

  const GlassSection({
    super.key,
    required this.children,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
        borderRadius: borderRadius,
        child: Column(children: children));
  }
}

// ─────────────────────────────────────────────────────────────
// GlassDivider — separatore adattivo
// ─────────────────────────────────────────────────────────────

class GlassDivider extends StatelessWidget {
  final double indent;
  const GlassDivider({super.key, this.indent = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 0.5,
        margin: EdgeInsets.symmetric(horizontal: indent),
        color: context.mfc.divider);
  }
}

// ─────────────────────────────────────────────────────────────
// GlassInputField — TextField adattivo
// ─────────────────────────────────────────────────────────────

class GlassInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final bool obscure;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? suffix;

  const GlassInputField({
    super.key,
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines = 1,
    this.onTap,
    this.readOnly = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: c.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.inputBorder, width: 0.9),
            boxShadow: c.showElevation
                ? [BoxShadow(
                    color: c.elevationColor.withOpacity(0.5),
                    blurRadius: 4, offset: const Offset(0, 1))]
                : null),
          child: TextField(
            controller:         controller,
            maxLines:           obscure ? 1 : maxLines,
            obscureText:        obscure,
            keyboardType:       keyboardType,
            keyboardAppearance: context.isDarkMode
                ? Brightness.dark : Brightness.light,
            textCapitalization: textCapitalization,
            readOnly:           readOnly,
            onTap:              onTap,
            style: TextStyle(color: c.inputText, fontSize: 14),
            decoration: InputDecoration(
              hintText:  hint,
              hintStyle: TextStyle(color: c.inputHint, fontSize: 14),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon,
                      color: c.iconSecondary, size: 17)
                  : null,
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GlassSectionHeader — intestazione sezione con icona
// ─────────────────────────────────────────────────────────────

class GlassSectionHeader extends StatelessWidget {
  final String label;
  final Color? accentColor;

  const GlassSectionHeader(this.label, {super.key, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? MarkFitColors.cyan;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label.toUpperCase(), style: TextStyle(
          color: color.withOpacity(context.isDarkMode ? 0.65 : 0.75),
          fontSize: 10, fontWeight: FontWeight.w800,
          letterSpacing: 1.4)));
  }
}

// ─────────────────────────────────────────────────────────────
// GlassChip — chip filtro adattivo
// ─────────────────────────────────────────────────────────────

class GlassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color accentColor;

  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.accentColor = MarkFitColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withOpacity(0.15)
              : c.glassCardInset,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected
                ? accentColor.withOpacity(0.55)
                : c.glassBorder,
            width: selected ? 1.2 : 0.9),
          boxShadow: selected && c.showElevation
              ? [BoxShadow(
                  color: accentColor.withOpacity(0.15),
                  blurRadius: 6, offset: const Offset(0, 1))]
              : null),
        child: Text(label, style: TextStyle(
            color: selected ? accentColor : c.textTertiary,
            fontSize: 12,
            fontWeight: selected
                ? FontWeight.w700 : FontWeight.w500))));
  }
}