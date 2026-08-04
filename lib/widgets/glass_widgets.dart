import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/markfit_colors.dart';

// ─────────────────────────────────────────────────────────────
// Libreria di widget Glass condivisi.
//
// ARCHITETTURA: un unico file esporta tutti i building block
// del Design System. Zero duplicazione. Zero hardcoding.
//
// Widgets esportati:
//   GlassContainer     — il building block fondamentale
//   GlassFilledButton  — pulsante primario colorato
//   GlassOutlineButton — pulsante secondario ghost
//   GlassIconButton    — pulsante icona
//   GlassInputField    — campo di testo adattivo
//   GlassChip          — chip filtro/tag
//   GlassDivider       — separatore
//   GlassSectionHeader — intestazione sezione (MAIUSCOLO)
//   GlassSectionTitle  — titolo sezione con icona
//   GlassTag           — tag piccolo con colore
//   GlassBadge         — numero/stato su elemento
// ─────────────────────────────────────────────────────────────

// ════════════════════════════════════════════════════════════
// GlassContainer — building block fondamentale
//
// Sostituisce il pattern:
//   ClipRRect → BackdropFilter → Container
// che era duplicato in ogni singolo widget.
//
// LIGHT MODE: ombra forte + bordo visibile + blur
// DARK MODE:  blur + bordo sottile + niente ombra
// ════════════════════════════════════════════════════════════

class GlassContainer extends StatelessWidget {
  final Widget          child;
  final EdgeInsetsGeometry? padding;
  final double          borderRadius;
  final Color?          accentBorderColor;
  final bool            prominent;
  final bool            inset;
  final double?         blurOverride;
  final List<BoxShadow>? shadowOverride;
  final Color?          fillOverride;
  final double          accentBorderWidth;
  final VoidCallback?   onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.accentBorderColor,
    this.prominent = false,
    this.inset = false,
    this.blurOverride,
    this.shadowOverride,
    this.fillOverride,
    this.accentBorderWidth = 1.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;
    final br     = BorderRadius.circular(borderRadius);

    // Fill
    final Color fill = fillOverride ??
        (inset     ? c.glassCardInset   :
         prominent ? c.glassCardStrong  : c.glassCard);

    // Border
    final Color borderColor = accentBorderColor != null
        ? accentBorderColor!.withOpacity(isDark ? 0.40 : 0.50)
        : c.glassBorder;
    final double borderW = accentBorderColor != null
        ? accentBorderWidth
        : (isDark ? 0.8 : 1.1);

    // Shadow (only light mode, or if accent)
    List<BoxShadow>? shadows = shadowOverride;
    if (shadows == null && c.showElevation) {
      shadows = [
        BoxShadow(
          color:       c.elevationColor,
          blurRadius:  prominent ? c.elevationBlur * 1.4
                                 : (inset ? c.elevationBlur * 0.4
                                          : c.elevationBlur * 0.8),
          offset:      const Offset(0, 3),
          spreadRadius: prominent ? -1 : -3,
        ),
      ];
      if (accentBorderColor != null) {
        shadows.add(BoxShadow(
          color:      accentBorderColor!.withOpacity(0.10),
          blurRadius: 12,
          offset:     const Offset(0, 4),
        ));
      }
    } else if (shadows == null && accentBorderColor != null) {
      shadows = [
        BoxShadow(
          color:      accentBorderColor!.withOpacity(0.08),
          blurRadius: 10,
        ),
      ];
    }

    final double blur = blurOverride ?? c.glassBlur;

    Widget container = ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color:        fill,
            borderRadius: br,
            border: Border.all(color: borderColor, width: borderW),
            boxShadow:    shadows,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: container);
    }
    return container;
  }
}

// ════════════════════════════════════════════════════════════
// GlassFilledButton — pulsante primario con gradiente
// ════════════════════════════════════════════════════════════

class GlassFilledButton extends StatelessWidget {
  final String        label;
  final Color         color;
  final VoidCallback? onTap;
  final IconData?     icon;
  final EdgeInsetsGeometry padding;
  final double        borderRadius;
  final bool          loading;
  final bool          fullWidth;

