import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/markfit_colors.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import '../../widgets/cosmic_background.dart';

// ─────────────────────────────────────────────────────────────
// Accent tokens
// ─────────────────────────────────────────────────────────────

const _cyan   = MarkFitColors.cyan;
const _teal   = MarkFitColors.teal;
const _tealDk = MarkFitColors.tealDk;
const _indigo = MarkFitColors.indigo;
const _orange = MarkFitColors.orange;
const _green  = MarkFitColors.green;
const _blue   = MarkFitColors.blue;

// ─────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────

class _ProgressPoint {
  final DateTime date;
  final double   maxWeight;
  final double   totalVolume;
  final int      maxReps;
  final int      setsCount;

  const _ProgressPoint({
    required this.date,
    required this.maxWeight,
    required this.totalVolume,
    required this.maxReps,
    required this.setsCount,
  });
}

class _ExerciseStat {
  final String           name;
  final double           personalRecord;
  final int              totalSessions;
  final double           totalVolume;
  final List<_ProgressPoint> points;

  const _ExerciseStat({
    required this.name,
    required this.personalRecord,
    required this.totalSessions,
    required this.totalVolume,
    required this.points,
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

// ─────────────────────────────────────────────────────────────
// ExerciseProgressScreen
// ─────────────────────────────────────────────────────────────

class ExerciseProgressScreen extends StatefulWidget {
  const ExerciseProgressScreen({super.key});
  @override
  State<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState
    extends State<ExerciseProgressScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  bool   _loading       = true;
  String _search        = '';
  String? _selectedName;
  _ChartMode _chartMode = _ChartMode.weight;

  Map<String, _ExerciseStat> _stats = {};
  List<String>               _names = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final sessions = HiveDatabase.instance.getSessions();
    final Map<String, Map<String, List<HiveSessionSet>>> byExerciseByDate = {};

    for (final session in sessions) {
      final dateStr = session.date.length >= 10
          ? session.date.substring(0, 10) : session.date;
      final sets    = HiveDatabase.instance.getSessionSets(session.key);

      for (final set in sets.where((s) => s.completed && s.weight > 0)) {
        byExerciseByDate
            .putIfAbsent(set.exerciseName, () => {})
            .putIfAbsent(dateStr, () => [])
            .add(set);
      }
    }

    // Build stats
    final Map<String, _ExerciseStat> newStats = {};

    for (final entry in byExerciseByDate.entries) {
      final name       = entry.key;
      final byDate     = entry.value;
      final points     = <_ProgressPoint>[];
      double pr        = 0;
      double totalVol  = 0;

      final sortedDates = byDate.keys.toList()..sort();

      for (final dateStr in sortedDates) {
        final daySets   = byDate[dateStr]!;
        final maxW      = daySets.map((s) => s.weight).reduce(math.max);
        final vol       = daySets.fold<double>(
            0, (sum, s) => sum + s.weight * s.reps);
        final maxReps   = daySets.map((s) => s.reps).reduce(math.max);

        if (maxW > pr) pr = maxW;
        totalVol += vol;

        points.add(_ProgressPoint(
          date:        DateTime.tryParse(dateStr) ?? DateTime.now(),
          maxWeight:   maxW,
          totalVolume: vol,
          maxReps:     maxReps,
          setsCount:   daySets.length,
        ));
      }

      newStats[name] = _ExerciseStat(
        name:           name,
        personalRecord: pr,
        totalSessions:  points.length,
        totalVolume:    totalVol,
        points:         points,
      );
    }

    // Sort by frequency (most used first)
    final sortedNames = newStats.keys.toList()
      ..sort((a, b) =>
          newStats[b]!.totalSessions.compareTo(newStats[a]!.totalSessions));

    if (mounted) {
      setState(() {
        _stats    = newStats;
        _names    = sortedNames;
        _selectedName = sortedNames.isNotEmpty ? sortedNames.first : null;
        _loading  = false;
      });
    }
  }

  List<String> get _filtered {
    if (_search.isEmpty) return _names;
    return _names.where((n) =>
        n.toLowerCase().contains(_search.toLowerCase())).toList();
  }

  _ExerciseStat? get _selected =>
      _selectedName != null ? _stats[_selectedName] : null;

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c         = context.mfc;
    final sysBottom = MediaQuery.of(context).viewPadding.bottom;
    final isDark    = context.isDarkMode;

    return Scaffold(
      backgroundColor:          Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: CosmicBackground(
        child: SafeArea(
          child: Column(children: [

            // ── Glass AppBar (pushed screen) ───────────────
            _buildAppBar(context, c),

            // ── Contenuto ─────────────────────────────────
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(
                      color: _teal, strokeWidth: 2))
                  : _stats.isEmpty
                      ? _buildEmpty(c)
                      : _buildContent(context, c, sysBottom)),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // AppBar
  // ─────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, MarkFitColors c) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: c.glassBlurStrong, sigmaY: c.glassBlurStrong),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            border: Border(bottom: BorderSide(
                color: _teal.withOpacity(0.2), width: 0.7)),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 8,
                    offset: const Offset(0, 2))]
                : null),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            // Back button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.glassCardInset,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: c.glassBorder, width: 0.8)),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15, color: c.iconPrimary))),
            const SizedBox(width: 12),
            // Titolo
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('Progressi', style: TextStyle(
                  color:        c.textPrimary,
                  fontSize:     17,
                  fontWeight:   FontWeight.w800,
                  letterSpacing: -0.3)),
              Text('Andamento esercizi nel tempo', style: TextStyle(
                  color: c.textTertiary, fontSize: 11)),
            ])),
            // Refresh
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

  // ─────────────────────────────────────────────────────────
  // Main content — due colonne su tablet, lista + dettaglio
  // su mobile (dettaglio mostrato sotto la lista selezionata)
  // ─────────────────────────────────────────────────────────

  Widget _buildContent(
      BuildContext context, MarkFitColors c, double sysBottom) {
    final width = MediaQuery.of(context).size.width;
    final useColumns = width > 700;

    if (useColumns) {
      return Row(children: [
        SizedBox(
          width: 260,
          child: _buildExerciseList(context, c, sysBottom)),
        Container(width: 0.5, color: c.divider),
        Expanded(child: _buildDetail(context, c, sysBottom)),
      ]);
    }

    return _buildMobileLayout(context, c, sysBottom);
  }

  // ─────────────────────────────────────────────────────────
  // Mobile layout — lista sopra, dettaglio sotto (collapsed)
  // ─────────────────────────────────────────────────────────

  Widget _buildMobileLayout(
      BuildContext context, MarkFitColors c, double sysBottom) {
    final filtered = _filtered;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 88 + sysBottom),
      children: [
        // Ricerca
        _SearchField(ctrl: _searchCtrl, c: c,
            onChanged: (v) => setState(() => _search = v)),
        const SizedBox(height: 12),

        // Stats globali
        if (_stats.isNotEmpty) ...[
          _GlobalStatsBar(stats: _stats, c: c),
          const SizedBox(height: 12),
        ],

        // Selettore esercizio + dettaglio inline
        if (filtered.isEmpty)
          _EmptySearch(c: c)
        else ...[
          // Header lista
          _ListHeader(count: filtered.length, c: c),
          const SizedBox(height: 8),

          ...filtered.map((name) {
            final stat   = _stats[name]!;
            final isSel  = name == _selectedName;
            return Column(children: [
              _ExerciseListTile(
                stat:       stat,
                isSelected: isSel,
                c:          c,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedName = name);
                }),
              // Dettaglio inline sotto il tile selezionato
              if (isSel && _selected != null) ...[
                const SizedBox(height: 8),
                _DetailPanel(
                    stat:      _selected!,
                    mode:      _chartMode,
                    onMode:    (m) => setState(() => _chartMode = m),
                    c:         c),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
            ]);
          }),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // Lista esercizi (tablet)
  // ─────────────────────────────────────────────────────────

  Widget _buildExerciseList(
      BuildContext context, MarkFitColors c, double sysBottom) {
    final filtered = _filtered;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: _SearchField(ctrl: _searchCtrl, c: c,
            onChanged: (v) => setState(() => _search = v))),
      Expanded(
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(12, 0, 12, 88 + sysBottom),
          itemCount: filtered.isEmpty ? 1 : filtered.length,
          itemBuilder: (_, i) {
            if (filtered.isEmpty) return _EmptySearch(c: c);
            final name = filtered[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ExerciseListTile(
                stat:       _stats[name]!,
                isSelected: name == _selectedName,
                c:          c,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedName = name);
                }));
          })),
    ]);
  }

  // ─────────────────────────────────────────────────────────
  // Dettaglio (tablet — colonna destra)
  // ─────────────────────────────────────────────────────────

  Widget _buildDetail(
      BuildContext context, MarkFitColors c, double sysBottom) {
    if (_selected == null) {
      return Center(child: Text('Seleziona un esercizio',
          style: TextStyle(color: c.textTertiary, fontSize: 14)));
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 88 + sysBottom),
      child: _DetailPanel(
          stat:   _selected!,
          mode:   _chartMode,
          onMode: (m) => setState(() => _chartMode = m),
          c:      c));
  }

  // ─────────────────────────────────────────────────────────
  // Empty states
  // ─────────────────────────────────────────────────────────

  Widget _buildEmpty(MarkFitColors c) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64,
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.show_chart_rounded,
              color: _teal, size: 30)),
        const SizedBox(height: 16),
        Text('Nessun dato ancora', style: TextStyle(
            color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Completa qualche sessione per vedere\ni tuoi progressi',
            style: TextStyle(color: c.textTertiary, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center),
      ])));
  }
}

