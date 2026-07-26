import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/persistence/categories_repository.dart';
import '../../models/goal_models.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/cosmic_background.dart';

// ── Design tokens ─────────────────────────────────────────────
const _cyan   = Color(0xFF00E5FF);
const _teal   = Color(0xFF00D4AA);
const _tealDk = Color(0xFF00A880);
const _indigo = Color(0xFF6366F1);
const _orange = Color(0xFFFF8C00);
const _red    = Color(0xFFFF3B30);
const _green  = Color(0xFF22C55E);
const _blue   = Color(0xFF3B82F6);

const _catColors = <String, Color>{
  'Studio':        Color(0xFF6366F1),
  'Sport':         Color(0xFF00D4AA),
  'Salute':        Color(0xFF22C55E),
  'Lavoro':        Color(0xFF3B82F6),
  'Alimentazione': Color(0xFFFF8C00),
  'Benessere':     Color(0xFFEC4899),
  'Produttività':  Color(0xFF8B5CF6),
  'Hobby':         Color(0xFFF59E0B),
  'Tempo libero':  Color(0xFF06B6D4),
  'Finanze':       Color(0xFF10B981),
  'Lettura':       Color(0xFF6B7280),
  'Meditazione':   Color(0xFF8A2BE2),
  'Personale':     Color(0xFFFF6B6B),
  'Altro':         Color(0xFF9CA3AF),
};

Color _colorFor(String cat) =>
    _catColors[cat] ?? const Color(0xFF9CA3AF);

// ─────────────────────────────────────────────────────────────
// Tipi di pianificazione — mappati 1:1 su scheduleType di HiveGoal
// ─────────────────────────────────────────────────────────────

enum _ScheduleType {
  daily,
  specificDays,
  weekdays,
  weekend,
  dateRange,
  customInterval,
}

extension _ScheduleTypeX on _ScheduleType {
  String get id {
    switch (this) {
      case _ScheduleType.daily:           return 'daily';
      case _ScheduleType.specificDays:    return 'specificDays';
      case _ScheduleType.weekdays:        return 'weekdays';
      case _ScheduleType.weekend:         return 'weekend';
      case _ScheduleType.dateRange:       return 'dateRange';
      case _ScheduleType.customInterval:  return 'customInterval';
    }
  }

  String get label {
    switch (this) {
      case _ScheduleType.daily:           return 'Ogni giorno';
      case _ScheduleType.specificDays:    return 'Giorni specifici';
      case _ScheduleType.weekdays:        return 'Giorni feriali';
      case _ScheduleType.weekend:         return 'Weekend';
      case _ScheduleType.dateRange:       return 'Intervallo date';
      case _ScheduleType.customInterval:  return 'Ogni N giorni';
    }
  }

  IconData get icon {
    switch (this) {
      case _ScheduleType.daily:           return Icons.all_inclusive_rounded;
      case _ScheduleType.specificDays:    return Icons.view_week_rounded;
      case _ScheduleType.weekdays:        return Icons.business_center_rounded;
      case _ScheduleType.weekend:         return Icons.weekend_rounded;
      case _ScheduleType.dateRange:       return Icons.date_range_rounded;
      case _ScheduleType.customInterval:  return Icons.repeat_rounded;
    }
  }

