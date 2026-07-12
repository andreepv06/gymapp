import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/navigation/app_router.dart';
import '../../providers/workout_provider.dart';
import '../../providers/session_provider.dart';
import '../../models/hive_models.dart';
import '../../main.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';
import '../../widgets/workout_icon.dart';
import 'active_session_screen.dart';

class SessionSelectorScreen extends StatefulWidget {
  const SessionSelectorScreen({super.key});

  @override
  State<SessionSelectorScreen> createState() =>
      _SessionSelectorScreenState();
}

class _SessionSelectorScreenState
    extends State<SessionSelectorScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<WorkoutProvider>().loadWorkouts());
  }

  // ── FIX 1: action sheet quando esiste sessione in pausa ──

  Future<void> _handleWorkoutTap(
    BuildContext context,
    HiveWorkout workout,
    WorkoutProvider workoutProvider,
    SessionProvider sessionProvider,
  ) async {
    workoutProvider.loadWorkoutExercises(workout.key);
    if (!context.mounted) return;

    // Controlla se esiste una sessione esplicitamente messa in pausa
    // per questa scheda specifica
    if (sessionProvider.hasPausedSessionForWorkout(workout.key)) {
      final paused =
          sessionProvider.getMostRecentPausedForWorkout(workout.key);

      final result = await showCupertinoModalPopup<String>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Sessione in pausa'),
          message: Text(
            'Hai una sessione in pausa per "${workout.name}".\nCosa vuoi fare?',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'resume'),
              child: const Text('Riprendi sessione'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'new'),
              child: const Text('Avvia nuova sessione'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Annulla'),
          ),
        ),
      );

      if (!context.mounted) return;
      if (result == null || result == 'cancel') return;

      if (result == 'resume' && paused != null) {
        // Ripristina la sessione in pausa in-memory
        await sessionProvider
            .resumePausedSession(paused['id'] as String);
        if (!context.mounted) return;
        // Naviga: ActiveSessionScreen rileva la sessione già attiva
        // e non ne avvia una nuova
        pushPage(context, ActiveSessionScreen(workout: workout));
      } else if (result == 'new') {
        // Avvia sessione indipendente senza toccare quella in pausa.
        // Poiché pauseSession() ha già pulito l'in-memory, startSession()
        // creerà una sessione nuova senza interferire con la lista pausa.
        pushPage(context, ActiveSessionScreen(workout: workout));
      }
    } else {
      // Nessuna sessione in pausa → avvio normale
      pushPage(context, ActiveSessionScreen(workout: workout));
    }
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final workouts = workoutProvider.workouts;
    final cs = Theme.of(context).colorScheme;

    if (workouts.isEmpty) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface,
          title: const Text('Sessione'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.fitness_center,
                      size: 40,
                      color: cs.onSecondaryContainer),
                ),
                const SizedBox(height: 20),
                Text(
                  'Nessuna scheda disponibile',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Crea prima una scheda\nper iniziare una sessione',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.outline),
                ),
                const SizedBox(height: 28),
                GlassButton(
                  onTap: () => context
                      .read<NavigationNotifier>()
                      .navigateTo(1),
                  icon: Icons.list_alt_rounded,
                  label: 'Vai alle schede',
                  minWidth: 200,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Sessione'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner sessione crash-recovery (in-memory attiva)
          if (sessionProvider.hasActiveSession)
            _PausedSessionBanner(
              workout: sessionProvider.currentWorkout!,
              onResume: () {
                pushPage(
                  context,
                  ActiveSessionScreen(
                    workout: sessionProvider.currentWorkout!,
                  ),
                );
              },
              onAbandon: () async {
                final confirm = await showGlassDialog<bool>(
                  context: context,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.delete_outline,
                                color: Colors.red, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Abbandona sessione',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Vuoi abbandonare la sessione in pausa? '
                          'I dati non verranno salvati.',
                        ),
                        const SizedBox(height: 24),
                        GlassDialogActions(
                          cancelLabel: 'Annulla',
                          confirmLabel: 'Abbandona',
                          confirmColor: Colors.red,
                          onCancel: () =>
                              Navigator.pop(context, false),
                          onConfirm: () =>
                              Navigator.pop(context, true),
                        ),
                      ],
                    ),
                  ),
                );
                if (confirm == true && context.mounted) {
                  await context
                      .read<SessionProvider>()
                      .abandonSession();
                }
              },
            ),

          _SessionHeader(),

          Padding(
            padding:
                const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'Scegli la scheda',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    color: cs.outline,
                    letterSpacing: 0.5,
                  ),
            ),
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  16, 0, 16, 100),
              itemCount: workouts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final workout = workouts[index];
                return _WorkoutSessionCard(
                  workout: workout,
                  hasPausedSession: sessionProvider
                      .hasPausedSessionForWorkout(workout.key),
                  onTap: () => _handleWorkoutTap(
                    context,
                    workout,
                    workoutProvider,
                    sessionProvider,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _PausedSessionBanner (crash recovery / sessione in-memory)
// ─────────────────────────────────────────────────────────────

class _PausedSessionBanner extends StatelessWidget {
  final HiveWorkout workout;
  final VoidCallback onResume;
  final VoidCallback onAbandon;

  const _PausedSessionBanner({
    required this.workout,
    required this.onResume,
    required this.onAbandon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter:
              ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer
                  .withOpacity(isDark ? 0.7 : 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                WorkoutAvatar(
                  iconId: workout.iconId,
                  iconColorIndex: workout.iconColorIndex,
                  customImagePath: workout.customImagePath,
                  size: 36,
                  iconSize: 18,
                  borderRadius: 9,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sessione in corso',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        workout.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onPrimaryContainer
                              .withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                GlassTextButton(
                  onPressed: onAbandon,
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: const Text('Elimina'),
                ),
                const SizedBox(width: 4),
                GlassFilledButton(
                  onPressed: onResume,
                  child: const Text('Riprendi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SessionHeader
// ─────────────────────────────────────────────────────────────

class _SessionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.secondary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.fitness_center_rounded,
                color: cs.onSecondary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pronto ad allenarti?',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        color: cs.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Scegli una scheda per iniziare',
                  style: TextStyle(
                    color: cs.onSecondaryContainer
                        .withOpacity(0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _WorkoutSessionCard
// ─────────────────────────────────────────────────────────────

class _WorkoutSessionCard extends StatelessWidget {
  final HiveWorkout workout;
  final VoidCallback onTap;
  final bool hasPausedSession;

  const _WorkoutSessionCard({
    required this.workout,
    required this.onTap,
    this.hasPausedSession = false,
  });

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              WorkoutAvatar(
                iconId: workout.iconId,
                iconColorIndex: workout.iconColorIndex,
                customImagePath: workout.customImagePath,
                size: 48,
                iconSize: 24,
                borderRadius: 12,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Indicatore sessione in pausa
                    if (hasPausedSession)
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Sessione in pausa',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        _formatDate(workout.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.outline,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: hasPausedSession
                      ? Colors.orange
                      : cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasPausedSession
                      ? Icons.play_arrow_rounded
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}