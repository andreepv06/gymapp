import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/persistence/categories_repository.dart';
import '../../core/theme/markfit_colors.dart';
import '../../models/goal_models.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/cosmic_background.dart';

// Accent tokens
const _cyan   = MarkFitColors.cyan;
const _teal   = MarkFitColors.teal;
const _tealDk = MarkFitColors.tealDk;
const _indigo = MarkFitColors.indigo;
const _orange = MarkFitColors.orange;
const _red    = MarkFitColors.red;
const _green  = MarkFitColors.green;
const _blue   = MarkFitColors.blue;

const _catColors = <String, Color>{
  'Studio': Color(0xFF6366F1), 'Sport': Color(0xFF00D4AA),
  'Salute': Color(0xFF22C55E), 'Lavoro': Color(0xFF3B82F6),
  'Alimentazione': Color(0xFFFF8C00), 'Benessere': Color(0xFFEC4899),
  'Produttività': Color(0xFF8B5CF6), 'Hobby': Color(0xFFF59E0B),
  'Tempo libero': Color(0xFF06B6D4), 'Finanze': Color(0xFF10B981),
  'Lettura': Color(0xFF6B7280), 'Meditazione': Color(0xFF8A2BE2),
  'Personale': Color(0xFFFF6B6B), 'Altro': Color(0xFF9CA3AF),
};
Color _colorFor(String cat) =>
    _catColors[cat] ?? const Color(0xFF9CA3AF);

enum _ScheduleType {
  daily, specificDays, weekdays, weekend, dateRange, customInterval
}

extension _ScheduleTypeX on _ScheduleType {
  String get id {
    switch (this) {
      case _ScheduleType.daily:          return 'daily';
      case _ScheduleType.specificDays:   return 'specificDays';
      case _ScheduleType.weekdays:       return 'weekdays';
      case _ScheduleType.weekend:        return 'weekend';
      case _ScheduleType.dateRange:      return 'dateRange';
      case _ScheduleType.customInterval: return 'customInterval';
    }
  }

  String get label {
    switch (this) {
      case _ScheduleType.daily:          return 'Ogni giorno';
      case _ScheduleType.specificDays:   return 'Giorni specifici';
      case _ScheduleType.weekdays:       return 'Giorni feriali';
      case _ScheduleType.weekend:        return 'Weekend';
      case _ScheduleType.dateRange:      return 'Intervallo date';
      case _ScheduleType.customInterval: return 'Ogni N giorni';
    }
  }

