import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/markfit_colors.dart';
import '../../models/training_mode.dart';
import '../../providers/training_mode_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';

// ─────────────────────────────────────────────────────────────
// Categorie modalità — mapping label/colore condiviso da questa
// schermata e dal relativo editor. NON vincola la struttura
// interna della modalità (Parte 2): serve solo per classificazione
// e UX.
// ─────────────────────────────────────────────────────────────
const Map<String, String> _categoryLabels = {
  'fixed': 'Serie fisse',
  'range': 'Intervallo',
  'pyramid': 'Piramidale',
  'custom': 'Custom',
  'other': 'Altro',
};

String _categoryLabel(String cat) =>
    _categoryLabels[cat] ??
    (cat.isEmpty ? 'Altro' : '${cat[0].toUpperCase()}${cat.substring(1)}');

Color _categoryColor(String cat) {
  switch (cat) {
    case 'fixed':   return MarkFitColors.teal;
    case 'range':   return MarkFitColors.cyan;
    case 'pyramid': return MarkFitColors.indigo;
    case 'custom':  return MarkFitColors.orange;
    default:        return MarkFitColors.blue;
  }
}

// ─────────────────────────────────────────────────────────────
// TrainingModesScreen — "Gestione modalità di allenamento"
// ─────────────────────────────────────────────────────────────
class TrainingModesScreen extends StatefulWidget {
  const TrainingModesScreen({super.key});

  @override
  State<TrainingModesScreen> createState() => _TrainingModesScreenState();
}

