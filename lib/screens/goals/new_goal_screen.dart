import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/persistence/categories_repository.dart';
import '../../models/goal_models.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';

// ── Design tokens ─────────────────────────────────────────────
const _cyan   = Color(0xFF00E5FF);
const _teal   = Color(0xFF00D4AA);
const _tealDk = Color(0xFF00A880);
const _indigo = Color(0xFF6366F1);
const _orange = Color(0xFFFF8C00);
const _red    = Color(0xFFFF3B30);
const _green  = Color(0xFF22C55E);
const _blue   = Color(0xFF3B82F6);

// Mappa colori categoria (condivisa con goals_screen)
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

// Tipi di durata
enum _DurationType { singleDay, range, days, indefinite }

extension _DurationTypeExt on _DurationType {
  String get label {
    switch (this) {
      case _DurationType.singleDay:   return 'Singolo giorno';
      case _DurationType.range:       return 'Intervallo date';
      case _DurationType.days:        return 'N. di giorni';
      case _DurationType.indefinite:  return 'Indefinita';
    }
  }

  IconData get icon {
    switch (this) {
      case _DurationType.singleDay:  return Icons.today_rounded;
      case _DurationType.range:      return Icons.date_range_rounded;
      case _DurationType.days:       return Icons.calendar_view_week_rounded;
      case _DurationType.indefinite: return Icons.all_inclusive_rounded;
    }
  }

  String get id {
    switch (this) {
      case _DurationType.singleDay:  return 'single';
      case _DurationType.range:      return 'range';
      case _DurationType.days:       return 'days';
      case _DurationType.indefinite: return 'indefinite';
    }
  }

  static _DurationType fromId(String id) {
    switch (id) {
      case 'single':     return _DurationType.singleDay;
      case 'range':      return _DurationType.range;
      case 'days':       return _DurationType.days;
      case 'indefinite': return _DurationType.indefinite;
      default:           return _DurationType.indefinite;
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
  // Controllers
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _daysCtrl   = TextEditingController();
  final _customCatCtrl = TextEditingController();

  // Form state
  String         _selectedCategory = '';
  _DurationType  _durationType     = _DurationType.indefinite;
  DateTime?      _startDate;
  DateTime?      _endDate;
  bool           _saving           = false;
  bool           _showCustomCatField = false;

  // Categorie caricate
  List<String> _allCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _prefillForEdit();
  }

  Future<void> _loadCategories() async {
    final cats = await CategoriesRepository.loadAll();
    if (mounted) setState(() => _allCategories = cats);
  }

  void _prefillForEdit() {
    final g = widget.editGoal;
    if (g == null) {
      _startDate = DateTime.now();
      return;
    }
    _titleCtrl.text       = g.title;
    _selectedCategory     = g.category;
    // Campi opzionali — acceduti in modo sicuro
    try {
      final dynamic rawDesc = (g as dynamic).description;
      if (rawDesc is String) _descCtrl.text = rawDesc;
    } catch (_) {}
    try {
      final dynamic rawDt = (g as dynamic).durationType;
      if (rawDt is String) {
        _durationType = _DurationTypeExt.fromId(rawDt);
      }
    } catch (_) {}
    try {
      final dynamic rawStart = (g as dynamic).startDate;
      if (rawStart is String && rawStart.isNotEmpty) {
        _startDate = DateTime.tryParse(rawStart);
      }
    } catch (_) {}
    try {
      final dynamic rawEnd = (g as dynamic).endDate;
      if (rawEnd is String && rawEnd.isNotEmpty) {
        _endDate = DateTime.tryParse(rawEnd);
      }
    } catch (_) {}
    try {
      final dynamic rawDays = (g as dynamic).durationDays;
      if (rawDays is int && rawDays > 0) {
        _daysCtrl.text = '$rawDays';
      }
    } catch (_) {}
    _startDate ??= DateTime.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _daysCtrl.dispose();
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
    if (_durationType == _DurationType.range) {
      if (_startDate == null || _endDate == null) {
        return 'Seleziona le date di inizio e fine.';
      }
      if (_endDate!.isBefore(_startDate!)) {
        return 'La data di fine deve essere successiva a quella di inizio.';
      }
    }
    if (_durationType == _DurationType.days) {
      final d = int.tryParse(_daysCtrl.text.trim());
      if (d == null || d < 1) {
        return 'Inserisci un numero di giorni valido (≥ 1).';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _red.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3)));
      return;
    }