  const GlassFilledButton({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
    this.icon,
    this.padding = const EdgeInsets.symmetric(
        horizontal: 20, vertical: 14),
    this.borderRadius = 14,
    this.loading = false,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    final colorEnd = Color.lerp(color, Colors.black, 0.18) ?? color;

    Widget content = loading
        ? SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: c.textOnAccent))
        : Row(
            mainAxisSize: fullWidth
                ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            if (icon != null) ...[
              Icon(icon, color: c.textOnAccent, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label, style: TextStyle(
                color: c.textOnAccent, fontSize: 15,
                fontWeight: FontWeight.w700)),
          ]);

    return GestureDetector(
      onTap: (onTap != null && !loading)
          ? () { HapticFeedback.mediumImpact(); onTap!(); }
          : null,
      child: AnimatedOpacity(
        opacity: onTap != null ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color, colorEnd]),
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [BoxShadow(
                color: color.withOpacity(0.40),
                blurRadius: 14,
                offset: const Offset(0, 4))]),
          child: content)));
  }
}

// ════════════════════════════════════════════════════════════
// GlassOutlineButton — pulsante secondario ghost
// ════════════════════════════════════════════════════════════

class GlassOutlineButton extends StatelessWidget {
  final String        label;
  final Color         color;
  final VoidCallback? onTap;
  final IconData?     icon;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GlassOutlineButton({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
    this.icon,
    this.padding = const EdgeInsets.symmetric(
        horizontal: 16, vertical: 11),
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: onTap != null
          ? () { HapticFeedback.selectionClick(); onTap!(); }
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.09 : 0.07),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                  color: color.withOpacity(isDark ? 0.38 : 0.55),
                  width: isDark ? 0.9 : 1.2),
              boxShadow: c.showElevation
                  ? [BoxShadow(
                      color: color.withOpacity(0.10),
                      blurRadius: 6, offset: const Offset(0, 2))]
                  : null),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
              ],
              Text(label, style: TextStyle(
                  color: color, fontSize: 13,
                  fontWeight: FontWeight.w700)),
            ])))));
  }
}

// ════════════════════════════════════════════════════════════
// GlassIconButton — pulsante icona compatto
// ════════════════════════════════════════════════════════════

class GlassIconButton extends StatelessWidget {
  final IconData      icon;
  final VoidCallback? onTap;
  final Color?        color;
  final double        size;
  final String?       tooltip;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.color,
    this.size = 36,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;
    final iconColor = color ?? c.iconPrimary;

    Widget btn = GestureDetector(
      onTap: onTap != null
          ? () { HapticFeedback.selectionClick(); onTap!(); }
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.3),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              color: c.glassCardInset,
              borderRadius: BorderRadius.circular(size * 0.3),
              border: Border.all(
                  color: c.glassBorder, width: isDark ? 0.8 : 1.0),
              boxShadow: c.showElevation
                  ? [BoxShadow(
                      color: c.elevationColor,
                      blurRadius: 6, offset: const Offset(0, 2))]
                  : null),
            child: Icon(icon, color: iconColor,
                size: size * 0.43)))));

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

// ════════════════════════════════════════════════════════════
// GlassInputField — TextField adattivo
// ════════════════════════════════════════════════════════════

class GlassInputField extends StatelessWidget {
  final TextEditingController controller;
  final String        hint;
  final IconData?     prefixIcon;
  final Widget?       suffix;
  final bool          obscure;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final int           maxLines;
  final VoidCallback? onTap;
  final bool          readOnly;
  final void Function(String)? onChanged;

