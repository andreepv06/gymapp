import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────
// GlassAppBar
//
// AppBar Glass UI riutilizzabile — riferimento allegato SwiftUI
// "Liquid Glass Navigation Bar" (titolo + sottotitolo +
// gruppi azioni + blur + traslucenza).
//
// Utilizzo come appBar di Scaffold:
//   appBar: GlassAppBar(title: 'Titolo', subtitle: 'Sub'),
//
// Utilizzo inline (top di Column):
//   GlassAppBar.inline(title: 'Titolo', actions: [...])
// ─────────────────────────────────────────────────────────────

class GlassAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String     title;
  final String?    subtitle;
  final List<Widget>? actions;
  final Widget?    leading;
  final bool       showBackButton;
  final Color      accentColor;
  final VoidCallback? onBack;
  final bool       centerTitle;
  final double     blurSigma;

  const GlassAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.accentColor    = const Color(0xFF00E5FF),
    this.onBack,
    this.centerTitle = false,
    this.blurSigma   = 16,
  });

  @override
  Size get preferredSize => Size.fromHeight(
      subtitle != null ? 72 : 56);

  // Costruttore per uso inline (non PreferredSizeWidget)
  static Widget inline({
    required String title,
    String? subtitle,
    List<Widget>? actions,
    VoidCallback? onBack,
    Color accentColor = const Color(0xFF00E5FF),
  }) {
    return _GlassAppBarBody(
      title: title, subtitle: subtitle,
      actions: actions, onBack: onBack,
      accentColor: accentColor, asSliver: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GlassAppBarBody(
      title: title, subtitle: subtitle,
      actions: actions, onBack: onBack,
      accentColor: accentColor, showBackButton: showBackButton,
      leading: leading, asSliver: false,
    );
  }
}

class _GlassAppBarBody extends StatelessWidget {
  final String      title;
  final String?     subtitle;
  final List<Widget>? actions;
  final Widget?     leading;
  final bool        showBackButton;
  final Color       accentColor;
  final VoidCallback? onBack;
  final bool        asSliver;

  const _GlassAppBarBody({
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.accentColor   = const Color(0xFF00E5FF),
    this.onBack,
    this.asSliver = false,
  });

  @override
  Widget build(BuildContext context) {
    final canPop   = Navigator.of(context).canPop();
    final showBack = showBackButton && canPop && leading == null;
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    final glassBg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.white.withOpacity(0.55);
    final glassBorder = isDark
        ? accentColor.withOpacity(0.18)
        : Colors.white.withOpacity(0.6);
    final textColor = isDark
        ? Colors.white
        : const Color(0xFF1C1C1E);
    final subColor = isDark
        ? Colors.white.withOpacity(0.45)
        : const Color(0xFF8E8E93);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: glassBg,
            border: Border(
              bottom: BorderSide(color: glassBorder, width: 0.6)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
              child: Row(children: [
                // Leading / back button
                if (showBack)
                  _BackBtn(accentColor: accentColor,
                      onBack: onBack ?? () => Navigator.of(context).pop(),
                      isDark: isDark)
                else if (leading != null)
                  leading!
                else
                  const SizedBox(width: 12),

                const SizedBox(width: 8),

                // Title + subtitle
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: textColor, fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(subtitle!,
                            style: TextStyle(
                                color: subColor, fontSize: 11,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),

                // Actions raggruppati (come ToolbarItemGroup iOS 26)
                if (actions != null && actions!.isNotEmpty)
                  _ActionsGroup(
                      actions: actions!, accentColor: accentColor,
                      isDark: isDark),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackBtn extends StatelessWidget {
  final Color accentColor;
  final VoidCallback onBack;
  final bool isDark;
  const _BackBtn({required this.accentColor, required this.onBack,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onBack(); },
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.08),
              width: 0.7),
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded,
            size: 15,
            color: isDark ? Colors.white : const Color(0xFF1C1C1E)),
      ),
    );
  }
}

class _ActionsGroup extends StatelessWidget {
  final List<Widget> actions;
  final Color accentColor;
  final bool isDark;
  const _ActionsGroup({required this.actions,
      required this.accentColor, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark
                    ? accentColor.withOpacity(0.15)
                    : Colors.black.withOpacity(0.06),
                width: 0.7),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: actions),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GlassAppBarAction — singola azione nella AppBar
// ─────────────────────────────────────────────────────────────

class GlassAppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const GlassAppBarAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? (isDark ? Colors.white : const Color(0xFF1C1C1E));
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(icon, size: 20, color: c),
      ),
    );
  }
}