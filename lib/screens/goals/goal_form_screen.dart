import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/goal_models.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/glass_action_buttons.dart';

class GoalFormScreen extends StatefulWidget {
  final HiveGoal? existing;
  const GoalFormScreen({super.key, this.existing});

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
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
    final g = widget.existing;
    if (g != null) {
      _titleCtrl.text = g.title;
      _descCtrl.text = g.description ?? '';
      _categoryCtrl.text = g.category;
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
    _categoryCtrl.dispose();
    super.dispose();
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
        category: _categoryCtrl.text.trim().isEmpty
            ? 'Generale'
            : _categoryCtrl.text.trim(),
        scheduleType: _scheduleType,
        scheduleDaysOfWeek:
            _scheduleType == 'specificDays' ? _selectedDays.toList() : null,
        scheduleStartDate: _scheduleType == 'dateRange' || _scheduleType == 'customInterval'
            ? (_rangeStart != null ? _fmt(_rangeStart!) : null)
            : null,
        scheduleEndDate:
            _scheduleType == 'dateRange' && _rangeEnd != null ? _fmt(_rangeEnd!) : null,
        scheduleCustomInterval:
            _scheduleType == 'customInterval' ? _customInterval : null,
        deadlineDate: _deadline != null ? _fmt(_deadline!) : null,
      );
    } else {
      final g = widget.existing!;
      g.title = _titleCtrl.text.trim();
      g.description = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      g.category = _categoryCtrl.text.trim().isEmpty ? 'Generale' : _categoryCtrl.text.trim();
      g.scheduleType = _scheduleType;
      g.scheduleDaysOfWeek = _scheduleType == 'specificDays' ? _selectedDays.toList() : null;
      g.scheduleStartDate = (_scheduleType == 'dateRange' || _scheduleType == 'customInterval') && _rangeStart != null
          ? _fmt(_rangeStart!)
          : null;
      g.scheduleEndDate = _scheduleType == 'dateRange' && _rangeEnd != null ? _fmt(_rangeEnd!) : null;
      g.scheduleCustomInterval = _scheduleType == 'customInterval' ? _customInterval : null;
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
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Titolo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _categoryCtrl,
            decoration: const InputDecoration(
                labelText: 'Categoria', hintText: 'Es. Salute, Studio...'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Descrizione (opzionale)'),
          ),
          const SizedBox(height: 20),
          Text('Ricorrenza', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ('daily', 'Ogni giorno'),
              ('specificDays', 'Giorni specifici'),
              ('weekend', 'Weekend'),
              ('weekdays', 'Lun-Ven'),
              ('dateRange', 'Intervallo date'),
              ('customInterval', 'Ogni N giorni'),
            ].map((opt) {
              final selected = _scheduleType == opt.$1;
              return ChoiceChip(
                label: Text(opt.$2),
                selected: selected,
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
                final selected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(_dayLabels[i]),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
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
                    onChanged: (v) =>
                        _customInterval = int.tryParse(v) ?? _customInterval,
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
            ),
          const SizedBox(height: 20),
          Text('Scadenza (opzionale)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _pickDate((d) => setState(() => _deadline = d)),
            child: Text(_deadline == null ? 'Imposta scadenza' : _fmt(_deadline!)),
          ),
          const SizedBox(height: 24),
          GlassFilledButton(onPressed: _save, child: const Text('Salva obiettivo')),
        ],
      ),
    );
  }
}