import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/markfit_colors.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../models/training_mode.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/training_mode_provider.dart';
import '../../services/one_rep_max_service.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';

// ─── Accent tokens ────────────────────────────────────────────
const _cyan   = MarkFitColors.cyan;
const _teal   = MarkFitColors.teal;
const _tealDk = MarkFitColors.tealDk;
const _indigo = MarkFitColors.indigo;
const _orange = MarkFitColors.orange;
const _green  = MarkFitColors.green;
const _red    = MarkFitColors.red;
const _blue   = MarkFitColors.blue;
const _grey   = Color(0xFF9CA3AF);

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
Color _groupColor(String g) =>
    _groupColors[g] ?? const Color(0xFF9CA3AF);

// ─────────────────────────────────────────────────────────────
// FASE 5 — Sistema Modalità di Allenamento: metadati di stato
// ─────────────────────────────────────────────────────────────
class _StatusMeta {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusMeta(this.label, this.color, this.icon);
}

const _statusMetaMap = <String, _StatusMeta>{
  'standard': _StatusMeta('Standard', _green, Icons.check_circle_rounded),
  'partial':  _StatusMeta('Parziale', _orange, Icons.adjust_rounded),
  'custom':   _StatusMeta('Custom', _indigo, Icons.diamond_rounded),
  'legacy':   _StatusMeta('Legacy', _grey, Icons.history_rounded),
};
_StatusMeta _statusMeta(String? s) =>
    _statusMetaMap[s ?? 'legacy'] ?? _statusMetaMap['legacy']!;

// Sentinella per lo scope "Tutte le modalità" nel selettore chip.
// Oggetto const dedicato: mai uguale a null né a una vera chiave
// (int) di TrainingMode, quindi il confronto == è sempre sicuro.
const Object _allScopeSentinel = Object();

// ─── Data models ─────────────────────────────────────────────

// FIX FASE 5 — SESSIONE ≠ DATA: ogni _ProgressPoint rappresenta
// ORA una singola sessione reale (identificata dall'iterazione
// sulla sessione stessa in _loadData, non da una chiave-data
// yyyy-MM-dd). Due sessioni completate nello stesso giorno
// producono quindi SEMPRE due _ProgressPoint distinti. `date`
// contiene l'orario completo (non solo il giorno) per consentire
// l'ordinamento cronologico esatto anche tra sessioni dello
// stesso giorno.
class _ProgressPoint {
  final DateTime date;
  final double   maxWeight;
  final double   totalVolume;
  final int      maxReps;
  final int      setsCount;
  const _ProgressPoint({
    required this.date, required this.maxWeight,
    required this.totalVolume, required this.maxReps,
    required this.setsCount,
  });
}

// FASE 5 — dettaglio di una singola serie eseguita, usato nel
// popup di dettaglio punto e per il calcolo del valore di sessione.
class _SetDetail {
  final int setNumber;
  final double weight;
  final int reps;
  final bool completed;
  const _SetDetail({
    required this.setNumber, required this.weight,
    required this.reps, required this.completed,
  });
}

// FASE 5 — un punto storico per esercizio+modalità: rappresenta
// UNA sessione (non un giorno), con il valore rappresentativo
// (media 1RM Epley sulle serie zavorrate valide — Parte 29) e lo
// stato di esecuzione persistito dalla Fase 4. `value` è null se
// la sessione non contiene serie zavorrate valide (es. esercizio
// interamente a corpo libero — Parte 25/27): il punto resta nello
// storico ma non produce un punto nel grafico del carico.
class _ModePoint {
  final DateTime date;
  final double? value;
  final String status; // 'standard' | 'partial' | 'custom' | 'legacy'
  final dynamic modeKey;
  final List<_SetDetail> sets;
  const _ModePoint({
    required this.date, required this.value, required this.status,
    required this.modeKey, required this.sets,
  });
}

class _ExerciseStat {
  final String               name;
  final String               muscleGroup;
  final double               personalRecord;
  final int                  totalSessions;
  final double               totalVolume;
  final List<_ProgressPoint> points;          // aggregato legacy ("Tutte") — per sessione
  final Map<dynamic, List<_ModePoint>> byMode; // FASE 5 — per modalità
  const _ExerciseStat({
    required this.name, required this.muscleGroup,
    required this.personalRecord, required this.totalSessions,
    required this.totalVolume, required this.points,
    required this.byMode,
  });

  double get lastWeight => points.isEmpty ? 0 : points.last.maxWeight;

  double get improvement {
    if (points.length < 2) return 0;
    final first = points.first.maxWeight;
    final last  = points.last.maxWeight;
    if (first <= 0) return 0;
    return ((last - first) / first) * 100;
  }
}

enum _ChartMode { weight, volume }

// ─── ExerciseProgressScreen ───────────────────────────────────

class ExerciseProgressScreen extends StatefulWidget {
  const ExerciseProgressScreen({super.key});
  @override
  State<ExerciseProgressScreen> createState() =>
      _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  final _searchCtrl = TextEditingController();

  bool       _loading          = true;
  String     _search           = '';
  String     _selectedCategory = 'Tutti';
  String?    _selectedName;       // null = list view, non-null = detail view
  _ChartMode _chartMode        = _ChartMode.weight;

  // FASE 5 — scope selezionato nella vista dettaglio: sentinella
  // "Tutte" oppure una vera chiave di TrainingMode (o null = Legacy).
  dynamic _selectedScope  = _allScopeSentinel;
  bool    _standardOnly   = false;

  Map<String, _ExerciseStat> _stats = {};
  List<String>               _names = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    // FASE 5 — necessario per risolvere nome/struttura delle
    // modalità storiche (chip, PR card, popup dettaglio).
    Future.microtask(
        () => context.read<TrainingModeProvider>().loadModes());
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  // ── Data loading ──────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Build muscle-group map from exercise library
    final epEx = context.read<ExerciseProvider>().exercises;
    final mgMap = <String, String>{
      for (final e in epEx) e.name: e.muscleGroup,
    };

    final sessions = HiveDatabase.instance.getSessions();

