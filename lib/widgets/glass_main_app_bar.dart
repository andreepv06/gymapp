import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

const _cyan   = Color(0xFF00E5FF);
const _teal   = Color(0xFF00D4AA);
const _tealDk = Color(0xFF00A880);

// ─────────────────────────────────────────────────────────────
// GlassToolbarAction — singola azione nella pill contestuale
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
// GlassMainAppBar — iOS 26 Liquid Glass Navigation Bar
//
// Layout (replica SwiftUI iOS 26):
//   [ScreenIcon] [Title / Subtitle] ···· [PrimaryGroup] [ProfilePill]
//
// PrimaryGroup = ToolbarItemGroup (glass pill, azioni contestuali)
// ProfilePill  = accesso rapido profilo (sempre presente)
// Background   = RadialDotPattern sottile (angolo top-right)
// ─────────────────────────────────────────────────────────────

class GlassMainAppBar extends StatelessWidget {
  final String  title;
  final String? subtitle;
  final Color   accentColor;
  final IconData screenIcon;

  /// Azioni contestuali (equivalente a SwiftUI ToolbarItemGroup).
  /// Max 2-3 per equilibrio visivo.
  final List<GlassToolbarAction> primaryActions;

  /// Callback tap sulla profile pill.
  /// Tipicamente naviga al tab Impostazioni o apre modifica profilo.
  final VoidCallback? onProfileTap;

  const GlassMainAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.accentColor = _cyan,
    required this.screenIcon,
    this.primaryActions = const [],
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Stack(children: [

          // ── Radial dot pattern (top-right) ────────────────────
          Positioned.fill(child: CustomPaint(
              painter: _RadialDotsPainter(accentColor))),

          // ── Bar content ────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border(bottom: BorderSide(
                  color: accentColor.withOpacity(0.15), width: 0.6))),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [

              // Screen icon
              Container(width: 32, height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9)),
                child: Icon(screenIcon, size: 16, color: accentColor)),
              const SizedBox(width: 10),

              // Title + subtitle
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                Text(title, style: const TextStyle(
                    color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),

              // ToolbarSpacer equivalent + Primary group
              if (primaryActions.isNotEmpty) ...[
                const SizedBox(width: 6),
                _GlassActionPill(
                    actions: primaryActions, accentColor: accentColor),
                const SizedBox(width: 8),
              ] else
                const SizedBox(width: 8),

              // Profile pill (always present — quick profile access)
              _ProfilePill(auth: auth, onTap: onProfileTap),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassActionPill — pill per azioni contestuali
// Replica SwiftUI ToolbarItemGroup: bottoni raggruppati in
// una capsula di vetro con separatori sottili.
// ─────────────────────────────────────────────────────────────

class _GlassActionPill extends StatelessWidget {
  final List<GlassToolbarAction> actions;
  final Color accentColor;
  const _GlassActionPill({required this.actions, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.09),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: Colors.white.withOpacity(0.16), width: 0.8),
            boxShadow: [
              BoxShadow(color: accentColor.withOpacity(0.06), blurRadius: 8),
              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6),
            ]),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (int i = 0; i < actions.length; i++) ...[
              if (i > 0) ...[
                const SizedBox(width: 2),
                Container(width: 0.5, height: 14,
                    color: Colors.white.withOpacity(0.2)),
                const SizedBox(width: 2),
              ],
              _ActionIconBtn(action: actions[i], accentColor: accentColor),
            ],
          ])),
      ),
    );
  }
}

class _ActionIconBtn extends StatelessWidget {
  final GlassToolbarAction action;
  final Color accentColor;
  const _ActionIconBtn({required this.action, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final color = action.color ?? Colors.white.withOpacity(0.85);
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
                decoration: const BoxDecoration(
                    color: _teal, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: Color(0x6600D4AA), blurRadius: 4)]))),
        ])));
  }
}

// ─────────────────────────────────────────────────────────────
// _ProfilePill — mini avatar sempre presente a destra
// Accesso rapido al profilo utente.
// ─────────────────────────────────────────────────────────────

class _ProfilePill extends StatelessWidget {
  final AuthProvider auth;
  final VoidCallback? onTap;
  const _ProfilePill({required this.auth, this.onTap});

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
              color: _teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _teal.withOpacity(0.35), width: 0.9),
              boxShadow: [
                BoxShadow(color: _teal.withOpacity(0.18), blurRadius: 8)
              ]),
            padding: const EdgeInsets.all(4),
            child: _MiniAvatar(
                b64: auth.avatarBase64, initials: auth.initials)))));
  }
}

class _MiniAvatar extends StatelessWidget {
  final String? b64;
  final String  initials;
  const _MiniAvatar({this.b64, required this.initials});

  @override
  Widget build(BuildContext context) {
    if (b64 != null && b64!.isNotEmpty) {
      try {
        final bytes = base64Decode(b64!);
        return ClipOval(child: Image.memory(
            bytes, width: 28, height: 28, fit: BoxFit.cover));
      } catch (_) {}
    }
    return Container(
      width: 28, height: 28,
      decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_teal, _tealDk]),
          shape: BoxShape.circle),
      child: Center(child: Text(
          initials.isEmpty ? '?' : initials[0].toUpperCase(),
          style: const TextStyle(color: Colors.white,
              fontSize: 11, fontWeight: FontWeight.w800))));
  }
}

// ─────────────────────────────────────────────────────────────
// _RadialDotsPainter — pattern decorativo ispirati all'articolo
// "Create Radial Pattern in SwiftUI".
// Anelli concentrici di punti che irradiano dall'angolo top-right.
// Opacità molto bassa (4-10%) per restare sottile e non invasivo.
// ─────────────────────────────────────────────────────────────

class _RadialDotsPainter extends CustomPainter {
  final Color color;
  const _RadialDotsPainter(this.color);

  static const _rings = [
    (r: 48.0,  n: 14, dr: 1.7, op: 0.10),
    (r: 78.0,  n: 22, dr: 1.3, op: 0.07),
    (r: 108.0, n: 28, dr: 1.0, op: 0.05),
    (r: 138.0, n: 34, dr: 0.7, op: 0.04),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Centro fuori dall'angolo top-right → solo la porzione
    // visibile nel rettangolo della barra viene disegnata.
    final cx = size.width + 12.0;
    final cy = -12.0;

    for (final ring in _rings) {
      final paint = Paint()..color = color.withOpacity(ring.op);
      for (int i = 0; i < ring.n; i++) {
        final angle = (i / ring.n) * 2 * math.pi;
        final x     = cx + ring.r * math.cos(angle);
        final y     = cy + ring.r * math.sin(angle);
        if (x >= 0 && y >= -ring.dr && x <= size.width && y <= size.height) {
          canvas.drawCircle(Offset(x, y), ring.dr, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_RadialDotsPainter old) => old.color != color;
}