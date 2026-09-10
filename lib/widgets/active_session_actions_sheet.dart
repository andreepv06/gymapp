import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/markfit_colors.dart';
import '../providers/session_provider.dart';
import 'shared_sheets.dart';

const _blue = Color(0xFF3B82F6);
const _orange = MarkFitColors.orange;
const _red = MarkFitColors.red;

/// Popup di conferma CENTRALIZZATO per l'abbandono di una sessione
/// attiva. Punto UNICO usato sia dal pulsante cestino dentro
/// ActiveSessionScreen (header, controlli rapidi) sia dall'azione
/// "Abbandona sessione" del popup unificato aperto da Home/
/// Allenamenti (showActiveSessionActionsSheet, sotto). Nessuna
/// seconda implementazione, nessun testo duplicato.
///
/// Ritorna true SOLO se l'utente ha confermato e la sessione è
/// stata effettivamente abbandonata (sp.abandonSession() eseguito).
/// Ritorna false se l'utente ha annullato o chiuso il popup.
Future<bool> showAbandonSessionConfirmation(BuildContext context) async {
  final sp = context.read<SessionProvider>();
  final name = sp.currentWorkout?.name ?? 'la sessione';

  final result = await showGlassDialog<String>(
    context: context,
    accentColor: _red,
    icon: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _red.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: _red.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: _red.withOpacity(0.2), blurRadius: 12),
        ],
      ),
      child: const Icon(Icons.delete_outline_rounded,
          color: _red, size: 22),
    ),
    title: 'Abbandonare la sessione?',
    message: '"$name" verrà eliminata: i dati inseriti andranno '
        'persi e la sessione non sarà salvata nello storico.',
    actions: [
      GlassDialogAction(
        label: 'Annulla',
        onTap: () => Navigator.pop(context, 'cancel'),
      ),
      GlassDialogAction(
        label: 'Abbandona sessione',
        isDestructive: true,
        onTap: () => Navigator.pop(context, 'abandon'),
      ),
    ],
  );

  if (result == 'abandon') {
    if (!context.mounted) return false;
    await context.read<SessionProvider>().abandonSession();
    return true;
  }
  return false;
}

/// Popup UNICO e centralizzato per la gestione di una sessione
/// ATTIVA, richiamato dal pulsante secondario presente sulla card
/// blu sia in Home sia in Allenamenti (stessa identica logica,
/// nessuna duplicazione).
///
/// FIX — l'azione "Abbandona sessione" non elimina più
/// direttamente: riusa showAbandonSessionConfirmation() sopra,
/// esattamente come il pulsante cestino in ActiveSessionScreen.
Future<void> showActiveSessionActionsSheet(BuildContext context) async {
  final sp = context.read<SessionProvider>();
  final name = sp.currentWorkout?.name ?? 'Sessione attiva';

  final result = await showGlassDialog<String>(
    context: context,
    accentColor: _blue,
    icon: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _blue.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: _blue.withOpacity(0.4)),
      ),
      child: const Icon(Icons.sports_gymnastics_rounded,
          color: Color(0xFF60A5FA), size: 22),
    ),
    title: 'Sessione attiva',
    message: '"$name" è in corso. Cosa vuoi fare?',
    actionsAxis: Axis.vertical,
    actions: [
      GlassDialogAction(
        label: 'Metti in pausa',
        color: _orange,
        onTap: () => Navigator.pop(context, 'pause'),
      ),
      GlassDialogAction(
        label: 'Abbandona sessione',
        isDestructive: true,
        onTap: () => Navigator.pop(context, 'abandon'),
      ),
      GlassDialogAction(
        label: 'Annulla',
        onTap: () => Navigator.pop(context, 'cancel'),
      ),
    ],
  );

  if (!context.mounted) return;
  if (result == 'pause') {
    await sp.pauseSession();
  } else if (result == 'abandon') {
    // FIX — riusa lo stesso popup di conferma centralizzato del
    // pulsante cestino, invece di abbandonare direttamente.
    await showAbandonSessionConfirmation(context);
  }
}