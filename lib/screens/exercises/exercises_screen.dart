import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exercise_provider.dart';
import '../../models/hive_models.dart';
import '../../widgets/glass_button.dart';

class ExercisesScreen extends StatefulWidget {
  final bool isDialog;
  const ExercisesScreen({super.key, this.isDialog = false});

  @override
  State<ExercisesScreen> createState() =>
      _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<ExerciseProvider>().loadExercises());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExerciseProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Esercizi'),
        leading: widget.isDialog
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      // GlassButton come FAB esteso centrato
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.of(context).padding.bottom > 0
              ? 90
              : 16,
        ),
        child: GlassButton(
          onTap: () => _showAddExerciseModal(context),
          icon: Icons.add_rounded,
          label: 'Nuovo esercizio',
        ),
      ),
      body: Column(
        children: [
          _MuscleGroupChips(
            groups: provider.muscleGroups,
            selected: provider.selectedMuscleGroup,
            onSelect: provider.selectMuscleGroup,
          ),
          Expanded(
            child: provider.exercises.isEmpty
                ? const Center(
                    child: CircularProgressIndicator())
                : _ExerciseList(
                    defaultExercises:
                        provider.defaultExercises,
                    customExercises: provider.customExercises,
                    selectedGroup:
                        provider.selectedMuscleGroup,
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddExerciseModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const AddExerciseModal(),
    );
  }
}

class _MuscleGroupChips extends StatelessWidget {
  final List<String> groups;
  final String selected;
  final ValueChanged<String> onSelect;

  const _MuscleGroupChips({
    required this.groups,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        itemCount: groups.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final group = groups[i];
          final isSelected = group == selected;
          return ChoiceChip(
            label: Text(group),
            selected: isSelected,
            onSelected: (_) => onSelect(group),
          );
        },
      ),
    );
  }
}

class _ExerciseList extends StatelessWidget {
  final List<HiveExercise> defaultExercises;
  final List<HiveExercise> customExercises;
  final String selectedGroup;

  const _ExerciseList({
    required this.defaultExercises,
    required this.customExercises,
    required this.selectedGroup,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedGroup != 'Tutti') {
      return ListView(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        children: [
          ...defaultExercises
              .map((e) => _ExerciseCard(exercise: e)),
          if (customExercises.isNotEmpty) ...[
            _GroupHeader(
                title: 'Personalizzati',
                color: Theme.of(context)
                    .colorScheme
                    .tertiary),
            ...customExercises
                .map((e) => _ExerciseCard(exercise: e)),
          ],
          const SizedBox(height: 100),
        ],
      );
    }

    final Map<String, List<HiveExercise>> grouped = {};
    for (final e in defaultExercises) {
      grouped.putIfAbsent(e.muscleGroup, () => []).add(e);
    }
    final sortedGroups = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      children: [
        for (final group in sortedGroups) ...[
          _GroupHeader(
              title: group,
              color:
                  Theme.of(context).colorScheme.primary),
          ...grouped[group]!
              .map((e) => _ExerciseCard(exercise: e)),
        ],
        if (customExercises.isNotEmpty) ...[
          _GroupHeader(
              title: 'Personalizzati',
              color:
                  Theme.of(context).colorScheme.tertiary),
          ...customExercises
              .map((e) => _ExerciseCard(exercise: e)),
        ],
        const SizedBox(height: 100),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _GroupHeader(
      {required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final HiveExercise exercise;
  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(exercise.name),
        subtitle: Text(exercise.muscleGroup),
        trailing: exercise.isCustom
            ? const Chip(
                label: Text('Custom'),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )
            : null,
        onTap: () {},
        onLongPress: exercise.isCustom
            ? () => _confirmDelete(context)
            : null,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina esercizio'),
        content: Text('Vuoi eliminare "${exercise.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              context
                  .read<ExerciseProvider>()
                  .deleteExercise(exercise.key);
              Navigator.pop(context);
            },
            child: const Text('Elimina',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class AddExerciseModal extends StatefulWidget {
  const AddExerciseModal({super.key});

  @override
  State<AddExerciseModal> createState() =>
      _AddExerciseModalState();
}

class _AddExerciseModalState extends State<AddExerciseModal> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedMuscle;
  bool _isCustom = true;

  static const _muscleGroups = [
    'Petto',
    'Spalle',
    'Schiena',
    'Bicipiti',
    'Tricipiti',
    'Lombari',
    'Gambe',
    'Addominali',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExerciseProvider>();
    final nameExists =
        provider.exerciseNameExists(_nameController.text);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
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
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Nuovo esercizio',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Nome esercizio'),
                textCapitalization:
                    TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Inserisci un nome';
                  }
                  return null;
                },
              ),
              if (nameExists &&
                  _nameController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .tertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Esiste già un esercizio con questo nome.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiary),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text('Gruppo muscolare',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _muscleGroups.map((muscle) {
                  return ChoiceChip(
                    label: Text(muscle),
                    selected: _selectedMuscle == muscle,
                    onSelected: (_) => setState(
                        () => _selectedMuscle = muscle),
                  );
                }).toList(),
              ),
              if (_selectedMuscle == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Seleziona un gruppo muscolare',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .error),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: nameExists
                      ? 'Note (obbligatorie)'
                      : 'Note (opzionale)',
                  hintText:
                      'Es. grip neutro, cavi alti...',
                ),
                validator: (v) {
                  if (nameExists &&
                      (v == null || v.trim().isEmpty)) {
                    return 'Aggiungi una nota per distinguerlo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title:
                    const Text('Segna come personalizzato'),
                value: _isCustom,
                onChanged: (v) =>
                    setState(() => _isCustom = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Salva esercizio'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMuscle == null) return;
    final exercise = HiveExercise(
      name: _nameController.text.trim(),
      muscleGroup: _selectedMuscle!,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      isCustom: _isCustom,
    );
    context.read<ExerciseProvider>().addExercise(exercise);
    Navigator.pop(context);
  }
}