import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hive_models.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';
import '../../widgets/workout_icon.dart';
import '../../db/hive_database.dart';
import 'workout_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Le mie schede'),
      ),
      body: provider.workouts.isEmpty
          ? _EmptyState(onAdd: () => _showAddWorkoutSheet(context))
          : _WorkoutList(
              workouts: provider.workouts,
              onAdd: () => _showAddWorkoutSheet(context),
            ),
    );
  }

  // ─────────────────────────────────────────
  // Nuova scheda
  //
  // FIX TASTIERA: il padding bottom è applicato qui, direttamente
  // dal contenuto del sheet (pattern identico a "Nuovo esercizio",
  // che non ha mai dato problemi). NESSUN autofocus: l'utente
  // tocca il campo quando vuole scrivere, eliminando del tutto la
  // corsa tra l'animazione di apertura del sheet e l'apertura
  // della tastiera che causava il salto verso l'alto.
  // ─────────────────────────────────────────
  void _showAddWorkoutSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    String? selectedIconId;
    int selectedColorIndex = 0;
    String? customImageBase64;

    showGlassBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GlassSheetHandle(),
                const SizedBox(height: 16),
                Text('Nuova scheda',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final result = await showIconPickerBottomSheet(
                          context,
                          initialIconId: selectedIconId,
                          initialColorIndex: selectedColorIndex,
                          initialImageBase64: customImageBase64,
                        );
                        if (result != null) {
                          setModal(() {
                            selectedIconId = result['iconId'] as String?;
                            selectedColorIndex =
                                result['colorIndex'] as int;
                            customImageBase64 =
                                result['imageBase64'] as String?;
                          });
                        }
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          WorkoutAvatar(
                            iconId: selectedIconId,
                            iconColorIndex: selectedColorIndex,
                            customImagePath: customImageBase64,
                            size: 56,
                            iconSize: 28,
                            borderRadius: 14,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surface,
                                    width: 1.5),
                              ),
                              child: const Icon(Icons.edit,
                                  size: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Nome scheda',
                          hintText: 'Es. Push A, Gambe...',
                          prefixIcon: Icon(Icons.edit_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 70),
                  child: Text(
                    "Tocca l'icona per personalizzarla",
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ),
                const SizedBox(height: 24),
                GlassDialogActions(
                  cancelLabel: 'Annulla',
                  confirmLabel: 'Crea',
                  onCancel: () => Navigator.pop(ctx),
                  onConfirm: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    final id = await context
                        .read<WorkoutProvider>()
                        .addWorkout(nameCtrl.text.trim());
                    await HiveDatabase.instance.updateWorkoutIcon(
                      id,
                      iconId: selectedIconId,
                      iconColorIndex: selectedColorIndex,
                      customImagePath: customImageBase64,
                    );
                    if (context.mounted) {
                      context.read<WorkoutProvider>().loadWorkouts();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkoutDetailScreen(
                            workoutId: id,
                            workoutName: nameCtrl.text.trim(),
                          ),
                        ),
                      ).then((_) {
                        if (context.mounted) {
                          context.read<WorkoutProvider>().loadWorkouts();
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkoutList extends StatelessWidget {
  final List<HiveWorkout> workouts;
  final VoidCallback onAdd;

  const _WorkoutList({required this.workouts, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            itemCount: workouts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _WorkoutCard(workout: workouts[i]),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(32, 8, 32, bottomPadding + 100),
          child: GlassButton(
            onTap: onAdd,
            icon: Icons.add_rounded,
            label: 'Nuova scheda',
          ),
        ),
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final HiveWorkout workout;
  const _WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? cs.surface.withOpacity(0.7)
                : cs.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : cs.outlineVariant.withOpacity(0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: WorkoutAvatar(
                iconId: workout.iconId,
                iconColorIndex: workout.iconColorIndex,
                customImagePath: workout.customImagePath,
                size: 48,
                iconSize: 24,
                borderRadius: 12,
              ),
              title: Text(workout.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_formatDate(workout.createdAt),
                  style: TextStyle(fontSize: 12, color: cs.outline)),
              trailing: IconButton(
                icon: Icon(Icons.more_vert, color: cs.outline),
                onPressed: () => _showOptionsSheet(context),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkoutDetailScreen(
                    workoutId: workout.key,
                    workoutName: workout.name,
                  ),
                ),
              ).then((_) {
                if (context.mounted) {
                  context.read<WorkoutProvider>().loadWorkouts();
                }
              }),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showOptionsSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showGlassBottomSheet(
      context: context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GlassSheetHandle(),
            const SizedBox(height: 16),
            Row(
              children: [
                WorkoutAvatar(
                  iconId: workout.iconId,
                  iconColorIndex: workout.iconColorIndex,
                  customImagePath: workout.customImagePath,
                  size: 36,
                  iconSize: 18,
                  borderRadius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    workout.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _OptionTile(
              icon: Icons.edit_outlined,
              label: 'Rinomina scheda',
              color: cs.primary,
              onTap: () {
                Navigator.pop(context);
                _showRenameSheet(context);
              },
            ),
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.image_outlined,
              label: 'Cambia icona / immagine',
              color: cs.tertiary,
              onTap: () {
                Navigator.pop(context);
                _showChangeIconSheet(context);
              },
            ),
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.delete_outline,
              label: 'Elimina scheda',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeIconSheet(BuildContext context) async {
    final result = await showIconPickerBottomSheet(
      context,
      initialIconId: workout.iconId,
      initialColorIndex: workout.iconColorIndex ?? 0,
      initialImageBase64: workout.customImagePath,
    );
    if (result != null) {
      await HiveDatabase.instance.updateWorkoutIcon(
        workout.key,
        iconId: result['iconId'] as String?,
        iconColorIndex: result['colorIndex'] as int,
        customImagePath: result['imageBase64'] as String?,
      );
      if (context.mounted) {
        context.read<WorkoutProvider>().loadWorkouts();
      }
    }
  }

  // FIX TASTIERA: padding bottom direttamente qui, nessun
  // autofocus — stesso pattern di "Nuova scheda" qui sopra.
  void _showRenameSheet(BuildContext context) {
    final controller = TextEditingController(text: workout.name);
    showGlassBottomSheet(
      context: context,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GlassSheetHandle(),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Rinomina scheda',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    const InputDecoration(labelText: 'Nome scheda'),
              ),
              const SizedBox(height: 16),
              GlassDialogActions(
                cancelLabel: 'Annulla',
                confirmLabel: 'Salva',
                onCancel: () => Navigator.pop(context),
                onConfirm: () {
                  if (controller.text.trim().isNotEmpty) {
                    context
                        .read<WorkoutProvider>()
                        .renameWorkout(workout.key, controller.text.trim());
                  }
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showGlassDialog(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 22),
              SizedBox(width: 10),
              Text('Elimina scheda',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            Text(
                'Vuoi eliminare "${workout.name}"? Questa azione è permanente.'),
            const SizedBox(height: 24),
            GlassDialogActions(
              cancelLabel: 'Annulla',
              confirmLabel: 'Elimina',
              confirmColor: Colors.red,
              onCancel: () => Navigator.pop(context),
              onConfirm: () {
                context.read<WorkoutProvider>().deleteWorkout(workout.key);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: color)),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: color.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: cs.primary.withOpacity(0.3), width: 1.5),
              ),
              child:
                  Icon(Icons.list_alt_outlined, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text('Nessuna scheda ancora',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Crea la tua prima scheda\nper iniziare ad allenarti',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 28),
            GlassButton(
              onTap: onAdd,
              icon: Icons.add_rounded,
              label: 'Crea scheda',
              minWidth: 220,
            ),
          ],
        ),
      ),
    );
  }
}