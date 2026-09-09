import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/markfit_colors.dart';
import '../providers/session_provider.dart';
import 'shared_sheets.dart';

const _blue = Color(0xFF3B82F6);
const _orange = MarkFitColors.orange;
const _red = MarkFitColors.red;

/// Popup UNICO e centralizzato per la gestione di una sessione
/// ATTIVA, richiamato dal pulsante secondario presente sulla card
/// blu sia in Home sia in Allenamenti (stessa identica logica,
/// nessuna duplicazione — Parte 8/14 della richiesta).
///
/// Offre solo due azioni esplicite:
///  - Metti in pausa: sp.pauseSession() — il timer si ferma, i dati
///    restano, la sessione diventa "in pausa" (già gestita
///    dall'app: appare nella lista sp.pausedSessions).
///  - Abbandona sessione: sp.abandonSession() — cancella la sessione
///    da Hive (mai salvata come allenamento completato) e ripulisce
///    lo stato di pausa persistito. Nessuna conferma aggiuntiva:
///    l'azione è già etichettata come distruttiva nel dialog stesso,
///    coerente con il pattern isDestructive già usato altrove
///    nell'app (es. "Abbandona" nel vecchio _onBack di
///    ActiveSessionScreen).
///
/// NON viene mai chiamato automaticamente da uno swipe back o da
/// una semplice navigazione — solo da un tap esplicito dell'utente
/// su questo pulsante.
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
    await sp.abandonSession();
  }
  // 'cancel' o null (dismiss): nessuna azione, sessione invariata.
}