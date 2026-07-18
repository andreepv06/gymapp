import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import '../../widgets/cosmic_background.dart';

const _teal  = Color(0xFF00D4AA);
const _cyan  = Color(0xFF00E5FF);
const _red   = Color(0xFFFF3B30);

const _kMuscleGroups = [
  'Tutti',
  'Petto',
  'Schiena',
  'Spalle',
  'Bicipiti',
  'Tricipiti',
  'Gambe',
  'Addominali',
  'Glutei',
  'Polpacci',
];

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
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

  // FIX TASTIERA: parametro posizionale + AnimatedPadding + ConstrainedBox
  Future<T?> _showKeyboardSafeSheet<T>(Widget child) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // PARTE 5: crea esercizio — mantiene tutte le funzionalità
  Future<void> _showCreateExerciseSheet() async {
    final exercises = context.read<ExerciseProvider>().exercises;
    await _showKeyboardSafeSheet(
      _ExerciseFormSheet(
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

  // PARTE 5: modifica esercizio — stessa struttura della creazione
  Future<void> _showEditExerciseSheet(HiveExercise exercise) async {
    final exercises = context.read<ExerciseProvider>().exercises;
    await _showKeyboardSafeSheet(
      _ExerciseFormSheet(
        initialName: exercise.name,
        initialMuscleGroup: exercise.muscleGroup,
        initialNotes: exercise.notes ?? '',
        // Esclude il nome corrente dal controllo duplicati
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

  Future<void> _confirmDeleteExercise(HiveExercise exercise) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1030),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
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
    final allExercises =
        context.watch<ExerciseProvider>().exercises;

    // Gruppi muscolari dinamici + predefiniti
    final groups = <String>{
      ..._kMuscleGroups,
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
          e.name.toLowerCase().contains(_search.toLowerCase()) ||
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
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
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
              const SizedBox(height: 12),

              // Ricerca
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter:
                        ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _cyan.withOpacity(0.2),
                            width: 0.8),
                      ),
                      child: TextField(
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Cerca esercizio...',
                          hintStyle: TextStyle(
                              color:
                                  Colors.white.withOpacity(0.3)),
                          prefixIcon: Icon(
                              Icons.search_rounded,
                              color:
                                  Colors.white.withOpacity(0.4),
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

              // FIX 3: chip filtri gruppi muscolari
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
                        duration:
                            const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel
                              ? _teal.withOpacity(0.2)
                              : Colors.white.withOpacity(0.06),
                          borderRadius:
                              BorderRadius.circular(9),
                          border: Border.all(
                            color: sel
                                ? _teal.withOpacity(0.6)
                                : Colors.white.withOpacity(0.1),
                            width: sel ? 1.2 : 0.8,
                          ),
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                      color:
                                          _teal.withOpacity(0.15),
                                      blurRadius: 8)
                                ]
                              : null,
                        ),
                        child: Text(g,
                            style: TextStyle(
                                color: sel
                                    ? _teal
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
                        onCreateNew: _showCreateExerciseSheet)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 0, 16, 40),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 8),
                          child: _ExerciseGlassCard(
                            exercise: filtered[i],
                            onEdit: () => _showEditExerciseSheet(
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
                color: _teal.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _teal.withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(Icons.fitness_center_rounded,
                  size: 36, color: _teal),
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
                    _teal.withOpacity(0.25),
                    _teal.withOpacity(0.12),
                  ]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _teal.withOpacity(0.5),
                      width: 1.2),
                  boxShadow: [
                    BoxShadow(
                        color: _teal.withOpacity(0.2),
                        blurRadius: 14)
                  ],
                ),
                child: const Text('Aggiungi esercizio',
                    style: TextStyle(
                        color: _teal,
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
                    color: _teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _teal.withOpacity(0.2)),
                  ),
                  child: const Icon(
                      Icons.fitness_center_rounded,
                      color: _teal,
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
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 14, color: _red.withOpacity(0.7)),
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

// ─────────────────────────────────────────────────────────────
// PARTE 5+6: _ExerciseFormSheet — form unificato creazione/modifica
// Stessa struttura per entrambe le operazioni (DRY).
// Mantiene: nome, gruppo muscolare, note, validazione, duplicati.
// ─────────────────────────────────────────────────────────────

class _ExerciseFormSheet extends StatefulWidget {
  final String? initialName;
  final String? initialMuscleGroup;
  final String? initialNotes;
  final Set<String> existingNames;
  final void Function(String name, String muscleGroup,
      String notes) onConfirm;

  const _ExerciseFormSheet({
    this.initialName,
    this.initialMuscleGroup,
    this.initialNotes,
    required this.existingNames,
    required this.onConfirm,
  });

  @override
  State<_ExerciseFormSheet> createState() =>
      _ExerciseFormSheetState();
}

class _ExerciseFormSheetState extends State<_ExerciseFormSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _notesCtrl;
  late String _selectedMuscle;
  String? _nameError;

  bool get _isEditing => widget.initialName != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.initialName ?? '');
    _notesCtrl =
        TextEditingController(text: widget.initialNotes ?? '');
    _selectedMuscle =
        widget.initialMuscleGroup ?? _kMuscleGroups[1];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _validate() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Il nome è obbligatorio');
      return;
    }
    if (widget.existingNames.contains(name.toLowerCase())) {
      setState(() => _nameError = 'Esercizio già esistente');
      return;
    }
    setState(() => _nameError = null);
    widget.onConfirm(name, _selectedMuscle, _notesCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    // Gruppi disponibili — predefiniti + qualsiasi altro già salvato
    final groups = _kMuscleGroups
        .where((g) => g != 'Tutti')
        .toList();

    final canConfirm = _nameCtrl.text.trim().isNotEmpty &&
        _nameError == null;

    return _GlassSheetWrapper(
      title:
          _isEditing ? 'Modifica esercizio' : 'Nuovo esercizio',
      subtitle: _isEditing ? widget.initialName : null,
      accentColor: _teal,
      leadingIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _teal.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.fitness_center_rounded,
            color: _teal, size: 20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nome
          _GlassTextField(
            controller: _nameCtrl,
            hintText: 'Es. Panca piana, Squat...',
            labelText: 'Nome esercizio',
            autofocus: true,
            onChanged: (v) {
              setState(() {
                _nameError = widget.existingNames
                        .contains(v.trim().toLowerCase())
                    ? 'Esercizio già esistente'
                    : null;
              });
            },
          ),
          if (_nameError != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_nameError!,
                  style: TextStyle(
                      color: _red.withOpacity(0.8),
                      fontSize: 11)),
            ),
          ],
          const SizedBox(height: 14),

          // PARTE 5: selezione gruppo muscolare
          Text('Gruppo muscolare',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: groups.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final g = groups[i];
                final sel = _selectedMuscle == g;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedMuscle = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? _teal.withOpacity(0.2)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: sel
                            ? _teal.withOpacity(0.6)
                            : Colors.white.withOpacity(0.1),
                        width: sel ? 1.2 : 0.8,
                      ),
                    ),
                    child: Text(g,
                        style: TextStyle(
                            color: sel
                                ? _teal
                                : Colors.white.withOpacity(0.55),
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Note (opzionale)
          _GlassTextField(
            controller: _notesCtrl,
            hintText: 'Es. Grip neutro, 3 secondi in discesa...',
            labelText: 'Note (opzionale)',
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          _GlassPrimaryButton(
            label: _isEditing ? 'Salva modifiche' : 'Aggiungi esercizio',
            color: _teal,
            onTap: canConfirm ? _validate : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Componenti condivisi (replicati da workouts_screen per evitare
// dipendenze circolari tra file dello stesso layer)
// ─────────────────────────────────────────────────────────────

class _GlassSheetWrapper extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Color accentColor;
  final Widget? leadingIcon;

  const _GlassSheetWrapper({
    required this.title,
    this.subtitle,
    required this.child,
    this.accentColor = _teal,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF060B14), Color(0xFF03040A)],
        ),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
            color: accentColor.withOpacity(0.3), width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  accentColor.withOpacity(0.3),
                  accentColor.withOpacity(0.6),
                  accentColor.withOpacity(0.3),
                ]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  leadingIcon!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: TextStyle(
                                color:
                                    accentColor.withOpacity(0.7),
                                fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final String? labelText;
  final bool autofocus;
  final void Function(String)? onChanged;
  final int maxLines;

  const _GlassTextField({
    this.controller,
    required this.hintText,
    this.labelText,
    this.autofocus = false,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _cyan.withOpacity(0.2), width: 0.8),
          ),
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            maxLines: maxLines,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
                color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hintText,
              labelText: labelText,
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 14),
              labelStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
            ),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _GlassPrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _GlassPrimaryButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(colors: [
                  color,
                  Color.lerp(color, Colors.black, 0.2) ?? color,
                ])
              : LinearGradient(colors: [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.03),
                ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? color.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: enabled
                ? Colors.white
                : Colors.white.withOpacity(0.3),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}