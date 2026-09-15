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
// ─────────────────────────────────────────────────────────────

// NUOVO (fix lentezza back) — variante di CupertinoPageRoute con
// reverseTransitionDuration più breve. Dopo il fix del flash bianco
// (che riguardava solo lo sfondo del DOM/browser), il pop stesso
// impiegava sempre la durata di animazione "standard" pensata per un
// push a freddo, non per il rilascio di un gesto già in corso —
// percepita come lentezza. Accorciamo SOLO la direzione "indietro":
// il push in avanti resta identico a prima. Nessuna modifica al
// meccanismo anti-flash-bianco (web/index.html, non toccato qui).
class _FastPopCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  _FastPopCupertinoPageRoute({required super.builder});

  @override
  Duration get reverseTransitionDuration =>
      const Duration(milliseconds: 220);
}

/// Pusha una nuova pagina con transizione CupertinoPageRoute
/// e full-screen swipe back abilitato.
Future<T?> pushPage<T extends Object?>(
    BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    _FastPopCupertinoPageRoute<T>(
      builder: (_) => FullScreenSwipeBack(child: page),
    ),
  );
}

/// Pusha una nuova pagina sostituendo quella corrente.
Future<T?> pushReplacementPage<T extends Object?,
    TO extends Object?>(BuildContext context, Widget page) {
  return Navigator.of(context).pushReplacement<T, TO>(
    _FastPopCupertinoPageRoute<T>(
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