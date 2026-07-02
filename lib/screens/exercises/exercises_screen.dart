import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import '../../db/hive_database.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';

const List<String> kExerciseMuscleGroups = [
  'Petto',
  'Schiena',
  'Spalle',
  'Bicipiti',
  'Tricipiti',
  'Lombari',
  'Gambe',
  'Addominali',
];

/// Libreria esercizi: lista raggruppata per gruppo muscolare,
/// ricerca, creazione/modifica/eliminazione.
///
/// [isDialog]: quando true, la schermata è incapsulata in un
/// Dialog (vedi home_screen.dart, schermata legacy non più
/// raggiunta dalla navigazione principale ma ancora presente).
/// In quel contesto non esiste una route precedente nel Navigator
/// da cui Flutter possa dedurre automaticamente un pulsante
/// "indietro": mostriamo quindi un pulsante di chiusura esplicito.
class ExercisesScreen extends StatefulWidget {
  final bool isDialog;
  const ExercisesScreen({super.key, this.isDialog = false});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  String _search = '';
  String _groupFilter = 'Tutti';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<ExerciseProvider>().loadExercises();
    });
  }

  Map<String, List<HiveExercise>> _groupedExercises(List<HiveExercise> all) {
    final filtered = all.where((e) {
      final matchGroup = _groupFilter == 'Tutti' || e.muscleGroup == _groupFilter;
      final matchSearch =
          _search.isEmpty || e.name.toLowerCase().contains(_search.toLowerCase());
      return matchGroup && matchSearch;
    }).toList();

    final Map<String, List<HiveExercise>> grouped = {};
    for (final ex in filtered) {
      grouped.putIfAbsent(ex.muscleGroup, () => []).add(ex);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return grouped;
  }

  void _showAddOrEditSheet({HiveExercise? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String selectedGroup = existing?.muscleGroup ?? kExerciseMuscleGroups.first;
    String? errorText;

    showGlassBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GlassSheetHandle(),
                const SizedBox(height: 16),
                Text(
                  existing == null ? 'Nuovo esercizio' : 'Modifica esercizio',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nome esercizio',
                    hintText: 'Es. Panca piana',
                    prefixIcon: const Icon(Icons.fitness_center),
                    errorText: errorText,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Gruppo muscolare',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kExerciseMuscleGroups.map((g) {
                    final selected = selectedGroup == g;
                    return ChoiceChip(
                      label: Text(g),
                      selected: selected,
                      onSelected: (_) => setModal(() => selectedGroup = g),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                GlassDialogActions(
                  cancelLabel: 'Annulla',
                  confirmLabel: existing == null ? 'Crea' : 'Salva',
                  onCancel: () => Navigator.pop(ctx),
                  onConfirm: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      setModal(() => errorText = 'Il nome non può essere vuoto');
                      return;
                    }

                    final db = HiveDatabase.instance;
                    final isDuplicate = existing == null
                        ? db.exerciseNameExists(name)
                        : (name.toLowerCase() != existing.name.toLowerCase() &&
                            db.exerciseNameExists(name));
                    if (isDuplicate) {
                      setModal(() => errorText = 'Esiste già un esercizio con questo nome');
                      return;
                    }

                    if (existing == null) {
                      await db.addExercise(
                        HiveExercise(name: name, muscleGroup: selectedGroup),
                      );
                    } else {
                      existing.name = name;
                      existing.muscleGroup = selectedGroup;
                      await existing.save();
                    }

                    if (ctx.mounted) {
                      context.read<ExerciseProvider>().loadExercises();
                      Navigator.pop(ctx);
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(HiveExercise exercise) {
    showGlassDialog(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text('Elimina esercizio',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ]),
            const SizedBox(height: 12),
            Text(
              'Eliminare "${exercise.name}"? Le schede che lo contengono già '
              'potrebbero mostrare un esercizio non più disponibile.',
            ),
            const SizedBox(height: 24),
            GlassDialogActions(
              cancelLabel: 'Annulla',
              confirmLabel: 'Elimina',
              confirmColor: Colors.red,
              onCancel: () => Navigator.pop(context),
              onConfirm: () async {
                await HiveDatabase.instance.deleteExercise(exercise.key);
                if (context.mounted) {
                  context.read<ExerciseProvider>().loadExercises();
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allExercises = context.watch<ExerciseProvider>().exercises;
    final grouped = _groupedExercises(allExercises);
    final groups = grouped.keys.toList()..sort();
    final filterOptions = ['Tutti', ...kExerciseMuscleGroups];

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        automaticallyImplyLeading: !widget.isDialog,
        leading: widget.isDialog
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('Libreria esercizi'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cerca esercizio...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filterOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final g = filterOptions[i];
                return ChoiceChip(
                  label: Text(g),
                  selected: _groupFilter == g,
                  onSelected: (_) => setState(() => _groupFilter = g),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: allExercises.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : groups.isEmpty
                    ? Center(
                        child: Text('Nessun esercizio trovato',
                            style: TextStyle(color: cs.outline)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: groups.length,
                        itemBuilder: (_, gi) {
                          final group = groups[gi];
                          final items = grouped[group]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 16, bottom: 8),
                                child: Text(
                                  group.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                              ...items.map((ex) => _ExerciseTile(
                                    exercise: ex,
                                    onEdit: () => _showAddOrEditSheet(existing: ex),
                                    onDelete: () => _confirmDelete(ex),
                                  )),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
            24, 8, 24, MediaQuery.of(context).padding.bottom + 16),
        child: GlassButton(
          onTap: () => _showAddOrEditSheet(),
          icon: Icons.add_rounded,
          label: 'Nuovo esercizio',
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final HiveExercise exercise;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExerciseTile({
    required this.exercise,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? cs.surface.withOpacity(0.8) : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : cs.outlineVariant,
        ),
      ),
      child: ListTile(
        title: Text(exercise.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: cs.primary),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}