// ─────────────────────────────────────────────────────────────
// _GlobalStatsBar — stats di riepilogo
// ─────────────────────────────────────────────────────────────

class _GlobalStatsBar extends StatelessWidget {
  final Map<String, _ExerciseStat> stats;
  final MarkFitColors c;
  const _GlobalStatsBar({required this.stats, required this.c});

  @override
  Widget build(BuildContext context) {
    final totalSessions = stats.values
        .fold<int>(0, (sum, s) => sum + s.totalSessions);
    final totalVolume   = stats.values
        .fold<double>(0, (sum, s) => sum + s.totalVolume);
    final exCount       = stats.length;

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
            _StatCell('$exCount',         'Esercizi',  _teal,   c),
            _StatDivider(c),
            _StatCell('$totalSessions',   'Sessioni',  _cyan,   c),
            _StatDivider(c),
            _StatCell('${(totalVolume / 1000).toStringAsFixed(1)}t',
                                          'Volume',   _indigo, c),
          ]))));
  }
}

class _StatCell extends StatelessWidget {
  final String value, label; final Color color; final MarkFitColors c;
  const _StatCell(this.value, this.label, this.color, this.c);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(
        color: color, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(
        color: c.textTertiary, fontSize: 9, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center),
  ]));
}

class _StatDivider extends StatelessWidget {
  final MarkFitColors c;
  const _StatDivider(this.c);
  @override
  Widget build(BuildContext context) =>
      Container(width: 0.6, height: 28, color: c.divider);
}