    setState(() => _saving = true);

    final gp          = context.read<GoalProvider>();
    final title       = _titleCtrl.text.trim();
    final category    = _selectedCategory;
    final description = _descCtrl.text.trim();
    final durationType = _durationType.id;
    final startDate   = _startDate?.toIso8601String() ??
        DateTime.now().toIso8601String();
    final endDate     = _endDate?.toIso8601String();
    final durationDays =
        int.tryParse(_daysCtrl.text.trim());

    try {
      if (widget.isEditing) {
        await gp.updateGoal(
          widget.editGoal!.key,
          title:        title,
          category:     category,
          description:  description,
          durationType: durationType,
          startDate:    startDate,
          endDate:      endDate,
          durationDays: durationDays,
        );
      } else {
        await gp.addGoal(
          title:        title,
          category:     category,
          description:  description,
          durationType: durationType,
          startDate:    startDate,
          endDate:      endDate,
          durationDays: durationDays,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore: $e',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: _red.withOpacity(0.85),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addCustomCategory() async {
    final name = _customCatCtrl.text.trim();
    if (name.isEmpty) return;
    final err = await CategoriesRepository.addCustom(name);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err, style: const TextStyle(
            color: Colors.white)),
        backgroundColor: _red.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16)));
      return;
    }
    await _loadCategories();
    if (mounted) {
      setState(() {
        _selectedCategory      = name;
        _showCustomCatField    = false;
        _customCatCtrl.clear();
        FocusScope.of(context).unfocus();
      });
    }
  }

  // ── Date picker Glass ─────────────────────────────────────────

  Future<DateTime?> _pickDate(DateTime initial,
      {DateTime? firstDate, DateTime? lastDate}) async {
    DateTime result = initial;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => _GlassDatePickerDialog(
        initialDate: initial,
        firstDate:   firstDate,
        lastDate:    lastDate,
        onConfirm:   (d) { result = d; Navigator.pop(ctx); },
        onCancel:    () => Navigator.pop(ctx),
      ),
    );
    return result;
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        child: SafeArea(
          child: Column(children: [
            // ── App Bar ────────────────────────────────────────
            _NewGoalAppBar(
              isEditing: widget.isEditing,
              onBack:    () => Navigator.pop(context),
              onSave:    _saving ? null : _save),

            // ── Form scrollabile ───────────────────────────────
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Titolo ────────────────────────────────
                      _FormLabel(label: 'Titolo', icon: Icons.edit_rounded,
                          color: _teal, required: true),
                      const SizedBox(height: 8),
                      _GlassInput(
                        controller: _titleCtrl,
                        hintText:   'Es. Leggere 20 min al giorno...',
                        accentColor: _teal,
                        onChanged:  (_) => setState(() {})),
                      const SizedBox(height: 16),

                      // ── Descrizione ───────────────────────────
                      _FormLabel(label: 'Descrizione',
                          icon: Icons.notes_rounded, color: _cyan),
                      const SizedBox(height: 8),
                      _GlassInput(
                        controller:  _descCtrl,
                        hintText:    'Aggiungi una nota (opzionale)...',
                        accentColor: _cyan,
                        maxLines:    3),
                      const SizedBox(height: 16),

                      // ── Categoria ─────────────────────────────
                      _FormLabel(label: 'Categoria',
                          icon: Icons.label_rounded, color: _indigo,
                          required: true),
                      const SizedBox(height: 10),
                      _CategoryGrid(
                        categories:       _allCategories,
                        selected:         _selectedCategory,
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
                        _CustomCategoryInput(
                          controller: _customCatCtrl,
                          onConfirm:  _addCustomCategory),
                      ],
                      const SizedBox(height: 16),

                      // ── Durata ────────────────────────────────
                      _FormLabel(label: 'Durata',
                          icon: Icons.schedule_rounded, color: _orange),
                      const SizedBox(height: 10),
                      _DurationSelector(
                        selected: _durationType,
                        onSelect: (t) =>
                            setState(() => _durationType = t)),
                      const SizedBox(height: 12),

                      // ── Inputs contestuali durata ─────────────
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: KeyedSubtree(
                          key: ValueKey(_durationType),
                          child: _buildDurationInputs()),
                      ),

                      // ── Pulsante Salva ────────────────────────
                      const SizedBox(height: 24),
                      _SaveButton(
                        isEditing: widget.isEditing,
                        isSaving:  _saving,
                        canSave:   _titleCtrl.text.trim().isNotEmpty &&
                            _selectedCategory.isNotEmpty,
                        onSave:    _save),
                      const SizedBox(height: 16),
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

  Widget _buildDurationInputs() {
    switch (_durationType) {
      case _DurationType.singleDay:
        return _SingleDayInput(
          date:     _startDate ?? DateTime.now(),
          onPick: () async {
            final d = await _pickDate(_startDate ?? DateTime.now());
            if (d != null) setState(() => _startDate = d);
          });

      case _DurationType.range:
        return _DateRangeInput(
          startDate: _startDate,
          endDate:   _endDate,
          onPickStart: () async {
            final d = await _pickDate(
                _startDate ?? DateTime.now());
            if (d != null) setState(() => _startDate = d);
          },
          onPickEnd: () async {
            final d = await _pickDate(
                _endDate ?? (_startDate ?? DateTime.now()),
                firstDate: _startDate);
            if (d != null) setState(() => _endDate = d);
          });

      case _DurationType.days:
        return _DaysCountInput(
          controller:  _daysCtrl,
          startDate:   _startDate ?? DateTime.now(),
          onPickStart: () async {
            final d = await _pickDate(_startDate ?? DateTime.now());
            if (d != null) setState(() => _startDate = d);
          });

      case _DurationType.indefinite:
        return _IndefiniteInfo();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// _NewGoalAppBar
// ─────────────────────────────────────────────────────────────

class _NewGoalAppBar extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onBack;
  final VoidCallback? onSave;
  const _NewGoalAppBar({
    required this.isEditing, required this.onBack, this.onSave});

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
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onBack();
              },
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 0.7)),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15, color: Colors.white))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(isEditing
                    ? 'Modifica obiettivo'
                    : 'Nuovo obiettivo',
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
            if (onSave != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onSave?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_teal, Color(0xFF00A880)]),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [BoxShadow(
                        color: _teal.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3))]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_rounded,
                        color: Colors.white, size: 15),
                    const SizedBox(width: 5),
                    Text(isEditing ? 'Aggiorna' : 'Salva',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ])))
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(11)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _teal.withOpacity(0.7))),
                  const SizedBox(width: 7),
                  const Text('Salvo...',
                      style: TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ])),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _FormLabel
