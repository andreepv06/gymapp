import 'package:flutter/cupertino.dart';
import '../../widgets/full_screen_swipe_back.dart';

// ─────────────────────────────────────────────────────────────
// app_router.dart
//
// Navigazione centralizzata con CupertinoPageRoute.
//
// Perché CupertinoPageRoute (non MaterialPageRoute):
//   • Gestisce internamente il background durante lo swipe-back
//     leggendo CupertinoTheme.scaffoldBackgroundColor
//   • Elimina il white-flash (problema noto Flutter #83183)
//   • Identico al comportamento nativo iOS di Instagram/WhatsApp
//   • Funziona su tutte le piattaforme (iOS, Android, web)
//
// Full-screen swipe back (iOS 26 / allegato tecnico):
//   Ogni pagina pushata viene automaticamente wrappata con
//   FullScreenSwipeBack, che abilita il pop gesture da qualsiasi
//   punto dello schermo (non solo dal bordo sinistro).
//   Il comportamento è identico a quello descritto nell'allegato
//   SwiftUI: dx > 0 && |dx| > |dy| come in
//   gestureRecognizerShouldBegin(_:).
// ─────────────────────────────────────────────────────────────

/// Pusha una nuova pagina con transizione CupertinoPageRoute
/// e full-screen swipe back abilitato.
Future<T?> pushPage<T extends Object?>(
    BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    CupertinoPageRoute<T>(
      builder: (_) => FullScreenSwipeBack(child: page),
    ),
  );
}

/// Pusha una nuova pagina sostituendo quella corrente.
Future<T?> pushReplacementPage<T extends Object?,
    TO extends Object?>(BuildContext context, Widget page) {
  return Navigator.of(context).pushReplacement<T, TO>(
    CupertinoPageRoute<T>(
      builder: (_) => FullScreenSwipeBack(child: page),
    ),
  );
}

/// Pusha rimuovendo tutto lo stack precedente.
/// NON wrappa con FullScreenSwipeBack (root screen).
Future<T?> pushAndRemoveAll<T extends Object?>(
    BuildContext context, Widget page) {
  return Navigator.of(context).pushAndRemoveUntil<T>(
    CupertinoPageRoute<T>(builder: (_) => page),
    (_) => false,
  );
}