  IconData get icon {
    switch (this) {
      case _ScheduleType.daily:          return Icons.all_inclusive_rounded;
      case _ScheduleType.specificDays:   return Icons.view_week_rounded;
      case _ScheduleType.weekdays:       return Icons.business_center_rounded;
      case _ScheduleType.weekend:        return Icons.weekend_rounded;
      case _ScheduleType.dateRange:      return Icons.date_range_rounded;
      case _ScheduleType.customInterval: return Icons.repeat_rounded;
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
  final _titleCtrl     = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _intervalCtrl  = TextEditingController();
  final _customCatCtrl = TextEditingController();

  String        _selectedCategory   = '';
  _ScheduleType _scheduleType       = _ScheduleType.daily;
  List<int>     _selectedDays       = [];
  DateTime?     _startDate;
  DateTime?     _endDate;
  String?       _deadlineDate;
  bool          _saving             = false;
  bool          _showCustomCatField = false;
  List<String>  _allCategories      = [];

  static const _dayNames = ['', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

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
    if (g == null) { _startDate = DateTime.now(); return; }
    _titleCtrl.text    = g.title;
    _descCtrl.text     = g.description ?? '';
    _selectedCategory  = g.category;
    _scheduleType      = _ScheduleTypeX.fromId(g.scheduleType);
    _selectedDays      = List<int>.from(g.scheduleDaysOfWeek ?? []);
    _startDate         = g.scheduleStartDate != null
        ? DateTime.tryParse(g.scheduleStartDate!) : DateTime.now();
    _endDate           = g.scheduleEndDate != null
        ? DateTime.tryParse(g.scheduleEndDate!) : null;
    _intervalCtrl.text = g.scheduleCustomInterval != null
        ? '${g.scheduleCustomInterval}' : '';
    _deadlineDate      = g.deadlineDate;
    _startDate         ??= DateTime.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose();
    _intervalCtrl.dispose(); _customCatCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_titleCtrl.text.trim().isEmpty) return 'Il titolo è obbligatorio.';
    if (_selectedCategory.isEmpty) return 'Seleziona una categoria.';
    if (_scheduleType == _ScheduleType.specificDays && _selectedDays.isEmpty)
      return 'Seleziona almeno un giorno.';
    if (_scheduleType == _ScheduleType.dateRange) {
      if (_startDate == null || _endDate == null)
        return 'Seleziona le date di inizio e fine.';
      if (_endDate!.isBefore(_startDate!))
        return 'La data di fine deve essere successiva a quella di inizio.';
    }
    if (_scheduleType == _ScheduleType.customInterval) {
      final n = int.tryParse(_intervalCtrl.text.trim());
      if (n == null || n < 1)
        return 'Inserisci un intervallo valido (≥ 1 giorno).';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final err = _validate();
    if (err != null) { _showError(err); return; }
    setState(() => _saving = true);
    final gp       = context.read<GoalProvider>();
    final title    = _titleCtrl.text.trim();
    final desc     = _descCtrl.text.trim();
    final cat      = _selectedCategory;
    final schType  = _scheduleType.id;
    final startStr = _startDate != null ? _fmtDate(_startDate!) : null;
    final endStr   = _endDate   != null ? _fmtDate(_endDate!)   : null;
    final interval = int.tryParse(_intervalCtrl.text.trim());
    final needsDays     = _scheduleType == _ScheduleType.specificDays;
    final needsRange    = _scheduleType == _ScheduleType.dateRange;
    final needsStart    = needsRange || _scheduleType == _ScheduleType.customInterval;
    final needsInterval = _scheduleType == _ScheduleType.customInterval;
    try {
      if (widget.isEditing) {
        final g = widget.editGoal!;
        g.title                  = title;
        g.description            = desc.isEmpty ? null : desc;
        g.category               = cat;
        g.scheduleType           = schType;
        g.scheduleDaysOfWeek     = needsDays ? _selectedDays : null;
        g.scheduleStartDate      = needsStart ? startStr : null;
        g.scheduleEndDate        = needsRange ? endStr : null;
        g.scheduleCustomInterval = needsInterval ? interval : null;
        g.deadlineDate           = _deadlineDate;
        await gp.updateGoal(g.key, g);
      } else {
        await gp.addGoal(
          title:                  title,
          description:            desc.isEmpty ? null : desc,
          category:               cat,
          scheduleType:           schType,
          scheduleDaysOfWeek:     needsDays ? _selectedDays : null,
          scheduleStartDate:      needsStart ? startStr : null,
          scheduleEndDate:        needsRange ? endStr : null,
          scheduleCustomInterval: needsInterval ? interval : null,
          deadlineDate:           _deadlineDate);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('Errore: $e');
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3)));
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime? d) {
    if (d == null) return 'Seleziona data';
    const m = ['','Gen','Feb','Mar','Apr','Mag','Giu',
        'Lug','Ago','Set','Ott','Nov','Dic'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

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

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? firstDate}) async {
    DateTime? picked;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => _GlassDatePicker(
        initialDate: initial, firstDate: firstDate,
        onConfirm:   (d) { picked = d; Navigator.pop(ctx); },
        onCancel:    () => Navigator.pop(ctx)));
    return picked;
  }

