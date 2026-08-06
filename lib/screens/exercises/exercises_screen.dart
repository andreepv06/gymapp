import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/markfit_colors.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';

// ─── Accent tokens ────────────────────────────────────────────
const _cyan   = MarkFitColors.cyan;
const _teal   = MarkFitColors.teal;
const _tealDk = MarkFitColors.tealDk;
const _red    = MarkFitColors.red;
const _indigo = MarkFitColors.indigo;
const _orange = MarkFitColors.orange;

// Muscle group palette
const _groupColors = <String, Color>{
  'Petto':        Color(0xFF3B82F6),
  'Schiena':      Color(0xFF6366F1),
  'Spalle':       Color(0xFF8B5CF6),
  'Bicipiti':     Color(0xFF00D4AA),
  'Tricipiti':    Color(0xFF00E5FF),
  'Gambe':        Color(0xFF22C55E),
  'Addome':       Color(0xFFFF8C00),
  'Glutei':       Color(0xFFEC4899),
  'Cardio':       Color(0xFFFF3B30),
  'Avambracci':   Color(0xFFF59E0B),
  'Corpo libero': Color(0xFF10B981),
};
Color _colorFor(String g) => _groupColors[g] ?? const Color(0xFF9CA3AF);

// ─── ExercisesScreen ──────────────────────────────────────────

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});
  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final _searchCtrl = TextEditingController();
  String _search        = '';
  String _selectedGroup = 'Tutti';

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<ExerciseProvider>().loadExercises());
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<String> _groups(List<HiveExercise> exercises) {
    final groups = <String>{'Tutti'};
    for (final e in exercises) {
      if (e.muscleGroup.isNotEmpty) groups.add(e.muscleGroup);
    }
    return groups.toList();
  }

  List<HiveExercise> _filtered(List<HiveExercise> exercises) {
    return exercises.where((e) {
      final groupOk  = _selectedGroup == 'Tutti' ||
          e.muscleGroup == _selectedGroup;
      final searchOk = _search.isEmpty ||
          e.name.toLowerCase().contains(_search.toLowerCase());
      return groupOk && searchOk;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _showAddSheet() async {
    final exercises = context.read<ExerciseProvider>().exercises;
    await showKeyboardSafeSheet(
      context,
      ExerciseFormSheet(
        existingNames: exercises.map((e) => e.name.toLowerCase()).toSet(),
        onConfirm: (name, muscleGroup, notes) {
          HiveDatabase.instance.addExercise(HiveExercise(
            name:        name,
            muscleGroup: muscleGroup,
            notes:       notes.isNotEmpty ? notes : null));
          if (mounted) {
            context.read<ExerciseProvider>().loadExercises();
            Navigator.pop(context);
          }
        }));
  }

  Future<void> _showEditSheet(HiveExercise exercise) async {
    final exercises = context.read<ExerciseProvider>().exercises;
    await showKeyboardSafeSheet(
      context,
      ExerciseFormSheet(
        initialName:        exercise.name,
        initialMuscleGroup: exercise.muscleGroup,
        initialNotes:       exercise.notes ?? '',
        existingNames: exercises
            .where((e) => e.key != exercise.key)
            .map((e) => e.name.toLowerCase())
            .toSet(),
        onConfirm: (name, muscleGroup, notes) {
          exercise.name        = name;
          exercise.muscleGroup = muscleGroup;
          exercise.notes       = notes.isNotEmpty ? notes : null;
          exercise.save();
          if (mounted) {
            context.read<ExerciseProvider>().loadExercises();
            Navigator.pop(context);
          }
        }));
  }

  Future<void> _confirmDelete(HiveExercise exercise) async {
    final ok = await showGlassDialog<bool>(
      context:     context,
      accentColor: _red,
      icon: Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color:  _red.withOpacity(0.12),
          shape:  BoxShape.circle,
          border: Border.all(color: _red.withOpacity(0.4))),
        child: const Icon(Icons.delete_outline_rounded,
            color: _red, size: 22)),
      title:   'Eliminare esercizio?',
      message: '"${exercise.name}" verrà rimosso dalla libreria.',
      actions: [
        GlassDialogAction(label: 'Annulla',
            onTap: () => Navigator.pop(context, false)),
        GlassDialogAction(label: 'Elimina', isDestructive: true,
            onTap: () => Navigator.pop(context, true)),
      ]);
    if (ok == true && mounted) {
      HiveDatabase.instance.deleteExercise(exercise.key);
      context.read<ExerciseProvider>().loadExercises();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c         = context.mfc;
    final isDark    = context.isDarkMode;
    final sysBottom = MediaQuery.of(context).viewPadding.bottom;
    final exercises = context.watch<ExerciseProvider>().exercises;
    final groups    = _groups(exercises);
    final filtered  = _filtered(exercises);

    return Scaffold(
      backgroundColor:          Colors.transparent,
      resizeToAvoidBottomInset: false,
      floatingActionButton: _GlassFAB(
          onTap: _showAddSheet, sysBottom: sysBottom, c: c),
      body: CosmicBackground(
        child: SafeArea(
          child: Column(children: [
            // AppBar
            _buildAppBar(context, c),
            // Body
            Expanded(
              child: RefreshIndicator(
                onRefresh:
                    () async => context.read<ExerciseProvider>().loadExercises(),
                color:           _teal,
                backgroundColor: c.glassCardStrong,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 88 + sysBottom),
                  children: [
                    // Search
                    _SearchBar(ctrl: _searchCtrl, c: c, isDark: isDark,
                        onChanged: (v) => setState(() => _search = v)),
                    const SizedBox(height: 10),
                    // Category chips
                    if (groups.length > 1) ...[
                      _GroupChips(
                        groups:   groups,
                        selected: _selectedGroup,
                        c:        c,
                        onSelect: (g) => setState(() => _selectedGroup = g)),
                      const SizedBox(height: 12),
                    ],
                    // Header
                    if (exercises.isNotEmpty)
                      _Header(total: exercises.length,
                          shown: filtered.length, c: c),
                    const SizedBox(height: 8),
                    // List
                    if (filtered.isEmpty)
                      _EmptyState(hasExercises: exercises.isNotEmpty, c: c)
                    else
                      ...filtered.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ExerciseTile(
                          exercise: e, c: c,
                          onEdit:   () => _showEditSheet(e),
                          onDelete: () => _confirmDelete(e)))),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, MarkFitColors c) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: c.glassBlurStrong, sigmaY: c.glassBlurStrong),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            border: Border(bottom: BorderSide(
                color: _cyan.withOpacity(0.12), width: 0.6)),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 6,
                    offset: const Offset(0, 2))]
                : null),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.glassCardInset,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: c.glassBorder, width: 0.8)),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15, color: c.iconPrimary))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('Libreria esercizi', style: TextStyle(
                  color: c.textPrimary, fontSize: 17,
                  fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              Text('Tutti gli esercizi disponibili', style: TextStyle(
                  color: c.textTertiary, fontSize: 11)),
            ])),
            // Add button
            GestureDetector(
              onTap: _showAddSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_teal, _tealDk]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(
                      color: _teal.withOpacity(0.4), blurRadius: 8,
                      offset: const Offset(0, 2))]),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 5),
                  Text('Nuovo', style: TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w700)),
                ]))),
          ]),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  final TextEditingController ctrl;
  final MarkFitColors         c;
  final bool                  isDark;
  final ValueChanged<String>  onChanged;
  const _SearchBar({required this.ctrl, required this.c,
      required this.isDark, required this.onChanged});
  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: widget.c.glassBlur, sigmaY: widget.c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: widget.c.inputBg,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: widget.c.inputBorder,
                width: widget.isDark ? 0.8 : 1.1)),
          child: TextField(
            controller:         widget.ctrl,
            style:              TextStyle(color: widget.c.inputText, fontSize: 14),
            keyboardAppearance: widget.isDark ? Brightness.dark : Brightness.light,
            cursorColor:        _teal,
            decoration: InputDecoration(
              hintText:  'Cerca per nome o gruppo muscolare...',
              hintStyle: TextStyle(color: widget.c.inputHint, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded,
                  color: widget.c.iconSecondary, size: 18),
              suffixIcon: widget.ctrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        widget.ctrl.clear();
                        widget.onChanged('');
                        setState(() {});
                      },
                      child: Icon(Icons.close_rounded,
                          color: widget.c.iconSecondary, size: 16))
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13)),
            onChanged: (v) { widget.onChanged(v); setState(() {}); }))));
  }
}