  const GlassInputField({
    super.key,
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines = 1,
    this.onTap,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: c.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: c.inputBorder,
                width: isDark ? 0.8 : 1.1),
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
            keyboardAppearance: isDark
                ? Brightness.dark : Brightness.light,
            textCapitalization: textCapitalization,
            readOnly:           readOnly,
            onTap:              onTap,
            onChanged:          onChanged,
            style: TextStyle(color: c.inputText, fontSize: 14),
            decoration: InputDecoration(
              hintText:  hint,
              hintStyle: TextStyle(
                  color: c.inputHint, fontSize: 14),
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

// ════════════════════════════════════════════════════════════
// GlassChip — chip filtro/tag adattivo
// ════════════════════════════════════════════════════════════

class GlassChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback? onTap;
  final Color        accentColor;

  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.accentColor = MarkFitColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: onTap != null
          ? () { HapticFeedback.selectionClick(); onTap!(); }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withOpacity(isDark ? 0.18 : 0.12)
              : c.glassCardInset,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected
                ? accentColor.withOpacity(isDark ? 0.55 : 0.60)
                : c.glassBorder,
            width: selected ? 1.2 : (isDark ? 0.8 : 1.0)),
          boxShadow: (selected && c.showElevation)
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

// ════════════════════════════════════════════════════════════
// GlassDivider — linea divisoria adattiva
// ════════════════════════════════════════════════════════════

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

// ════════════════════════════════════════════════════════════
// GlassSectionHeader — label sezione uppercase
// ════════════════════════════════════════════════════════════

class GlassSectionHeader extends StatelessWidget {
  final String label;
  final Color? accentColor;

  const GlassSectionHeader(this.label, {super.key, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;
    final color  = accentColor ?? MarkFitColors.cyan;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label.toUpperCase(), style: TextStyle(
          color: color.withOpacity(isDark ? 0.65 : 0.80),
          fontSize: 10, fontWeight: FontWeight.w800,
          letterSpacing: 1.5)));
  }
}

// ════════════════════════════════════════════════════════════
// GlassRowHeader — riga titolo + sottotitolo sezione
// ════════════════════════════════════════════════════════════

class GlassRowHeader extends StatelessWidget {
  final IconData icon;
  final String   title;
  final Color    color;

  const GlassRowHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Row(children: [
      Container(width: 30, height: 30,
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: color)),
      const SizedBox(width: 9),
      Text(title, style: TextStyle(
          color: c.textPrimary, fontSize: 15,
          fontWeight: FontWeight.w800, letterSpacing: -0.2)),
    ]);
  }
}

// ════════════════════════════════════════════════════════════
// GlassTag — tag piccolo colorato
// ════════════════════════════════════════════════════════════

class GlassTag extends StatelessWidget {
  final String label;
  final Color  color;

  const GlassTag({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.30), width: 0.7)),
      child: Text(label, style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.w700)));
  }
}

// ════════════════════════════════════════════════════════════
// GlassTile — tile per liste settings/menu
// ════════════════════════════════════════════════════════════

class GlassTile extends StatelessWidget {
  final IconData      icon;
  final Color         iconColor;
  final String        title;
  final Color?        titleColor;
  final String?       subtitle;
  final Widget?       trailing;
  final VoidCallback? onTap;

  const GlassTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return GestureDetector(
      onTap: onTap != null
          ? () { HapticFeedback.selectionClick(); onTap!(); }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 19)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(title, style: TextStyle(
                color: titleColor ?? c.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(
                  fontSize: 11, color: c.textTertiary)),
            ],
          ])),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(Icons.chevron_right_rounded,
                color: c.textTertiary, size: 18),
        ])));
  }
}


// ════════════════════════════════════════════════════════════
// GlassHeaderPill — pill azioni inline per header di schermata
//
// Usato da HistoryScreen e SettingsScreen come trailing
// dell'header, replicando esattamente il pattern di
// _GestioneEserciziPill in AllenamentiScreen.
// ════════════════════════════════════════════════════════════

class GlassHeaderPill extends StatelessWidget {
  final List<Widget> children;

  const GlassHeaderPill({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: c.glassBorder, width: isDark ? 0.9 : 1.1),
            boxShadow: c.showElevation
                ? [BoxShadow(
                    color:       c.elevationColor,
                    blurRadius:  8,
                    offset:      const Offset(0, 2),
                    spreadRadius: -2)]
                : null),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children:     children))));
  }
}

// ════════════════════════════════════════════════════════════
// GlassHeaderPillBtn — singolo pulsante dentro GlassHeaderPill
// ════════════════════════════════════════════════════════════

class GlassHeaderPillBtn extends StatefulWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final String       tooltip;

  const GlassHeaderPillBtn({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<GlassHeaderPillBtn> createState() => _GlassHeaderPillBtnState();
}

class _GlassHeaderPillBtnState extends State<GlassHeaderPillBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp:     (_) {
          setState(() => _pressed = false);
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale:    _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width:  44,
            height: 44,
            decoration: BoxDecoration(
              color: _pressed
                  ? widget.color.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12)),
            child: Icon(
                widget.icon, size: 20, color: widget.color)))));
  }
}