  @override
  Widget build(BuildContext context) {
    final kbHeight = MediaQuery.of(context).viewInsets.bottom;
    final canSave  = _titleCtrl.text.trim().isNotEmpty &&
        _selectedCategory.isNotEmpty;

    return Scaffold(
      backgroundColor:          Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: CosmicBackground(
        child: SafeArea(
          child: Column(children: [
            _AppBar(
              isEditing: widget.isEditing, saving: _saving, canSave: canSave,
              onBack: () => Navigator.pop(context),
              onSave: _saving ? null : _save),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 40 + kbHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    _Label(label: 'Titolo', icon: Icons.edit_rounded,
                        color: _teal, required: true),
                    const SizedBox(height: 8),
                    _GlassTextField(controller: _titleCtrl,
                        hint: 'Es. Correre 30 min al giorno...',
                        accent: _teal,
                        onChanged: (_) => setState(() {})),
                    const SizedBox(height: 16),
                    _Label(label: 'Descrizione', icon: Icons.notes_rounded,
                        color: _cyan),
                    const SizedBox(height: 8),
                    _GlassTextField(controller: _descCtrl,
                        hint: 'Note opzionali...', accent: _cyan, maxLines: 3),
                    const SizedBox(height: 16),
                    _Label(label: 'Categoria', icon: Icons.label_rounded,
                        color: _indigo, required: true),
                    const SizedBox(height: 10),
                    _CategoryGrid(
                      categories:  _allCategories,
                      selected:    _selectedCategory,
                      onSelect:    (c) => setState(() => _selectedCategory = c),
                      onAddCustom: () => setState(() {
                        _showCustomCatField = !_showCustomCatField;
                        if (!_showCustomCatField) _customCatCtrl.clear();
                      })),
                    if (_showCustomCatField) ...[
                      const SizedBox(height: 10),
                      _CustomCatInput(controller: _customCatCtrl,
                          onConfirm: _addCustomCategory),
                    ],
                    const SizedBox(height: 16),
                    _Label(label: 'Pianificazione', icon: Icons.schedule_rounded,
                        color: _orange),
                    const SizedBox(height: 10),
                    _ScheduleSelector(
                        selected: _scheduleType,
                        onSelect: (t) => setState(() => _scheduleType = t)),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim, child: SizeTransition(
                              sizeFactor: anim, child: child)),
                      child: KeyedSubtree(
                          key: ValueKey(_scheduleType),
                          child: _buildScheduleDetails())),
                    const SizedBox(height: 16),
                    _Label(label: 'Scadenza (opzionale)',
                        icon: Icons.flag_rounded, color: _red),
                    const SizedBox(height: 8),
                    _DateRow(
                      icon:     Icons.event_rounded,
                      label:    'Data scadenza',
                      value:    _deadlineDate != null
                          ? _displayDate(DateTime.tryParse(_deadlineDate!))
                          : 'Nessuna scadenza',
                      color:    _red,
                      hasValue: _deadlineDate != null,
                      onTap: () async {
                        final d = await _pickDate(_deadlineDate != null
                            ? DateTime.parse(_deadlineDate!)
                            : DateTime.now());
                        if (d != null)
                          setState(() => _deadlineDate = _fmtDate(d));
                      },
                      onClear: _deadlineDate != null
                          ? () => setState(() => _deadlineDate = null) : null),
                    const SizedBox(height: 28),
                    _SaveBtn(
                      isEditing: widget.isEditing, saving: _saving,
                      canSave: canSave, onSave: _save),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildScheduleDetails() {
    final c = context.mfc;
    switch (_scheduleType) {
      case _ScheduleType.daily:
      case _ScheduleType.weekdays:
      case _ScheduleType.weekend:
        return _InfoBox(
          icon: _scheduleType.icon,
          text: _scheduleType == _ScheduleType.daily
              ? 'L\'obiettivo sarà presente ogni giorno.'
              : _scheduleType == _ScheduleType.weekdays
                  ? 'Visibile dal lunedì al venerdì.'
                  : 'Visibile sabato e domenica.');

      case _ScheduleType.specificDays:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('Seleziona i giorni:', style: TextStyle(
              color: c.textTertiary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8,
            children: List.generate(7, (i) {
              final day = i + 1;
              final sel = _selectedDays.contains(day);
              return GestureDetector(
                onTap: () => setState(() {
                  if (sel) _selectedDays.remove(day);
                  else     _selectedDays.add(day);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _indigo.withOpacity(0.2) : c.glassCardInset,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: sel ? _indigo.withOpacity(0.6) : c.glassBorder,
                      width: sel ? 1.2 : 0.8)),
                  child: Text(_dayNames[day], style: TextStyle(
                      color: sel ? _indigo : c.textTertiary,
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500))));
            })),
          ]);

      case _ScheduleType.dateRange:
        return Column(children: [
          _DateRow(
            icon: Icons.play_arrow_rounded, label: 'Data inizio',
            value: _displayDate(_startDate), color: _green,
            hasValue: _startDate != null,
            onTap: () async {
              final d = await _pickDate(_startDate ?? DateTime.now());
              if (d != null) setState(() => _startDate = d);
            }),
          const SizedBox(height: 8),
          _DateRow(
            icon: Icons.stop_rounded, label: 'Data fine',
            value: _displayDate(_endDate), color: _red,
            hasValue: _endDate != null,
            onTap: () async {
              final d = await _pickDate(
                  _endDate ?? (_startDate ?? DateTime.now()),
                  firstDate: _startDate);
              if (d != null) setState(() => _endDate = d);
            }),
        ]);

      case _ScheduleType.customInterval:
        final c = context.mfc;
        final isDark = context.isDarkMode;
        return Column(children: [
          _DateRow(
            icon: Icons.play_arrow_rounded, label: 'Data inizio',
            value: _displayDate(_startDate), color: _green,
            hasValue: _startDate != null,
            onTap: () async {
              final d = await _pickDate(_startDate ?? DateTime.now());
              if (d != null) setState(() => _startDate = d);
            }),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: c.inputBg,
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
                      controller:         _intervalCtrl,
                      keyboardType:       TextInputType.number,
                      keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
                      style: TextStyle(color: c.inputText, fontSize: 14),
                      decoration: InputDecoration(
                        hintText:  'Ogni quanti giorni? (es. 2)',
                        hintStyle: TextStyle(color: c.inputHint, fontSize: 14),
                        border:    InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0, vertical: 13)))),
                ]))),
          ),
        ]);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// _AppBar — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final bool isEditing, saving, canSave;
  final VoidCallback onBack;
  final VoidCallback? onSave;
  const _AppBar({required this.isEditing, required this.saving,
      required this.canSave, required this.onBack, this.onSave});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: c.glassBlurStrong, sigmaY: c.glassBlurStrong),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            border: Border(bottom: BorderSide(
                color: _teal.withOpacity(0.15), width: 0.6)),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 6,
                    offset: const Offset(0, 2))]
                : null),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); onBack(); },
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.glassCardInset,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: c.glassBorder, width: 0.7)),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15, color: c.iconPrimary))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(isEditing ? 'Modifica obiettivo' : 'Nuovo obiettivo',
                  style: TextStyle(color: c.textPrimary,
                      fontSize: 17, fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
              Text(isEditing ? 'Aggiorna i dettagli' : 'Definisci un traguardo',
                  style: TextStyle(color: c.textTertiary, fontSize: 11)),
            ])),
            if (saving)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: c.glassCardInset,
                  borderRadius: BorderRadius.circular(11)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: _teal.withOpacity(0.7))),
                  const SizedBox(width: 7),
                  Text('Salvo...', style: TextStyle(
                      color: c.textPrimary, fontSize: 12,
                      fontWeight: FontWeight.w600)),
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
                    gradient: canSave ? const LinearGradient(
                        colors: [_teal, _tealDk]) : null,
                    color: canSave ? null : c.glassCardInset,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: canSave ? [BoxShadow(
                        color: _teal.withOpacity(0.4), blurRadius: 10,
                        offset: const Offset(0, 3))] : null),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_rounded,
                        color: canSave ? Colors.white : c.textTertiary,
                        size: 15),
                    const SizedBox(width: 5),
                    Text(isEditing ? 'Aggiorna' : 'Salva',
                        style: TextStyle(
                            color: canSave ? Colors.white : c.textTertiary,
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ]))),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _Label — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final bool required;
  const _Label({required this.label, required this.icon,
      required this.color, this.required = false});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Row(children: [
      Container(width: 26, height: 26,
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 13, color: color)),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(
          color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
      if (required) ...[
        const SizedBox(width: 4),
        Text('*', style: TextStyle(
            color: _red.withOpacity(0.8), fontSize: 13,
            fontWeight: FontWeight.w700)),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassTextField — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint; final Color accent;
  final void Function(String)? onChanged;
  final int maxLines;
  const _GlassTextField({required this.controller, required this.hint,
      required this.accent, this.onChanged, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: c.inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: c.inputBorder, width: isDark ? 0.8 : 1.0)),
          child: TextField(
            controller:         controller,
            maxLines:           maxLines,
            keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: c.inputText, fontSize: 14),
            decoration: InputDecoration(
              hintText:  hint,
              hintStyle: TextStyle(color: c.inputHint, fontSize: 14),
              border:    InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13)),
            onChanged: onChanged))));
  }
}

