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
// FIX TASTIERA — VERSIONE DEFINITIVA
//
// CAUSA REALE DEL BUG:
// showModalBottomSheet con isScrollControlled: true gestisce GIÀ
// internamente l'adattamento alla tastiera. Le versioni precedenti
// aggiungevano un Padding(bottom: viewInsets.bottom) manuale, che
// si SOMMAVA a quello già applicato dal framework. Il risultato è
// un doppio spostamento verso l'alto al primo frame in cui la
// tastiera si apre — esattamente il sintomo riportato: il campo
// "sparisce" verso l'alto la prima volta, perché viene spinto del
// doppio rispetto al necessario. Chiudendo e riaprendo la
// tastiera il bug non si ripresenta perché a quel punto i
// meccanismi interni del framework hanno già raggiunto uno stato
// stabile.
//
// CORREZIONE:
// Si rimuove il Padding manuale e si delega l'adattamento alla
// tastiera a un Scaffold con resizeToAvoidBottomInset: true.
// Questo è esattamente lo stesso identico meccanismo che fa
// funzionare correttamente la tastiera in TUTTE le altre
// schermate dell'app (es. login, dove non è mai stato segnalato
// alcun problema): è il meccanismo robusto e testato del
// framework, non una nostra logica ad-hoc che può confliggere con
// quella di sistema.
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
    builder: (sheetContext) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: GlassBottomSheetWrapper(child: child),
      );
    },
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