  static _ScheduleType fromId(String id) {
    switch (id) {
      case 'daily':          return _ScheduleType.daily;
      case 'specificDays':   return _ScheduleType.specificDays;
      case 'weekdays':       return _ScheduleType.weekdays;
      case 'weekend':        return _ScheduleType.weekend;
      case 'dateRange':      return _ScheduleType.dateRange;
      case 'customInterval': return _ScheduleType.customInterval;
      default:               return _ScheduleType.daily;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// NewGoalScreen
// ─────────────────────────────────────────────────────────────

class NewGoalScreen extends StatefulWidget {
  final HiveGoal? editGoal;
  const NewGoalScreen({super.key, this.editGoal});
  bool get isEditing => editGoal != null;

  @override
  State<NewGoalScreen> createState() => _NewGoalScreenState();
}

class _NewGoalScreenState extends State<NewGoalScreen> {
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _intervalCtrl = TextEditingController();
  final _customCatCtrl = TextEditingController();

  String        _selectedCategory   = '';
  _ScheduleType _scheduleType       = _ScheduleType.daily;
  List<int>     _selectedDays       = [];   // per specificDays
  DateTime?     _startDate;
  DateTime?     _endDate;
  String?       _deadlineDate;
  bool          _saving             = false;
  bool          _showCustomCatField = false;

  List<String>  _allCategories = [];

  // Nomi giorni della settimana (1=Lun ... 7=Dom)
  static const _dayNames = [
    '', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _prefill();
  }

  Future<void> _loadCategories() async {
    final cats = await CategoriesRepository.loadAll();
    if (mounted) setState(() => _allCategories = cats);
  }

  void _prefill() {
    final g = widget.editGoal;
    if (g == null) {
      _startDate = DateTime.now();
      return;
    }
    _titleCtrl.text    = g.title;
    _descCtrl.text     = g.description ?? '';
    _selectedCategory  = g.category;
    _scheduleType      = _ScheduleTypeX.fromId(g.scheduleType);
    _selectedDays      = List<int>.from(g.scheduleDaysOfWeek ?? []);
    _startDate         = g.scheduleStartDate != null
        ? DateTime.tryParse(g.scheduleStartDate!) ?? DateTime.now()
        : DateTime.now();
    _endDate           = g.scheduleEndDate != null
        ? DateTime.tryParse(g.scheduleEndDate!) : null;
    _intervalCtrl.text =
        g.scheduleCustomInterval != null
            ? '${g.scheduleCustomInterval}'
            : '';
    _deadlineDate      = g.deadlineDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _intervalCtrl.dispose();
    _customCatCtrl.dispose();
    super.dispose();
  }

  // ── Validazione ───────────────────────────────────────────────

  String? _validate() {
    if (_titleCtrl.text.trim().isEmpty) {
      return 'Il titolo è obbligatorio.';
    }
    if (_selectedCategory.isEmpty) {
      return 'Seleziona una categoria.';
    }
    if (_scheduleType == _ScheduleType.specificDays &&
        _selectedDays.isEmpty) {
      return 'Seleziona almeno un giorno.';
    }
    if (_scheduleType == _ScheduleType.dateRange) {
      if (_startDate == null || _endDate == null) {
        return 'Seleziona le date di inizio e fine.';
      }
      if (_endDate!.isBefore(_startDate!)) {
        return 'La data di fine deve essere successiva a quella di inizio.';
      }
    }
    if (_scheduleType == _ScheduleType.customInterval) {
      final n = int.tryParse(_intervalCtrl.text.trim());
      if (n == null || n < 1) {
        return 'Inserisci un intervallo valido (≥ 1 giorno).';
      }
    }
    return null;
  }

  // ── Salvataggio ───────────────────────────────────────────────

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      _showError(err);
      return;
    }
    setState(() => _saving = true);

    final gp       = context.read<GoalProvider>();
    final title    = _titleCtrl.text.trim();
    final desc     = _descCtrl.text.trim();
    final cat      = _selectedCategory;
    final schType  = _scheduleType.id;
    final startStr = _startDate != null ? _fmtDate(_startDate!) : null;
    final endStr   = _endDate   != null ? _fmtDate(_endDate!)   : null;
    final interval = int.tryParse(_intervalCtrl.text.trim());

    try {
      if (widget.isEditing) {
        // updateGoal(key, HiveGoal) — aggiorniamo il model esistente
        final existing = widget.editGoal!;
        existing.title                  = title;
        existing.description            = desc.isEmpty ? null : desc;
        existing.category               = cat;
        existing.scheduleType           = schType;
        existing.scheduleDaysOfWeek     =
            _scheduleType == _ScheduleType.specificDays
                ? _selectedDays : null;
        existing.scheduleStartDate      =
            (_scheduleType == _ScheduleType.dateRange ||
             _scheduleType == _ScheduleType.customInterval)
                ? startStr : null;
        existing.scheduleEndDate        =
            _scheduleType == _ScheduleType.dateRange ? endStr : null;
        existing.scheduleCustomInterval =
            _scheduleType == _ScheduleType.customInterval ? interval : null;
        existing.deadlineDate           = _deadlineDate;
        await gp.updateGoal(existing.key, existing);
      } else {
        await gp.addGoal(
          title:                title,
          description:          desc.isEmpty ? null : desc,
          category:             cat,
          scheduleType:         schType,
          scheduleDaysOfWeek:
              _scheduleType == _ScheduleType.specificDays
                  ? _selectedDays : null,
          scheduleStartDate:
              (_scheduleType == _ScheduleType.dateRange ||
               _scheduleType == _ScheduleType.customInterval)
                  ? startStr : null,
          scheduleEndDate:
              _scheduleType == _ScheduleType.dateRange ? endStr : null,
          scheduleCustomInterval:
              _scheduleType == _ScheduleType.customInterval ? interval : null,
          deadlineDate: _deadlineDate,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('Errore durante il salvataggio: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: _red.withOpacity(0.85),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3)));
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime? d) {
    if (d == null) return 'Seleziona data';
    const months = ['','Gen','Feb','Mar','Apr','Mag','Giu',
        'Lug','Ago','Set','Ott','Nov','Dic'];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  // ── Categoria personalizzata ──────────────────────────────────

  Future<void> _addCustomCategory() async {
    final name = _customCatCtrl.text.trim();
    if (name.isEmpty) return;
    final err = await CategoriesRepository.addCustom(name);
    if (err != null && mounted) { _showError(err); return; }
    await _loadCategories();
    if (mounted) setState(() {
      _selectedCategory   = name;
      _showCustomCatField = false;
      _customCatCtrl.clear();
      FocusScope.of(context).unfocus();
    });
  }

  // ── Date picker Glass ─────────────────────────────────────────

  Future<DateTime?> _pickDate(DateTime initial,
      {DateTime? firstDate}) async {
    DateTime? picked;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => _GlassDatePicker(
        initialDate: initial,
        firstDate:   firstDate,
        onConfirm:   (d) { picked = d; Navigator.pop(ctx); },
        onCancel:    () => Navigator.pop(ctx)));
    return picked;
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        child: SafeArea(
          child: Column(children: [
            _AppBar(
              isEditing: widget.isEditing,
              saving:    _saving,
              canSave:   _titleCtrl.text.trim().isNotEmpty &&
                  _selectedCategory.isNotEmpty,
              onBack: () => Navigator.pop(context),
              onSave: _saving ? null : _save),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Titolo ───────────────────────────────
                      _Label(label: 'Titolo',
                          icon: Icons.edit_rounded,
                          color: _teal, required: true),
                      const SizedBox(height: 8),
                      _GlassTextField(
                        controller:  _titleCtrl,
                        hint:        'Es. Leggere 20 min al giorno...',
                        accent:      _teal,
                        onChanged:   (_) => setState(() {})),
                      const SizedBox(height: 16),

                      // ── Descrizione ──────────────────────────
                      _Label(label: 'Descrizione',
                          icon: Icons.notes_rounded, color: _cyan),
                      const SizedBox(height: 8),
                      _GlassTextField(
                        controller: _descCtrl,
                        hint:       'Note opzionali...',
                        accent:     _cyan,
                        maxLines:   3),
                      const SizedBox(height: 16),

                      // ── Categoria ────────────────────────────
                      _Label(label: 'Categoria',
                          icon: Icons.label_rounded,
                          color: _indigo, required: true),
                      const SizedBox(height: 10),
                      _CategoryGrid(
                        categories:  _allCategories,
                        selected:    _selectedCategory,
                        onSelect: (c) =>
                            setState(() => _selectedCategory = c),
                        onAddCustom: () =>
                            setState(() {
                          _showCustomCatField = !_showCustomCatField;
                          if (!_showCustomCatField) {
                            _customCatCtrl.clear();
                          }
                        })),
                      if (_showCustomCatField) ...[
                        const SizedBox(height: 10),
                        _CustomCatInput(
                          controller: _customCatCtrl,
                          onConfirm:  _addCustomCategory),
                      ],
                      const SizedBox(height: 16),

                      // ── Pianificazione ───────────────────────
                      _Label(label: 'Pianificazione',
                          icon: Icons.schedule_rounded, color: _orange),
                      const SizedBox(height: 10),
                      _ScheduleSelector(
                        selected: _scheduleType,
                        onSelect: (t) =>
                            setState(() => _scheduleType = t)),
                      const SizedBox(height: 12),

                      // ── Controlli contestuali ────────────────
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim,
                                child: SizeTransition(
                                    sizeFactor: anim, child: child)),
                        child: KeyedSubtree(
                          key: ValueKey(_scheduleType),
                          child: _buildScheduleDetails())),
                      const SizedBox(height: 16),

                      // ── Scadenza (opzionale) ─────────────────
                      _Label(label: 'Scadenza (opzionale)',
                          icon: Icons.flag_rounded, color: _red),
                      const SizedBox(height: 8),
                      _DateRow(
                        icon:   Icons.event_rounded,
                        label:  'Data scadenza',
                        value:  _deadlineDate != null
                            ? _displayDate(DateTime.tryParse(_deadlineDate!))
                            : 'Nessuna scadenza',
                        color:  _red,
                        hasValue: _deadlineDate != null,
                        onTap:  () async {
                          final d = await _pickDate(
                              _deadlineDate != null
                                  ? DateTime.parse(_deadlineDate!)
                                  : DateTime.now());
                          if (d != null) {
                            setState(
                                () => _deadlineDate = _fmtDate(d));
                          }
                        },
                        onClear: _deadlineDate != null
                            ? () => setState(() => _deadlineDate = null)
                            : null),
                      const SizedBox(height: 28),

                      // ── Pulsante Salva ───────────────────────
                      _SaveBtn(
                        isEditing: widget.isEditing,
                        saving:    _saving,
                        canSave: _titleCtrl.text.trim().isNotEmpty &&
                            _selectedCategory.isNotEmpty,
                        onSave: _save),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildScheduleDetails() {
    switch (_scheduleType) {
      case _ScheduleType.daily:
      case _ScheduleType.weekdays:
      case _ScheduleType.weekend:
        return _InfoBox(
          icon: _scheduleType.icon,
          text: _scheduleType == _ScheduleType.daily
              ? 'L\'obiettivo verrà mostrato ogni giorno.'
              : _scheduleType == _ScheduleType.weekdays
                  ? 'Visibile dal lunedì al venerdì.'
                  : 'Visibile sabato e domenica.');

      case _ScheduleType.specificDays:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('Seleziona i giorni:',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8,
            children: List.generate(7, (i) {
              final day = i + 1; // 1=Lun...7=Dom
              final sel = _selectedDays.contains(day);
              return GestureDetector(
                onTap: () => setState(() {
                  if (sel) {
                    _selectedDays.remove(day);
                  } else {
                    _selectedDays.add(day);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? _indigo.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: sel
                          ? _indigo.withOpacity(0.6)
                          : Colors.white.withOpacity(0.12),
                      width: sel ? 1.2 : 0.8)),
                  child: Text(_dayNames[day], style: TextStyle(
                      color: sel
                          ? _indigo
                          : Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: sel
                          ? FontWeight.w700 : FontWeight.w500))));
            })),
        ]);

      case _ScheduleType.dateRange:
        return Column(children: [
          _DateRow(
            icon:  Icons.play_arrow_rounded,
            label: 'Data inizio',
            value: _displayDate(_startDate),
            color: _green,
            hasValue: _startDate != null,
            onTap: () async {
              final d = await _pickDate(
                  _startDate ?? DateTime.now());
              if (d != null) setState(() => _startDate = d);
            }),
          const SizedBox(height: 8),
          _DateRow(
            icon:  Icons.stop_rounded,
            label: 'Data fine',
            value: _displayDate(_endDate),
            color: _red,
            hasValue: _endDate != null,
            onTap: () async {
              final d = await _pickDate(
                  _endDate ?? (_startDate ?? DateTime.now()),
                  firstDate: _startDate);
              if (d != null) setState(() => _endDate = d);
            }),
        ]);

      case _ScheduleType.customInterval:
        return Column(children: [
          _DateRow(
            icon:  Icons.play_arrow_rounded,
            label: 'Data inizio',
            value: _displayDate(_startDate),
            color: _green,
            hasValue: _startDate != null,
            onTap: () async {
              final d = await _pickDate(
                  _startDate ?? DateTime.now());
              if (d != null) setState(() => _startDate = d);
            }),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _blue.withOpacity(0.2), width: 0.8)),
                child: Row(children: [
                  const SizedBox(width: 14),
                  Icon(Icons.repeat_rounded,
                      color: _blue.withOpacity(0.7), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller:  _intervalCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText:  'Ogni quanti giorni? (es. 2)',
                        hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0, vertical: 13)))),
                ]))),
          ),
        ]);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// _AppBar