// ─────────────────────────────────────────────────────────────
// _CategoryGrid — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  final List<String>     categories;
  final String           selected;
  final ValueChanged<String> onSelect;
  final VoidCallback     onAddCustom;
  const _CategoryGrid({required this.categories, required this.selected,
      required this.onSelect, required this.onAddCustom});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      ...categories.map((cat) {
        final isSel = cat == selected;
        final color = _colorFor(cat);
        return GestureDetector(
          onTap: () => onSelect(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSel
                  ? color.withOpacity(0.18) : c.glassCardInset,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSel ? color.withOpacity(0.6) : c.glassBorder,
                width: isSel ? 1.3 : 0.8),
              boxShadow: isSel && c.showElevation
                  ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8)]
                  : null),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle,
                  boxShadow: isSel ? [BoxShadow(
                      color: color.withOpacity(0.6), blurRadius: 4)] : null)),
              const SizedBox(width: 7),
              Text(cat, style: TextStyle(
                  color: isSel ? color : c.textTertiary,
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
            ])));
      }),
      // "+ Personalizzata" button
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
// _CustomCatInput — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _CustomCatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onConfirm;
  const _CustomCatInput({required this.controller, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: c.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cyan.withOpacity(0.25), width: 0.8)),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller:         controller,
                keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: c.inputText, fontSize: 13),
                decoration: InputDecoration(
                  hintText:  'Nome categoria...',
                  hintStyle: TextStyle(color: c.inputHint, fontSize: 13),
                  border:    InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12)),
                onSubmitted: (_) => onConfirm())),
            GestureDetector(
              onTap: onConfirm,
              child: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_cyan, Color(0xFF00B8D4)]),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [BoxShadow(
                      color: _cyan.withOpacity(0.3), blurRadius: 8)]),
                child: const Text('Aggiungi', style: TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w700)))),
          ]))));
  }
}

