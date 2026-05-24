import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hive_models.dart';
import '../../providers/workout_provider.dart';
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
    Future.microtask(() =>
        context.read<WorkoutProvider>().loadWorkouts());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Le mie schede'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWorkoutDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuova scheda'),
      ),
      body: provider.workouts.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: provider.workouts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _WorkoutCard(
                workout: provider.workouts[i],
              ),
            ),
    );
  }

  void _showAddWorkoutDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuova scheda'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nome scheda',
            hintText: 'Es. Push A, Gambe, Full Body...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _saveWorkout(context, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => _saveWorkout(context, controller.text),
            child: const Text('Crea'),
          ),
        ],
      ),
    );
  }

  void _saveWorkout(BuildContext context, String name) async {
    if (name.trim().isEmpty) return;
    final provider = context.read<WorkoutProvider>();
    final id = await provider.addWorkout(name.trim());
    if (context.mounted) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutDetailScreen(workoutId: id, workoutName: name.trim()),
        ),
      );
    }
  }
}

class _WorkoutCard extends StatelessWidget {
  final HiveWorkout workout;
  const _WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(workout.name,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(_formatDate(workout.createdAt)),
        leading: const CircleAvatar(child: Icon(Icons.list_alt)),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenu(context, value),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'rename', child: Text('Rinomina')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Elimina', style: TextStyle(color: Colors.red)),
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
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Elimina scheda'),
          content: Text('Vuoi eliminare "${workout.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () {
                context.read<WorkoutProvider>().deleteWorkout(workout.key);
                Navigator.pop(context);
              },
              child: const Text('Elimina',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else if (value == 'rename') {
      final controller = TextEditingController(text: workout.name);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Rinomina scheda'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  context
                      .read<WorkoutProvider>()
                      .renameWorkout(workout.key, controller.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.list_alt_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('Nessuna scheda ancora',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Crea la tua prima scheda di allenamento',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          
        ],
      ),
    );
  }
}