// ─────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final bool isEditing, saving, canSave;
  final VoidCallback onBack;
  final VoidCallback? onSave;
  const _AppBar({
    required this.isEditing, required this.saving,
    required this.canSave, required this.onBack, this.onSave});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(bottom: BorderSide(
                color: _teal.withOpacity(0.15), width: 0.6))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            // Back
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); onBack(); },
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.12), width: 0.7)),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15, color: Colors.white))),
            const SizedBox(width: 12),
            // Titolo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(isEditing
                    ? 'Modifica obiettivo' : 'Nuovo obiettivo',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 17, fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
                Text(isEditing
                    ? 'Aggiorna i dettagli'
                    : 'Definisci un traguardo',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11)),
              ])),
            // Azione salva
            if (saving)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(11)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _teal.withOpacity(0.7))),
                  const SizedBox(width: 7),
                  const Text('Salvo...',
                      style: TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]))
            else
              GestureDetector(
                onTap: canSave ? () {
                  HapticFeedback.mediumImpact();
                  onSave?.call();
                } : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: canSave
                        ? const LinearGradient(
                            colors: [_teal, _tealDk])
                        : null,
                    color: canSave
                        ? null : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: canSave ? [BoxShadow(
                        color: _teal.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3))] : null),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_rounded, color: canSave
                        ? Colors.white
                        : Colors.white.withOpacity(0.25), size: 15),
                    const SizedBox(width: 5),
                    Text(isEditing ? 'Aggiorna' : 'Salva',
                        style: TextStyle(
                            color: canSave
                                ? Colors.white
                                : Colors.white.withOpacity(0.25),
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ]))),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _Label
// ─────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final bool required;
  const _Label({required this.label, required this.icon,
      required this.color, this.required = false});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 26, height: 26,
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, size: 13, color: color)),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(color: Colors.white,
        fontSize: 13, fontWeight: FontWeight.w700)),
    if (required) ...[
      const SizedBox(width: 4),
      Text('*', style: TextStyle(
          color: _red.withOpacity(0.8), fontSize: 13,
          fontWeight: FontWeight.w700)),
    ],
  ]);
}

