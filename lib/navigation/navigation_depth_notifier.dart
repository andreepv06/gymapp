import 'package:flutter/material.dart';

/// Tiene traccia della profondità dello stack del Navigator root.
///
/// depth == 0  → l'utente è su una delle 4 tab principali (Oggi,
///               Allenamenti, Storico, Impostazioni): lo swipe
///               orizzontale tra tab deve essere ABILITATO.
/// depth  > 0  → l'utente ha aperto una schermata interna (es.
///               WorkoutDetailScreen, GoalFormScreen): lo swipe tra
///               tab deve essere DISABILITATO, lasciando il gesto
///               orizzontale allo swipe-back nativo iOS della
///               schermata interna.
class NavigationDepthNotifier extends ChangeNotifier {
  int _depth = 0;

  int get depth => _depth;
  bool get isAtRoot => _depth == 0;

  void push() {
    _depth++;
    notifyListeners();
  }

  void pop() {
    if (_depth > 0) {
      _depth--;
      notifyListeners();
    }
  }

  /// Da usare solo in scenari di reset esplicito (es. logout),
  /// per evitare che un conteggio desincronizzato blocchi
  /// permanentemente lo swipe tra tab.
  void reset() {
    if (_depth != 0) {
      _depth = 0;
      notifyListeners();
    }
  }
}

/// Observer collegato al Navigator root: incrementa/decrementa
/// [NavigationDepthNotifier] ad ogni push/pop di una PageRoute.
///
/// La primissima route (quella iniziale di MaterialApp, con
/// previousRoute == null) viene volutamente ignorata: non è una
/// navigazione reale dell'utente, è la route di partenza
/// dell'app, e non deve contare come "profondità 1".
class DepthTrackingNavigatorObserver extends NavigatorObserver {
  final NavigationDepthNotifier depthNotifier;

  DepthTrackingNavigatorObserver(this.depthNotifier);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return;
    if (route is PageRoute) depthNotifier.push();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) depthNotifier.pop();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) depthNotifier.pop();
  }
}