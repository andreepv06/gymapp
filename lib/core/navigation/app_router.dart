import 'package:flutter/cupertino.dart';

/// Navigazione centralizzata con CupertinoPageRoute.
///
/// Perché CupertinoPageRoute (non MaterialPageRoute):
/// - Gestisce internamente il background durante lo swipe-back
///   leggendo CupertinoTheme.scaffoldBackgroundColor
/// - Elimina il white-flash (problema noto Flutter #83183)
/// - Identico al comportamento nativo iOS di Instagram/WhatsApp
/// - Funziona su tutte le piattaforme (iOS, Android, web)
Future<T?> pushPage<T extends Object?>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    CupertinoPageRoute<T>(builder: (_) => page),
  );
}

Future<T?> pushReplacementPage<T extends Object?, TO extends Object?>(
    BuildContext context, Widget page) {
  return Navigator.of(context).pushReplacement<T, TO>(
    CupertinoPageRoute<T>(builder: (_) => page),
  );
}

Future<T?> pushAndRemoveAll<T extends Object?>(
    BuildContext context, Widget page) {
  return Navigator.of(context).pushAndRemoveUntil<T>(
    CupertinoPageRoute<T>(builder: (_) => page),
    (_) => false,
  );
}