import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hive_models.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/glass_button.dart';
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
      // Nessun + nell'AppBar
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Le mie schede'),
      ),
      body: provider.workouts.isEmpty
          ? _EmptyState(
              onAdd: () => _showAddWorkoutDialog(context))
          : _WorkoutList(
              workouts: provider.workouts,
              onAdd: () => _showAddWorkoutDialog(context),
            ),
    );
  }

  void _showAddWorkoutDialog(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, _) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Nuova scheda',
                  style:
                      Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Dai un nome alla tua scheda',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .outline),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: false,
                textCapitalization:
                    TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome scheda',
                  hintText: 'Es. Push A, Gambe, Full Body...',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
                onSubmitted: (_) {
                  Navigator.pop(ctx);
                  _saveWorkout(context, controller.text);
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _saveWorkout(
                            context, controller.text);
                      },
                      child: const Text('Crea'),
                    ),
                  ),
                ],
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

  const _WorkoutList(
      {required this.workouts, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding:
                const EdgeInsets.fromLTRB(16, 16, 16, 12),
            itemCount: workouts.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
            itemBuilder: (_, i) =>
                _WorkoutCard(workout: workouts[i]),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              32, 8, 32, bottomPadding + 100),
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
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.list_alt,
              color: cs.onPrimaryContainer, size: 22),
        ),
        title: Text(workout.name,
            style:
                const TextStyle(fontWeight: FontWeight.w600)),
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
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _handleMenu(BuildContext context, String value) {
    if (value == 'delete') {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Elimina scheda'),
          content: Text('Vuoi eliminare "${workout.name}"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red),
              onPressed: () {
                context
                    .read<WorkoutProvider>()
                    .deleteWorkout(workout.key);
                Navigator.pop(context);
              },
              child: const Text('Elimina'),
            ),
          ],
        ),
      );
    } else if (value == 'rename') {
      final controller =
          TextEditingController(text: workout.name);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Rinomina scheda',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: false,
                textCapitalization:
                    TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Nome scheda'),
                onSubmitted: (_) {
                  if (controller.text.trim().isNotEmpty) {
                    context
                        .read<WorkoutProvider>()
                        .renameWorkout(workout.key,
                            controller.text.trim());
                  }
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (controller.text
                            .trim()
                            .isNotEmpty) {
                          context
                              .read<WorkoutProvider>()
                              .renameWorkout(workout.key,
                                  controller.text.trim());
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('Salva'),
                    ),
                  ),
                ],
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
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.list_alt_outlined,
                  size: 40, color: cs.onPrimaryContainer),
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