    // FIX FASE 5 — SESSIONE ≠ DATA (bug fix):
    //
    // PRIMA: le serie valide venivano accumulate in una mappa
    // keyed by "yyyy-MM-dd" (byExerciseByDate), quindi due
    // sessioni completate nello stesso giorno finivano nello
    // stesso bucket e producevano UN SOLO _ProgressPoint —
    // esattamente il comportamento vietato (due sessioni distinte
    // devono sempre produrre due punti dati distinti, anche se
    // cadono nello stesso giorno).
    //
    // ORA: l'identità dell'aggregazione è la SESSIONE stessa
    // (siamo già dentro `for (final session in sessions)`, quindi
    // ogni iterazione è per costruzione una sessione distinta).
    // legacyPointsByExercise accumula UN _ProgressPoint per ogni
    // sessione reale che contiene almeno una serie valida
    // (completata, peso > 0) per quell'esercizio — mai per data.
    final legacyPointsByExercise = <String, List<_ProgressPoint>>{};
    // FASE 5 — punti per esercizio+modalità, uno per sessione reale
    // (già corretto: era già per-sessione, non per-data).
    final pointsByExercise = <String, List<_ModePoint>>{};

    for (final session in sessions) {
      final dt = DateTime.tryParse(session.date) ?? DateTime.now();
      final sets = HiveDatabase.instance.getSessionSets(session.key);

      final byExercise = <String, List<HiveSessionSet>>{};
      for (final s in sets) {
        byExercise.putIfAbsent(s.exerciseName, () => []).add(s);
      }

      for (final entry in byExercise.entries) {
        final exName = entry.key;
        final exSets = entry.value;

        // Aggregato legacy ("Tutte") — UN punto per QUESTA sessione
        // (mai raggruppato con altre sessioni della stessa data),
        // calcolato sulle sole serie completate con peso > 0
        // (Parte 26, invariato rispetto a prima del fix).
        final weightedCompleted =
            exSets.where((s) => s.completed && s.weight > 0).toList();
        if (weightedCompleted.isNotEmpty) {
          final maxW = weightedCompleted.map((s) => s.weight).reduce(math.max);
          final vol  = weightedCompleted.fold<double>(
              0, (s, e) => s + e.weight * e.reps);
          final maxR = weightedCompleted.map((s) => s.reps).reduce(math.max);
          legacyPointsByExercise.putIfAbsent(exName, () => []).add(
              _ProgressPoint(
                date:        dt,
                maxWeight:   maxW,
                totalVolume: vol,
                maxReps:     maxR,
                setsCount:   weightedCompleted.length,
              ));
        }

        // FASE 5 — punto per modalità: tutte le serie di questo
        // esercizio in questa sessione condividono lo stesso
        // trainingModeKey/executionStatus (assegnati in blocco da
        // SessionProvider.finishSession — Fase 4). Già per-sessione
        // per costruzione (un _ModePoint per ogni iterazione della
        // sessione corrente), non necessita correzioni.
        final modeKey = exSets.first.trainingModeKey;
        final status  = exSets.first.executionStatus;

        final validInputs = exSets
            .where((s) => s.completed)
            .map((s) => WeightedSetInput(weight: s.weight, reps: s.reps))
            .toList();
        final value = OneRepMaxService.representativeSessionValue(validInputs);

        final setDetails = (List<HiveSessionSet>.from(exSets)
              ..sort((a, b) => a.setNumber.compareTo(b.setNumber)))
            .map((s) => _SetDetail(
                setNumber: s.setNumber, weight: s.weight,
                reps: s.reps, completed: s.completed))
            .toList();

        pointsByExercise.putIfAbsent(exName, () => []).add(_ModePoint(
          date: dt, value: value, status: status ?? 'legacy',
          modeKey: modeKey, sets: setDetails,
        ));
      }
    }

    // Ordinamento cronologico per DATA E ORA COMPLETE (Parte 8 del
    // fix): garantisce l'ordine esatto anche tra più sessioni dello
    // stesso giorno con orari diversi.
    for (final list in pointsByExercise.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
    }
    for (final list in legacyPointsByExercise.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
    }

    final newStats = <String, _ExerciseStat>{};

    for (final entry in pointsByExercise.entries) {
      final name       = entry.key;
      final allPoints  = entry.value;
      final legacyPoints = legacyPointsByExercise[name] ?? [];

      // PR e volume totale: massimo/somma sono operazioni
      // associative, quindi il risultato numerico è identico a
      // prima del fix — cambia solo la granularità della lista
      // `points` usata da grafico/lista sessioni/miglioramento.
      double pr = 0, totalVol = 0;
      for (final p in legacyPoints) {
        if (p.maxWeight > pr) pr = p.maxWeight;
        totalVol += p.totalVolume;
      }

      final byMode = <dynamic, List<_ModePoint>>{};
      for (final p in allPoints) {
        byMode.putIfAbsent(p.modeKey, () => []).add(p);
      }

      newStats[name] = _ExerciseStat(
        name:           name,
        muscleGroup:    mgMap[name] ?? '',
        personalRecord: pr,
        totalSessions:  allPoints.length,
        totalVolume:    totalVol,
        points:         legacyPoints,
        byMode:         byMode,
      );
    }

    final sorted = newStats.keys.toList()
      ..sort((a, b) =>
          newStats[b]!.totalSessions.compareTo(newStats[a]!.totalSessions));