// ─────────────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final bool required;
  const _FormLabel({
    required this.label, required this.icon,
    required this.color, this.required = false});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 26, height: 26,
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, size: 13, color: color)),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(
        color: Colors.white, fontSize: 13,
        fontWeight: FontWeight.w700)),
    if (required) ...[
      const SizedBox(width: 4),
      Text('*', style: TextStyle(
          color: _red.withOpacity(0.8), fontSize: 13,
          fontWeight: FontWeight.w700)),
    ],
  ]);
}

// ─────────────────────────────────────────────────────────────
// _GlassInput
// ─────────────────────────────────────────────────────────────

class _GlassInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Color accentColor;
  final void Function(String)? onChanged;
  final int maxLines;

  const _GlassInput({
    required this.controller, required this.hintText,
    required this.accentColor, this.onChanged,
    this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: accentColor.withOpacity(0.2), width: 0.8)),
          child: TextField(
            controller: controller,
            maxLines:   maxLines,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
                color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText:  hintText,
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13)),
            onChanged: onChanged),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _CategoryGrid
// ─────────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onAddCustom;

  const _CategoryGrid({
    required this.categories, required this.selected,
    required this.onSelect, required this.onAddCustom});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
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
                boxShadow: isSel
                    ? [BoxShadow(
                        color: color.withOpacity(0.25),
                        blurRadius: 8)] : null),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: _colorFor(cat), shape: BoxShape.circle,
                      boxShadow: isSel ? [BoxShadow(
                          color: _colorFor(cat).withOpacity(0.6),
                          blurRadius: 4)] : null)),
                const SizedBox(width: 7),
                Text(cat, style: TextStyle(
                    color: isSel ? color : Colors.white.withOpacity(0.55),
                    fontSize: 12,
                    fontWeight: isSel
                        ? FontWeight.w700 : FontWeight.w500)),
              ]),
            ),
          );
        }),
        // Chip aggiungi categoria custom
        GestureDetector(
          onTap: onAddCustom,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _cyan.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _cyan.withOpacity(0.25), width: 0.8),
              boxShadow: null),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded,
                  color: _cyan.withOpacity(0.7), size: 14),
              const SizedBox(width: 5),
              Text('Personalizzata',
                  style: TextStyle(
                      color: _cyan.withOpacity(0.7), fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ])),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _CustomCategoryInput
