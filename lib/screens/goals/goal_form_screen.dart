import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/goal_models.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';

/// Categorie predefinite (aggiornate con le 12 dalla specifica).
const List<String> kGoalCategories = [
  'Sport',
  'Salute',
  'Studio',
  'Lavoro',
  'Produttività',
  'Benessere',
  'Lettura',
  'Hobby',
  'Personale',
  'Casa',
  'Alimentazione',
  'Recupero',
];

const String _customCategoriesKey = 'custom_goal_categories';

class GoalFormScreen extends StatefulWidget {
  final HiveGoal? existing;
  const GoalFormScreen({super.key, this.existing});

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _selectedCategory = kGoalCategories.first;
  List<String> _customCategories = [];

  String _scheduleType = 'daily';
  final Set<int> _selectedDays = {};
  int _customInterval = 2;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime? _deadline;

  static const _dayLabels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();

    final g = widget.existing;
    if (g != null) {
      _titleCtrl.text = g.title;
      _descCtrl.text = g.description ?? '';
      _selectedCategory = g.category;
      _scheduleType = g.scheduleType;
      _selectedDays.addAll(g.scheduleDaysOfWeek ?? []);
      _customInterval = g.scheduleCustomInterval ?? 2;
      _rangeStart = DateTime.tryParse(g.scheduleStartDate ?? '');
      _rangeEnd = DateTime.tryParse(g.scheduleEndDate ?? '');
      _deadline = DateTime.tryParse(g.deadlineDate ?? '');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_customCategoriesKey) ?? [];
    if (mounted) setState(() => _customCategories = saved);
  }

  Future<void> _saveCustomCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_customCategories.contains(category)) {
      _customCategories.add(category);
      await prefs.setStringList(_customCategoriesKey, _customCategories);
    }
  }

  void _showCategoryPicker() {
    showGlassBottomSheet(
      context: context,
      child: _CategoryPickerSheet(
        selected: _selectedCategory,
        predefined: kGoalCategories,
        custom: _customCategories,
        onSelected: (cat) {
          setState(() => _selectedCategory = cat);
          Navigator.pop(context);
        },
        onNewCategory: (cat, save) async {
          if (save) await _saveCustomCategory(cat);
          if (mounted) {
            setState(() {
              _selectedCategory = cat;
              if (save && !_customCategories.contains(cat)) {
                _customCategories.add(cat);
              }
            });
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final provider = context.read<GoalProvider>();

    if (widget.existing == null) {
      await provider.addGoal(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        category: _selectedCategory,
        scheduleType: _scheduleType,
        scheduleDaysOfWeek:
            _scheduleType == 'specificDays' ? _selectedDays.toList() : null,
        scheduleStartDate: (_scheduleType == 'dateRange' || _scheduleType == 'customInterval') && _rangeStart != null
            ? _fmt(_rangeStart!)
            : null,
        scheduleEndDate: _scheduleType == 'dateRange' && _rangeEnd != null
            ? _fmt(_rangeEnd!)
            : null,
        scheduleCustomInterval:
            _scheduleType == 'customInterval' ? _customInterval : null,
        deadlineDate: _deadline != null ? _fmt(_deadline!) : null,
      );
    } else {
      final g = widget.existing!;
      g.title = _titleCtrl.text.trim();
      g.description = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      g.category = _selectedCategory;
      g.scheduleType = _scheduleType;
      g.scheduleDaysOfWeek =
          _scheduleType == 'specificDays' ? _selectedDays.toList() : null;
      g.scheduleStartDate = (_scheduleType == 'dateRange' || _scheduleType == 'customInterval') && _rangeStart != null
          ? _fmt(_rangeStart!)
          : null;
      g.scheduleEndDate = _scheduleType == 'dateRange' && _rangeEnd != null
          ? _fmt(_rangeEnd!)
          : null;
      g.scheduleCustomInterval =
          _scheduleType == 'customInterval' ? _customInterval : null;
      g.deadlineDate = _deadline != null ? _fmt(_deadline!) : null;
      await provider.updateGoal(g.key, g);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Nuovo obiettivo' : 'Modifica obiettivo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Titolo
          TextField(
            controller: _titleCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Titolo',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Descrizione (opzionale)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 20),

          // Categoria — tappable field che apre il glass picker
          Text('Categoria', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showCategoryPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.category_outlined, color: cs.outline, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedCategory,
                      style: TextStyle(fontSize: 16, color: cs.onSurface),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, color: cs.outline),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Ricorrenza
          Text('Ricorrenza', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ('daily', 'Ogni giorno'),
              ('specificDays', 'Giorni specifici'),
              ('weekend', 'Weekend'),
              ('weekdays', 'Lun–Ven'),
              ('dateRange', 'Intervallo date'),
              ('customInterval', 'Ogni N giorni'),
            ].map((opt) {
              return ChoiceChip(
                label: Text(opt.$2),
                selected: _scheduleType == opt.$1,
                onSelected: (_) => setState(() => _scheduleType = opt.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          if (_scheduleType == 'specificDays')
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final day = i + 1;
                return FilterChip(
                  label: Text(_dayLabels[i]),
                  selected: _selectedDays.contains(day),
                  onSelected: (v) => setState(() {
                    v ? _selectedDays.add(day) : _selectedDays.remove(day);
                  }),
                );
              }),
            ),

          if (_scheduleType == 'customInterval')
            Row(
              children: [
                const Text('Ogni'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    initialValue: '$_customInterval',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _customInterval = int.tryParse(v) ?? _customInterval,
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('giorni'),
              ],
            ),

          if (_scheduleType == 'dateRange' || _scheduleType == 'customInterval')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _pickDate((d) => setState(() => _rangeStart = d)),
                      child: Text(_rangeStart == null ? 'Data inizio' : 'Dal ${_fmt(_rangeStart!)}'),
                    ),
                  ),
                  if (_scheduleType == 'dateRange')
                    Expanded(
                      child: TextButton(
                        onPressed: () => _pickDate((d) => setState(() => _rangeEnd = d)),
                        child: Text(_rangeEnd == null ? 'Data fine' : 'Al ${_fmt(_rangeEnd!)}'),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Scadenza
          Text('Scadenza (opzionale)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _pickDate((d) => setState(() => _deadline = d)),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(_deadline == null ? 'Imposta scadenza' : _fmt(_deadline!)),
          ),

          const SizedBox(height: 24),
          GlassFilledButton(
            onPressed: _save,
            child: const Text('Salva obiettivo'),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Glass category picker — bottom sheet iOS-style
/// ─────────────────────────────────────────────
class _CategoryPickerSheet extends StatefulWidget {
  final String selected;
  final List<String> predefined;
  final List<String> custom;
  final ValueChanged<String> onSelected;
  final void Function(String cat, bool save) onNewCategory;

  const _CategoryPickerSheet({
    required this.selected,
    required this.predefined,
    required this.custom,
    required this.onSelected,
    required this.onNewCategory,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  bool _showNewField = false;
  final _newCtrl = TextEditingController();
  bool _saveForFuture = true;

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GlassSheetHandle(),
            const SizedBox(height: 16),
            Text('Categoria', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            // Categorie predefinite
            Text('Predefinite',
                style: TextStyle(fontSize: 11, color: cs.outline, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.predefined.map((cat) {
                final sel = cat == widget.selected;
                return GestureDetector(
                  onTap: () => widget.onSelected(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? cs.primary
                          : cs.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? cs.primary : cs.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: sel ? cs.onPrimary : cs.onSurface,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Categorie custom (se esistono)
            if (widget.custom.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Le tue categorie',
                  style: TextStyle(fontSize: 11, color: cs.outline, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.custom.map((cat) {
                  final sel = cat == widget.selected;
                  return GestureDetector(
                    onTap: () => widget.onSelected(cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? cs.tertiary : cs.tertiaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? cs.tertiary : cs.tertiary.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: sel ? cs.onTertiary : cs.tertiary,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // Aggiungi nuova
            if (!_showNewField)
              GestureDetector(
                onTap: () => setState(() => _showNewField = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: cs.primary.withOpacity(0.4),
                        style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 18, color: cs.primary),
                      const SizedBox(width: 6),
                      Text('Nuova categoria...',
                          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              )
            else ...[
              TextField(
                controller: _newCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nome categoria',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_rounded),
                    onPressed: () {
                      final cat = _newCtrl.text.trim();
                      if (cat.isNotEmpty) {
                        widget.onNewCategory(cat, _saveForFuture);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _saveForFuture,
                    onChanged: (v) => setState(() => _saveForFuture = v ?? true),
                  ),
                  const Text('Salva per utilizzo futuro'),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}