// ─────────────────────────────────────────────────────────────
// _ListHeader
// ─────────────────────────────────────────────────────────────

class _ListHeader extends StatelessWidget {
  final int count; final MarkFitColors c;
  const _ListHeader({required this.count, required this.c});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 28, height: 28,
      decoration: BoxDecoration(
          color: _teal.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.fitness_center_rounded,
          size: 14, color: _teal)),
    const SizedBox(width: 8),
    Text('$count esercizi tracciati', style: TextStyle(
        color: c.textPrimary, fontSize: 14,
        fontWeight: FontWeight.w700, letterSpacing: -0.2)),
  ]);
}

// ─────────────────────────────────────────────────────────────
// _SearchField — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final MarkFitColors         c;
  final ValueChanged<String>  onChanged;
  const _SearchField({required this.ctrl, required this.c,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: c.inputBg,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: c.inputBorder,
                width: isDark ? 0.8 : 1.0)),
          child: TextField(
            controller:         ctrl,
            style:              TextStyle(color: c.inputText, fontSize: 14),
            keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
            decoration: InputDecoration(
              hintText:  'Cerca esercizio...',
              hintStyle: TextStyle(color: c.inputHint, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded,
                  color: c.iconSecondary, size: 18),
              suffixIcon: ctrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () { ctrl.clear(); onChanged(''); },
                      child: Icon(Icons.close_rounded,
                          color: c.iconSecondary, size: 16))
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13)),
            onChanged: onChanged))));
  }
}