// ─────────────────────────────────────────────────────────────
// _GlassTextField
// ─────────────────────────────────────────────────────────────

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint; final Color accent;
  final void Function(String)? onChanged;
  final int maxLines;
  const _GlassTextField({
    required this.controller, required this.hint, required this.accent,
    this.onChanged, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.2), width: 0.8)),
        child: TextField(
          controller: controller, maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3), fontSize: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13)),
          onChanged: onChanged))));
}

// ─────────────────────────────────────────────────────────────
// _CategoryGrid
// ─────────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  final List<String> categories; final String selected;
  final ValueChanged<String> onSelect; final VoidCallback onAddCustom;
  const _CategoryGrid({required this.categories, required this.selected,
      required this.onSelect, required this.onAddCustom});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      ...categories.map((cat) {
        final isSel = cat == selected;
        final color = _colorFor(cat);
        return GestureDetector(
          onTap: () => onSelect(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSel
                  ? color.withOpacity(0.18)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSel
                    ? color.withOpacity(0.6)
                    : Colors.white.withOpacity(0.1),
                width: isSel ? 1.3 : 0.8),
              boxShadow: isSel ? [BoxShadow(
                  color: color.withOpacity(0.25), blurRadius: 8)] : null),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle,
                    boxShadow: isSel ? [BoxShadow(
                        color: color.withOpacity(0.6), blurRadius: 4)]
                        : null)),
              const SizedBox(width: 7),
              Text(cat, style: TextStyle(
                  color: isSel ? color : Colors.white.withOpacity(0.55),
                  fontSize: 12,
                  fontWeight: isSel
                      ? FontWeight.w700 : FontWeight.w500)),
            ])));
      }),
      // Chip aggiungi personalizzata
      GestureDetector(
        onTap: onAddCustom,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _cyan.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cyan.withOpacity(0.25), width: 0.8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, color: _cyan.withOpacity(0.7), size: 14),
            const SizedBox(width: 5),
            Text('Personalizzata', style: TextStyle(
                color: _cyan.withOpacity(0.7), fontSize: 12,
                fontWeight: FontWeight.w500)),
          ]))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// _CustomCatInput