    if (mounted) setState(() { _stats = newStats; _names = sorted; _loading = false; });
  }

  // ── Filters ───────────────────────────────────────────────

  List<String> get _categories {
    final cats = <String>{'Tutti'};
    for (final s in _stats.values) {
      if (s.muscleGroup.isNotEmpty) cats.add(s.muscleGroup);
    }
    return cats.toList();
  }

  List<String> get _filteredNames => _names.where((n) {
    final s = _stats[n]!;
    return (_selectedCategory == 'Tutti' || s.muscleGroup == _selectedCategory) &&
        (_search.isEmpty || n.toLowerCase().contains(_search.toLowerCase()));
  }).toList();

  _ExerciseStat? get _selected =>
      _selectedName != null ? _stats[_selectedName] : null;

  void _openExercise(String name) {
    setState(() {
      _selectedName   = name;
      _selectedScope  = _allScopeSentinel;
      _standardOnly   = false;
    });
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c         = context.mfc;
    final sysBottom = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor:          Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: CosmicBackground(
        child: SafeArea(
          child: Column(children: [
            _buildAppBar(context, c),
            Expanded(child: _loading
                ? Center(child: CircularProgressIndicator(
                    color: _teal, strokeWidth: 2))
                : _stats.isEmpty
                    ? _buildEmptyData(c, sysBottom)
                    : _selected != null
                        ? _buildDetailView(context, c, sysBottom)
                        : _buildListView(context, c, sysBottom)),
          ]),
        ),
      ),
    );
  }

  // ── Dynamic AppBar ────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, MarkFitColors c) {
    final inDetail  = _selected != null;
    final accent    = inDetail ? _groupColor(_selected!.muscleGroup) : _teal;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: c.glassBlurStrong, sigmaY: c.glassBlurStrong),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            border: Border(bottom: BorderSide(
                color: accent.withOpacity(0.2), width: 0.7)),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 8,
                    offset: const Offset(0, 2))]
                : null),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (inDetail) {
                  setState(() => _selectedName = null);
                } else {
                  Navigator.pop(context);
                }
              },
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.glassCardInset,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: c.glassBorder, width: 0.8)),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15, color: c.iconPrimary))),
            const SizedBox(width: 12),
            Expanded(child: inDetail
                ? Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(_selected!.name, style: TextStyle(
                        color: c.textPrimary, fontSize: 17,
                        fontWeight: FontWeight.w800, letterSpacing: -0.3),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (_selected!.muscleGroup.isNotEmpty)
                      Text(_selected!.muscleGroup, style: TextStyle(
                          color: accent, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text('Progressi', style: TextStyle(
                        color: c.textPrimary, fontSize: 17,
                        fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    Text('Andamento esercizi nel tempo', style: TextStyle(
                        color: c.textTertiary, fontSize: 11)),
                  ])),
            if (inDetail)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _teal.withOpacity(0.3), width: 0.7)),
                child: Text('${_selected!.totalSessions} sess.',
                    style: const TextStyle(
                        color: _teal, fontSize: 11,
                        fontWeight: FontWeight.w700)))
            else
              GestureDetector(
                onTap: _loadData,
                child: Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: c.glassCardInset,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: c.glassBorder, width: 0.8)),
                  child: Icon(Icons.refresh_rounded,
                      size: 18, color: c.iconPrimary))),
          ]),
        ),
      ),
    );
  }

  // ── List view ─────────────────────────────────────────────

  Widget _buildListView(
      BuildContext context, MarkFitColors c, double sysBottom) {
    final filtered = _filteredNames;
    final cats     = _categories;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 88 + sysBottom),
      children: [
        _GlobalStatsBar(stats: _stats, c: c),
        const SizedBox(height: 12),
        _SearchField(
          ctrl:      _searchCtrl, c: c,
          isDark:    context.isDarkMode,
          onChanged: (v) => setState(() {
            _search = v; _selectedName = null;
          })),
        const SizedBox(height: 8),
        if (cats.length > 1) ...[
          _CategoryChips(
            categories: cats,
            selected:   _selectedCategory,
            c:          c,
            onSelect: (cat) => setState(() {
              _selectedCategory = cat; _selectedName = null;
            })),
          const SizedBox(height: 12),
        ],
        if (filtered.isNotEmpty) ...[
          _ListHeader(count: filtered.length, c: c),
          const SizedBox(height: 8),
        ],
        if (filtered.isEmpty)
          _EmptySearch(c: c)
        else
          ...filtered.map((name) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ExerciseTile(
              stat:  _stats[name]!,
              c:     c,
              onTap: () {
                HapticFeedback.selectionClick();
                _openExercise(name);
              }))),
      ],
    );
  }

  // ── Detail view ───────────────────────────────────────────

  Widget _buildDetailView(
      BuildContext context, MarkFitColors c, double sysBottom) {
    final stat = _selected!;
    final tp   = context.watch<TrainingModeProvider>();

    final modeKeys = stat.byMode.keys.toList()
      ..sort((a, b) {
        final da = stat.byMode[a]!.last.date;
        final db = stat.byMode[b]!.last.date;
        return db.compareTo(da);
      });

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 88 + sysBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (modeKeys.isNotEmpty) ...[
            _ModeScopeChips(
              modeKeys: modeKeys,
              selected: _selectedScope,
              tp:       tp,
              c:        c,
              onSelect: (k) => setState(() {
                _selectedScope = k;
                _standardOnly  = false;
              })),
            const SizedBox(height: 12),
          ],
          if (_selectedScope == _allScopeSentinel)
            _buildAggregateSection(context, stat, c)
          else
            _buildModeSection(context, stat, c, _selectedScope),
        ],
      ),
    );
  }

  // ── Aggregato "Tutte le modalità" — ORA per sessione, non per
  // giorno (fix Fase 5). ────────────────────────────────────

  Widget _buildAggregateSection(
      BuildContext context, _ExerciseStat stat, MarkFitColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PRCard(stat: stat, c: c),
        const SizedBox(height: 12),
        if (stat.points.length >= 2) ...[
          _ChartModeToggle(
              mode:   _chartMode,
              onMode: (m) => setState(() => _chartMode = m),
              c:      c),
          const SizedBox(height: 8),
          _ProgressChart(points: stat.points, mode: _chartMode, c: c),
          const SizedBox(height: 12),
        ] else
          _NotEnoughDataCard(sessions: stat.points.length, c: c),
        const SizedBox(height: 4),
        _RecentSessions(points: stat.points, c: c),
      ],
    );
  }

  // ── FASE 5 — Sezione modalità-specifica ─────────────────────

  Widget _buildModeSection(BuildContext context, _ExerciseStat stat,
      MarkFitColors c, dynamic scope) {
    final points = stat.byMode[scope] ?? const <_ModePoint>[];
    final tp     = context.watch<TrainingModeProvider>();
    final mode   = scope == null ? null : tp.getByKey(scope);
    final modeLabel = scope == null
        ? 'Legacy (nessuna modalità)'
        : (mode?.structureLabel ?? 'Modalità eliminata');

    final valuedPoints = points.where((p) => p.value != null).toList();
    final standardPoints =
        valuedPoints.where((p) => p.status == 'standard').toList();
    final chartPoints = _standardOnly ? standardPoints : valuedPoints;

    final values = valuedPoints.map((p) => p.value!).toList();
    final record = values.isEmpty ? null : values.reduce(math.max);
    final last   = valuedPoints.isEmpty ? null : valuedPoints.last.value;
    final first  = valuedPoints.isEmpty ? null : valuedPoints.first.value;
    final improvement = (first != null && last != null && first > 0)
        ? ((last - first) / first) * 100
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ModePRCard(
          modeLabel: modeLabel, record: record, last: last,
          improvement: improvement, totalSessions: points.length, c: c),
        const SizedBox(height: 12),
        _StandardCompleteToggle(
          standardOnly: _standardOnly,
          onChanged:    (v) => setState(() => _standardOnly = v),
          c:            c),
        const SizedBox(height: 8),
        if (chartPoints.length >= 2) ...[
          _ModeChart(points: chartPoints, c: c),
          const SizedBox(height: 8),
          _ModeLegend(c: c),
        ] else
          _NotEnoughDataCard(sessions: chartPoints.length, c: c),
        const SizedBox(height: 12),
        _ModeSessionsList(
          points:       points.reversed.take(15).toList(),
          exerciseName: stat.name,
          modeLabel:    modeLabel,
          mode:         mode,
          c:            c),
      ],
    );
  }

  Widget _buildEmptyData(MarkFitColors c, double sysBottom) {
    return Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, sysBottom),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 72, height: 72,
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.1), shape: BoxShape.circle,
            border: Border.all(color: _teal.withOpacity(0.2))),
          child: const Icon(Icons.show_chart_rounded, color: _teal, size: 34)),
        const SizedBox(height: 20),
        Text('Nessun dato disponibile', style: TextStyle(
            color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Completa sessioni con pesi per vedere\ni tuoi progressi',
            style: TextStyle(color: c.textTertiary, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _loadData,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _teal.withOpacity(0.3))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh_rounded, color: _teal, size: 16),
              SizedBox(width: 8),
              Text('Aggiorna', style: TextStyle(
                  color: _teal, fontSize: 13, fontWeight: FontWeight.w600)),
            ]))),
      ]));
  }
}