// ─────────────────────────────────────────────────────────────
// _ExerciseListTile — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _ExerciseListTile extends StatelessWidget {
  final _ExerciseStat stat;
  final bool          isSelected;
  final MarkFitColors c;
  final VoidCallback  onTap;
  const _ExerciseListTile({required this.stat, required this.isSelected,
      required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imp     = stat.improvement;
    final impColor = imp > 0 ? _green : imp < 0 ? MarkFitColors.red : c.textTertiary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? _teal.withOpacity(0.12) : c.glassCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _teal.withOpacity(0.55) : c.glassBorder,
            width: isSelected ? 1.2 : 0.8),
          boxShadow: isSelected && c.showElevation
              ? [BoxShadow(color: c.elevationColor, blurRadius: 8,
                  offset: const Offset(0, 2))]
              : c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 4)]
                  : null),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(children: [
            // Icona
            Container(width: 36, height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? _teal.withOpacity(0.18) : c.glassCardInset,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected
                    ? _teal.withOpacity(0.4) : c.glassBorder, width: 0.7)),
              child: Icon(Icons.fitness_center_rounded, size: 17,
                  color: isSelected ? _teal : c.iconSecondary)),
            const SizedBox(width: 10),
            // Info
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stat.name, style: TextStyle(
                  color: c.textPrimary, fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('PR: ${_fmtW(stat.personalRecord)} · '
                  '${stat.totalSessions} sess.',
                  style: TextStyle(
                      color: c.textTertiary, fontSize: 10)),
            ])),
            // Miglioramento
            if (stat.points.length >= 2) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: impColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: impColor.withOpacity(0.3), width: 0.7)),
                child: Text(
                  '${imp >= 0 ? '+' : ''}${imp.toStringAsFixed(0)}%',
                  style: TextStyle(color: impColor, fontSize: 10,
                      fontWeight: FontWeight.w700))),
            ],
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(Icons.expand_less_rounded, color: _teal, size: 16),
            ],
          ]))));
  }

  String _fmtW(double w) =>
      w % 1 == 0 ? '${w.toInt()} kg' : '${w.toStringAsFixed(1)} kg';
}

// ─────────────────────────────────────────────────────────────
// _DetailPanel — grafico + stats + sessioni recenti
// ─────────────────────────────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  final _ExerciseStat stat;
  final _ChartMode    mode;
  final ValueChanged<_ChartMode> onMode;
  final MarkFitColors c;
  const _DetailPanel({required this.stat, required this.mode,
      required this.onMode, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titolo pannello
        _PanelHeader(name: stat.name, c: c),
        const SizedBox(height: 12),

        // Record personale + stats
        _PRCard(stat: stat, c: c),
        const SizedBox(height: 12),

        // Grafico
        if (stat.points.length >= 2) ...[
          _ChartModeToggle(mode: mode, onMode: onMode, c: c),
          const SizedBox(height: 8),
          _ProgressChart(points: stat.points, mode: mode, c: c),
          const SizedBox(height: 12),
        ],

        // Sessioni recenti
        _RecentSessions(points: stat.points, c: c),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _PanelHeader
// ─────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final String name; final MarkFitColors c;
  const _PanelHeader({required this.name, required this.c});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 32, height: 32,
      decoration: BoxDecoration(
          color: _teal.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9)),
      child: const Icon(Icons.show_chart_rounded, size: 16, color: _teal)),
    const SizedBox(width: 10),
    Expanded(child: Text(name, style: TextStyle(
        color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800,
        letterSpacing: -0.3),
        maxLines: 1, overflow: TextOverflow.ellipsis)),
  ]);
}