// ─────────────────────────────────────────────────────────────

class _CustomCatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onConfirm;
  const _CustomCatInput(
      {required this.controller, required this.onConfirm});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        decoration: BoxDecoration(
          color: _cyan.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cyan.withOpacity(0.25), width: 0.8)),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText:  'Nome categoria...',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12)),
              onSubmitted: (_) => onConfirm())),
          GestureDetector(
            onTap: onConfirm,
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_cyan, Color(0xFF00B8D4)]),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [BoxShadow(
                    color: _cyan.withOpacity(0.3), blurRadius: 8)]),
              child: const Text('Aggiungi',
                  style: TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w700)))),
        ]))));
}

// ─────────────────────────────────────────────────────────────
// _ScheduleSelector
// ─────────────────────────────────────────────────────────────

class _ScheduleSelector extends StatelessWidget {
  final _ScheduleType selected;
  final ValueChanged<_ScheduleType> onSelect;
  const _ScheduleSelector(
      {required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _orange.withOpacity(0.15), width: 0.8)),
          child: Column(children: _ScheduleType.values.asMap().entries.map((e) {
            final i    = e.key;
            final type = e.value;
            final isSel = type == selected;
            final last  = i == _ScheduleType.values.length - 1;
            return Column(children: [
              GestureDetector(
                onTap: () => onSelect(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: isSel
                        ? _orange.withOpacity(0.09)
                        : Colors.transparent),
                  child: Row(children: [
                    Container(width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: isSel
                            ? _orange.withOpacity(0.15)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(9)),
                      child: Icon(type.icon, size: 17,
                          color: isSel
                              ? _orange
                              : Colors.white.withOpacity(0.35))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(type.label, style: TextStyle(
                        color: isSel
                            ? Colors.white
                            : Colors.white.withOpacity(0.55),
                        fontSize: 13,
                        fontWeight: isSel
                            ? FontWeight.w700 : FontWeight.w500))),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: isSel ? _orange : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel
                              ? _orange
                              : Colors.white.withOpacity(0.2),
                          width: 1.5)),
                      child: isSel
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 11)
                          : null),
                  ]))),
              if (!last)
                Divider(height: 0, thickness: 0.5,
                    indent: 14, endIndent: 14,
                    color: Colors.white.withOpacity(0.05)),
            ]);
          }).toList()),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _InfoBox
