import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/workout_provider.dart';
import '../../models/hive_models.dart';
import '../../main.dart';
import 'active_session_screen.dart';

class SessionSelectorScreen extends StatefulWidget {
  const SessionSelectorScreen({super.key});

  @override
  State<SessionSelectorScreen> createState() =>
      _SessionSelectorScreenState();
}

class _SessionSelectorScreenState extends State<SessionSelectorScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<WorkoutProvider>().loadWorkouts());
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutProvider>();
    final workouts = workoutProvider.workouts;
    final cs = Theme.of(context).colorScheme;

    if (workouts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sessione')),
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
                      size: 40, color: cs.onSecondaryContainer),
                ),
                const SizedBox(height: 20),
                Text('Nessuna scheda disponibile',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Crea prima una scheda di allenamento\nper iniziare una sessione',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.outline),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () =>
                      context.read<NavigationNotifier>().navigateTo(1),
                  icon: const Icon(Icons.add),
                  label: const Text('Vai alle schede'),
                  style: FilledButton.styleFrom(minimumSize: const Size(200, 50)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sessione')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner "Inizia allenamento" in evidenza
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_circle_filled,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inizia allenamento',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Seleziona una scheda qui sotto',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text('Le tue schede',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: cs.outline, letterSpacing: 0.5)),
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: workouts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final workout = workouts[index];
                return _WorkoutSessionCard(
                  workout: workout,
                  onTap: () async {
                    workoutProvider.loadWorkoutExercises(workout.key);
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActiveSessionScreen(workout: workout),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutSessionCard extends StatelessWidget {
  final HiveWorkout workout;
  final VoidCallback onTap;
  const _WorkoutSessionCard({required this.workout, required this.onTap});

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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.list_alt,
                    color: cs.onPrimaryContainer, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workout.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(_formatDate(workout.createdAt),
                        style: TextStyle(fontSize: 12, color: cs.outline)),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 20),
              ),
            ],
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
}