class _TrainingModesScreenState extends State<TrainingModesScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _category = 'Tutti';

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<TrainingModeProvider>().loadModes());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<T?> _openSheet<T>(Widget child) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditor({TrainingMode? existing}) async {
    await _openSheet(_TrainingModeEditorSheet(existing: existing));
    if (mounted) context.read<TrainingModeProvider>().loadModes();
  }

  Future<void> _confirmDelete(TrainingMode mode) async {
    if (mode.isDefault) {
      await showGlassDialog<void>(
        context: context,
        accentColor: MarkFitColors.orange,
        title: 'Impossibile eliminare',
        message:
            '"${mode.name}" è la modalità predefinita. Imposta un\'altra '
            'modalità come predefinita prima di eliminarla.',
        actions: [
          GlassDialogAction(label: 'OK', onTap: () => Navigator.pop(context)),
        ],
      );
      return;
    }
    final ok = await showGlassDialog<bool>(
      context: context,
      accentColor: MarkFitColors.red,
      icon: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: MarkFitColors.red.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: MarkFitColors.red.withOpacity(0.4))),
        child: const Icon(Icons.delete_outline_rounded,
            color: MarkFitColors.red, size: 22)),
      title: 'Eliminare modalità?',
      message:
          '"${mode.name}" non sarà più selezionabile per nuovi esercizi. '
          'Lo storico che la utilizza rimane intatto.',
      actions: [
        GlassDialogAction(
            label: 'Annulla', onTap: () => Navigator.pop(context, false)),
        GlassDialogAction(
            label: 'Elimina',
            isDestructive: true,
            onTap: () => Navigator.pop(context, true)),
      ],
    );
    if (ok == true && mounted) {
      await context.read<TrainingModeProvider>().softDelete(mode.key);
    }
  }

  Future<void> _setDefault(TrainingMode mode) async {
    await context.read<TrainingModeProvider>().setDefault(mode.key);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    final tp = context.watch<TrainingModeProvider>();
    final categories = <String>['Tutti', ...tp.availableCategories];
    final filtered = tp.search(_search, category: _category)
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        subtle: true,
        child: SafeArea(
          child: Column(children: [
            _buildAppBar(context, c),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  _SearchBar(
                      ctrl: _searchCtrl,
                      c: c,
                      isDark: context.isDarkMode,
                      onChanged: (v) => setState(() => _search = v)),
                  const SizedBox(height: 10),
                  if (categories.length > 1) ...[
                    _CategoryChips(
                        categories: categories,
                        selected: _category,
                        onSelect: (v) => setState(() => _category = v)),
                    const SizedBox(height: 12),
                  ],
                  if (filtered.isEmpty)
                    _EmptyState(c: c)
                  else
                    ...filtered.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ModeCard(
                          mode: m,
                          c: c,
                          onTap: () => _showEditor(existing: m),
                          onSetDefault: () => _setDefault(m),
                          onDelete: () => _confirmDelete(m),
                        ))),
                ],
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
            border: Border(
                bottom: BorderSide(
                    color: MarkFitColors.indigo.withOpacity(0.15),
                    width: 0.6)),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 6,
                    offset: const Offset(0, 2))]
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.glassCardInset,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: c.glassBorder, width: 0.8)),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15, color: c.iconPrimary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Modalità di allenamento', style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
                  Text('Gestisci le tue modalità', style: TextStyle(
                      color: c.textTertiary, fontSize: 11)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showEditor(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [MarkFitColors.teal, MarkFitColors.tealDk]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(
                      color: MarkFitColors.teal.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2))]),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 5),
                  Text('Nuova', style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SearchBar
// ─────────────────────────────────────────────────────────────
class _SearchBar extends StatefulWidget {
  final TextEditingController ctrl;
  final MarkFitColors c;
  final bool isDark;
  final ValueChanged<String> onChanged;
  const _SearchBar(
      {required this.ctrl,
      required this.c,
      required this.isDark,
      required this.onChanged});
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
            border: Border.all(
                color: widget.c.inputBorder,
                width: widget.isDark ? 0.8 : 1.1)),
          child: TextField(
            controller: widget.ctrl,
            style: TextStyle(color: widget.c.inputText, fontSize: 14),
            keyboardAppearance:
                widget.isDark ? Brightness.dark : Brightness.light,
            cursorColor: MarkFitColors.indigo,
            decoration: InputDecoration(
              hintText: 'Cerca modalità...',
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
                  horizontal: 14, vertical: 13),
            ),
            onChanged: (v) {
              widget.onChanged(v);
              setState(() {});
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _CategoryChips
// ─────────────────────────────────────────────────────────────
class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryChips(
      {required this.categories,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final sel = selected == cat;
          final color =
              cat == 'Tutti' ? MarkFitColors.cyan : _categoryColor(cat);
          final label = cat == 'Tutti' ? 'Tutti' : _categoryLabel(cat);
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? color.withOpacity(0.15) : c.glassCardInset,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: sel ? color.withOpacity(0.55) : c.glassBorder,
                    width: sel ? 1.2 : 0.8),
              ),
              child: Text(label, style: TextStyle(
                  color: sel ? color : c.textTertiary,
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ModeCard
// ─────────────────────────────────────────────────────────────
class _ModeCard extends StatelessWidget {
  final TrainingMode mode;
  final MarkFitColors c;
  final VoidCallback onTap, onSetDefault, onDelete;
  const _ModeCard({
    required this.mode,
    required this.c,
    required this.onTap,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(mode.category);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: mode.isDefault
                    ? MarkFitColors.orange.withOpacity(0.5)
                    : c.glassBorder,
                width: mode.isDefault ? 1.2 : 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 6,
                    offset: const Offset(0, 1))]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: onSetDefault,
                child: Icon(
                    mode.isDefault
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: mode.isDefault
                        ? MarkFitColors.orange
                        : c.iconSecondary,
                    size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mode.name, style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: color.withOpacity(0.25), width: 0.6)),
                          child: Text(_categoryLabel(mode.category),
                              style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(mode.structureLabel, style: TextStyle(
                              color: c.textTertiary, fontSize: 11),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c.glassCardInset,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: c.glassBorder, width: 0.7)),
                  child: Icon(Icons.edit_outlined,
                      size: 14, color: c.iconSecondary)),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: MarkFitColors.red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: MarkFitColors.red.withOpacity(0.25),
                        width: 0.7)),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 14, color: MarkFitColors.red.withOpacity(0.8))),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final MarkFitColors c;
  const _EmptyState({required this.c});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: MarkFitColors.indigo.withOpacity(0.08),
                  shape: BoxShape.circle),
              child: const Icon(Icons.repeat_rounded,
                  color: MarkFitColors.indigo, size: 26),
            ),
            const SizedBox(height: 14),
            Text('Nessuna modalità trovata', style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Prova a cambiare filtri o crea una nuova modalità',
                style: TextStyle(color: c.textTertiary, fontSize: 13),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// _EditableSet — stato locale editabile di una singola serie,
// indipendente da TrainingModeSet finché non viene salvato.
// ─────────────────────────────────────────────────────────────
class _EditableSet {
  final bool isRange;
  final int fixedReps;
  final int minReps;
  final int maxReps;
  const _EditableSet({
    this.isRange = false,
    this.fixedReps = 8,
    this.minReps = 8,
    this.maxReps = 12,
  });

  factory _EditableSet.fromMode(TrainingModeSet s) => _EditableSet(
        isRange: s.isRange,
        fixedReps: s.fixedReps ?? 8,
        minReps: s.minReps ?? 8,
        maxReps: s.maxReps ?? 12,
      );

  TrainingModeSet toModel(int order) => isRange
      ? TrainingModeSet(order: order, minReps: minReps, maxReps: maxReps)
      : TrainingModeSet(order: order, fixedReps: fixedReps);
}

// ─────────────────────────────────────────────────────────────
// _TrainingModeEditorSheet
//
// VERSIONAMENTO (Parte 10/11/34/35): salvare modifiche su una
// modalità ESISTENTE non la altera mai. Crea sempre una nuova
// TrainingMode (parentModeKey → vecchia), poi soft-elimina la
// vecchia. Se la vecchia era la predefinita, la nuova diventa
// automaticamente predefinita, così l'invariante "esattamente una
// predefinita" resta valida senza violare la regola per cui non si
// può eliminare la modalità predefinita corrente (Parte 9): qui
// l'eliminazione avviene solo DOPO aver assegnato il nuovo default.
// ─────────────────────────────────────────────────────────────
class _TrainingModeEditorSheet extends StatefulWidget {
  final TrainingMode? existing;
  const _TrainingModeEditorSheet({this.existing});

  @override
  State<_TrainingModeEditorSheet> createState() =>
      _TrainingModeEditorSheetState();
}

class _TrainingModeEditorSheetState extends State<_TrainingModeEditorSheet> {
  late TextEditingController _nameCtrl;
  late String _category;
  late List<_EditableSet> _sets;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _category = ex?.category ?? 'custom';
    if (ex != null) {
      _sets = ex.orderedSets.map((s) => _EditableSet.fromMode(s)).toList();
      if (_sets.isEmpty) _sets = [const _EditableSet()];
    } else {
      _sets = const [_EditableSet(), _EditableSet(), _EditableSet()];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _addSet() {
    final last = _sets.isNotEmpty ? _sets.last : const _EditableSet();
    setState(() => _sets = [
          ..._sets,
          _EditableSet(
              isRange: last.isRange,
              fixedReps: last.fixedReps,
              minReps: last.minReps,
              maxReps: last.maxReps),
        ]);
  }

  void _removeSet(int i) {
    if (_sets.length <= 1) return;
    setState(() {
      final list = List<_EditableSet>.from(_sets);
      list.removeAt(i);
      _sets = list;
    });
  }

  void _moveUp(int i) {
    if (i == 0) return;
    setState(() {
      final list = List<_EditableSet>.from(_sets);
      final item = list.removeAt(i);
      list.insert(i - 1, item);
      _sets = list;
    });
  }

  void _moveDown(int i) {
    if (i == _sets.length - 1) return;
    setState(() {
      final list = List<_EditableSet>.from(_sets);
      final item = list.removeAt(i);
      list.insert(i + 1, item);
      _sets = list;
    });
  }

  void _updateSet(int i, _EditableSet updated) {
    setState(() {
      final list = List<_EditableSet>.from(_sets);
      list[i] = updated;
      _sets = list;
    });
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty && _sets.isNotEmpty;

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final tp = context.read<TrainingModeProvider>();
    final now = DateTime.now().toIso8601String();
    final orderedSets = <TrainingModeSet>[
      for (var i = 0; i < _sets.length; i++) _sets[i].toModel(i + 1),
    ];
    final existing = widget.existing;
    final newMode = TrainingMode(
      name: _nameCtrl.text.trim(),
      category: _category,
      createdAt: now,
      origin: existing != null ? existing.origin : 'custom',
      parentModeKey: existing != null ? existing.key as int? : null,
      sets: orderedSets,
    );
    final newKey = await tp.addMode(newMode);
    if (existing != null) {
      final wasDefault = existing.isDefault;
      if (wasDefault) {
        await tp.setDefault(newKey);
      }
      await tp.softDelete(existing.key);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return GlassSheetWrapper(
      title: _isEditing ? 'Modifica modalità' : 'Nuova modalità',
      subtitle: _isEditing
          ? 'Il salvataggio crea una nuova versione'
          : null,
      accentColor: MarkFitColors.indigo,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTextField(
            controller: _nameCtrl,
            hintText: 'Es. 3×8, Piramidale...',
            labelText: 'Nome',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Categoria', style: TextStyle(
                color: c.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4)),
          ),
          const SizedBox(height: 8),
          _CategorySelector(
              selected: _category,
              onSelect: (v) => setState(() => _category = v)),
          const SizedBox(height: 16),
          Row(children: [
            Text('Serie', style: TextStyle(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: _addSet,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: MarkFitColors.teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: MarkFitColors.teal.withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 14, color: MarkFitColors.teal),
                  const SizedBox(width: 4),
                  Text('Aggiungi', style: TextStyle(
                      color: MarkFitColors.teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          ..._sets.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SetEditorRow(
                  index: e.key,
                  total: _sets.length,
                  set: e.value,
                  c: c,
                  onChanged: (s) => _updateSet(e.key, s),
                  onRemove: _sets.length > 1 ? () => _removeSet(e.key) : null,
                  onMoveUp: e.key > 0 ? () => _moveUp(e.key) : null,
                  onMoveDown:
                      e.key < _sets.length - 1 ? () => _moveDown(e.key) : null,
                ),
              )),
          const SizedBox(height: 10),
          GlassPrimaryButton(
            label: _saving
                ? 'Salvataggio...'
                : (_isEditing ? 'Salva come nuova versione' : 'Crea modalità'),
            color: MarkFitColors.indigo,
            onTap: (_canSave && !_saving) ? _save : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _CategorySelector
// ─────────────────────────────────────────────────────────────
class _CategorySelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategorySelector({required this.selected, required this.onSelect});

  static const _cats = ['fixed', 'range', 'pyramid', 'custom', 'other'];

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _cats.map((cat) {
        final sel = selected == cat;
        final color = _categoryColor(cat);
        return GestureDetector(
          onTap: () => onSelect(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? color.withOpacity(0.18) : c.glassCardInset,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel ? color.withOpacity(0.6) : c.glassBorder,
                  width: sel ? 1.3 : 0.8),
            ),
            child: Text(_categoryLabel(cat), style: TextStyle(
                color: sel ? color : c.textTertiary,
                fontSize: 12,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SetEditorRow
// ─────────────────────────────────────────────────────────────
class _SetEditorRow extends StatelessWidget {
  final int index, total;
  final _EditableSet set;
  final MarkFitColors c;
  final ValueChanged<_EditableSet> onChanged;
  final VoidCallback? onRemove, onMoveUp, onMoveDown;
  const _SetEditorRow({
    required this.index,
    required this.total,
    required this.set,
    required this.c,
    required this.onChanged,
    this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.glassCardInset,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.glassBorder, width: 0.8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                      color: MarkFitColors.indigo.withOpacity(0.12),
                      shape: BoxShape.circle),
                  child: Center(child: Text('${index + 1}', style: const TextStyle(
                      color: MarkFitColors.indigo,
                      fontSize: 11,
                      fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 8),
                Text('Serie ${index + 1}', style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
                const Spacer(),
                if (onMoveUp != null)
                  _TinyIconBtn(
                      icon: Icons.keyboard_arrow_up_rounded,
                      c: c,
                      onTap: onMoveUp!),
                if (onMoveDown != null)
                  _TinyIconBtn(
                      icon: Icons.keyboard_arrow_down_rounded,
                      c: c,
                      onTap: onMoveDown!),
                if (onRemove != null)
                  _TinyIconBtn(
                      icon: Icons.close_rounded,
                      c: c,
                      color: MarkFitColors.red,
                      onTap: onRemove!),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _RangeToggle(
                  isRange: set.isRange,
                  c: c,
                  onChanged: (v) => onChanged(_EditableSet(
                      isRange: v,
                      fixedReps: set.fixedReps,
                      minReps: set.minReps,
                      maxReps: set.maxReps)),
                ),
                const SizedBox(width: 10),
                if (!set.isRange)
                  Expanded(
                    child: _RepsStepper(
                      label: 'Reps',
                      value: set.fixedReps,
                      c: c,
                      onChanged: (v) => onChanged(_EditableSet(
                          isRange: false,
                          fixedReps: v,
                          minReps: set.minReps,
                          maxReps: set.maxReps)),
                    ),
                  )
                else ...[
                  Expanded(
                    child: _RepsStepper(
                      label: 'Min',
                      value: set.minReps,
                      c: c,
                      onChanged: (v) => onChanged(_EditableSet(
                          isRange: true,
                          fixedReps: set.fixedReps,
                          minReps: v > set.maxReps ? set.maxReps : v,
                          maxReps: set.maxReps)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RepsStepper(
                      label: 'Max',
                      value: set.maxReps,
                      c: c,
                      onChanged: (v) => onChanged(_EditableSet(
                          isRange: true,
                          fixedReps: set.fixedReps,
                          minReps: set.minReps,
                          maxReps: v < set.minReps ? set.minReps : v)),
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  final bool isRange;
  final MarkFitColors c;
  final ValueChanged<bool> onChanged;
  const _RangeToggle(
      {required this.isRange, required this.c, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
          color: c.glassCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.glassBorder, width: 0.7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _btn('Fisse', !isRange, () => onChanged(false)),
        _btn('Range', isRange, () => onChanged(true)),
      ]),
    );
  }

  Widget _btn(String label, bool sel, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
              color: sel
                  ? MarkFitColors.indigo.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6)),
          child: Text(label, style: TextStyle(
              color: sel ? MarkFitColors.indigo : c.textTertiary,
              fontSize: 10,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
        ),
      );
}

class _RepsStepper extends StatelessWidget {
  final String label;
  final int value;
  final MarkFitColors c;
  final ValueChanged<int> onChanged;
  const _RepsStepper({
    required this.label,
    required this.value,
    required this.c,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: c.inputBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: c.inputBorder, width: 0.8)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(
            color: c.textTertiary, fontSize: 9, fontWeight: FontWeight.w600)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: value > 1 ? () => onChanged(value - 1) : null,
            child: Icon(Icons.remove_circle_outline_rounded,
                size: 18,
                color: value > 1 ? MarkFitColors.cyan : c.textTertiary),
          ),
          SizedBox(
            width: 28,
            child: Text('$value', textAlign: TextAlign.center, style: TextStyle(
                color: c.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
          ),
          GestureDetector(
            onTap: () => onChanged(value + 1),
            child: const Icon(Icons.add_circle_outline_rounded,
                size: 18, color: MarkFitColors.cyan),
          ),
        ]),
      ]),
    );
  }
}

class _TinyIconBtn extends StatelessWidget {
  final IconData icon;
  final MarkFitColors c;
  final Color? color;
  final VoidCallback onTap;
  const _TinyIconBtn(
      {required this.icon, required this.c, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 18, color: color ?? c.iconSecondary),
        ),
      );
}