// ─────────────────────────────────────────────────────────────
// _ScheduleSelector — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _ScheduleSelector extends StatelessWidget {
  final _ScheduleType selected;
  final ValueChanged<_ScheduleType> onSelect;
  const _ScheduleSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _orange.withOpacity(0.15), width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 8,
                    offset: const Offset(0, 2))]
                : null),
          child: Column(
            children: _ScheduleType.values.asMap().entries.map((e) {
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
                      color: isSel ? _orange.withOpacity(0.09) : Colors.transparent),
                    child: Row(children: [
                      Container(width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: isSel
                              ? _orange.withOpacity(0.15) : c.glassCardInset,
                          borderRadius: BorderRadius.circular(9)),
                        child: Icon(type.icon, size: 17,
                            color: isSel ? _orange : c.iconSecondary)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(type.label, style: TextStyle(
                          color: isSel ? c.textPrimary : c.textTertiary,
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
                            color: isSel ? _orange : c.glassBorder,
                            width: 1.5)),
                        child: isSel
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 11)
                            : null),
                    ]))),
                if (!last)
                  Divider(height: 0, thickness: 0.5,
                      indent: 14, endIndent: 14, color: c.divider),
              ]);
            }).toList()),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _InfoBox — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBox({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: c.glassBlur,
          sigmaY: c.glassBlur,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _indigo.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _indigo.withOpacity(0.18),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: _indigo.withOpacity(0.7),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 12,
                    height: 1.5,
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
// _DateRow — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool hasValue;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.hasValue,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: c.glassBlur,
            sigmaY: c.glassBlur,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: c.inputBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 0.8,
              ),
              boxShadow: c.showElevation
                  ? [
                      BoxShadow(
                        color: c.elevationColor,
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: color.withOpacity(0.7),
                  size: 18,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: c.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        value,
                        style: TextStyle(
                          color: hasValue
                              ? c.textPrimary
                              : c.inputHint,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                if (onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(
                      Icons.close_rounded,
                      color: c.iconSecondary,
                      size: 16,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: c.iconSecondary,
                    size: 18,
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
// _SaveBtn — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _SaveBtn extends StatelessWidget {
  final bool isEditing, saving, canSave;
  final VoidCallback onSave;
  const _SaveBtn({required this.isEditing, required this.saving,
      required this.canSave, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final active = canSave && !saving;
    return GestureDetector(
      onTap: active ? onSave : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: active ? const LinearGradient(
              colors: [_teal, _tealDk]) : null,
          color: active ? null : c.glassCardInset,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? _teal.withOpacity(0.4) : c.glassBorder,
            width: 1),
          boxShadow: active ? [BoxShadow(color: _teal.withOpacity(0.4),
              blurRadius: 16, offset: const Offset(0, 4))] : null),
        child: saving
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      color: Colors.white.withOpacity(0.7))),
                const SizedBox(width: 10),
                const Text('Salvataggio...', style: TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w600)),
              ])
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(isEditing ? Icons.update_rounded : Icons.add_circle_rounded,
                    color: active ? Colors.white : c.textTertiary, size: 18),
                const SizedBox(width: 8),
                Text(isEditing ? 'Aggiorna obiettivo' : 'Crea obiettivo',
                    style: TextStyle(
                        color: active ? Colors.white : c.textTertiary,
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ])));
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassDatePicker — sempre scuro (modal overlay)
// ─────────────────────────────────────────────────────────────

