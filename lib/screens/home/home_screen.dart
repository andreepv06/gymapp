import 'dart:ui';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // AppBar con leggero blur quando scrollato
          SliverAppBar(
            expandedHeight: 120,
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
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Cosa vuoi fare oggi?',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.outline,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 130),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Bottone principale ALLENATI con Glass ──
                _GlassActionButton(
                  onTap: () =>
                      context.read<NavigationNotifier>().navigateTo(2),
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // ── Azioni secondarie ──
                Row(
                  children: [
                    Expanded(
                      child: _GlassSecondaryCard(
                        icon: Icons.list_alt_rounded,
                        label: 'Schede',
                        color: cs.primaryContainer,
                        iconColor: cs.onPrimaryContainer,
                        isDark: isDark,
                        onTap: () =>
                            context.read<NavigationNotifier>().navigateTo(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GlassSecondaryCard(
                        icon: Icons.bar_chart_rounded,
                        label: 'Storico',
                        color: cs.tertiaryContainer,
                        iconColor: cs.onTertiaryContainer,
                        isDark: isDark,
                        onTap: () =>
                            context.read<NavigationNotifier>().navigateTo(3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Esercizi recenti ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Esercizi',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
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

// ─────────────────────────────────────────────
// GLASS ACTION BUTTON — Inizia allenamento
// ─────────────────────────────────────────────
class _GlassActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _GlassActionButton({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Usa sempre primary ma con strato glass sopra
    final baseColor = cs.primary;
    final glassOverlay = Colors.white.withOpacity(isDark ? 0.08 : 0.18);
    final borderColor = Colors.white.withOpacity(isDark ? 0.12 : 0.4);
    final fgColor = cs.onPrimary;
    final iconBg = Colors.white.withOpacity(0.18);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor, width: 1.2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    baseColor,
                    baseColor.withOpacity(0.85),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Shine glass in alto
                  Positioned(
                    top: 0,
                    left: 12,
                    right: 12,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),

                  // Overlay glass
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            glassOverlay,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Contenuto
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: fgColor,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inizia allenamento',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: fgColor,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Seleziona una scheda e allenati',
                              style: TextStyle(
                                color: fgColor.withOpacity(0.75),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: fgColor.withOpacity(0.65),
                        size: 16,
                      ),
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

// ─────────────────────────────────────────────
// GLASS SECONDARY CARD — Schede / Storico
// ─────────────────────────────────────────────
class _GlassSecondaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final bool isDark;
  final VoidCallback onTap;

  const _GlassSecondaryCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.white.withOpacity(0.6);
    final glassOverlay = Colors.white.withOpacity(isDark ? 0.04 : 0.3);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.7 : 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    glassOverlay,
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(isDark ? 0.2 : 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: iconColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(icon, size: 22, color: iconColor),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                      letterSpacing: -0.1,
                    ),
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

// ─────────────────────────────────────────────
// ESERCIZI PREVIEW
// ─────────────────────────────────────────────
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
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
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
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
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
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              ),
              if (i < preview.length - 1)
                Divider(height: 1, indent: 60, color: cs.outlineVariant),
            ],
          );
        }).toList(),
      ),
    );
  }
}