// ─────────────────────────────────────────────────────────────

class _CustomCategoryInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onConfirm;
  const _CustomCategoryInput({
    required this.controller, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: _cyan.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _cyan.withOpacity(0.25), width: 0.8)),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText:  'Nome categoria personalizzata...',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 13),
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
                    style: TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w700)))),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _DurationSelector
// ─────────────────────────────────────────────────────────────

class _DurationSelector extends StatelessWidget {
  final _DurationType selected;
  final ValueChanged<_DurationType> onSelect;
  const _DurationSelector(
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
          child: Column(children: [
            ..._DurationType.values.asMap().entries.map((e) {
              final i    = e.key;
              final type = e.value;
              final isSel = type == selected;
              final last = i == _DurationType.values.length - 1;
              return Column(children: [
                GestureDetector(
                  onTap: () => onSelect(type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: isSel
                          ? _orange.withOpacity(0.1)
                          : Colors.transparent),
                    child: Row(children: [
                      Container(width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: isSel
                              ? _orange.withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(9)),
                        child: Icon(type.icon, size: 17,
                            color: isSel
                                ? _orange
                                : Colors.white.withOpacity(0.4))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(type.label,
                            style: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.55),
                                fontSize: 13,
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500))),
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
                    ]),
                  ),
                ),
                if (!last)
                  Divider(height: 0, thickness: 0.5,
                      indent: 14, endIndent: 14,
                      color: Colors.white.withOpacity(0.05)),
              ]);
            }),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widget inputs durata contestuali
// ─────────────────────────────────────────────────────────────

class _SingleDayInput extends StatelessWidget {
  final DateTime date; final VoidCallback onPick;
  const _SingleDayInput({required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return _DatePickerRow(
      icon: Icons.today_rounded, label: 'Data obiettivo',
      date: date, color: _orange, onPick: onPick);
  }
}

class _DateRangeInput extends StatelessWidget {
  final DateTime? startDate, endDate;
  final VoidCallback onPickStart, onPickEnd;
  const _DateRangeInput({
    this.startDate, this.endDate,
    required this.onPickStart, required this.onPickEnd});

