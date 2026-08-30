import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/markfit_colors.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';
import '../../widgets/workout_icon.dart';
import 'workout_detail_screen.dart';
import '../session/active_session_screen.dart';

const _kTeal   = MarkFitColors.teal;
const _kCyan   = MarkFitColors.cyan;
const _kRed    = MarkFitColors.red;
const _kOrange = MarkFitColors.orange;

// ─────────────────────────────────────────────────────────────
// WorkoutsScreen — "Le mie schede"
// ─────────────────────────────────────────────────────────────
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {

  Future<T?> _openSheet<T>(Widget child) {
    return showModalBottomSheet<T>(
      context:            context,
      isScrollControlled: true,
      useSafeArea:        true,
      backgroundColor:    Colors.transparent,
      isDismissible:      true,
      enableDrag:         true,
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child:   child,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateSheet() async {
    await _openSheet(WorkoutCreateSheet(
      onConfirm: (name) async {
        await HiveDatabase.instance.addWorkout(HiveWorkout(
          name:           name,
          iconId:         'dumbbell',
          iconColorIndex: 0,
          createdAt:      DateTime.now().toIso8601String(),
        ));
        if (mounted) {
          context.read<WorkoutProvider>().loadWorkouts();
          Navigator.pop(context);
        }
      },
    ));
  }

  Future<void> _showWorkoutOptions(HiveWorkout workout) async {
    await _openSheet(_WorkoutOptionsSheet(
      workout:        workout,
      onStartSession: () async {
        Navigator.pop(context);
        context.read<WorkoutProvider>().loadWorkoutExercises(workout.key);
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ActiveSessionScreen(workout: workout)),
        );
        if (mounted) context.read<WorkoutProvider>().loadWorkouts();
      },
      onEdit: () {
        Navigator.pop(context);
        _openDetailScreen(workout);
      },
      onRename: () {
        Navigator.pop(context);
        _showRenameSheet(workout);
      },
      onEditIconColor: () {
        Navigator.pop(context);
        _showIconColorSheet(workout);
      },
      onDelete: () {
        Navigator.pop(context);
        _confirmDelete(workout);
      },
    ));
  }

  Future<void> _openDetailScreen(HiveWorkout workout) async {
    context.read<WorkoutProvider>().loadWorkoutExercises(workout.key);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          workoutId:   workout.key,
          workoutName: workout.name,
        ),
      ),
    );
    if (mounted) context.read<WorkoutProvider>().loadWorkouts();
  }

  Future<void> _showRenameSheet(HiveWorkout workout) async {
    final ctrl = TextEditingController(text: workout.name);
    await _openSheet(_WorkoutRenameSheet(
      controller: ctrl,
      onConfirm: () {
        final name = ctrl.text.trim();
        if (name.isEmpty) return;
        HiveDatabase.instance.updateWorkout(workout.key, name);
        if (mounted) {
          context.read<WorkoutProvider>().loadWorkouts();
          Navigator.pop(context);
        }
      },
    ));
  }

  // FIX: usa showWorkoutIconColorSheet — popup a layout fisso
  // (anteprima + tab Icona/Colore + pulsanti sempre visibili),
  // aperto direttamente e non annidato in _openSheet.
  Future<void> _showIconColorSheet(HiveWorkout workout) async {
    await showWorkoutIconColorSheet(
      context,
      initialIconId:     workout.iconId,
      initialColorValue: workout.iconColorIndex,
      onSelect: (iconId, colorArgb) {
        workout.iconId         = iconId;
        workout.iconColorIndex = colorArgb;
        workout.save();
        if (mounted) {
          context.read<WorkoutProvider>().loadWorkouts();
          Navigator.pop(context);
        }
      },
    );
  }

  Future<void> _confirmDelete(HiveWorkout workout) async {
    final ok = await showGlassDialog<bool>(
      context:     context,
      accentColor: _kRed,
      icon: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color:     _kRed.withOpacity(0.12),
          shape:     BoxShape.circle,
          border:    Border.all(color: _kRed.withOpacity(0.4)),
          boxShadow: [BoxShadow(
              color: _kRed.withOpacity(0.2), blurRadius: 12)]),
        child: const Icon(Icons.delete_outline_rounded,
            color: _kRed, size: 22)),
      title:   'Elimina scheda',
      message: 'Vuoi eliminare "${workout.name}"? '
          'Tutti gli esercizi associati verranno rimossi.',
      actions: [
        GlassDialogAction(
          label: 'Annulla',
          onTap: () => Navigator.pop(context, false),
        ),
        GlassDialogAction(
          label:         'Elimina',
          isDestructive: true,
          onTap:         () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok == true && mounted) {
      final exercises =
          HiveDatabase.instance.getWorkoutExercises(workout.key);
      for (final ex in exercises) {
        await HiveDatabase.instance.deleteWorkoutExercise(ex.key);
      }
      await HiveDatabase.instance.deleteWorkout(workout.key);
      if (mounted) context.read<WorkoutProvider>().loadWorkouts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        subtle: true,
        child: SafeArea(
          child: Column(
            children: [
              // FIX: passa canGoBack per mostrare il pulsante indietro
              _GlassAppBar(
                onAdd:     _showCreateSheet,
                canGoBack: Navigator.of(context).canPop(),
              ),
              Expanded(
                child: Consumer<WorkoutProvider>(
                  builder: (ctx, wp, _) {
                    final workouts =
                        HiveDatabase.instance.getWorkouts()
                          ..sort((a, b) => a.name.compareTo(b.name));

                    if (workouts.isEmpty) {
                      return _EmptyState(onAdd: _showCreateSheet);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      physics: const BouncingScrollPhysics(),
                      itemCount: workouts.length,
                      itemBuilder: (_, i) {
                        final w = workouts[i];
                        return _WorkoutGlassCard(
                          workout:     w,
                          onTap:       () => _openDetailScreen(w),
                          onThreeDots: () => _showWorkoutOptions(w),
                          onStartSession: () async {
                            context
                                .read<WorkoutProvider>()
                                .loadWorkoutExercises(w.key);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ActiveSessionScreen(workout: w),
                              ),
                            );
                            if (mounted) {
                              context.read<WorkoutProvider>().loadWorkouts();
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassAppBar — FIX: aggiunto pulsante indietro Glass
//
// Il pulsante è mostrato quando canGoBack == true
// (WorkoutsScreen è sempre pushata, non è mai root tab).
// Coerente con _WorkoutHeader e _SessionHeader già presenti.
// ─────────────────────────────────────────────────────────────
class _GlassAppBar extends StatelessWidget {
  final VoidCallback onAdd;
  final bool         canGoBack;
  const _GlassAppBar({required this.onAdd, this.canGoBack = true});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: c.glassBlurStrong, sigmaY: c.glassBlurStrong),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color:        c.glassCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _kCyan.withOpacity(0.25), width: 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(
                      color:      c.elevationColor,
                      blurRadius: 12,
                      offset:     const Offset(0, 2))]
                  : null,
            ),
            child: Row(
              children: [
                // FIX: pulsante indietro Glass (coerente con _WorkoutHeader)
                if (canGoBack) ...[
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width:  36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:        c.glassCardInset,
                        borderRadius: BorderRadius.circular(10),
                        border:       Border.all(color: c.glassBorder),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: c.iconPrimary,
                        size:  15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Titolo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Le mie schede', style: TextStyle(
                          color:      c.textPrimary,
                          fontSize:   18,
                          fontWeight: FontWeight.w800)),
                      Text('Le tue schede di allenamento',
                          style: TextStyle(
                              color: c.textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
                // Pulsante aggiungi
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width:  38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_kTeal, MarkFitColors.tealDk]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                          color:     _kTeal.withOpacity(0.4),
                          blurRadius: 10,
                          offset:    const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 20),
                  ),
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
// _WorkoutGlassCard — ADATTIVO
// ─────────────────────────────────────────────────────────────
class _WorkoutGlassCard extends StatelessWidget {
  final HiveWorkout  workout;
  final VoidCallback onTap;
  final VoidCallback onThreeDots;
  final VoidCallback onStartSession;

  const _WorkoutGlassCard({
    required this.workout,
    required this.onTap,
    required this.onThreeDots,
    required this.onStartSession,
  });

  @override
  Widget build(BuildContext context) {
    final c     = context.mfc;
    final color = resolveWorkoutColor(workout.iconColorIndex);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: c.glassBlur, sigmaY: c.glassBlur),
            child: Container(
              decoration: BoxDecoration(
                color:        c.glassCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.glassBorder, width: 0.8),
                boxShadow: c.showElevation
                    ? [BoxShadow(
                        color:     c.elevationColor,
                        blurRadius: 8,
                        offset:    const Offset(0, 2))]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    WorkoutAvatar(
                      iconId:         workout.iconId,
                      iconColorIndex: workout.iconColorIndex,
                      size:           54,
                      iconSize:       27,
                      borderRadius:   14,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(workout.name, style: TextStyle(
                              color:      c.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 5),
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            _CardInfoTag(
                              label: _exerciseCount(workout.key),
                              color: color,
                              c:     c,
                            ),
                          ]),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onStartSession,
                      child: Container(
                        width:  38,
                        height: 38,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color:        color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withOpacity(0.4)),
                        ),
                        child: Icon(Icons.play_arrow_rounded,
                            color: color, size: 22),
                      ),
                    ),
                    GestureDetector(
                      onTap: onThreeDots,
                      child: Container(
                        width:  38,
                        height: 38,
                        decoration: BoxDecoration(
                          color:        c.glassCardInset,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.glassBorder),
                        ),
                        child: Icon(Icons.more_vert_rounded,
                            color: c.iconSecondary, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _exerciseCount(dynamic workoutKey) {
    try {
      return '${HiveDatabase.instance.getWorkoutExercises(workoutKey).length} eserc.';
    } catch (_) {
      return '0 eserc.';
    }
  }
}

class _CardInfoTag extends StatelessWidget {
  final String        label;
  final Color         color;
  final MarkFitColors c;
  const _CardInfoTag({
    required this.label, required this.color, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.7),
      ),
      child: Text(label, style: TextStyle(
          color:      color,
          fontSize:   11,
          fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  86,
              height: 86,
              decoration: BoxDecoration(
                color:     _kTeal.withOpacity(0.08),
                shape:     BoxShape.circle,
                border:    Border.all(
                    color: _kCyan.withOpacity(0.3), width: 1),
                boxShadow: [BoxShadow(
                    color: _kCyan.withOpacity(0.12), blurRadius: 24)],
              ),
              child: const Icon(Icons.fitness_center_rounded,
                  size: 40, color: _kTeal),
            ),
            const SizedBox(height: 22),
            Text('Nessuna scheda', style: TextStyle(
                color:      c.textPrimary,
                fontSize:   20,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Crea la tua prima scheda di allenamento\n'
              'per iniziare a tracciare i tuoi progressi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c.textTertiary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 28),
            GlassPrimaryButton(
              label: 'Crea scheda',
              color: _kTeal,
              onTap: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// SHEET WIDGETS — tutti theme-aware via GlassSheetWrapper
// ═════════════════════════════════════════════════════════════

class _WorkoutOptionsSheet extends StatelessWidget {
  final HiveWorkout  workout;
  final VoidCallback onStartSession;
  final VoidCallback onEdit;
  final VoidCallback onRename;
  final VoidCallback onEditIconColor;
  final VoidCallback onDelete;

  const _WorkoutOptionsSheet({
    required this.workout,
    required this.onStartSession,
    required this.onEdit,
    required this.onRename,
    required this.onEditIconColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c     = context.mfc;
    final color = resolveWorkoutColor(workout.iconColorIndex);

    return GlassSheetWrapper(
      title:       workout.name,
      accentColor: color,
      leadingIcon: WorkoutAvatar(
        iconId:         workout.iconId,
        iconColorIndex: workout.iconColorIndex,
        size:           40,
        iconSize:       20,
        borderRadius:   10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OptionTile(
            icon:  Icons.play_circle_outline_rounded,
            label: 'Avvia allenamento',
            color: _kTeal,
            c:     c,
            onTap: onStartSession,
          ),
          const SizedBox(height: 4),
          _OptionTile(
            icon:  Icons.edit_note_rounded,
            label: 'Modifica esercizi',
            color: _kCyan,
            c:     c,
            onTap: onEdit,
          ),
          const SizedBox(height: 4),
          _OptionTile(
            icon:  Icons.drive_file_rename_outline_rounded,
            label: 'Rinomina scheda',
            color: c.iconPrimary,
            c:     c,
            onTap: onRename,
          ),
          const SizedBox(height: 4),
          _OptionTile(
            icon:  Icons.palette_rounded,
            label: 'Modifica icona e colore',
            color: color,
            c:     c,
            onTap: onEditIconColor,
          ),
          const SizedBox(height: 8),
          Divider(height: 0, thickness: 0.6, color: c.divider),
          const SizedBox(height: 8),
          _OptionTile(
            icon:  Icons.delete_outline_rounded,
            label: 'Elimina scheda',
            color: _kRed,
            c:     c,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final Color         color;
  final MarkFitColors c;
  final VoidCallback  onTap;

  const _OptionTile({
    required this.icon,  required this.label,
    required this.color, required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Container(
              width:  38,
              height: 38,
              decoration: BoxDecoration(
                color:        color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color:      c.textPrimary,
                  fontSize:   15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: c.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _WorkoutRenameSheet extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback          onConfirm;

  const _WorkoutRenameSheet({
    required this.controller, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return GlassSheetWrapper(
      title:       'Rinomina scheda',
      accentColor: _kTeal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTextField(
            controller: controller,
            hintText:   'Nome scheda...',
            autofocus:  true,
            onChanged:  (_) {},
          ),
          const SizedBox(height: 20),
          GlassPrimaryButton(
            label: 'Rinomina',
            color: _kTeal,
            onTap: onConfirm,
          ),
        ],
      ),
    );
  }
}