// ─────────────────────────────────────────────────────────────
// _PRCard — record personale e statistiche aggregate
// ─────────────────────────────────────────────────────────────

class _PRCard extends StatelessWidget {
  final _ExerciseStat stat; final MarkFitColors c;
  const _PRCard({required this.stat, required this.c});

  String _fmtW(double w) =>
      w % 1 == 0 ? '${w.toInt()} kg' : '${w.toStringAsFixed(1)} kg';

  String _fmtVol(double v) =>
      v >= 1000
          ? '${(v / 1000).toStringAsFixed(1)} t'
          : '${v.toStringAsFixed(0)} kg';

  @override
  Widget build(BuildContext context) {
    final imp      = stat.improvement;
    final impColor = imp > 0 ? _green : imp < 0 ? MarkFitColors.red : c.textTertiary;
    final impLabel = imp > 0
        ? '+${imp.toStringAsFixed(1)}%'
        : imp < 0
            ? '${imp.toStringAsFixed(1)}%'
            : '=';

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
            // PR + carico attuale
            Row(children: [
              Expanded(child: _KpiCell(
                icon:  Icons.emoji_events_rounded,
                color: _orange,
                label: 'Record personale',
                value: _fmtW(stat.personalRecord),
                c:     c)),
              Container(width: 0.6, height: 44, color: c.divider),
              Expanded(child: _KpiCell(
                icon:  Icons.fitness_center_rounded,
                color: _teal,
                label: 'Ultimo carico',
                value: _fmtW(stat.lastWeight),
                c:     c)),
              Container(width: 0.6, height: 44, color: c.divider),
              Expanded(child: _KpiCell(
                icon:  Icons.trending_up_rounded,
                color: impColor,
                label: 'Progresso',
                value: impLabel,
                c:     c)),
            ]),
            const SizedBox(height: 12),
            Divider(height: 0, thickness: 0.5, color: c.divider),
            const SizedBox(height: 12),
            // Sessioni + volume totale
            Row(children: [
              Expanded(child: _KpiCell(
                icon:  Icons.calendar_today_rounded,
                color: _cyan,
                label: 'Sessioni',
                value: '${stat.totalSessions}',
                c:     c)),
              Container(width: 0.6, height: 44, color: c.divider),
              Expanded(child: _KpiCell(
                icon:  Icons.stacked_bar_chart_rounded,
                color: _indigo,
                label: 'Volume totale',
                value: _fmtVol(stat.totalVolume),
                c:     c)),
            ]),
          ]))));
  }
}

class _KpiCell extends StatelessWidget {
  final IconData      icon;
  final Color         color;
  final String        label, value;
  final MarkFitColors c;
  const _KpiCell({required this.icon, required this.color,
      required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(width: 32, height: 32,
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9)),
      child: Icon(icon, size: 16, color: color)),
    const SizedBox(height: 6),
    Text(value, style: TextStyle(
        color: color, fontSize: 15, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(
        color: c.textTertiary, fontSize: 9, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center),
  ]);
}