  @override
  Widget build(BuildContext context) => Column(children: [
    _DatePickerRow(
      icon: Icons.play_arrow_rounded, label: 'Data inizio',
      date: startDate, color: _green, onPick: onPickStart),
    const SizedBox(height: 8),
    _DatePickerRow(
      icon: Icons.stop_rounded, label: 'Data fine',
      date: endDate, color: _red,
      placeholder: 'Seleziona data fine',
      onPick: onPickEnd),
  ]);
}

class _DaysCountInput extends StatelessWidget {
  final TextEditingController controller;
  final DateTime startDate; final VoidCallback onPickStart;
  const _DaysCountInput({
    required this.controller, required this.startDate,
    required this.onPickStart});

  @override
  Widget build(BuildContext context) => Column(children: [
    _DatePickerRow(
      icon: Icons.play_arrow_rounded, label: 'Data inizio',
      date: startDate, color: _green, onPick: onPickStart),
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
            Container(
              width: 46,
              alignment: Alignment.center,
              child: Icon(Icons.calendar_view_week_rounded,
                  color: _blue.withOpacity(0.7), size: 18)),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText:  'Numero di giorni (es. 30)',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 0, vertical: 13)))),
          ]),
        ),
      ),
    ),
  ]);
}

class _IndefiniteInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _indigo.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _indigo.withOpacity(0.2), width: 0.8)),
          child: Row(children: [
            Icon(Icons.all_inclusive_rounded,
                color: _indigo.withOpacity(0.7), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'L\'obiettivo non ha una scadenza. '
                'Verrà mostrato ogni giorno fino a quando non decidi di eliminarlo.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12, height: 1.5))),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _DatePickerRow
// ─────────────────────────────────────────────────────────────

class _DatePickerRow extends StatelessWidget {
  final IconData icon; final String label;
  final DateTime? date; final Color color;
  final String placeholder; final VoidCallback onPick;

  const _DatePickerRow({
    required this.icon, required this.label,
    this.date, required this.color,
    this.placeholder = 'Seleziona data',
    required this.onPick});

  String _format(DateTime? d) {
    if (d == null) return placeholder;
    const months = [
      '', 'Gen','Feb','Mar','Apr','Mag','Giu',
      'Lug','Ago','Set','Ott','Nov','Dic'];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(label, style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10, fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  Text(_format(date), style: TextStyle(
                      color: date != null
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                      fontSize: 13, fontWeight: FontWeight.w600)),
                ])),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.25), size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SaveButton
// ─────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool isEditing, isSaving, canSave;
  final VoidCallback onSave;
  const _SaveButton({
    required this.isEditing, required this.isSaving,
    required this.canSave, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final active = canSave && !isSaving;
    return GestureDetector(
      onTap: active ? onSave : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [_teal, Color(0xFF00A880)])
              : null,
          color: active ? null : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? _teal.withOpacity(0.4)
                : Colors.white.withOpacity(0.1),
            width: 1),
          boxShadow: active
              ? [BoxShadow(
                  color: _teal.withOpacity(0.4), blurRadius: 16,
                  offset: const Offset(0, 4))]
              : null),
        child: isSaving
            ? Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withOpacity(0.7))),
                const SizedBox(width: 10),
                const Text('Salvataggio...',
                    style: TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ])
            : Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Icon(isEditing
                    ? Icons.update_rounded
                    : Icons.add_circle_rounded,
                  color: active
                      ? Colors.white
                      : Colors.white.withOpacity(0.25),
                  size: 18),
                const SizedBox(width: 8),
                Text(isEditing ? 'Aggiorna obiettivo' : 'Crea obiettivo',
                    style: TextStyle(
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.25),
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassDatePickerDialog
// Calendario Glass a 3 livelli: giorni → mesi → anni
// ─────────────────────────────────────────────────────────────

class _GlassDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? firstDate, lastDate;
  final ValueChanged<DateTime> onConfirm;
  final VoidCallback onCancel;

  const _GlassDatePickerDialog({
    required this.initialDate, required this.onConfirm,
    required this.onCancel, this.firstDate, this.lastDate});

  @override
  State<_GlassDatePickerDialog> createState() =>
      _GlassDatePickerDialogState();
}