// ─── _GlobalStatsBar ──────────────────────────────────────────

class _GlobalStatsBar extends StatelessWidget {
  final Map<String, _ExerciseStat> stats;
  final MarkFitColors              c;
  const _GlobalStatsBar({required this.stats, required this.c});

  @override
  Widget build(BuildContext context) {
    final totalSess = stats.values.fold<int>(0, (s, e) => s + e.totalSessions);
    final totalVol  = stats.values.fold<double>(0, (s, e) => s + e.totalVolume);
    final volLabel  = totalVol >= 1000
        ? '${(totalVol / 1000).toStringAsFixed(1)}t'
        : '${totalVol.toStringAsFixed(0)} kg';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _teal.withOpacity(0.2), width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 10,
                    offset: const Offset(0, 2))]
                : null),
          child: Row(children: [
            _SC('${stats.length}', 'Esercizi', _teal,   c),
            _D(c),
            _SC('$totalSess',      'Sessioni',  _cyan,   c),
            _D(c),
            _SC(volLabel,          'Volume',    _indigo, c),
          ]))));
  }
}

class _SC extends StatelessWidget {
  final String v, l; final Color color; final MarkFitColors c;
  const _SC(this.v, this.l, this.color, this.c);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(l, style: TextStyle(color: c.textTertiary, fontSize: 9, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center),
  ]));
}

class _D extends StatelessWidget {
  final MarkFitColors c; const _D(this.c);
  @override
  Widget build(BuildContext context) =>
      Container(width: 0.6, height: 28, color: c.divider);
}

// ─── _SearchField ────────────────────────────────────────────

class _SearchField extends StatefulWidget {
  final TextEditingController ctrl;
  final MarkFitColors         c;
  final bool                  isDark;
  final ValueChanged<String>  onChanged;
  const _SearchField({required this.ctrl, required this.c,
      required this.isDark, required this.onChanged});
  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
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
              hintText:  'Cerca esercizio...',
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
            onChanged: (v) {
              widget.onChanged(v);
              setState(() {});
            }))));
  }
}

// ─── _CategoryChips ──────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final List<String>         categories;
  final String               selected;
  final MarkFitColors        c;
  final ValueChanged<String> onSelect;
  const _CategoryChips({required this.categories, required this.selected,
      required this.c, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount:       categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cat   = categories[i];
          final isSel = cat == selected;
          final color = cat == 'Tutti' ? _cyan : _groupColor(cat);
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSel ? color.withOpacity(0.15) : c.glassCardInset,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isSel ? color.withOpacity(0.55) : c.glassBorder,
                  width: isSel ? 1.2 : 0.8),
                boxShadow: isSel && c.showElevation
                    ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 6)]
                    : null),
              child: Text(cat, style: TextStyle(
                  color: isSel ? color : c.textTertiary,
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500))));
        }));
  }
}

// ─── _ListHeader ─────────────────────────────────────────────

class _ListHeader extends StatelessWidget {
  final int count; final MarkFitColors c;
  const _ListHeader({required this.count, required this.c});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 28, height: 28,
      decoration: BoxDecoration(
          color: _teal.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.fitness_center_rounded, size: 14, color: _teal)),
    const SizedBox(width: 8),
    Text('$count esercizi tracciati', style: TextStyle(
        color: c.textPrimary, fontSize: 14,
        fontWeight: FontWeight.w700, letterSpacing: -0.2)),
  ]);
}

// ─── _ExerciseTile ───────────────────────────────────────────

class _ExerciseTile extends StatelessWidget {
  final _ExerciseStat stat;
  final MarkFitColors c;
  final VoidCallback  onTap;
  const _ExerciseTile({required this.stat, required this.c, required this.onTap});

  String _fmtW(double w) =>
      w % 1 == 0 ? '${w.toInt()} kg' : '${w.toStringAsFixed(1)} kg';

  @override
  Widget build(BuildContext context) {
    final imp      = stat.improvement;
    final impColor = imp > 0 ? _green : imp < 0 ? _red : c.textTertiary;
    final impLabel = imp > 0
        ? '+${imp.toStringAsFixed(0)}%'
        : imp < 0 ? '${imp.toStringAsFixed(0)}%' : '=';
    final grColor  = _groupColor(stat.muscleGroup);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: c.glassCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.glassBorder, width: 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 6,
                      offset: const Offset(0, 1))]
                  : null),
            child: Row(children: [
              // Icon
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: stat.muscleGroup.isEmpty
                      ? _teal.withOpacity(0.1)
                      : grColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: stat.muscleGroup.isEmpty
                          ? _teal.withOpacity(0.2)
                          : grColor.withOpacity(0.25), width: 0.7)),
                child: Icon(Icons.fitness_center_rounded, size: 17,
                    color: stat.muscleGroup.isEmpty ? _teal : grColor)),
              const SizedBox(width: 10),
              // Info
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(stat.name, style: TextStyle(
                    color:      c.textPrimary,
                    fontSize:   13,
                    fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  if (stat.muscleGroup.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: grColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: grColor.withOpacity(0.25), width: 0.6)),
                      child: Text(stat.muscleGroup, style: TextStyle(
                          color: grColor, fontSize: 10,
                          fontWeight: FontWeight.w600))),
                    const SizedBox(width: 6),
                  ],
                  Text('PR: ${_fmtW(stat.personalRecord)}',
                      style: TextStyle(color: c.textTertiary, fontSize: 10)),
                  Text(' · ${stat.totalSessions} sess.',
                      style: TextStyle(color: c.textTertiary, fontSize: 10)),
                ]),
              ])),
              const SizedBox(width: 8),
              // Improvement badge
              if (stat.points.length >= 2)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: impColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: impColor.withOpacity(0.3), width: 0.7)),
                  child: Text(impLabel, style: TextStyle(
                      color: impColor, fontSize: 10,
                      fontWeight: FontWeight.w700))),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  color: c.textTertiary, size: 16,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── _PRCard (aggregato "Tutte") ───────────────────────────────

