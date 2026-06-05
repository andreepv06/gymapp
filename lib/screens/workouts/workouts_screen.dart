import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hive_models.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';
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

  void _showAddWorkoutSheet(BuildContext context) {
    final controller = TextEditingController();
    showGlassBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GlassSheetHandle(),
              const SizedBox(height: 20),
              Text('Nuova scheda',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Dai un nome alla tua scheda',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                        color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: false,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome scheda',
                  hintText: 'Es. Push A, Gambe...',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
                onSubmitted: (_) {
                  Navigator.pop(ctx);
                  _saveWorkout(context, controller.text);
                },
              ),
              const SizedBox(height: 20),
              GlassDialogActions(
                cancelLabel: 'Annulla',
                confirmLabel: 'Crea',
                onCancel: () => Navigator.pop(ctx),
                onConfirm: () {
                  Navigator.pop(ctx);
                  _saveWorkout(context, controller.text);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _saveWorkout(BuildContext context, String name) async {
    if (name.trim().isEmpty) return;
    final provider = context.read<WorkoutProvider>();
    final id = await provider.addWorkout(name.trim());
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutDetailScreen(
              workoutId: id, workoutName: name.trim()),
        ),
      ).then((_) {
        if (context.mounted) {
          context.read<WorkoutProvider>().loadWorkouts();
        }
      });
    }
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
                color:
                    Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: cs.primary.withOpacity(0.3), width: 1),
                ),
                child: Icon(Icons.list_alt, color: cs.primary, size: 22),
              ),
              title: Text(workout.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_formatDate(workout.createdAt),
                  style: TextStyle(fontSize: 12, color: cs.outline)),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => _handleMenu(context, value),
                icon: Icon(Icons.more_vert, color: cs.outline),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Rinomina'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: cs.error),
                      const SizedBox(width: 8),
                      Text('Elimina',
                          style: TextStyle(color: cs.error)),
                    ]),
                  ),
                ],
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

  void _handleMenu(BuildContext context, String value) {
    if (value == 'delete') {
      showGlassDialog(
        context: context,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.delete_outline,
                      color: Colors.red, size: 22),
                  const SizedBox(width: 10),
                  Text('Elimina scheda',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Text('Vuoi eliminare "${workout.name}"?',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              GlassDialogActions(
                cancelLabel: 'Annulla',
                confirmLabel: 'Elimina',
                confirmColor: Colors.red,
                onCancel: () => Navigator.pop(context),
                onConfirm: () {
                  context
                      .read<WorkoutProvider>()
                      .deleteWorkout(workout.key);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      );
    } else if (value == 'rename') {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GlassSheetHandle(),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Rinomina scheda',
                    style:
                        Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: false,
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
                    context.read<WorkoutProvider>().renameWorkout(
                        workout.key, controller.text.trim());
                  }
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }
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
              child: Icon(Icons.list_alt_outlined,
                  size: 40, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Nessuna scheda ancora',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
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