// ─────────────────────────────────────────────────────────────
// _ChartModeToggle
// ─────────────────────────────────────────────────────────────

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
          height: 34,
          decoration: BoxDecoration(
            color: c.glassCardInset,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.glassBorder, width: 0.8)),
          child: Row(children: _ChartMode.values.map((m) {
            final sel   = m == mode;
            final label = m == _ChartMode.weight ? 'Carico (kg)' : 'Volume (kg)';
            return Expanded(child: GestureDetector(
              onTap: () => onMode(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: sel ? _teal.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: sel ? Border.all(
                      color: _teal.withOpacity(0.5), width: 1) : null),
                child: Center(child: Text(label, style: TextStyle(
                    color:      sel ? _teal : c.textTertiary,
                    fontSize:   11,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500))))));
          }).toList()))));
  }
}

// ─────────────────────────────────────────────────────────────
// _ProgressChart — grafico adattivo con CustomPaint
// ─────────────────────────────────────────────────────────────

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
                points:  points,
                mode:    mode,
                isDark:  context.isDarkMode,
                teal:    _teal,
                cyan:    _cyan,
                divider: c.divider,
                textColor: c.textTertiary),
            size: const Size.fromHeight(168)))));
  }
}

class _ChartPainter extends CustomPainter {
  final List<_ProgressPoint> points;
  final _ChartMode           mode;
  final bool                 isDark;
  final Color                teal, cyan, divider, textColor;

  const _ChartPainter({
    required this.points, required this.mode,
    required this.isDark, required this.teal,
    required this.cyan, required this.divider,
    required this.textColor});

