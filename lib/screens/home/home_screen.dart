import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/auth_provider.dart';
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
    Future.microtask(
        () => context.read<ExerciseProvider>().loadExercises());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final account = auth.currentAccount;

    final greeting = _getGreeting();
    final name = account?.firstName ?? account?.displayName;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: cs.surface,
            surfaceTintColor: cs.surfaceTint,
            actions: [
              IconButton(
                tooltip: 'Catalogo esercizi',
                icon: const Icon(Icons.fitness_center_outlined),
                onPressed: () => _showExercisesDialog(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 0, 14),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name != null && name.isNotEmpty
                        ? '$greeting, $name!'
                        : '$greeting!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Cosa vuoi fare oggi?',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.outline,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Bottone ALLENATI in evidenza — grande e prominente
                _MainActionButton(
                  onTap: () =>
                      context.read<NavigationNotifier>().navigateTo(2),
                ),
                const SizedBox(height: 12),

                // Azioni secondarie: Schede e Storico
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryActionCard(
                        icon: Icons.list_alt_rounded,
                        label: 'Schede',
                        color: cs.primaryContainer,
                        iconColor: cs.onPrimaryContainer,
                        onTap: () =>
                            context.read<NavigationNotifier>().navigateTo(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SecondaryActionCard(
                        icon: Icons.bar_chart_rounded,
                        label: 'Storico',
                        color: cs.tertiaryContainer,
                        iconColor: cs.onTertiaryContainer,
                        onTap: () =>
                            context.read<NavigationNotifier>().navigateTo(3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Esercizi recenti
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Esercizi',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextButton(
                      onPressed: () => _showExercisesDialog(context),
                      child: const Text('Vedi tutti'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const _ExercisesPreview(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buongiorno';
    if (hour < 18) return 'Buon pomeriggio';
    return 'Buonasera';
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

// Bottone principale ALLENATI — grande e prominente
class _MainActionButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MainActionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.primary,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_circle_filled_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inizia allenamento',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Seleziona una scheda e allenati',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Card secondaria per Schede e Storico
class _SecondaryActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _SecondaryActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
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
    final cs = Theme.of(context).colorScheme;
    final exercises = context.watch<ExerciseProvider>().exercises;
    final preview = exercises.take(5).toList();
    if (preview.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: preview.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          return Column(
            children: [
              ListTile(
                dense: true,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.fitness_center,
                      size: 16, color: cs.onPrimaryContainer),
                ),
                title: Text(e.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
                subtitle: Text(e.muscleGroup,
                    style: TextStyle(fontSize: 11, color: cs.outline)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              ),
              if (i < preview.length - 1)
                Divider(height: 1, indent: 56, color: cs.outlineVariant),
            ],
          );
        }).toList(),
      ),
    );
  }
}