class _GroupChips extends StatelessWidget {
  final List<String>         groups;
  final String                selected;
  final MarkFitColors        c;
  final ValueChanged<String> onSelect;
  const _GroupChips({required this.groups, required this.selected,
      required this.c, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount:        groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final g   = groups[i];
          final sel = g == selected;
          final col = g == 'Tutti' ? _cyan : _colorFor(g);
          return GestureDetector(
            onTap: () => onSelect(g),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? col.withOpacity(0.15) : c.glassCardInset,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: sel ? col.withOpacity(0.55) : c.glassBorder,
                  width: sel ? 1.2 : 0.8),
                boxShadow: sel && c.showElevation
                    ? [BoxShadow(color: col.withOpacity(0.15), blurRadius: 6)]
                    : null),
              child: Text(g, style: TextStyle(
                  color:      sel ? col : c.textTertiary,
                  fontSize:   12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500))));
        }));
  }
}

class _Header extends StatelessWidget {
  final int total, shown; final MarkFitColors c;
  const _Header({required this.total, required this.shown, required this.c});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 28, height: 28,
      decoration: BoxDecoration(
          color: _teal.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.fitness_center_rounded,
          size: 14, color: _teal)),
    const SizedBox(width: 8),
    Text('$shown di $total esercizi', style: TextStyle(
        color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
  ]);
}