class _PRCard extends StatelessWidget {
  final _ExerciseStat stat;
  final MarkFitColors c;
  const _PRCard({required this.stat, required this.c});

  String _fmtW(double w) =>
      w % 1 == 0 ? '${w.toInt()} kg' : '${w.toStringAsFixed(1)} kg';

  String _fmtVol(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)} t'
                : '${v.toStringAsFixed(0)} kg';

  @override
  Widget build(BuildContext context) {
    final imp      = stat.improvement;
    final impColor = imp > 0 ? _green : imp < 0 ? _red : c.textTertiary;
    final impLabel = imp > 0 ? '+${imp.toStringAsFixed(1)}%'
        : imp < 0 ? '${imp.toStringAsFixed(1)}%' : '=';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _teal.withOpacity(0.25), width: 0.9),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 12,
                    offset: const Offset(0, 2))]
                : null),
          child: Column(children: [
            Row(children: [
              _KpiCell(icon: Icons.emoji_events_rounded, color: _orange,
                  label: 'Record', value: _fmtW(stat.personalRecord), c: c),
              Container(width: 0.6, height: 44, color: c.divider),
              _KpiCell(icon: Icons.fitness_center_rounded, color: _teal,
                  label: 'Ultimo', value: _fmtW(stat.lastWeight), c: c),
              Container(width: 0.6, height: 44, color: c.divider),
              _KpiCell(icon: Icons.trending_up_rounded, color: impColor,
                  label: 'Progresso', value: impLabel, c: c),
            ]),
            const SizedBox(height: 12),
            Divider(height: 0, thickness: 0.5, color: c.divider),
            const SizedBox(height: 12),
            Row(children: [
              _KpiCell(icon: Icons.calendar_today_rounded, color: _cyan,
                  label: 'Sessioni',
                  value: '${stat.totalSessions}', c: c),
              Container(width: 0.6, height: 44, color: c.divider),
              _KpiCell(icon: Icons.stacked_bar_chart_rounded, color: _indigo,
                  label: 'Volume', value: _fmtVol(stat.totalVolume), c: c),
              Container(width: 0.6, height: 44, color: c.divider),
              _KpiCell(icon: Icons.repeat_rounded, color: _blue,
                  label: 'Max reps',
                  value: stat.points.isEmpty ? '-'
                      : '${stat.points.map((p) => p.maxReps).reduce(math.max)}',
                  c: c),
            ]),
          ]))));
  }
}

class _KpiCell extends StatelessWidget {
  final IconData icon; final Color color;
  final String label, value; final MarkFitColors c;
  const _KpiCell({required this.icon, required this.color,
      required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Container(width: 30, height: 30,
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 15, color: color)),
    const SizedBox(height: 5),
    Text(value, style: TextStyle(
        color: color, fontSize: 14, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(
        color: c.textTertiary, fontSize: 9, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center),
  ]));
}

// ─── _ChartModeToggle (aggregato "Tutte") ──────────────────────

class _ChartModeToggle extends StatelessWidget {
  final _ChartMode               mode;
  final ValueChanged<_ChartMode> onMode;
  final MarkFitColors            c;
  const _ChartModeToggle({required this.mode, required this.onMode,
      required this.c});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: c.glassCardInset,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.glassBorder, width: 0.8)),
          child: Row(children: _ChartMode.values.map((m) {
            final sel = m == mode;
            final lbl = m == _ChartMode.weight ? 'Peso (kg)' : 'Volume (kg)';
            return Expanded(child: GestureDetector(
              onTap: () => onMode(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: sel ? _teal.withOpacity(0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: sel
                      ? Border.all(color: _teal.withOpacity(0.5), width: 1)
                      : null),
                child: Center(child: Text(lbl, style: TextStyle(
                    color:      sel ? _teal : c.textTertiary,
                    fontSize:   11,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500))))));
          }).toList()))));
  }
}

// ─── _ProgressChart (aggregato "Tutte") ─────────────────────────

class _ProgressChart extends StatelessWidget {
  final List<_ProgressPoint> points;
  final _ChartMode           mode;
  final MarkFitColors        c;
  const _ProgressChart({required this.points, required this.mode,
      required this.c});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.glassBorder, width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 10,
                    offset: const Offset(0, 2))]
                : null),
          child: CustomPaint(
            painter: _ChartPainter(
              points:    points, mode: mode,
              isDark:    context.isDarkMode,
              teal:      _teal, cyan: _cyan,
              orange:    _orange,
              gridColor: c.divider,
              labelColor: c.textTertiary),
            size: const Size.fromHeight(168)))));
  }
}

class _ChartPainter extends CustomPainter {
  final List<_ProgressPoint> points;
  final _ChartMode           mode;
  final bool                 isDark;
  final Color                teal, cyan, orange, gridColor, labelColor;

  const _ChartPainter({
    required this.points, required this.mode,
    required this.isDark, required this.teal,
    required this.cyan, required this.orange,
    required this.gridColor, required this.labelColor,
  });

  List<double> get _vals => mode == _ChartMode.weight
      ? points.map((p) => p.maxWeight).toList()
      : points.map((p) => p.totalVolume).toList();

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final vals   = _vals;
    final minVal = vals.reduce(math.min);
    final maxVal = vals.reduce(math.max);
    final range  = (maxVal - minVal).clamp(1.0, double.infinity);

    const padL = 48.0, padR = 8.0, padT = 8.0, padB = 24.0;
    final w = size.width  - padL - padR;
    final h = size.height - padT - padB;