enum _PickerView { days, months, years }

class _GlassDatePickerDialogState
    extends State<_GlassDatePickerDialog> {
  late DateTime _focus;
  late DateTime _selected;
  _PickerView _view = _PickerView.days;

  static const _dayNames = ['L','M','M','G','V','S','D'];
  static const _monthShort = [
    'Gen','Feb','Mar','Apr','Mag','Giu',
    'Lug','Ago','Set','Ott','Nov','Dic'];
  static const _monthFull = [
    'Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
    'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];

  @override
  void initState() {
    super.initState();
    _focus    = widget.initialDate;
    _selected = widget.initialDate;
  }

  String get _headerLabel {
    switch (_view) {
      case _PickerView.days:
        return '${_monthFull[_focus.month - 1]} ${_focus.year}';
      case _PickerView.months:
        return '${_focus.year}';
      case _PickerView.years:
        final dec = (_focus.year ~/ 10) * 10;
        return '$dec – ${dec + 9}';
    }
  }

  void _prev() => setState(() {
    switch (_view) {
      case _PickerView.days:
        _focus = DateTime(_focus.year, _focus.month - 1); break;
      case _PickerView.months:
        _focus = DateTime(_focus.year - 1, _focus.month); break;
      case _PickerView.years:
        _focus = DateTime(_focus.year - 10, _focus.month); break;
    }
  });

  void _next() => setState(() {
    switch (_view) {
      case _PickerView.days:
        _focus = DateTime(_focus.year, _focus.month + 1); break;
      case _PickerView.months:
        _focus = DateTime(_focus.year + 1, _focus.month); break;
      case _PickerView.years:
        _focus = DateTime(_focus.year + 10, _focus.month); break;
    }
  });

  bool _isDisabled(DateTime d) {
    final norm = DateTime(d.year, d.month, d.day);
    if (widget.firstDate != null) {
      final fd = DateTime(widget.firstDate!.year,
          widget.firstDate!.month, widget.firstDate!.day);
      if (norm.isBefore(fd)) return true;
    }
    if (widget.lastDate != null) {
      final ld = DateTime(widget.lastDate!.year,
          widget.lastDate!.month, widget.lastDate!.day);
      if (norm.isAfter(ld)) return true;
    }
    return false;
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
              // Navigazione
              Row(children: [
                _NavBtn(icon: Icons.chevron_left_rounded, onTap: _prev),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _view = _view == _PickerView.days
                          ? _PickerView.months
                          : _view == _PickerView.months
                              ? _PickerView.years
                              : _PickerView.days;
                    }),
                    child: Text(_headerLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.w800)))),
                _NavBtn(icon: Icons.chevron_right_rounded, onTap: _next),
              ]),
              const SizedBox(height: 12),
              Container(height: 0.6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    _teal.withOpacity(0.3),
                    Colors.transparent]))),
              const SizedBox(height: 12),
              // Griglia
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey('${_view}_${_focus.year}_${_focus.month}'),
                  child: _buildContent())),
              // Azioni
              const SizedBox(height: 16),
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
                            colors: [_teal, Color(0xFF00A880)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: _teal.withOpacity(0.4),
                            blurRadius: 10)]),
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

  Widget _buildContent() {
    switch (_view) {
      case _PickerView.days:    return _buildDays();
      case _PickerView.months:  return _buildMonths();
      case _PickerView.years:   return _buildYears();
    }
  }

  Widget _buildDays() {
    final firstDay  = DateTime(_focus.year, _focus.month, 1);
    final daysCount =
        DateTime(_focus.year, _focus.month + 1, 0).day;
    final offset    = (firstDay.weekday - 1) % 7;
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final selNorm   = DateTime(
        _selected.year, _selected.month, _selected.day);

    return Column(children: [
      Row(children: _dayNames.map((n) => Expanded(
        child: Center(child: Text(n, style: TextStyle(
            color: _teal.withOpacity(0.6), fontSize: 11,
            fontWeight: FontWeight.w700))))).toList()),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, childAspectRatio: 1,
                mainAxisSpacing: 4, crossAxisSpacing: 0),
        itemCount: offset + daysCount,
        itemBuilder: (_, idx) {
          if (idx < offset) return const SizedBox.shrink();
          final day  = idx - offset + 1;
          final date = DateTime(_focus.year, _focus.month, day);
          final norm = DateTime(date.year, date.month, date.day);
          final isSel     = norm == selNorm;
          final isToday   = norm == today;
          final isDisabled = _isDisabled(date);
          return GestureDetector(
            onTap: isDisabled ? null : () =>
                setState(() => _selected = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSel ? _teal
                    : isToday ? _cyan.withOpacity(0.12)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !isSel
                    ? Border.all(
                        color: _cyan.withOpacity(0.45), width: 1)
                    : null,
                boxShadow: isSel ? [BoxShadow(
                    color: _teal.withOpacity(0.45), blurRadius: 8)]
                    : null),
              child: Center(child: Text('$day', style: TextStyle(
                  color: isDisabled
                      ? Colors.white.withOpacity(0.2)
                      : isSel ? Colors.white
                      : Colors.white.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: isSel || isToday
                      ? FontWeight.w800 : FontWeight.w500)))));
        }),
    ]);
  }

  Widget _buildMonths() {
    final now = DateTime.now();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.8,
          mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: 12,
      itemBuilder: (_, i) {
        final isCurrent =
            _focus.year == now.year && i + 1 == now.month;
        final isSel =
            i + 1 == _selected.month &&
            _focus.year == _selected.year;
        return GestureDetector(
          onTap: () => setState(() {
            _focus = DateTime(_focus.year, i + 1);
            _view  = _PickerView.days;
          }),
          child: _PickerCell(
            label: _monthShort[i], color: _teal,
            isSelected: isSel, isCurrent: isCurrent));
      });
  }

  Widget _buildYears() {
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
        final year   = dec - 1 + i;
        final isCurrent = year == now.year;
        final isSel  = year == _selected.year;
        final isOut  = i == 0 || i == 11;
        return GestureDetector(
          onTap: () => setState(() {
            _focus = DateTime(year, _focus.month);
            _view  = _PickerView.months;
          }),
          child: _PickerCell(
            label: '$year', color: _teal,
            isSelected: isSel, isCurrent: isCurrent,
            isOutOfRange: isOut));
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
        border: Border.all(
            color: Colors.white.withOpacity(0.12), width: 0.8)),
      child: Icon(icon, color: Colors.white, size: 20)));
}

class _PickerCell extends StatelessWidget {
  final String label; final Color color;
  final bool isSelected, isCurrent, isOutOfRange;
  const _PickerCell({
    required this.label, required this.color,
    this.isSelected = false, this.isCurrent = false,
    this.isOutOfRange = false});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 130),
    decoration: BoxDecoration(
      color: isSelected ? color.withOpacity(0.2)
          : isCurrent   ? color.withOpacity(0.07)
          : Colors.white.withOpacity(isOutOfRange ? 0.02 : 0.04),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isSelected ? color.withOpacity(0.6)
            : isCurrent   ? color.withOpacity(0.3)
            : Colors.white.withOpacity(isOutOfRange ? 0.05 : 0.1),
        width: isSelected ? 1.3 : 1),
      boxShadow: isSelected
          ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8)]
          : null),
    child: Center(child: Text(label,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: isOutOfRange ? Colors.white.withOpacity(0.25)
                : isSelected ? color
                : Colors.white.withOpacity(0.75),
            fontSize: 12,
            fontWeight: isSelected || isCurrent
                ? FontWeight.w700 : FontWeight.w500))));
}