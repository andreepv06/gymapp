import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

// ─────────────────────────────────────────────────────────────
// FullScreenSwipeBack
//
// Replica il comportamento iOS 26 / SwiftUI descritto nell'allegato:
//   gestureRecognizerShouldBegin → dx > 0 && |dx| > |dy|
//   Trigger pop: frazione schermo ≥ 30% oppure velocity > 500 px/s
//
// MODIFICATO (fix lentezza) — la soglia di velocity, dichiarata ma
// mai realmente usata nella versione precedente (il pop scattava
// solo in base alla distanza percorsa), è ora implementata con un
// vero VelocityTracker. Un flick rapido ma breve — tipico quando lo
// swipe non parte dal bordo estremo — ora fa scattare il pop subito,
// invece di richiedere sempre almeno il 30% di trascinamento.
//
// Non interferisce con:
//   • ListView / SingleChildScrollView (scroll verticale)
//   • PageView / TabBarView (scroll orizzontale interno)
//   • TextField / GestureDetector figli
//   • Root route (canPop == false)
//
// Utilizzo: wrappare ogni pagina pushata tramite pushPage().
// Non applicare alle tab del MainShell (root).
// ─────────────────────────────────────────────────────────────

class FullScreenSwipeBack extends StatefulWidget {
  final Widget child;
  const FullScreenSwipeBack({super.key, required this.child});

  @override
  State<FullScreenSwipeBack> createState() => _FullScreenSwipeBackState();
}

class _FullScreenSwipeBackState extends State<FullScreenSwipeBack> {
  // Stato del riconoscimento del gesto corrente
  _SwipeState _state = _SwipeState.idle;
  Offset      _start = Offset.zero;
  double      _accumulated = 0;

  // NUOVO (fix lentezza) — traccia la velocità reale del gesto in
  // px/s tramite VelocityTracker (la stessa classe usata
  // internamente da Flutter per i gesti drag/fling), alimentato ad
  // ogni movimento fin dal primo istante del gesto.
  VelocityTracker? _velocityTracker;

  // Soglie (identiche all'implementazione UIKit allegata)
  static const double _fractionThreshold  = 0.30; // 30% larghezza
  static const double _velocityThreshold  = 500.0; // px/s
  static const double _directionLockPx   = 8.0;   // px minimi per lock

  // ── Helpers ────────────────────────────────────────────────

  bool _canPop() {
    if (!mounted) return false;
    try {
      final route = ModalRoute.of(context);
      return route != null &&
          !route.isFirst &&
          Navigator.of(context).canPop();
    } catch (_) {
      return false;
    }
  }

  void _reset() {
    _state            = _SwipeState.idle;
    _start            = Offset.zero;
    _accumulated      = 0;
    _velocityTracker  = null;
  }

  // ── Pointer Listener ───────────────────────────────────────
  //
  // Usiamo Listener (raw pointer) per il rilevamento della
  // direzione iniziale, così possiamo cedere il gesto ai widget
  // interni (ScrollView, PageView) quando necessario.
  // Quando il gesto è chiaramente orizzontale destro, usciamo
  // SOLO al rilascio — non creiamo una nostra transizione visiva,
  // perché CupertinoPageRoute gestisce già l'animazione pop
  // internamente in modo nativo e fluido.

  void _onPointerDown(PointerDownEvent e) {
    if (!_canPop()) {
      _state = _SwipeState.rejected;
      return;
    }
    _start       = e.position;
    _accumulated = 0;
    _state       = _SwipeState.detecting;
    // NUOVO — inizializza il tracker fin dal primo tocco.
    _velocityTracker = VelocityTracker.withKind(e.kind);
    _velocityTracker!.addPosition(e.timeStamp, e.position);
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_state == _SwipeState.rejected) return;
    if (_state == _SwipeState.idle)     return;

