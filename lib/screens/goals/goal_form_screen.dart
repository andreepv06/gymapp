import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/persistence/categories_repository.dart';
import '../../models/goal_models.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';

class GoalFormScreen extends StatefulWidget {
  final HiveGoal? existing;
  const GoalFormScreen({super.key, this.existing});

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _selectedCategory = CategoriesRepository.predefined.first;
  List<String> _customCategories = [];

  String _scheduleType = 'daily';
  final Set<int> _selectedDays = {};
  int _customInterval = 2;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime? _deadline;
  bool _saving = false;

  static const _dayLabels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
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

  Future<void> _loadCategories() async {
    final custom = await CategoriesRepository.loadCustom();
    if (mounted) setState(() => _customCategories = custom);
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final provider = context.read<GoalProvider>();
    if (widget.existing == null) {
      await provider.addGoal(
        title: _titleCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        category: _selectedCategory,
        scheduleType: _scheduleType,
        scheduleDaysOfWeek:
            _scheduleType == 'specificDays' ? _selectedDays.toList() : null,
        scheduleStartDate:
            (_scheduleType == 'dateRange' || _scheduleType == 'customInterval') &&
                    _rangeStart != null
                ? _fmt(_rangeStart!)
                : null,
        scheduleEndDate:
            _scheduleType == 'dateRange' && _rangeEnd != null
                ? _fmt(_rangeEnd!)
                : null,
        scheduleCustomInterval:
            _scheduleType == 'customInterval' ? _customInterval : null,
        deadlineDate: _deadline != null ? _fmt(_deadline!) : null,
      );
    } else {
      final g = widget.existing!;
      g.title = _titleCtrl.text.trim();
      g.description =
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      g.category = _selectedCategory;
      g.scheduleType = _scheduleType;
      g.scheduleDaysOfWeek =
          _scheduleType == 'specificDays' ? _selectedDays.toList() : null;
      g.scheduleStartDate =
          (_scheduleType == 'dateRange' || _scheduleType == 'customInterval') &&
                  _rangeStart != null
              ? _fmt(_rangeStart!)
              : null;
      g.scheduleEndDate =
          _scheduleType == 'dateRange' && _rangeEnd != null
              ? _fmt(_rangeEnd!)
              : null;
      g.scheduleCustomInterval =
          _scheduleType == 'customInterval' ? _customInterval : null;
      g.deadlineDate = _deadline != null ? _fmt(_deadline!) : null;
      await provider.updateGoal(g.key, g);
    }

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  void _openCategoryPicker() {
    showGlassBottomSheet(
      context: context,
      child: _CategoryPickerSheet(
        selected: _selectedCategory,
        customCategories: _customCategories,
        onSelect: (cat) {
          setState(() => _selectedCategory = cat);
          Navigator.pop(context);
        },
        onCategoriesUpdated: (custom) {
          setState(() => _customCategories = custom);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null
            ? 'Nuovo obiettivo'
            : 'Modifica obiettivo'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : GlassTextButton(
                  onPressed: _save,
                  child: const Text('Salva'),
                ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Titolo
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Titolo *',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 14),

            // Descrizione
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descrizione (opzionale)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 20),

            // Categoria — campo tappable che apre il picker Glass
            Text('Categoria',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _openCategoryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.category_outlined,
                        color: cs.outline, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_selectedCategory,
                          style: const TextStyle(fontSize: 16)),
                    ),
                    Icon(Icons.expand_more_rounded, color: cs.outline),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Ricorrenza
            Text('Ricorrenza',
                style: Theme.of(context).textTheme.titleSmall),
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
              ]
                  .map((opt) => ChoiceChip(
                        label: Text(opt.$2),
                        selected: _scheduleType == opt.$1,
                        onSelected: (_) =>
                            setState(() => _scheduleType = opt.$1),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),

            if (_scheduleType == 'specificDays')
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(7, (i) {
                  final day = i + 1;
                  return FilterChip(
                    label: Text(_dayLabels[i]),
                    selected: _selectedDays.contains(day),
                    onSelected: (v) => setState(() =>
                        v ? _selectedDays.add(day) : _selectedDays.remove(day)),
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
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (v) =>
                          _customInterval = int.tryParse(v) ?? _customInterval,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('giorni'),
                ],
              ),

            if (_scheduleType == 'dateRange' ||
                _scheduleType == 'customInterval') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () =>
                          _pickDate((d) => setState(() => _rangeStart = d)),
                      child: Text(_rangeStart == null
                          ? 'Data inizio'
                          : 'Dal ${_fmt(_rangeStart!)}'),
                    ),
                  ),
                  if (_scheduleType == 'dateRange')
                    Expanded(
                      child: TextButton(
                        onPressed: () =>
                            _pickDate((d) => setState(() => _rangeEnd = d)),
                        child: Text(_rangeEnd == null
                            ? 'Data fine'
                            : 'Al ${_fmt(_rangeEnd!)}'),
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Scadenza
            Text('Scadenza (opzionale)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  _pickDate((d) => setState(() => _deadline = d)),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(_deadline == null
                  ? 'Imposta scadenza'
                  : _fmt(_deadline!)),
            ),

            const SizedBox(height: 32),
            GlassFilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Salva obiettivo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _CategoryPickerSheet — Glass bottom sheet
// ─────────────────────────────────────────────

class _CategoryPickerSheet extends StatefulWidget {
  final String selected;
  final List<String> customCategories;
  final ValueChanged<String> onSelect;
  final ValueChanged<List<String>> onCategoriesUpdated;

  const _CategoryPickerSheet({
    required this.selected,
    required this.customCategories,
    required this.onSelect,
    required this.onCategoriesUpdated,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late List<String> _custom;
  bool _showAddField = false;
  final _addCtrl = TextEditingController();
  String? _addError;

  @override
  void initState() {
    super.initState();
    _custom = List.from(widget.customCategories);
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAdd() async {
    final err = await CategoriesRepository.addCustom(_addCtrl.text);
    if (err != null) {
      setState(() => _addError = err);
      return;
    }
    final updated = await CategoriesRepository.loadCustom();
    setState(() {
      _custom = updated;
      _showAddField = false;
      _addCtrl.clear();
      _addError = null;
    });
    widget.onCategoriesUpdated(_custom);
  }

  void _showRenameDialog(String old) {
    final ctrl = TextEditingController(text: old);
    String? err;
    showGlassDialog(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setD) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rinomina categoria',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                    labelText: 'Nuovo nome', errorText: err),
              ),
              const SizedBox(height: 20),
              GlassDialogActions(
                cancelLabel: 'Annulla',
                confirmLabel: 'Rinomina',
                onCancel: () => Navigator.pop(ctx),
                onConfirm: () async {
                  final e =
                      await CategoriesRepository.renameCustom(old, ctrl.text);
                  if (e != null) {
                    setD(() => err = e);
                    return;
                  }
                  final updated = await CategoriesRepository.loadCustom();
                  setState(() => _custom = updated);
                  widget.onCategoriesUpdated(_custom);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(String name) {
    showGlassDialog(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('Elimina categoria',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            Text(
                'Eliminare "$name"?\nGli obiettivi esistenti mantengono la categoria.'),
            const SizedBox(height: 20),
            GlassDialogActions(
              cancelLabel: 'Annulla',
              confirmLabel: 'Elimina',
              confirmColor: Colors.red,
              onCancel: () => Navigator.pop(context),
              onConfirm: () async {
                await CategoriesRepository.deleteCustom(name);
                final updated = await CategoriesRepository.loadCustom();
                setState(() => _custom = updated);
                widget.onCategoriesUpdated(_custom);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomOptions(String cat) {
    showGlassDialog(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cat,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('Rinomina'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(cat);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Elimina',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirm(cat);
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

            // Predefinite
            Text('Predefinite',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.outline,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CategoriesRepository.predefined.map((cat) {
                final sel = cat == widget.selected;
                return _CatChip(
                  label: cat,
                  selected: sel,
                  onTap: () => widget.onSelect(cat),
                );
              }).toList(),
            ),

            // Custom
            if (_custom.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Le mie categorie',
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.outline,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _custom.map((cat) {
                  final sel = cat == widget.selected;
                  return _CatChip(
                    label: cat,
                    selected: sel,
                    isCustom: true,
                    onTap: () => widget.onSelect(cat),
                    onLongPress: () => _showCustomOptions(cat),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // Aggiungi categoria
            if (!_showAddField)
              GestureDetector(
                onTap: () => setState(() => _showAddField = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: cs.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 18, color: cs.primary),
                      const SizedBox(width: 6),
                      Text('Aggiungi categoria',
                          style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              )
            else ...[
              TextField(
                controller: _addCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nome categoria',
                  hintText: 'Es. Famiglia, Sport...',
                  errorText: _addError,
                ),
                onSubmitted: (_) => _submitAdd(),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GlassTextButton(
                    onPressed: () => setState(() {
                      _showAddField = false;
                      _addCtrl.clear();
                      _addError = null;
                    }),
                    child: const Text('Annulla'),
                  ),
                  const SizedBox(width: 8),
                  GlassTextButton(
                    onPressed: _submitAdd,
                    foregroundColor: cs.primary,
                    child: const Text('Aggiungi',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
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

/// Chip categoria riutilizzabile nel picker.
class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isCustom;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isCustom = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected
        ? (isCustom ? cs.tertiary : cs.primary)
        : (isCustom
            ? cs.tertiaryContainer.withOpacity(0.3)
            : cs.surfaceContainerHighest.withOpacity(0.5));
    final fg = selected
        ? (isCustom ? cs.onTertiary : cs.onPrimary)
        : (isCustom ? cs.tertiary : cs.onSurface);
    final border = selected
        ? Colors.transparent
        : (isCustom
            ? cs.tertiary.withOpacity(0.4)
            : cs.outlineVariant.withOpacity(0.5));

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: fg,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontSize: 13)),
            if (isCustom && !selected) ...[
              const SizedBox(width: 4),
              Icon(Icons.more_horiz, size: 12, color: fg.withOpacity(0.6)),
            ],
          ],
        ),
      ),
    );
  }
}