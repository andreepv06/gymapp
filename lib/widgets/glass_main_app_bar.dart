import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/markfit_colors.dart';
import '../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────
// GlassToolbarAction
// ─────────────────────────────────────────────────────────────

class GlassToolbarAction {
  final IconData     icon;
  final String       tooltip;
  final VoidCallback onTap;
  final Color?       color;
  final bool         hasBadge;

  const GlassToolbarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.hasBadge = false,
  });
}

// ─────────────────────────────────────────────────────────────
// GlassMainAppBar
// ─────────────────────────────────────────────────────────────

class GlassMainAppBar extends StatelessWidget {
  final String    title;
  final String?   subtitle;
  final Color     accentColor;
  final IconData  screenIcon;
  final List<GlassToolbarAction> primaryActions;
  final VoidCallback? onProfileTap;

  const GlassMainAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.accentColor = MarkFitColors.cyan,
    required this.screenIcon,
    this.primaryActions = const [],
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final c      = context.mfc;
    final isDark = context.isDarkMode;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: c.glassBlurStrong, sigmaY: c.glassBlurStrong),
        child: Stack(children: [

          Positioned.fill(child: CustomPaint(
              painter: _RadialDotsPainter(accentColor, isDark))),

          Container(
            decoration: BoxDecoration(
              color: c.glassCard,
              border: Border(bottom: BorderSide(
                  color: accentColor.withOpacity(isDark ? 0.20 : 0.15),
                  width: isDark ? 0.6 : 0.8)),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 8)]
                  : null),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [

              // Screen icon
              Container(width: 32, height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(isDark ? 0.12 : 0.10),
                  borderRadius: BorderRadius.circular(9)),
                child: Icon(screenIcon, size: 16, color: accentColor)),
              const SizedBox(width: 10),

              // Title + subtitle
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                Text(title, style: TextStyle(
                    color: c.textPrimary, fontSize: 17,
                    fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: TextStyle(
                      color: c.textTertiary, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),

              if (primaryActions.isNotEmpty) ...[
                const SizedBox(width: 8),
                _ActionPill(
                    actions: primaryActions, c: c,
                    accentColor: accentColor, isDark: isDark),
              ],
              const SizedBox(width: 8),

              _ProfilePill(auth: auth, c: c,
                  onTap: onProfileTap, isDark: isDark),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ActionPill
// ─────────────────────────────────────────────────────────────

class _ActionPill extends StatelessWidget {
  final List<GlassToolbarAction> actions;
  final MarkFitColors c;
  final Color accentColor;
  final bool isDark;

  const _ActionPill({
    required this.actions, required this.c,
    required this.accentColor, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCardStrong,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: c.glassBorder, width: isDark ? 0.8 : 1.0),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 8,
                    offset: const Offset(0, 2))]
                : null),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (int i = 0; i < actions.length; i++) ...[
              if (i > 0) ...[
                const SizedBox(width: 2),
                Container(width: 0.5, height: 14, color: c.divider),
                const SizedBox(width: 2),
              ],
              _ActionBtn(action: actions[i], c: c),
            ],
          ]))));
  }
}

class _ActionBtn extends StatelessWidget {
  final GlassToolbarAction action;
  final MarkFitColors c;
  const _ActionBtn({required this.action, required this.c});

  @override
  Widget build(BuildContext context) {
    final color = action.color ?? c.iconPrimary;
    return Tooltip(
      message: action.tooltip,
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); action.onTap(); },
        child: Stack(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(action.icon, size: 17, color: color)),
          if (action.hasBadge)
            Positioned(right: 5, top: 5,
              child: Container(width: 7, height: 7,
                decoration: BoxDecoration(
                  color: MarkFitColors.teal,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: MarkFitColors.teal.withOpacity(0.5),
                      blurRadius: 4)]))),
        ])));
  }
}

// ─────────────────────────────────────────────────────────────
// _ProfilePill
// ─────────────────────────────────────────────────────────────

class _ProfilePill extends StatelessWidget {
  final AuthProvider  auth;
  final MarkFitColors c;
  final VoidCallback? onTap;
  final bool isDark;

  const _ProfilePill({
    required this.auth, required this.c,
    this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap?.call(); },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: MarkFitColors.teal.withOpacity(isDark ? 0.12 : 0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: MarkFitColors.teal.withOpacity(isDark ? 0.35 : 0.45),
                  width: isDark ? 0.9 : 1.2),
              boxShadow: c.showElevation
                  ? [BoxShadow(
                      color: MarkFitColors.teal.withOpacity(0.15),
                      blurRadius: 8, offset: const Offset(0, 2))]
                  : null),
            padding: const EdgeInsets.all(4),
            child: _MiniAvatar(auth: auth, isDark: isDark),
          ),        // chiude Container
        ),          // chiude BackdropFilter
      ),            // chiude ClipRRect
    );              // chiude GestureDetector
  }
}

class _MiniAvatar extends StatelessWidget {
  final AuthProvider auth;
  final bool isDark;
  const _MiniAvatar({required this.auth, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final b64 = auth.avatarBase64;
    if (b64 != null && b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        return ClipOval(child: Image.memory(bytes,
            width: 28, height: 28, fit: BoxFit.cover));
      } catch (_) {}
    }
    return Container(
      width: 28, height: 28,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [MarkFitColors.teal, MarkFitColors.tealDk]),
        shape: BoxShape.circle),
      child: Center(child: Text(
        auth.initials.isEmpty ? '?' : auth.initials[0].toUpperCase(),
        style: const TextStyle(color: Colors.white,
            fontSize: 11, fontWeight: FontWeight.w800))));
  }
}

// ─────────────────────────────────────────────────────────────
// _RadialDotsPainter
// ─────────────────────────────────────────────────────────────

class _RadialDotsPainter extends CustomPainter {
  final Color accent;
  final bool  isDark;
  const _RadialDotsPainter(this.accent, this.isDark);

  static const _rings = [
    (r: 44.0,  n: 12, dr: 1.6, opDark: 0.10, opLight: 0.07),
    (r: 72.0,  n: 20, dr: 1.2, opDark: 0.07, opLight: 0.05),
    (r: 100.0, n: 26, dr: 0.9, opDark: 0.05, opLight: 0.035),
    (r: 128.0, n: 32, dr: 0.7, opDark: 0.04, opLight: 0.025),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width + 10.0;
    final cy = -10.0;
    for (final ring in _rings) {
      final op    = isDark ? ring.opDark : ring.opLight;
      final paint = Paint()..color = accent.withOpacity(op);
      for (int i = 0; i < ring.n; i++) {
        final angle = (i / ring.n) * 2 * math.pi;
        final x     = cx + ring.r * math.cos(angle);
        final y     = cy + ring.r * math.sin(angle);
        if (x >= 0 && y >= -ring.dr &&
            x <= size.width && y <= size.height) {
          canvas.drawCircle(Offset(x, y), ring.dr, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_RadialDotsPainter old) =>
      old.accent != accent || old.isDark != isDark;
}