// ─────────────────────────────────────────────────────────────

class _InfoBox extends StatelessWidget {
  final IconData icon; final String text;
  const _InfoBox({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _indigo.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _indigo.withOpacity(0.18), width: 0.8)),
        child: Row(children: [
          Icon(icon, color: _indigo.withOpacity(0.7), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12, height: 1.5))),
        ]))));
}

// ─────────────────────────────────────────────────────────────
// _DateRow
// ─────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  final IconData icon; final String label, value;
  final Color color; final bool hasValue;
  final VoidCallback onTap; final VoidCallback? onClear;
  const _DateRow({
    required this.icon, required this.label, required this.value,
    required this.color, required this.hasValue,
    required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: color.withOpacity(0.2), width: 0.8)),
          child: Row(children: [
            Icon(icon, color: color.withOpacity(0.7), size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(label, style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10, fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(
                  color: hasValue
                      ? Colors.white : Colors.white.withOpacity(0.3),
                  fontSize: 13, fontWeight: FontWeight.w600)),
            ])),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    color: Colors.white.withOpacity(0.3), size: 16))
            else
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.25), size: 18),
          ])))));
}

// ─────────────────────────────────────────────────────────────
// _SaveBtn
// ─────────────────────────────────────────────────────────────

class _SaveBtn extends StatelessWidget {
  final bool isEditing, saving, canSave;
  final VoidCallback onSave;
  const _SaveBtn({required this.isEditing, required this.saving,
      required this.canSave, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final active = canSave && !saving;
    return GestureDetector(
      onTap: active ? onSave : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(colors: [_teal, _tealDk])
              : null,
          color: active ? null : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? _teal.withOpacity(0.4)
                : Colors.white.withOpacity(0.1),
            width: 1),
          boxShadow: active ? [BoxShadow(
              color: _teal.withOpacity(0.4), blurRadius: 16,
              offset: const Offset(0, 4))] : null),
        child: saving
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      color: Colors.white.withOpacity(0.7))),
                const SizedBox(width: 10),
                const Text('Salvataggio...',
                    style: TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ])
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(isEditing
                    ? Icons.update_rounded : Icons.add_circle_rounded,
                  color: active ? Colors.white : Colors.white.withOpacity(0.25),
                  size: 18),
                const SizedBox(width: 8),
                Text(isEditing
                    ? 'Aggiorna obiettivo' : 'Crea obiettivo',
                  style: TextStyle(
                      color: active
                          ? Colors.white : Colors.white.withOpacity(0.25),
                      fontSize: 15, fontWeight: FontWeight.w700)),
              ])));
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassDatePicker — calendario Glass a 3 livelli
// ─────────────────────────────────────────────────────────────