class _ExerciseTile extends StatelessWidget {
  final HiveExercise  exercise;
  final MarkFitColors c;
  final VoidCallback  onEdit, onDelete;
  const _ExerciseTile({required this.exercise, required this.c,
      required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final grColor = _colorFor(exercise.muscleGroup);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.glassBorder, width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 6,
                    offset: const Offset(0, 1))]
                : null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(children: [
              // Group color dot + icon
              Container(width: 38, height: 38,
                decoration: BoxDecoration(
                  color: grColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: grColor.withOpacity(0.25), width: 0.7)),
                child: Icon(Icons.fitness_center_rounded,
                    size: 18, color: grColor)),
              const SizedBox(width: 12),
              // Name + group + notes
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(exercise.name, style: TextStyle(
                    color:      c.textPrimary,
                    fontSize:   14,
                    fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  if (exercise.muscleGroup.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: grColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: grColor.withOpacity(0.25), width: 0.6)),
                      child: Text(exercise.muscleGroup, style: TextStyle(
                          color: grColor, fontSize: 10,
                          fontWeight: FontWeight.w600))),
                    const SizedBox(width: 6),
                  ],
                  if (exercise.notes != null &&
                      exercise.notes!.isNotEmpty)
                    Expanded(child: Text(exercise.notes!,
                        style: TextStyle(
                            color: c.textTertiary, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ])),
              const SizedBox(width: 8),
              // Edit
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c.glassCardInset,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: c.glassBorder, width: 0.7)),
                  child: Icon(Icons.edit_outlined,
                      size: 14, color: c.iconSecondary))),
              const SizedBox(width: 6),
              // Delete
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _red.withOpacity(0.25), width: 0.7)),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 14, color: _red.withOpacity(0.8)))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool          hasExercises;
  final MarkFitColors c;
  const _EmptyState({required this.hasExercises, required this.c});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(
          color: _teal.withOpacity(0.08), shape: BoxShape.circle),
        child: Icon(Icons.fitness_center_rounded,
            color: _teal.withOpacity(0.6), size: 26)),
      const SizedBox(height: 14),
      Text(
        hasExercises ? 'Nessun esercizio trovato'
                     : 'Nessun esercizio ancora',
        style: TextStyle(color: c.textPrimary, fontSize: 15,
            fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        hasExercises
            ? 'Prova a cambiare filtri o ricerca'
            : 'Aggiungi il tuo primo esercizio',
        style: TextStyle(color: c.textTertiary, fontSize: 13)),
    ])));
}

class _GlassFAB extends StatelessWidget {
  final VoidCallback  onTap;
  final double        sysBottom;
  final MarkFitColors c;
  const _GlassFAB({required this.onTap, required this.sysBottom,
      required this.c});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: sysBottom > 0 ? 0 : 8),
    child: GestureDetector(
      onTap: () { HapticFeedback.mediumImpact(); onTap(); },
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_teal, _tealDk]),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
              color: _teal.withOpacity(0.45), blurRadius: 16,
              offset: const Offset(0, 4))]),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28))));
}