class _GlassDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? firstDate;
  final ValueChanged<DateTime> onConfirm;
  final VoidCallback onCancel;
  const _GlassDatePicker({required this.initialDate, required this.onConfirm,
      required this.onCancel, this.firstDate});
  @override
  State<_GlassDatePicker> createState() => _GlassDatePickerState();
}

enum _PkView { days, months, years }

class _GlassDatePickerState extends State<_GlassDatePicker> {
  late DateTime _focus, _selected;
  _PkView _view = _PkView.days;
  static const _dl = ['L','M','M','G','V','S','D'];
  static const _ms = ['Gen','Feb','Mar','Apr','Mag','Giu',
      'Lug','Ago','Set','Ott','Nov','Dic'];
  static const _mf = ['Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
      'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];

  @override
  void initState() { super.initState(); _focus = _selected = widget.initialDate; }

  String get _header {
    switch (_view) {
      case _PkView.days:   return '${_mf[_focus.month - 1]} ${_focus.year}';
      case _PkView.months: return '${_focus.year}';
      case _PkView.years:
        final d = (_focus.year ~/ 10) * 10; return '$d – ${d + 9}';
    }
  }

  void _prev() => setState(() {
    switch (_view) {
      case _PkView.days:   _focus = DateTime(_focus.year, _focus.month - 1); break;
      case _PkView.months: _focus = DateTime(_focus.year - 1, _focus.month); break;
      case _PkView.years:  _focus = DateTime(_focus.year - 10, _focus.month); break;
    }
  });

  void _next() => setState(() {
    switch (_view) {
      case _PkView.days:   _focus = DateTime(_focus.year, _focus.month + 1); break;
      case _PkView.months: _focus = DateTime(_focus.year + 1, _focus.month); break;
      case _PkView.years:  _focus = DateTime(_focus.year + 10, _focus.month); break;
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            // Always dark: modal overlay
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D1117), Color(0xFF060B14)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _teal.withOpacity(0.25), width: 1)),
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                _NavBtn(icon: Icons.chevron_left_rounded, onTap: _prev),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _view = _view == _PkView.days ? _PkView.months
                          : _view == _PkView.months ? _PkView.years : _PkView.days;
                    }),
                    child: Text(_header, textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.w800)))),
                _NavBtn(icon: Icons.chevron_right_rounded, onTap: _next),
              ]),
              const SizedBox(height: 12),
              Container(height: 0.6, decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent, _teal.withOpacity(0.3),
                    Colors.transparent]))),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                    key: ValueKey('${_view}_${_focus.year}_${_focus.month}'),
                    child: _buildGrid())),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: widget.onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.12))),
                    child: const Text('Annulla', textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white,
                            fontSize: 14, fontWeight: FontWeight.w600))))),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => widget.onConfirm(_selected),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_teal, _tealDk]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                          color: _teal.withOpacity(0.4), blurRadius: 10)]),
                    child: const Text('Conferma', textAlign: TextAlign.center,
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
      Row(children: _dl.map((n) => Expanded(
        child: Center(child: Text(n, style: TextStyle(
            color: _teal.withOpacity(0.6), fontSize: 11,
            fontWeight: FontWeight.w700))))).toList()),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, childAspectRatio: 1, mainAxisSpacing: 4),
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
                    : isTd ? _cyan.withOpacity(0.12) : Colors.transparent,
                shape: BoxShape.circle,
                border: isTd && !isSel
                    ? Border.all(color: _cyan.withOpacity(0.45), width: 1)
                    : null,
                boxShadow: isSel
                    ? [BoxShadow(color: _teal.withOpacity(0.45), blurRadius: 8)]
                    : null),
              child: Center(child: Text('$day', style: TextStyle(
                  color: isDis ? Colors.white.withOpacity(0.2)
                      : isSel ? Colors.white : Colors.white.withOpacity(0.8),
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
        final isSel = i + 1 == _selected.month && _focus.year == _selected.year;
        return GestureDetector(
          onTap: () => setState(() {
            _focus = DateTime(_focus.year, i + 1); _view = _PkView.days;
          }),
          child: _Cell(label: _ms[i], isSelected: isSel, isCurrent: isCur));
      });
  }

  Widget _years() {
    final dec = (_focus.year ~/ 10) * 10; final now = DateTime.now();
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
            _focus = DateTime(yr, _focus.month); _view = _PkView.months;
          }),
          child: _Cell(label: '$yr', isSelected: isSel,
              isCurrent: isCur, isOutOfRange: isOut));
      });
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});
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

class _Cell extends StatelessWidget {
  final String label;
  final bool   isSelected, isCurrent, isOutOfRange;
  const _Cell({required this.label, this.isSelected = false,
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
          ? [BoxShadow(color: _teal.withOpacity(0.2), blurRadius: 8)] : null),
    child: Center(child: Text(label, textAlign: TextAlign.center,
        style: TextStyle(
            color: isOutOfRange ? Colors.white.withOpacity(0.25)
                : isSelected ? _teal : Colors.white.withOpacity(0.75),
            fontSize: 12,
            fontWeight: isSelected || isCurrent
                ? FontWeight.w700 : FontWeight.w500))));
}