class _GlassDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? firstDate;
  final ValueChanged<DateTime> onConfirm;
  final VoidCallback onCancel;
  const _GlassDatePicker({
    required this.initialDate, required this.onConfirm,
    required this.onCancel, this.firstDate});
  @override
  State<_GlassDatePicker> createState() => _GlassDatePickerState();
}

enum _PkView { days, months, years }

class _GlassDatePickerState extends State<_GlassDatePicker> {
  late DateTime _focus, _selected;
  _PkView _view = _PkView.days;

  static const _dayLabels = ['L','M','M','G','V','S','D'];
  static const _monthShort = [
    'Gen','Feb','Mar','Apr','Mag','Giu',
    'Lug','Ago','Set','Ott','Nov','Dic'];
  static const _monthFull = [
    'Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
    'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];

  @override
  void initState() {
    super.initState();
    _focus = _selected = widget.initialDate;
  }

  String get _header {
    switch (_view) {
      case _PkView.days:
        return '${_monthFull[_focus.month - 1]} ${_focus.year}';
      case _PkView.months: return '${_focus.year}';
      case _PkView.years:
        final d = (_focus.year ~/ 10) * 10;
        return '$d – ${d + 9}';
    }
  }

  void _prev() => setState(() {
    switch (_view) {
      case _PkView.days:
        _focus = DateTime(_focus.year, _focus.month - 1); break;
      case _PkView.months:
        _focus = DateTime(_focus.year - 1, _focus.month); break;
      case _PkView.years:
        _focus = DateTime(_focus.year - 10, _focus.month); break;
    }
  });

  void _next() => setState(() {
    switch (_view) {
      case _PkView.days:
        _focus = DateTime(_focus.year, _focus.month + 1); break;
      case _PkView.months:
        _focus = DateTime(_focus.year + 1, _focus.month); break;
      case _PkView.years:
        _focus = DateTime(_focus.year + 10, _focus.month); break;
    }
  });

  bool _disabled(DateTime d) {
    if (widget.firstDate == null) return false;
    final fd = DateTime(widget.firstDate!.year,
        widget.firstDate!.month, widget.firstDate!.day);
    return DateTime(d.year, d.month, d.day).isBefore(fd);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 24, vertical: 80),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0D1117), Color(0xFF060B14)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: _teal.withOpacity(0.25), width: 1)),
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Nav
              Row(children: [
                _PkNavBtn(icon: Icons.chevron_left_rounded, onTap: _prev),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _view = _view == _PkView.days
                          ? _PkView.months
                          : _view == _PkView.months
                              ? _PkView.years
                              : _PkView.days;
                    }),
                    child: Text(_header,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.w800)))),
                _PkNavBtn(icon: Icons.chevron_right_rounded, onTap: _next),
              ]),
              const SizedBox(height: 12),
              Container(height: 0.6, decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  _teal.withOpacity(0.3),
                  Colors.transparent]))),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey('${_view}_${_focus.year}_${_focus.month}'),
                  child: _buildGrid())),
              const SizedBox(height: 16),
              // Azioni
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onCancel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.12))),
                      child: const Text('Annulla',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white,
                              fontSize: 14, fontWeight: FontWeight.w600))))),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onConfirm(_selected),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_teal, _tealDk]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: _teal.withOpacity(0.4), blurRadius: 10)]),
                      child: const Text('Conferma',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white,
                              fontSize: 14, fontWeight: FontWeight.w700))))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    switch (_view) {
      case _PkView.days:   return _days();
      case _PkView.months: return _months();
      case _PkView.years:  return _years();
    }
  }

  Widget _days() {
    final first = DateTime(_focus.year, _focus.month, 1);
    final count = DateTime(_focus.year, _focus.month + 1, 0).day;
    final off   = (first.weekday - 1) % 7;
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selN  = DateTime(_selected.year, _selected.month, _selected.day);

    return Column(children: [
      Row(children: _dayLabels.map((n) => Expanded(
        child: Center(child: Text(n, style: TextStyle(
            color: _teal.withOpacity(0.6), fontSize: 11,
            fontWeight: FontWeight.w700))))).toList()),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, childAspectRatio: 1,
            mainAxisSpacing: 4),
        itemCount: off + count,
        itemBuilder: (_, idx) {
          if (idx < off) return const SizedBox.shrink();
          final day  = idx - off + 1;
          final date = DateTime(_focus.year, _focus.month, day);
          final norm = DateTime(date.year, date.month, date.day);
          final isSel = norm == selN;
          final isTd  = norm == today;
          final isDis = _disabled(date);
          return GestureDetector(
            onTap: isDis ? null : () => setState(() => _selected = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSel ? _teal
                    : isTd ? _cyan.withOpacity(0.12)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: isTd && !isSel
                    ? Border.all(color: _cyan.withOpacity(0.45), width: 1)
                    : null,
                boxShadow: isSel ? [BoxShadow(
                    color: _teal.withOpacity(0.45), blurRadius: 8)] : null),
              child: Center(child: Text('$day', style: TextStyle(
                  color: isDis ? Colors.white.withOpacity(0.2)
                      : isSel ? Colors.white
                      : Colors.white.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: isSel || isTd
                      ? FontWeight.w800 : FontWeight.w500)))));
        }),
    ]);
  }

  Widget _months() {
    final now = DateTime.now();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.8,
          mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: 12,
      itemBuilder: (_, i) {
        final isCur = _focus.year == now.year && i + 1 == now.month;
        final isSel = i + 1 == _selected.month &&
            _focus.year == _selected.year;
        return GestureDetector(
          onTap: () => setState(() {
            _focus = DateTime(_focus.year, i + 1);
            _view  = _PkView.days;
          }),
          child: _PkCell(label: _monthShort[i],
              isSelected: isSel, isCurrent: isCur));
      });
  }

  Widget _years() {
    final dec = (_focus.year ~/ 10) * 10;
    final now = DateTime.now();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.8,
          mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: 12,
      itemBuilder: (_, i) {
        final yr   = dec - 1 + i;
        final isCur = yr == now.year;
        final isSel = yr == _selected.year;
        final isOut = i == 0 || i == 11;
        return GestureDetector(
          onTap: () => setState(() {
            _focus = DateTime(yr, _focus.month);
            _view  = _PkView.months;
          }),
          child: _PkCell(label: '$yr', isSelected: isSel,
              isCurrent: isCur, isOutOfRange: isOut));
      });
  }
}