    // NUOVO — alimenta il tracker ad ogni movimento, indipendente-
    // mente dalla fase (detecting o tracking): garantisce una stima
    // di velocità accurata anche per gesti brevi e rapidi.
    _velocityTracker?.addPosition(e.timeStamp, e.position);

    final dx = e.position.dx - _start.dx;
    final dy = e.position.dy - _start.dy;

    // Fase di rilevamento direzione: aspettiamo almeno _directionLockPx
    if (_state == _SwipeState.detecting) {
      if (dx.abs() < _directionLockPx && dy.abs() < _directionLockPx) return;

      // Controlla dx > 0 && |dx| > |dy| (come SwiftUI allegato)
      if (dx > 0 && dx.abs() > dy.abs()) {
        _state = _SwipeState.tracking;
      } else {
        // Movimento verticale o verso sinistra → cedere ai widget interni
        _state = _SwipeState.rejected;
        return;
      }
    }

    // Fase tracking: accumula solo movimento positivo (verso destra)
    if (_state == _SwipeState.tracking) {
      if (e.delta.dx > 0) {
        _accumulated += e.delta.dx;
      } else if (e.delta.dx < -20) {
        // Utente ha invertito decisamente → annulla
        _reset();
      }
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_state != _SwipeState.tracking) {
      _reset();
      return;
    }

    final width    = MediaQuery.sizeOf(context).width;
    final fraction = (_accumulated / width).clamp(0.0, 1.0);

    // NUOVO (fix lentezza) — velocità reale calcolata dal
    // VelocityTracker, finalmente utilizzata: un flick rapido fa
    // scattare il pop anche molto sotto il 30% di trascinamento,
    // esattamente come descritto nel commento originale del file ma
    // mai realmente implementato prima d'ora.
    final velocityEstimate = _velocityTracker?.getVelocity();
    final vx = velocityEstimate?.pixelsPerSecond.dx ?? 0.0;

    final shouldPop =
        fraction >= _fractionThreshold || vx > _velocityThreshold;

    _reset();

    if (shouldPop && _canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _onPointerCancel(PointerCancelEvent e) => _reset();

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown:   _onPointerDown,
      onPointerMove:   _onPointerMove,
      onPointerUp:     _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SwipeBackWithVelocity
//
// Alternativa che usa GestureDetector.onHorizontalDrag* per
// avere accesso alla velocity reale.
// Usata internamente da pushPage come fallback su schermate
// senza scroll orizzontale.
// ─────────────────────────────────────────────────────────────

class _SwipeBackWithVelocity extends StatefulWidget {
  final Widget child;
  const _SwipeBackWithVelocity({required this.child});

  @override
  State<_SwipeBackWithVelocity> createState() =>
      _SwipeBackWithVelocityState();
}

class _SwipeBackWithVelocityState
    extends State<_SwipeBackWithVelocity> {
  double _accumulated = 0;
  bool   _active      = false;

  bool _canPop() {
    if (!mounted) return false;
    try {
      final route = ModalRoute.of(context);
      return route != null &&
          !route.isFirst &&
          Navigator.of(context).canPop();
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (d) {
        _accumulated = 0;
        _active      = _canPop();
      },
      onHorizontalDragUpdate: (d) {
        if (!_active) return;
        if (d.delta.dx > 0) {
          _accumulated += d.delta.dx;
        } else if (d.delta.dx < -15) {
          _accumulated = 0;
          _active = false;
        }
      },
      onHorizontalDragEnd: (d) {
        if (!_active) { _accumulated = 0; return; }
        final width    = MediaQuery.sizeOf(context).width;
        final fraction = (_accumulated / width).clamp(0.0, 1.0);
        final velocity = d.primaryVelocity ?? 0;
        _accumulated = 0;
        _active      = false;
        if ((fraction >= 0.30 || velocity > 500) && _canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SwipeState
// ─────────────────────────────────────────────────────────────

enum _SwipeState { idle, detecting, tracking, rejected }