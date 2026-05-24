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
    Future.microtask(() {
      context.read<WorkoutProvider>().loadWorkouts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutProvider>();
    final workouts = workoutProvider.workouts;

    if (workouts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sessione')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fitness_center, size: 64),
                const SizedBox(height: 20),
                const Text('Nessuna scheda disponibile',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Crea prima una scheda di allenamento',
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      context.read<NavigationNotifier>().navigateTo(1),
                  child: const Text('Vai alle schede'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Avvia sessione')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: workouts.length,
        itemBuilder: (context, index) {
          final workout = workouts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.list_alt),
              title: Text(workout.name),
              subtitle: Text(workout.createdAt.split('T').first),
              trailing: const Icon(Icons.play_arrow),
              onTap: () async {
                workoutProvider.loadWorkoutExercises(workout.key);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ActiveSessionScreen(workout: workout),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}