class _PkNavBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _PkNavBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 36, height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.8)),
      child: Icon(icon, color: Colors.white, size: 20)));
}

class _PkCell extends StatelessWidget {
  final String label; final bool isSelected, isCurrent, isOutOfRange;
  const _PkCell({required this.label, this.isSelected = false,
      this.isCurrent = false, this.isOutOfRange = false});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 130),
    decoration: BoxDecoration(
      color: isSelected ? _teal.withOpacity(0.2)
          : isCurrent   ? _teal.withOpacity(0.07)
          : Colors.white.withOpacity(isOutOfRange ? 0.02 : 0.04),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isSelected ? _teal.withOpacity(0.6)
            : isCurrent   ? _teal.withOpacity(0.3)
            : Colors.white.withOpacity(isOutOfRange ? 0.05 : 0.1),
        width: isSelected ? 1.3 : 1),
      boxShadow: isSelected
          ? [BoxShadow(color: _teal.withOpacity(0.2), blurRadius: 8)]
          : null),
    child: Center(child: Text(label,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: isOutOfRange ? Colors.white.withOpacity(0.25)
                : isSelected ? _teal
                : Colors.white.withOpacity(0.75),
            fontSize: 12,
            fontWeight: isSelected || isCurrent
                ? FontWeight.w700 : FontWeight.w500))));
}