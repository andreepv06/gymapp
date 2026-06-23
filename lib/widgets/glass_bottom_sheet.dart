import 'dart:ui';
import 'package:flutter/material.dart';

class GlassBottomSheetWrapper extends StatelessWidget {
  final Widget child;
  const GlassBottomSheetWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? cs.surface.withOpacity(0.88)
                : cs.surface.withOpacity(0.94),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : cs.outlineVariant.withOpacity(0.4),
                width: 1,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlassDialog extends StatelessWidget {
  final Widget child;
  const GlassDialog({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? cs.surface.withOpacity(0.88)
                  : cs.surface.withOpacity(0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : cs.outlineVariant.withOpacity(0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// showGlassBottomSheet
//
// VERSIONE DEFINITIVA — torna al pattern minimo e proven.
//
// Nessuno Scaffold, nessun Padding aggiunto a questo livello
// centrale. Ogni sheet gestisce da sé l'eventuale padding per la
// tastiera (esattamente come il pattern "Nuovo esercizio" che non
// ha mai dato problemi). Questo elimina sia il bug "il pannello
// appare dall'alto" (causato dallo Scaffold che si espandeva a
// piena altezza e allineava il contenuto in cima) sia qualsiasi
// doppia gestione della tastiera in conflitto con quella di ogni
// singolo sheet.
// ─────────────────────────────────────────────
Future<T?> showGlassBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    builder: (_) => GlassBottomSheetWrapper(child: child),
  );
}

Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required Widget child,
}) {
  return showDialog<T>(
    context: context,
    builder: (_) => GlassDialog(child: child),
  );
}