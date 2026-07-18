import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';

const _tealLocal = Color(0xFF00D4AA);
const _cyanLocal = Color(0xFF00E5FF);
const _redLocal  = Color(0xFFFF3B30);

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() =>
      _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  String _search = '';
  String _muscle = 'Tutti';

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<ExerciseProvider>().loadExercises());
  }

  // PUNTO 1: usa showKeyboardSafeSheet + ExerciseFormSheet UNIFICATO
  // da shared_sheets — identico a quello usato da AllenamentiScreen
  Future<void> _showCreateExerciseSheet() async {
    final exercises =
        context.read<ExerciseProvider>().exercises;
    await showKeyboardSafeSheet(
      context,
      ExerciseFormSheet(
        existingNames:
            exercises.map((e) => e.name.toLowerCase()).toSet(),
        onConfirm: (name, muscleGroup, notes) {
          HiveDatabase.instance.addExercise(HiveExercise(
            name: name,
            muscleGroup: muscleGroup,
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

  // PUNTO 1: modifica esercizio — stesso ExerciseFormSheet condiviso
  Future<void> _showEditExerciseSheet(
      HiveExercise exercise) async {
    final exercises =
        context.read<ExerciseProvider>().exercises;
    await showKeyboardSafeSheet(
      context,
      ExerciseFormSheet(
        initialName: exercise.name,
        initialMuscleGroup: exercise.muscleGroup,
        initialNotes: exercise.notes ?? '',
        existingNames: exercises
            .where((e) => e.key != exercise.key)
            .map((e) => e.name.toLowerCase())
            .toSet(),
        onConfirm: (name, muscleGroup, notes) {
          exercise.name = name;
          exercise.muscleGroup = muscleGroup;
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

  Future<void> _confirmDeleteExercise(
      HiveExercise exercise) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1030),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline,
                color: _redLocal, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text('Elimina esercizio',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          'Eliminare "${exercise.name}"?\n'
          'Questa azione non può essere annullata.',
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
                    color: _redLocal,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await HiveDatabase.instance
          .deleteExercise(exercise.key);
      context.read<ExerciseProvider>().loadExercises();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allExercises =
        context.watch<ExerciseProvider>().exercises;

    // Gruppi dinamici: predefiniti + quelli già salvati
    final groups = <String>{
      'Tutti',
      ...kMuscleGroups,
      ...allExercises.map((e) => e.muscleGroup),
    }.toList()
      ..sort();
    if (groups.contains('Tutti')) {
      groups.remove('Tutti');
      groups.insert(0, 'Tutti');
    }

    final filtered = allExercises.where((e) {
      final matchM =
          _muscle == 'Tutti' || e.muscleGroup == _muscle;
      final matchS = _search.isEmpty ||
          e.name
              .toLowerCase()
              .contains(_search.toLowerCase()) ||
          e.muscleGroup
              .toLowerCase()
              .contains(_search.toLowerCase());
      return matchM && matchS;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        subtle: true,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    16, 12, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          Navigator.pop(context),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                              sigmaX: 8, sigmaY: 8),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.08),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white
                                      .withOpacity(0.15)),
                            ),
                            child: const Icon(
                                Icons
                                    .arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Esercizi',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                    ),
                    GestureDetector(
                      onTap: _showCreateExerciseSheet,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _tealLocal.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color:
                                  _tealLocal.withOpacity(0.35)),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: _tealLocal, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Campo ricerca Glass
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                        sigmaX: 8, sigmaY: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withOpacity(0.05),
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: _cyanLocal.withOpacity(0.2),
                            width: 0.8),
                      ),
                      child: TextField(
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Cerca esercizio...',
                          hintStyle: TextStyle(
                              color: Colors.white
                                  .withOpacity(0.3)),
                          prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.white
                                  .withOpacity(0.4),
                              size: 18),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  vertical: 12),
                        ),
                        onChanged: (v) =>
                            setState(() => _search = v),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Chip filtri gruppi muscolari
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final g = groups[i];
                    final sel = _muscle == g;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _muscle = g),
                      child: AnimatedContainer(
                        duration: const Duration(
                            milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel
                              ? _tealLocal.withOpacity(0.2)
                              : Colors.white
                                  .withOpacity(0.06),
                          borderRadius:
                              BorderRadius.circular(9),
                          border: Border.all(
                            color: sel
                                ? _tealLocal.withOpacity(0.6)
                                : Colors.white
                                    .withOpacity(0.1),
                            width: sel ? 1.2 : 0.8,
                          ),
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                      color: _tealLocal
                                          .withOpacity(0.15),
                                      blurRadius: 8)
                                ]
                              : null,
                        ),
                        child: Text(g,
                            style: TextStyle(
                                color: sel
                                    ? _tealLocal
                                    : Colors.white
                                        .withOpacity(0.55),
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Lista esercizi
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyExercisesState(
                        onCreateNew:
                            _showCreateExerciseSheet)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 0, 16, 40),
                        physics:
                            const BouncingScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: 8),
                          child: _ExerciseGlassCard(
                            exercise: filtered[i],
                            onEdit: () =>
                                _showEditExerciseSheet(
                                    filtered[i]),
                            onDelete: () =>
                                _confirmDeleteExercise(
                                    filtered[i]),
                          ),
                        ),
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
// _EmptyExercisesState
// ─────────────────────────────────────────────────────────────

class _EmptyExercisesState extends StatelessWidget {
  final VoidCallback onCreateNew;

  const _EmptyExercisesState({required this.onCreateNew});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _tealLocal.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _tealLocal.withOpacity(0.3),
                    width: 1.5),
              ),
              child: const Icon(Icons.fitness_center_rounded,
                  size: 36, color: _tealLocal),
            ),
            const SizedBox(height: 20),
            const Text('Nessun esercizio',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Aggiungi i tuoi esercizi\nper costruire le schede',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 13,
                  height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onCreateNew,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _tealLocal.withOpacity(0.25),
                    _tealLocal.withOpacity(0.12),
                  ]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _tealLocal.withOpacity(0.5),
                      width: 1.2),
                  boxShadow: [
                    BoxShadow(
                        color: _tealLocal.withOpacity(0.2),
                        blurRadius: 14)
                  ],
                ),
                child: const Text('Aggiungi esercizio',
                    style: TextStyle(
                        color: _tealLocal,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
          ],
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
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 0.8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _tealLocal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _tealLocal.withOpacity(0.2)),
                  ),
                  child: const Icon(
                      Icons.fitness_center_rounded,
                      color: _tealLocal,
                      size: 18),
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
                      const SizedBox(height: 3),
                      Text(exercise.muscleGroup,
                          style: TextStyle(
                              color:
                                  Colors.white.withOpacity(0.5),
                              fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit_rounded,
                        size: 14,
                        color:
                            Colors.white.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _redLocal.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                        Icons.delete_outline_rounded,
                        size: 14,
                        color: _redLocal.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}