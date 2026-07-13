import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import '../../widgets/cosmic_background.dart';

const _teal = Color(0xFF00D4AA);
const _red = Color(0xFFFF3B30);

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() =>
      _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  String _search = '';
  String _muscleFilter = 'Tutti';

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<ExerciseProvider>().loadExercises());
  }

  Future<T?> _showKeyboardSafeSheet<T>(Widget child) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => child,
    );
  }

  Future<void> _showAddSheet() async {
    final nameCtrl = TextEditingController();
    final muscleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    await _showKeyboardSafeSheet(
      _AddExerciseSheet(
        nameController: nameCtrl,
        muscleController: muscleCtrl,
        notesController: notesCtrl,
        onConfirm: () {
          final name = nameCtrl.text.trim();
          final muscle = muscleCtrl.text.trim();
          if (name.isEmpty || muscle.isEmpty) return;
          final notes = notesCtrl.text.trim();
          // FIX: addExercise accetta HiveExercise, non String separati
          HiveDatabase.instance.addExercise(HiveExercise(
            name: name,
            muscleGroup: muscle,
            notes: notes.isNotEmpty ? notes : null,
          ));
          if (mounted) {
            context.read<ExerciseProvider>().loadExercises();
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Future<void> _showEditSheet(HiveExercise exercise) async {
    final nameCtrl =
        TextEditingController(text: exercise.name);
    final muscleCtrl =
        TextEditingController(text: exercise.muscleGroup);
    final notesCtrl =
        TextEditingController(text: exercise.notes ?? '');

    await _showKeyboardSafeSheet(
      _AddExerciseSheet(
        nameController: nameCtrl,
        muscleController: muscleCtrl,
        notesController: notesCtrl,
        title: 'Modifica esercizio',
        confirmLabel: 'Salva',
        onConfirm: () {
          final name = nameCtrl.text.trim();
          final muscle = muscleCtrl.text.trim();
          if (name.isEmpty || muscle.isEmpty) return;
          final notes = notesCtrl.text.trim();
          // Mutazione diretta + save() sull'oggetto Hive
          exercise.name = name;
          exercise.muscleGroup = muscle;
          exercise.notes = notes.isNotEmpty ? notes : null;
          exercise.save();
          if (mounted) {
            context.read<ExerciseProvider>().loadExercises();
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(HiveExercise exercise) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1030),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.delete_outline, color: _red, size: 22),
            SizedBox(width: 10),
            Text('Elimina esercizio',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
        content: Text(
          'Eliminare "${exercise.name}"? '
          'Non sarà più disponibile nelle schede.',
          style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annulla',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina',
                style: TextStyle(
                    color: _red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await HiveDatabase.instance.deleteExercise(exercise.key);
      context.read<ExerciseProvider>().loadExercises();
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises =
        context.watch<ExerciseProvider>().exercises;

    // Gruppi muscolari
    final muscleGroups = <String>{'Tutti'};
    for (final ex in exercises) {
      muscleGroups.add(ex.muscleGroup);
    }
    final groups = muscleGroups.toList()..sort();
    if (groups.contains('Tutti')) {
      groups.remove('Tutti');
      groups.insert(0, 'Tutti');
    }

    // Filtraggio
    final filtered = exercises.where((ex) {
      final matchMuscle = _muscleFilter == 'Tutti' ||
          ex.muscleGroup == _muscleFilter;
      final matchSearch = _search.isEmpty ||
          ex.name
              .toLowerCase()
              .contains(_search.toLowerCase()) ||
          ex.muscleGroup
              .toLowerCase()
              .contains(_search.toLowerCase());
      return matchMuscle && matchSearch;
    }).toList();

    // Raggruppamento per gruppo muscolare
    final grouped = <String, List<HiveExercise>>{};
    for (final ex in filtered) {
      grouped.putIfAbsent(ex.muscleGroup, () => []).add(ex);
    }
    final sortedGroups = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        subtle: true,
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar Glass ──────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                              sigmaX: 8, sigmaY: 8),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withOpacity(0.08),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white
                                      .withOpacity(0.15)),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Libreria esercizi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${exercises.length} esercizi',
                            style: TextStyle(
                              color:
                                  Colors.white.withOpacity(0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _showAddSheet,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _teal.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _teal.withOpacity(0.35)),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: _teal, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Ricerca Glass ─────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                        sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color:
                                Colors.white.withOpacity(0.15),
                            width: 1),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(Icons.search_rounded,
                              size: 18,
                              color:
                                  Colors.white.withOpacity(0.45)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (v) =>
                                  setState(() => _search = v),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Cerca esercizio...',
                                hintStyle: TextStyle(
                                    color: Colors.white
                                        .withOpacity(0.35),
                                    fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_search.isNotEmpty)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _search = ''),
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(8),
                                child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white
                                        .withOpacity(0.4)),
                              ),
                            )
                          else
                            const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ── Filtri gruppi muscolari ───────────────────
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final g = groups[i];
                    final selected = _muscleFilter == g;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _muscleFilter = g),
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? _teal.withOpacity(0.2)
                              : Colors.white.withOpacity(0.06),
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? _teal.withOpacity(0.6)
                                : Colors.white.withOpacity(0.1),
                            width: selected ? 1.3 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color:
                                        _teal.withOpacity(0.2),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          g,
                          style: TextStyle(
                            color: selected
                                ? _teal
                                : Colors.white.withOpacity(0.55),
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // ── Lista esercizi ────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fitness_center_outlined,
                                size: 40,
                                color: Colors.white
                                    .withOpacity(0.2)),
                            const SizedBox(height: 12),
                            Text('Nessun esercizio trovato',
                                style: TextStyle(
                                    color: Colors.white
                                        .withOpacity(0.4),
                                    fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 0, 16, 80),
                        physics: const BouncingScrollPhysics(),
                        itemCount: sortedGroups.length,
                        itemBuilder: (_, gi) {
                          final group = sortedGroups[gi];
                          final groupExercises =
                              grouped[group] ?? [];

                          return Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Intestazione categoria
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 8, top: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: _teal,
                                        borderRadius:
                                            BorderRadius.circular(
                                                2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      group.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white
                                            .withOpacity(0.9),
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight.w800,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${groupExercises.length}',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withOpacity(0.35),
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Card esercizi del gruppo
                              ...groupExercises.map(
                                (ex) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 8),
                                  child: _ExerciseGlassCard(
                                    exercise: ex,
                                    onEdit: () =>
                                        _showEditSheet(ex),
                                    onDelete: () =>
                                        _confirmDelete(ex),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ExerciseGlassCard
// ─────────────────────────────────────────────────────────────

class _ExerciseGlassCard extends StatelessWidget {
  final HiveExercise exercise;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExerciseGlassCard({
    required this.exercise,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasNotes =
        exercise.notes != null && exercise.notes!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.09),
                Colors.white.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _teal.withOpacity(0.2)),
                  ),
                  child: const Icon(
                      Icons.fitness_center_rounded,
                      color: _teal,
                      size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(exercise.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (hasNotes)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 3),
                          child: Text(exercise.notes!,
                              style: TextStyle(
                                  color: Colors.white
                                      .withOpacity(0.4),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CardAction(
                      icon: Icons.edit_outlined,
                      color: Colors.white.withOpacity(0.4),
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 4),
                    _CardAction(
                      icon: Icons.delete_outline_rounded,
                      color: _red.withOpacity(0.7),
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _AddExerciseSheet — crea o modifica esercizio
// ─────────────────────────────────────────────────────────────

class _AddExerciseSheet extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController muscleController;
  final TextEditingController notesController;
  final VoidCallback onConfirm;
  final String title;
  final String confirmLabel;

  const _AddExerciseSheet({
    required this.nameController,
    required this.muscleController,
    required this.notesController,
    required this.onConfirm,
    this.title = 'Nuovo esercizio',
    this.confirmLabel = 'Aggiungi esercizio',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF100B22).withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24)),
        border: Border.all(
            color: Colors.white.withOpacity(0.12), width: 1),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                      Icons.fitness_center_rounded,
                      color: _teal,
                      size: 20),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nome esercizio',
                hintText: 'Es. Panca piana, Squat...',
                labelStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5)),
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: muscleController,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Gruppo muscolare',
                hintText: 'Es. Petto, Gambe, Dorso...',
                labelStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5)),
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notesController,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Note (opzionale)',
                hintText:
                    'Indicazioni tecniche, varianti...',
                labelStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5)),
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14)),
                ),
                child: Text(confirmLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}