import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/navigation/app_router.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';
import '../../widgets/workout_icon.dart';
import 'workout_detail_screen.dart';

const _teal = Color(0xFF00D4AA);
const _red  = Color(0xFFFF3B30);

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() =>
      _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<WorkoutProvider>().loadWorkouts());
  }

  // PUNTO 2: usa showKeyboardSafeSheet da shared_sheets
  Future<void> _showCreateSheet() async {
    await showKeyboardSafeSheet(
      context,
      // PUNTO 2: WorkoutCreateSheet UNIFICATO — stesso di AllenamentiScreen
      WorkoutCreateSheet(
        onConfirm: (name) {
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
    showKeyboardSafeSheet(
      context,
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
    final ctrl =
        TextEditingController(text: workout.name);
    await showKeyboardSafeSheet(
      context,
      _WorkoutRenameSheet(
        nameController: ctrl,
        onConfirm: () {
          final name = ctrl.text.trim();
          if (name.isEmpty) return;
          HiveDatabase.instance
              .updateWorkout(workout.key, name);
          if (mounted) {
            context.read<WorkoutProvider>().loadWorkouts();
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Future<void> _showIconSheet(HiveWorkout workout) async {
    await showKeyboardSafeSheet(
      context,
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
  final confirm = await showGlassDialog<bool>(
    context: context,
    accentColor: kRed,
    icon: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: kRed.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: kRed.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(color: kRed.withOpacity(0.2), blurRadius: 12)
        ],
      ),
      child: Icon(Icons.delete_outline_rounded,
          color: kRed.withOpacity(0.9), size: 20),
    ),
    title: 'Elimina scheda',
    message: 'Eliminare "${workout.name}"?\n'
        'Questa azione non può essere annullata.',
    actions: [
      GlassDialogAction(
        label: 'Annulla',
        onTap: () => Navigator.pop(context, false),
      ),
      GlassDialogAction(
        label: 'Elimina',
        isDestructive: true,
        onTap: () => Navigator.pop(context, true),
      ),
    ],
  );
  if (confirm == true && mounted) {
    await HiveDatabase.instance.deleteWorkout(workout.key);
    context.read<WorkoutProvider>().loadWorkouts();
  }
}
  
  @override
  Widget build(BuildContext context) {
    final workouts =
        context.watch<WorkoutProvider>().workouts;
    final hasWorkouts = workouts.isNotEmpty;

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
                action: hasWorkouts
                    ? GestureDetector(
                        onTap: _showCreateSheet,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _teal.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color:
                                    _teal.withOpacity(0.35)),
                          ),
                          child: const Icon(
                              Icons.add_rounded,
                              color: _teal,
                              size: 20),
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: hasWorkouts
                    ? ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 12, 16, 40),
                        physics:
                            const BouncingScrollPhysics(),
                        itemCount: workouts.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: 12),
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
                                  workoutId:
                                      workouts[i].key,
                                  workoutName:
                                      workouts[i].name,
                                ),
                              );
                            },
                            onOptions: () =>
                                _showWorkoutOptions(
                                    workouts[i]),
                          ),
                        ),
                      )
                    : _EmptyWorkoutsState(
                        onCreateNew: _showCreateSheet),
              ),
            ],
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

  const _GlassAppBar({
    required this.title,
    required this.onBack,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter:
                    ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            Colors.white.withOpacity(0.15)),
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
// _EmptyWorkoutsState
// ─────────────────────────────────────────────────────────────

class _EmptyWorkoutsState extends StatelessWidget {
  final VoidCallback onCreateNew;

  const _EmptyWorkoutsState({required this.onCreateNew});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 32),
        child: GestureDetector(
          onTap: onCreateNew,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter:
                  ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 44, horizontal: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      kTeal.withOpacity(0.1),
                      Colors.white.withOpacity(0.04),
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(28),
                  border: Border.all(
                      color: kCyan.withOpacity(0.35),
                      width: 1.2),
                  boxShadow: [
                    BoxShadow(
                        color: kCyan.withOpacity(0.1),
                        blurRadius: 28,
                        spreadRadius: 2),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: kTeal.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: kTeal.withOpacity(0.35),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  kTeal.withOpacity(0.2),
                              blurRadius: 18)
                        ],
                      ),
                      child: const Icon(
                          Icons.fitness_center_rounded,
                          size: 36,
                          color: kTeal),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Crea la tua prima scheda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tocca qui per iniziare a\nconfigurare il tuo allenamento',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            Colors.white.withOpacity(0.45),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 13),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          kTeal.withOpacity(0.25),
                          kTeal.withOpacity(0.12),
                        ]),
                        borderRadius:
                            BorderRadius.circular(14),
                        border: Border.all(
                            color: kTeal.withOpacity(0.5),
                            width: 1.2),
                        boxShadow: [
                          BoxShadow(
                              color: kTeal.withOpacity(0.2),
                              blurRadius: 14)
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color:
                                  kTeal.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.add_rounded,
                                color: kTeal,
                                size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Text('Inizia ora',
                              style: TextStyle(
                                  color: kTeal,
                                  fontWeight:
                                      FontWeight.w700,
                                  fontSize: 15)),
                        ],
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
                    iconColorIndex:
                        workout.iconColorIndex ?? 0,
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
                                fontWeight:
                                    FontWeight.w700),
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis),
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
                                  label:
                                      '$circuits circuiti'),
                            if (sets > 0)
                              _CardInfoTag(
                                  icon:
                                      Icons.repeat_rounded,
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
                            color: Colors.white
                                .withOpacity(0.06),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white
                                  .withOpacity(0.5),
                              size: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color:
                              Colors.white.withOpacity(0.35)),
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

  const _CardInfoTag(
      {required this.icon, required this.label});

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
// _WorkoutOptionsSheet — usa GlassSheetWrapper da shared_sheets
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
    return GlassSheetWrapper(
      title: workout.name,
      subtitle: 'Opzioni scheda',
      accentColor: kTeal,
      leadingIcon: WorkoutAvatar(
        iconId: workout.iconId ?? 'dumbbell',
        iconColorIndex: workout.iconColorIndex ?? 0,
        customImagePath: workout.customImagePath,
        size: 36,
        iconSize: 18,
        borderRadius: 9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter:
                  ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
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
                      label: 'Cambia icona / colore',
                      onTap: onChangeIcon,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter:
                  ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
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
// _WorkoutRenameSheet — usa GlassSheetWrapper + GlassTextField
// ─────────────────────────────────────────────────────────────

class _WorkoutRenameSheet extends StatefulWidget {
  final TextEditingController nameController;
  final VoidCallback onConfirm;

  const _WorkoutRenameSheet({
    required this.nameController,
    required this.onConfirm,
  });

  @override
  State<_WorkoutRenameSheet> createState() =>
      _WorkoutRenameSheetState();
}

class _WorkoutRenameSheetState
    extends State<_WorkoutRenameSheet> {
  @override
  Widget build(BuildContext context) {
    final hasName =
        widget.nameController.text.trim().isNotEmpty;

    return GlassSheetWrapper(
      title: 'Rinomina scheda',
      accentColor: kTeal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTextField(
            controller: widget.nameController,
            hintText: 'Nuovo nome...',
            labelText: 'Nome scheda',
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          GlassPrimaryButton(
            label: 'Salva',
            color: kTeal,
            onTap: hasName ? widget.onConfirm : null,
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

class _WorkoutIconSheetState
    extends State<_WorkoutIconSheet> {
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
    _selectedColor = widget.currentColorIndex
        .clamp(0, _colors.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _colors[_selectedColor];

    return GlassSheetWrapper(
      title: 'Icona e colore',
      accentColor: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                const SizedBox(height: 6),
                Text('Anteprima',
                    style: TextStyle(
                        color:
                            Colors.white.withOpacity(0.35),
                        fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Colore',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _colors.asMap().entries.map((e) {
              final sel = e.key == _selectedColor;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedColor = e.key),
                child: AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: e.value,
                    shape: BoxShape.circle,
                    border: sel
                        ? Border.all(
                            color: Colors.white,
                            width: 2.5)
                        : Border.all(
                            color: Colors.transparent),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                                color:
                                    e.value.withOpacity(0.6),
                                blurRadius: 10)
                          ]
                        : null,
                  ),
                  child: sel
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Icona',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _icons.map((icon) {
              final sel = icon.$1 == _selectedIcon;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedIcon = icon.$1),
                child: AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 150),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: sel
                        ? accent.withOpacity(0.2)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel
                          ? accent.withOpacity(0.6)
                          : Colors.white.withOpacity(0.1),
                      width: sel ? 1.5 : 1,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                                color:
                                    accent.withOpacity(0.2),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: Icon(icon.$2,
                      color: sel
                          ? accent
                          : Colors.white.withOpacity(0.5),
                      size: 24),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          GlassPrimaryButton(
            label: 'Applica',
            color: accent,
            onTap: () =>
                widget.onSelect(_selectedIcon, _selectedColor),
          ),
        ],
      ),
    );
  }
}