    // Grid
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = padT + h - h * i / 4;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridPaint);
      final v = minVal + range * i / 4;
      final lbl = v >= 1000 ? '${(v/1000).toStringAsFixed(1)}t'
                            : v.toStringAsFixed(0);
      _drawText(canvas, lbl, Offset(2, y - 6), 7.5, labelColor);
    }

    // X labels
    final step = math.max(1, (points.length / 5).ceil());
    for (var i = 0; i < points.length; i += step) {
      final x = padL + w * i / (points.length - 1);
      final d = points[i].date;
      _drawText(canvas, '${d.day}/${d.month}',
          Offset(x - 10, size.height - padB + 4), 7.5, labelColor);
    }

    // Compute points
    final pts = <Offset>[];
    for (var i = 0; i < vals.length; i++) {
      pts.add(Offset(
        padL + w * i / (vals.length - 1),
        padT + h - h * ((vals[i] - minVal) / range)));
    }

    // Fill
    final fillPath = Path()
      ..moveTo(pts.first.dx, padT + h)
      ..lineTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
      final cp2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    fillPath..lineTo(pts.last.dx, padT + h)..close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [teal.withOpacity(isDark ? 0.3 : 0.18),
                   teal.withOpacity(0.01)],
          stops: const [0, 1])
          .createShader(Rect.fromLTWH(0, padT, size.width, h))
      ..style = PaintingStyle.fill);

    // Line
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
      final cp2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(linePath, Paint()
      ..color = teal..strokeWidth = 2.2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // Dots + PR marker
    final prIdx = vals.indexOf(vals.reduce(math.max));
    for (var i = 0; i < pts.length; i++) {
      final pt    = pts[i];
      final isPR  = i == prIdx;
      final color = isPR ? orange : teal;
      canvas.drawCircle(pt, 5, Paint()
        ..color = color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(pt, isPR ? 5 : 4, Paint()..color = color);
      canvas.drawCircle(pt, isPR ? 2.5 : 2, Paint()..color = Colors.white);
    }
  }

  void _drawText(Canvas c, String t, Offset o, double sz, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: t,
          style: TextStyle(color: color, fontSize: sz,
              fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points || old.mode != mode || old.isDark != isDark;
}

// ─── _RecentSessions (aggregato "Tutte") ───────────────────────

class _RecentSessions extends StatelessWidget {
  final List<_ProgressPoint> points;
  final MarkFitColors        c;
  const _RecentSessions({required this.points, required this.c});

  String _fmtDate(DateTime d) {
    const m = ['','Gen','Feb','Mar','Apr','Mag','Giu',
        'Lug','Ago','Set','Ott','Nov','Dic'];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${m[d.month]} ${d.year}  $hh:$mm';
  }

  String _fmtW(double w) =>
      w % 1 == 0 ? '${w.toInt()} kg' : '${w.toStringAsFixed(1)} kg';

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final recent = points.reversed.take(6).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(
              color: _cyan.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.history_rounded, size: 14, color: _cyan)),
        const SizedBox(width: 8),
        Text('Sessioni recenti', style: TextStyle(
            color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
          child: Container(
            decoration: BoxDecoration(
              color: c.glassCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.glassBorder, width: 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 8,
                      offset: const Offset(0, 2))]
                  : null),
            child: Column(children: recent.asMap().entries.map((e) {
              final i     = e.key;
              final pt    = e.value;
              final isLast = i == recent.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Container(width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _teal.withOpacity(0.1),
                        shape: BoxShape.circle),
                      child: Center(child: Text('${i + 1}', style: const TextStyle(
                          color: _teal, fontSize: 11,
                          fontWeight: FontWeight.w700)))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(_fmtDate(pt.date), style: TextStyle(
                          color: c.textPrimary, fontSize: 13,
                          fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${pt.setsCount} serie · max ${pt.maxReps} reps',
                          style: TextStyle(color: c.textTertiary, fontSize: 10)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _teal.withOpacity(0.3), width: 0.7)),
                      child: Text(_fmtW(pt.maxWeight), style: const TextStyle(
                          color: _teal, fontSize: 12,
                          fontWeight: FontWeight.w700))),
                  ])),
                if (!isLast)
                  Divider(height: 0, thickness: 0.5,
                      indent: 14, endIndent: 14, color: c.divider),
              ]);
            }).toList())))),
    ]);
  }
}

// ─── _NotEnoughDataCard (condiviso) ─────────────────────────────

class _NotEnoughDataCard extends StatelessWidget {
  final int          sessions;
  final MarkFitColors c;
  const _NotEnoughDataCard({required this.sessions, required this.c});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _indigo.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _indigo.withOpacity(0.2), width: 0.8)),
        child: Row(children: [
          Icon(Icons.info_outline_rounded,
              color: _indigo.withOpacity(0.7), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(
            sessions == 1
                ? 'Completa almeno 2 sessioni per visualizzare il grafico.'
                : 'Servono almeno 2 sessioni con dati validi per il grafico.',
            style: TextStyle(
                color: c.textTertiary, fontSize: 12, height: 1.5))),
        ]))));
}

// ─── _EmptySearch ─────────────────────────────────────────────

class _EmptySearch extends StatelessWidget {
  final MarkFitColors c;
  const _EmptySearch({required this.c});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text('Nessun esercizio trovato',
        style: TextStyle(color: c.textTertiary, fontSize: 13))));
}

// ═════════════════════════════════════════════════════════════
// FASE 5 — Storico e grafici per esercizio + modalità
// ═════════════════════════════════════════════════════════════

// ─── _ModeScopeChips ────────────────────────────────────────

class _ModeScopeChips extends StatelessWidget {
  final List<dynamic>       modeKeys;
  final dynamic              selected;
  final TrainingModeProvider tp;
  final MarkFitColors        c;
  final ValueChanged<dynamic> onSelect;
  const _ModeScopeChips({
    required this.modeKeys, required this.selected,
    required this.tp, required this.c, required this.onSelect,
  });

  String _labelFor(dynamic k) {
    if (k == null) return 'Legacy';
    final m = tp.getByKey(k);
    return m?.structureLabel ?? 'Eliminata';
  }

