import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/navigation/app_router.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/workout_icon.dart';
import 'workout_detail_screen.dart';

const _teal = Color(0xFF00D4AA);
const _red  = Color(0xFFFF3B30);

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});
  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<WorkoutProvider>().loadWorkouts());
  }

  // FIX: metodo DENTRO la classe — context è disponibile
  Future<T?> _showKeyboardSafeSheet<T>(Widget child) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateSheet() async {
    final ctrl = TextEditingController();
    await _showKeyboardSafeSheet(
      _WorkoutCreateSheet(
        nameController: ctrl,
        onConfirm: () {
          final name = ctrl.text.trim();
          if (name.isEmpty) return;
          HiveDatabase.instance.addWorkout(HiveWorkout(
            name: name,
            iconId: 'dumbbell',
            iconColorIndex: 0,
            createdAt: DateTime.now().toIso8601String(),
          ));
          if (mounted) {
            context.read<WorkoutProvider>().loadWorkouts();
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showWorkoutOptions(HiveWorkout workout) {
    _showKeyboardSafeSheet(
      _WorkoutOptionsSheet(
        workout: workout,
        onRename: () {
          Navigator.pop(context);
          _showRenameSheet(workout);
        },
        onChangeIcon: () {
          Navigator.pop(context);
          _showIconSheet(workout);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(workout);
        },
      ),
    );
  }

  Future<void> _showRenameSheet(HiveWorkout workout) async {
    final ctrl = TextEditingController(text: workout.name);
    await _showKeyboardSafeSheet(
      _WorkoutRenameSheet(
        nameController: ctrl,
        onConfirm: () {
          final name = ctrl.text.trim();
          if (name.isEmpty) return;
          HiveDatabase.instance.updateWorkout(workout.key, name);
          if (mounted) {
            context.read<WorkoutProvider>().loadWorkouts();
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Future<void> _showIconSheet(HiveWorkout workout) async {
    await _showKeyboardSafeSheet(
      _WorkoutIconSheet(
        currentIconId: workout.iconId ?? 'dumbbell',
        currentColorIndex: workout.iconColorIndex ?? 0,
        onSelect: (iconId, colorIndex) {
          workout.iconId = iconId;
          workout.iconColorIndex = colorIndex;
          workout.save();
          if (mounted) {
            context.read<WorkoutProvider>().loadWorkouts();
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(HiveWorkout workout) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1030),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: _red, size: 22),
            const SizedBox(width: 10),
            const Text('Elimina scheda',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
        content: Text(
          'Eliminare "${workout.name}"? '
          'Questa azione non può essere annullata.',
          style: TextStyle(
              color: Colors.white.withOpacity(0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annulla',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina',
                style: TextStyle(
                    color: _red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await HiveDatabase.instance.deleteWorkout(workout.key);
      context.read<WorkoutProvider>().loadWorkouts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final workouts = context.watch<WorkoutProvider>().workouts;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        subtle: true,
        child: SafeArea(
          child: Column(
            children: [
              _GlassAppBar(
                title: 'Le mie schede',
                onBack: () => Navigator.pop(context),
                action: GestureDetector(
                  onTap: _showCreateSheet,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _teal.withOpacity(0.35)),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: _teal, size: 20),
                  ),
                ),
              ),
              Expanded(
                child: workouts.isEmpty
                    ? _EmptyWorkoutsState(
                        onCreateNew: _showCreateSheet)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 12, 16, 100),
                        physics: const BouncingScrollPhysics(),
                        itemCount: workouts.length,
                        itemBuilder: (_, i) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 12),
                            child: _WorkoutGlassCard(
                              workout: workouts[i],
                              onTap: () {
                                context
                                    .read<WorkoutProvider>()
                                    .loadWorkoutExercises(
                                        workouts[i].key);
                                pushPage(
                                  context,
                                  WorkoutDetailScreen(
                                    workoutId: workouts[i].key,
                                    workoutName: workouts[i].name,
                                  ),
                                );
                              },
                              onOptions: () =>
                                  _showWorkoutOptions(workouts[i]),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: _showCreateSheet,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _teal.withOpacity(0.28),
                      const Color(0xFF00A880).withOpacity(0.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _teal.withOpacity(0.55), width: 1.3),
                  boxShadow: [
                    BoxShadow(
                        color: _teal.withOpacity(0.25),
                        blurRadius: 20,
                        spreadRadius: 1)
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: _teal, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Nuova scheda',
                      style: TextStyle(
                        color: _teal,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
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
}

// ─────────────────────────────────────────────────────────────
// _GlassAppBar
// ─────────────────────────────────────────────────────────────

class _GlassAppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? action;
  const _GlassAppBar(
      {required this.title, required this.onBack, this.action});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _WorkoutGlassCard
// ─────────────────────────────────────────────────────────────

class _WorkoutGlassCard extends StatelessWidget {
  final HiveWorkout workout;
  final VoidCallback onTap;
  final VoidCallback onOptions;
  const _WorkoutGlassCard({
    required this.workout,
    required this.onTap,
    required this.onOptions,
  });
  Map<String, int> _stats() {
    final allEx =
        HiveDatabase.instance.getWorkoutExercises(workout.key);
    final circuits =
        HiveDatabase.instance.getCircuits(workout.key);
    return {
      'free': allEx.where((e) => !e.isInCircuit).length,
      'circuits': circuits.length,
      'sets': allEx.fold(0, (s, e) => s + e.sets),
    };
  }
  @override
  Widget build(BuildContext context) {
    final stats = _stats();
    final freeEx = stats['free'] ?? 0;
    final circuits = stats['circuits'] ?? 0;
    final sets = stats['sets'] ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  WorkoutAvatar(
                    iconId: workout.iconId ?? 'dumbbell',
                    iconColorIndex: workout.iconColorIndex ?? 0,
                    customImagePath: workout.customImagePath,
                    size: 52,
                    iconSize: 26,
                    borderRadius: 14,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(workout.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (freeEx > 0)
                              _CardInfoTag(
                                  icon: Icons
                                      .fitness_center_outlined,
                                  label: '$freeEx eserc.'),
                            if (circuits > 0)
                              _CardInfoTag(
                                  icon: Icons.loop_rounded,
                                  label: '$circuits circuiti'),
                            if (sets > 0)
                              _CardInfoTag(
                                  icon: Icons.repeat_rounded,
                                  label: '$sets serie'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: onOptions,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Icon(
                              Icons.more_horiz_rounded,
                              color:
                                  Colors.white.withOpacity(0.5),
                              size: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: Colors.white.withOpacity(0.35)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardInfoTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CardInfoTag({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.white38),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _EmptyWorkoutsState
// ─────────────────────────────────────────────────────────────

class _EmptyWorkoutsState extends StatelessWidget {
  final VoidCallback onCreateNew;
  const _EmptyWorkoutsState({required this.onCreateNew});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _teal.withOpacity(0.25), width: 1.5),
              ),
              child: const Icon(Icons.fitness_center_outlined,
                  size: 38, color: _teal),
            ),
            const SizedBox(height: 20),
            const Text('Nessuna scheda',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Crea la tua prima scheda\ne inizia ad allenarti',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 14,
                  height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onCreateNew,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _teal.withOpacity(0.3),
                    _teal.withOpacity(0.15)
                  ]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _teal.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                        color: _teal.withOpacity(0.2),
                        blurRadius: 16)
                  ],
                ),
                child: const Text('Crea nuova scheda',
                    style: TextStyle(
                        color: _teal,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _WorkoutOptionsSheet
// ─────────────────────────────────────────────────────────────

class _WorkoutOptionsSheet extends StatelessWidget {
  final HiveWorkout workout;
  final VoidCallback onRename;
  final VoidCallback onChangeIcon;
  final VoidCallback onDelete;
  const _WorkoutOptionsSheet({
    required this.workout,
    required this.onRename,
    required this.onChangeIcon,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF100B22).withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24)),
        border: Border.all(
            color: Colors.white.withOpacity(0.12), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              WorkoutAvatar(
                iconId: workout.iconId ?? 'dumbbell',
                iconColorIndex: workout.iconColorIndex ?? 0,
                customImagePath: workout.customImagePath,
                size: 36,
                iconSize: 18,
                borderRadius: 9,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(workout.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    _OptionRow(
                      icon: Icons
                          .drive_file_rename_outline_rounded,
                      label: 'Rinomina scheda',
                      onTap: onRename,
                    ),
                    Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.06),
                        indent: 52),
                    _OptionRow(
                      icon: Icons.image_outlined,
                      label: 'Cambia icona / immagine',
                      onTap: onChangeIcon,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _red.withOpacity(0.2)),
                ),
                child: _OptionRow(
                  icon: Icons.delete_outline_rounded,
                  label: 'Elimina scheda',
                  color: _red,
                  onTap: onDelete,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  size: 16, color: c.withOpacity(0.8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: c,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: c.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _WorkoutCreateSheet / _WorkoutRenameSheet
// ─────────────────────────────────────────────────────────────

class _WorkoutCreateSheet extends StatelessWidget {
  final TextEditingController nameController;
  final VoidCallback onConfirm;
  const _WorkoutCreateSheet(
      {required this.nameController, required this.onConfirm});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF100B22).withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24)),
        border: Border.all(
            color: Colors.white.withOpacity(0.12), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded,
                    color: _teal, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Nuova scheda',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nome scheda',
              hintText: 'Es. Push Day, Full Body...',
              labelStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5)),
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Crea scheda',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutRenameSheet extends StatelessWidget {
  final TextEditingController nameController;
  final VoidCallback onConfirm;
  const _WorkoutRenameSheet(
      {required this.nameController, required this.onConfirm});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF100B22).withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24)),
        border: Border.all(
            color: Colors.white.withOpacity(0.12), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Rinomina scheda',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nuovo nome',
              labelStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Salva',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _WorkoutIconSheet
// ─────────────────────────────────────────────────────────────

class _WorkoutIconSheet extends StatefulWidget {
  final String currentIconId;
  final int currentColorIndex;
  final void Function(String iconId, int colorIndex) onSelect;
  const _WorkoutIconSheet({
    required this.currentIconId,
    required this.currentColorIndex,
    required this.onSelect,
  });
  @override
  State<_WorkoutIconSheet> createState() =>
      _WorkoutIconSheetState();
}

class _WorkoutIconSheetState extends State<_WorkoutIconSheet> {
  static const _icons = [
    ('dumbbell', Icons.fitness_center_rounded),
    ('bike', Icons.directions_bike_rounded),
    ('run', Icons.directions_run_rounded),
    ('swim', Icons.pool_rounded),
    ('yoga', Icons.self_improvement_rounded),
    ('sports', Icons.sports_rounded),
    ('heart', Icons.favorite_rounded),
    ('star', Icons.star_rounded),
    ('flash', Icons.bolt_rounded),
    ('target', Icons.track_changes_rounded),
    ('mountain', Icons.terrain_rounded),
    ('fire', Icons.local_fire_department_rounded),
  ];
  static const _colors = [
    Color(0xFF00D4AA),
    Color(0xFF6366F1),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
  ];
  late String _selectedIcon;
  late int _selectedColor;
  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.currentIconId;
    _selectedColor =
        widget.currentColorIndex.clamp(0, _colors.length - 1);
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF100B22).withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24)),
        border: Border.all(
            color: Colors.white.withOpacity(0.12), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  WorkoutAvatar(
                    iconId: _selectedIcon,
                    iconColorIndex: _selectedColor,
                    size: 72,
                    iconSize: 36,
                    borderRadius: 18,
                  ),
                  const SizedBox(height: 8),
                  Text('Anteprima',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Icona e colore',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Text('Colore',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colors.asMap().entries.map((e) {
                final selected = e.key == _selectedColor;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedColor = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(
                              color: Colors.white, width: 2.5)
                          : Border.all(
                              color: Colors.transparent),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                  color:
                                      e.value.withOpacity(0.6),
                                  blurRadius: 10)
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Text('Icona',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _icons.map((icon) {
                final selected = icon.$1 == _selectedIcon;
                final accentColor = _colors[_selectedColor];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedIcon = icon.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: selected
                          ? accentColor.withOpacity(0.2)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? accentColor.withOpacity(0.6)
                            : Colors.white.withOpacity(0.1),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Icon(icon.$2,
                        color: selected
                            ? accentColor
                            : Colors.white.withOpacity(0.5),
                        size: 24),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onSelect(
                    _selectedIcon, _selectedColor),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colors[_selectedColor],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Applica',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}