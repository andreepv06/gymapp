import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exercise_provider.dart';
import '../../main.dart';
import '../exercises/exercises_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        context.read<ExerciseProvider>().loadExercises());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MarkFit'),
        actions: [
          IconButton(
            tooltip: 'Catalogo esercizi',
            icon: const Icon(Icons.fitness_center_outlined),
            onPressed: () => _showExercisesDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Buon allenamento!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cosa vuoi fare oggi?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.outline,
                ),
          ),
          const SizedBox(height: 32),
          _BigActionCard(
            icon: Icons.list_alt,
            title: 'Le mie schede',
            subtitle: 'Crea e gestisci i tuoi allenamenti',
            color: colorScheme.primaryContainer,
            onTap: () =>
                context.read<NavigationNotifier>().navigateTo(1),
          ),
          const SizedBox(height: 16),
          _BigActionCard(
            icon: Icons.play_circle_outline,
            title: 'Inizia sessione',
            subtitle: 'Seleziona una scheda e allenati',
            color: colorScheme.secondaryContainer,
            onTap: () =>
                context.read<NavigationNotifier>().navigateTo(2),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Esercizi recenti',
                  style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: () => _showExercisesDialog(context),
                child: const Text('Vedi tutti'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _ExercisesPreview(),
        ],
      ),
    );
  }

  void _showExercisesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.75,
            child: const ExercisesScreen(isDialog: true),
          ),
        ),
      ),
    );
  }
}

class _BigActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _BigActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExercisesPreview extends StatelessWidget {
  const _ExercisesPreview();

  @override
  Widget build(BuildContext context) {
    final exercises = context.watch<ExerciseProvider>().exercises;
    final preview = exercises.take(4).toList();
    if (preview.isEmpty) return const SizedBox.shrink();
    return Column(
      children: preview
          .map((e) => ListTile(
                dense: true,
                leading: const Icon(Icons.fitness_center, size: 18),
                title: Text(e.name),
                subtitle: Text(e.muscleGroup),
                contentPadding: EdgeInsets.zero,
              ))
          .toList(),
    );
  }
}