  @override
  Widget build(BuildContext context) {
    final items = <dynamic>[_allScopeSentinel, ...modeKeys];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final k     = items[i];
          final isAll = k == _allScopeSentinel;
          final sel   = selected == k;
          final label = isAll ? 'Tutte' : _labelFor(k);
          final color = isAll ? _cyan : _indigo;
          return GestureDetector(
            onTap: () => onSelect(k),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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

// ─── _ModePRCard ────────────────────────────────────────────

class _ModePRCard extends StatelessWidget {
  final String        modeLabel;
  final double?        record, last;
  final double?        improvement;
  final int            totalSessions;
  final MarkFitColors  c;
  const _ModePRCard({
    required this.modeLabel, required this.record, required this.last,
    required this.improvement, required this.totalSessions, required this.c,
  });

  String _fmtW(double? w) => w == null
      ? '-'
      : (w % 1 == 0 ? '${w.toInt()} kg' : '${w.toStringAsFixed(1)} kg');

  @override
  Widget build(BuildContext context) {
    final impColor = improvement == null
        ? c.textTertiary
        : improvement! > 0 ? _green : improvement! < 0 ? _red : c.textTertiary;
    final impLabel = improvement == null
        ? '-'
        : (improvement! > 0 ? '+${improvement!.toStringAsFixed(1)}%'
            : improvement! < 0 ? '${improvement!.toStringAsFixed(1)}%' : '=');

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _indigo.withOpacity(0.25), width: 0.9),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 12,
                    offset: const Offset(0, 2))]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.repeat_rounded, size: 15, color: _indigo),
                const SizedBox(width: 6),
                Expanded(child: Text(modeLabel, style: TextStyle(
                    color: c.textPrimary, fontSize: 13,
                    fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _KpiCell(icon: Icons.emoji_events_rounded, color: _orange,
                    label: 'Record', value: _fmtW(record), c: c),
                Container(width: 0.6, height: 44, color: c.divider),
                _KpiCell(icon: Icons.fitness_center_rounded, color: _teal,
                    label: 'Ultimo', value: _fmtW(last), c: c),
                Container(width: 0.6, height: 44, color: c.divider),
                _KpiCell(icon: Icons.trending_up_rounded, color: impColor,
                    label: 'Progresso', value: impLabel, c: c),
                Container(width: 0.6, height: 44, color: c.divider),
                _KpiCell(icon: Icons.calendar_today_rounded, color: _cyan,
                    label: 'Sessioni', value: '$totalSessions', c: c),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── _StandardCompleteToggle ────────────────────────────────

class _StandardCompleteToggle extends StatelessWidget {
  final bool                standardOnly;
  final ValueChanged<bool>  onChanged;
  final MarkFitColors       c;
  const _StandardCompleteToggle({
    required this.standardOnly, required this.onChanged, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: c.glassCardInset,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.glassBorder, width: 0.8),
          ),
          child: Row(children: [
            Expanded(child: _btn('Completo', !standardOnly,
                () => onChanged(false))),
            Expanded(child: _btn('Solo Standard', standardOnly,
                () => onChanged(true))),
          ]),
        ),
      ),
    );
  }

  Widget _btn(String label, bool sel, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: sel ? _teal.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: sel
                ? Border.all(color: _teal.withOpacity(0.5), width: 1)
                : null,
          ),
          child: Center(child: Text(label, style: TextStyle(
              color:      sel ? _teal : c.textTertiary,
              fontSize:   11,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500))),
        ),
      );
}

// ─── _ModeChart / _ModeChartPainter ──────────────────────────

class _ModeChart extends StatelessWidget {
  final List<_ModePoint> points;
  final MarkFitColors    c;
  const _ModeChart({required this.points, required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (details) => _handleTap(context, details),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
          child: Container(
            height: 200,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            decoration: BoxDecoration(
              color: c.glassCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.glassBorder, width: 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 10,
                      offset: const Offset(0, 2))]
                  : null,
            ),
            child: CustomPaint(
              painter: _ModeChartPainter(
                points: points, gridColor: c.divider,
                labelColor: c.textTertiary),
              size: const Size.fromHeight(168),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, TapUpDetails details) {
    // Tocco approssimato: trova il punto più vicino sull'asse X.
    // L'area del grafico è disegnata dal painter con lo stesso
    // sistema di coordinate qui ricostruito.
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || points.isEmpty) return;
    final local = details.localPosition;
    const padL = 12.0 + 48.0, padR = 12.0 + 8.0;
    final w = box.size.width - padL - padR;
    if (w <= 0) return;
    final relX = ((local.dx - padL) / w).clamp(0.0, 1.0);
    final idx  = (relX * (points.length - 1)).round()
        .clamp(0, points.length - 1);
    _showPointDetailFromChart(context, points[idx]);
  }
}

void _showPointDetailFromChart(BuildContext context, _ModePoint p) {
  // Il chiamante reale (con nome esercizio/modalità) è gestito da
  // _ModeSessionsList; il tap diretto sul grafico apre comunque il
  // dettaglio con le informazioni disponibili sul punto stesso.
  final c = context.mfc;
  final tp = context.read<TrainingModeProvider>();
  final mode = p.modeKey == null ? null : tp.getByKey(p.modeKey);
  final modeLabel = p.modeKey == null
      ? 'Legacy (nessuna modalità)'
      : (mode?.structureLabel ?? 'Modalità eliminata');
  _showPointDetail(context, c, '', modeLabel, mode, p);
}

class _ModeChartPainter extends CustomPainter {
  final List<_ModePoint> points;
  final Color             gridColor, labelColor;
  const _ModeChartPainter({
    required this.points, required this.gridColor, required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final values = points.map((p) => p.value!).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range  = (maxVal - minVal).clamp(1.0, double.infinity);

    const padL = 48.0, padR = 8.0, padT = 8.0, padB = 24.0;
    final w = size.width  - padL - padR;
    final h = size.height - padT - padB;

    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = padT + h - h * i / 4;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridPaint);
      final v = minVal + range * i / 4;
      _drawText(canvas,
          v >= 1000 ? '${(v/1000).toStringAsFixed(1)}t' : v.toStringAsFixed(0),
          Offset(2, y - 6), 7.5, labelColor);
    }