  List<double> get _values => mode == _ChartMode.weight
      ? points.map((p) => p.maxWeight).toList()
      : points.map((p) => p.totalVolume).toList();

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || points.length < 2) return;

    final vals   = _values;
    final minVal = vals.reduce(math.min);
    final maxVal = vals.reduce(math.max);
    final range  = (maxVal - minVal).clamp(1.0, double.infinity);

    const padL = 48.0, padR = 8.0, padT = 8.0, padB = 24.0;
    final w = size.width  - padL - padR;
    final h = size.height - padT - padB;

    // ── Grid lines ──────────────────────────────────────────
    final gridPaint = Paint()
      ..color       = divider
      ..strokeWidth = 0.5;

    const steps = 4;
    for (int i = 0; i <= steps; i++) {
      final y = padT + h - (h * i / steps);
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridPaint);
      // Y label
      final labelVal = minVal + (range * i / steps);
      final labelStr = labelVal >= 1000
          ? '${(labelVal / 1000).toStringAsFixed(1)}t'
          : '${labelVal.toStringAsFixed(0)}';
      _drawText(canvas, labelStr, Offset(0, y - 6), 8, textColor);
    }

    // ── X axis labels ────────────────────────────────────────
    final step = (points.length / math.min(points.length, 5)).ceil();
    for (int i = 0; i < points.length; i += step) {
      final x = padL + w * i / (points.length - 1);
      final d = points[i].date;
      final s = '${d.day}/${d.month}';
      _drawText(canvas, s, Offset(x - 10, size.height - padB + 4),
          7.5, textColor);
    }

    // ── Gradient fill ─────────────────────────────────────────
    final path = Path();
    final pathPoints = <Offset>[];
    for (int i = 0; i < vals.length; i++) {
      final x = padL + w * i / (vals.length - 1);
      final y = padT + h - h * ((vals[i] - minVal) / range);
      pathPoints.add(Offset(x, y));
    }
    path.moveTo(pathPoints.first.dx, padT + h);
    path.lineTo(pathPoints.first.dx, pathPoints.first.dy);
    for (int i = 1; i < pathPoints.length; i++) {
      final cp1 = Offset(
          (pathPoints[i - 1].dx + pathPoints[i].dx) / 2,
          pathPoints[i - 1].dy);
      final cp2 = Offset(
          (pathPoints[i - 1].dx + pathPoints[i].dx) / 2,
          pathPoints[i].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy,
          pathPoints[i].dx, pathPoints[i].dy);
    }
    path.lineTo(pathPoints.last.dx, padT + h);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [teal.withOpacity(isDark ? 0.3 : 0.2),
                   teal.withOpacity(0.02)],
          stops: const [0, 1]).createShader(
              Rect.fromLTWH(0, padT, size.width, h))
        ..style = PaintingStyle.fill);

    // ── Line ──────────────────────────────────────────────────
    final linePaint = Paint()
      ..color       = teal
      ..strokeWidth = 2.0
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    final linePath = Path();
    linePath.moveTo(pathPoints.first.dx, pathPoints.first.dy);
    for (int i = 1; i < pathPoints.length; i++) {
      final cp1 = Offset(
          (pathPoints[i - 1].dx + pathPoints[i].dx) / 2,
          pathPoints[i - 1].dy);
      final cp2 = Offset(
          (pathPoints[i - 1].dx + pathPoints[i].dx) / 2,
          pathPoints[i].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy,
          pathPoints[i].dx, pathPoints[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // ── Dots ──────────────────────────────────────────────────
    for (final pt in pathPoints) {
      // Glow
      canvas.drawCircle(pt, 5,
          Paint()..color = teal.withOpacity(0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      // Outer dot
      canvas.drawCircle(pt, 4, Paint()..color = teal);
      // Inner white
      canvas.drawCircle(pt, 2, Paint()..color = Colors.white);
    }

    // ── PR star on highest point ───────────────────────────────
    final maxIdx = vals.indexOf(vals.reduce(math.max));
    if (maxIdx >= 0 && maxIdx < pathPoints.length) {
      final pt = pathPoints[maxIdx];
      canvas.drawCircle(pt, 6,
          Paint()..color = _orange.withOpacity(0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawCircle(pt, 5, Paint()..color = _orange);
      canvas.drawCircle(pt, 2.5, Paint()..color = Colors.white);
    }
  }

  void _drawText(Canvas canvas, String text,
      Offset offset, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text,
          style: TextStyle(color: color, fontSize: size,
              fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points || old.mode != mode || old.isDark != isDark;

  // Expose _orange for use inside paint()
  static const _orange = MarkFitColors.orange;
}

// ─────────────────────────────────────────────────────────────
// _RecentSessions — ultime 5 sessioni per l'esercizio
// ─────────────────────────────────────────────────────────────

class _RecentSessions extends StatelessWidget {
  final List<_ProgressPoint> points;
  final MarkFitColors        c;
  const _RecentSessions({required this.points, required this.c});

  String _fmtDate(DateTime d) {
    const m = ['','Gen','Feb','Mar','Apr','Mag','Giu',
        'Lug','Ago','Set','Ott','Nov','Dic'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  String _fmtW(double w) =>
      w % 1 == 0 ? '${w.toInt()} kg' : '${w.toStringAsFixed(1)} kg';

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final recent = points.reversed.take(5).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Row(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(
              color: _cyan.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.history_rounded,
              size: 14, color: _cyan)),
        const SizedBox(width: 8),
        Text('Sessioni recenti', style: TextStyle(
            color: c.textPrimary, fontSize: 14,
            fontWeight: FontWeight.w700)),
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
              final i   = e.key;
              final pt  = e.value;
              final isLast = i == recent.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  child: Row(children: [
                    // Numero ordine
                    Container(width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: _teal.withOpacity(0.1),
                        shape: BoxShape.circle),
                      child: Center(child: Text('${i + 1}', style: TextStyle(
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
                      Text('${pt.setsCount} serie · max ${pt.maxReps} rips',
                          style: TextStyle(color: c.textTertiary, fontSize: 10)),
                    ])),
                    // Max weight badge
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

// ─────────────────────────────────────────────────────────────
// _EmptySearch
// ─────────────────────────────────────────────────────────────

class _EmptySearch extends StatelessWidget {
  final MarkFitColors c;
  const _EmptySearch({required this.c});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text('Nessun esercizio trovato',
        style: TextStyle(color: c.textTertiary, fontSize: 13))));
}