    final step = math.max(1, (points.length / 5).ceil());
    for (var i = 0; i < points.length; i += step) {
      final x = padL + w * i / (points.length - 1);
      final d = points[i].date;
      _drawText(canvas, '${d.day}/${d.month}',
          Offset(x - 10, size.height - padB + 4), 7.5, labelColor);
    }

    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      pts.add(Offset(
        padL + w * i / (values.length - 1),
        padT + h - h * ((values[i] - minVal) / range)));
    }

    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
      final cp2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(linePath, Paint()
      ..color = _teal.withOpacity(0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    // Marker distinti per stato (Parte 37 — mai solo colore).
    for (var i = 0; i < pts.length; i++) {
      final pt   = pts[i];
      final meta = _statusMeta(points[i].status);
      canvas.drawCircle(pt, 6, Paint()
        ..color = meta.color.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      switch (points[i].status) {
        case 'standard':
          canvas.drawCircle(pt, 4.5, Paint()..color = meta.color);
          canvas.drawCircle(pt, 2, Paint()..color = Colors.white);
          break;
        case 'partial':
          canvas.drawCircle(pt, 4.5, Paint()
            ..color = meta.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
          break;
        case 'custom':
          const r = 5.5;
          final path = Path()
            ..moveTo(pt.dx, pt.dy - r)
            ..lineTo(pt.dx + r, pt.dy)
            ..lineTo(pt.dx, pt.dy + r)
            ..lineTo(pt.dx - r, pt.dy)
            ..close();
          canvas.drawPath(path, Paint()..color = meta.color);
          break;
        default:
          canvas.drawCircle(pt, 4, Paint()..color = meta.color);
      }
    }
  }

  void _drawText(Canvas c, String t, Offset o, double sz, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: t,
          style: TextStyle(color: color, fontSize: sz,
              fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _ModeChartPainter old) => old.points != points;
}

// ─── _ModeLegend ─────────────────────────────────────────────

class _ModeLegend extends StatelessWidget {
  final MarkFitColors c;
  const _ModeLegend({required this.c});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
            color: c.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
    return Wrap(spacing: 14, runSpacing: 6, children: [
      item(Icons.circle_rounded, 'Standard', _green),
      item(Icons.circle_outlined, 'Parziale', _orange),
      item(Icons.diamond_rounded, 'Custom', _indigo),
    ]);
  }
}

// ─── _ModeSessionsList ───────────────────────────────────────

class _ModeSessionsList extends StatelessWidget {
  final List<_ModePoint> points;
  final String            exerciseName;
  final String            modeLabel;
  final TrainingMode?     mode;
  final MarkFitColors     c;
  const _ModeSessionsList({
    required this.points, required this.exerciseName,
    required this.modeLabel, required this.mode, required this.c,
  });

  String _fmtDate(DateTime d) {
    const m = ['','Gen','Feb','Mar','Apr','Mag','Giu',
        'Lug','Ago','Set','Ott','Nov','Dic'];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${m[d.month]} ${d.year}  $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(
              color: _cyan.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.history_rounded, size: 14, color: _cyan)),
        const SizedBox(width: 8),
        Text('Sessioni recenti', style: TextStyle(
            color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
          child: Container(
            decoration: BoxDecoration(
              color: c.glassCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.glassBorder, width: 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 8,
                      offset: const Offset(0, 2))]
                  : null,
            ),
            child: Column(children: points.asMap().entries.map((e) {
              final i      = e.key;
              final p      = e.value;
              final meta   = _statusMeta(p.status);
              final isLast = i == points.length - 1;
              return GestureDetector(
                onTap: () => _showPointDetail(
                    context, c, exerciseName, modeLabel, mode, p),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(children: [
                      Container(width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: meta.color.withOpacity(0.12),
                          shape: BoxShape.circle),
                        child: Icon(meta.icon, size: 14, color: meta.color)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fmtDate(p.date), style: TextStyle(
                              color: c.textPrimary, fontSize: 13,
                              fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(meta.label, style: TextStyle(
                              color: meta.color, fontSize: 10,
                              fontWeight: FontWeight.w600)),
                        ],
                      )),
                      if (p.value != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _teal.withOpacity(0.3), width: 0.7)),
                          child: Text('${p.value!.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                  color: _teal, fontSize: 12,
                                  fontWeight: FontWeight.w700)))
                      else
                        Text('corpo libero', style: TextStyle(
                            color: c.textTertiary, fontSize: 11,
                            fontStyle: FontStyle.italic)),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded,
                          color: c.textTertiary, size: 16),
                    ]),
                  ),
                  if (!isLast)
                    Divider(height: 0, thickness: 0.5,
                        indent: 14, endIndent: 14, color: c.divider),
                ]),
              );
            }).toList()),
          ),
        ),
      ),
    ]);
  }
}

// ─── Popup dettaglio punto ───────────────────────────────────

String _modeFmtWeight(double w) =>
    w % 1 == 0 ? '${w.toInt()} kg' : '${w.toStringAsFixed(1)} kg';

String _modeFmtDateTimeFull(DateTime d) {
  const m = ['','Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
      'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${m[d.month]} ${d.year} — $hh:$mm';
}

void _showPointDetail(
  BuildContext context,
  MarkFitColors c,
  String exerciseName,
  String modeLabel,
  TrainingMode? mode,
  _ModePoint p,
) {
  final meta = _statusMeta(p.status);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => GlassSheetWrapper(
      title: exerciseName.isNotEmpty ? exerciseName : 'Dettaglio sessione',
      subtitle: _modeFmtDateTimeFull(p.date),
      accentColor: meta.color,
      leadingIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: meta.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(meta.icon, color: meta.color, size: 20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: meta.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: meta.color.withOpacity(0.35))),
              child: Text(meta.label, style: TextStyle(
                  color: meta.color, fontSize: 12,
                  fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Expanded(child: Text(modeLabel, style: TextStyle(
                color: c.textTertiary, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 12),
          if (p.value != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _teal.withOpacity(0.25))),
              child: Row(children: [
                const Icon(Icons.emoji_events_rounded,
                    color: _teal, size: 18),
                const SizedBox(width: 8),
                Text('Valore stimato: ', style: TextStyle(
                    color: c.textSecondary, fontSize: 13)),
                Text('${p.value!.toStringAsFixed(1)} kg', style: const TextStyle(
                    color: _teal, fontSize: 15, fontWeight: FontWeight.w800)),
              ]))
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.glassCardInset,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.glassBorder)),
              child: Text(
                  'Nessuna serie zavorrata valida — sessione a corpo libero.',
                  style: TextStyle(color: c.textTertiary, fontSize: 12,
                      fontStyle: FontStyle.italic))),
          const SizedBox(height: 16),
          Text('Serie eseguite', style: TextStyle(
              color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...p.sets.map((s) {
            final ordered = mode?.orderedSets;
            final expected = (ordered != null && s.setNumber - 1 < ordered.length)
                ? ordered[s.setNumber - 1].label
                : null;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 22, child: Text('${s.setNumber}',
                    style: TextStyle(color: c.textTertiary, fontSize: 12,
                        fontWeight: FontWeight.w700))),
                Icon(s.completed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 15,
                    color: s.completed ? _green : c.textTertiary),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    s.weight > 0
                        ? '${_modeFmtWeight(s.weight)} × ${s.reps} reps'
                        : '${s.reps} reps (corpo libero)',
                    style: TextStyle(color: c.textPrimary, fontSize: 13))),
                if (expected != null)
                  Text('previsto: $expected', style: TextStyle(
                      color: c.textTertiary, fontSize: 11)),
              ]),
            );
          }),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: c.glassCardInset,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.glassBorder)),
              child: Text('Chiudi', textAlign: TextAlign.center,
                  style: TextStyle(color: c.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w600))),
          ),
        ],
      ),
    ),
  );
}