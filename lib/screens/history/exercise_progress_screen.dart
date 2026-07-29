import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import '../../widgets/cosmic_background.dart';

// ── Design tokens ─────────────────────────────────────────────
const _cyan   = Color(0xFF00E5FF);
const _teal   = Color(0xFF00D4AA);
const _tealDk = Color(0xFF00A880);
const _indigo = Color(0xFF6366F1);
const _orange = Color(0xFFFF8C00);
const _green  = Color(0xFF22C55E);
const _red    = Color(0xFFFF3B30);

// ─────────────────────────────────────────────────────────────
// ExerciseProgressScreen
// ─────────────────────────────────────────────────────────────

class ExerciseProgressScreen extends StatefulWidget {
  const ExerciseProgressScreen({super.key});

  @override
  State<ExerciseProgressScreen> createState() =>
      _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState
    extends State<ExerciseProgressScreen> {
  dynamic  _selectedKey;
  String   _selectedName = '';
  List<Map<String, dynamic>> _history = [];
  bool     _loading      = false;
  String   _muscleFilter = 'Tutti';

  Future<void> _loadHistory(dynamic key, String name) async {
    setState(() {
      _selectedKey  = key;
      _selectedName = name;
      _loading      = true;
    });

    final raw      = HiveDatabase.instance.getExerciseHistory(key);
    final sessions = HiveDatabase.instance.getSessions();
    final sMap     = {for (final s in sessions) s.key: s};

    final maps = raw.map((s) {
      final session = sMap[s.sessionKey];
      return {
        'date':       session?.date ?? '',
        'weight':     s.weight,
        'reps':       s.reps,
        'set_number': s.setNumber,
        'completed':  s.completed ? 1 : 0,
      };
    }).where((m) => (m['date'] as String).isNotEmpty).toList();

    setState(() { _history = maps; _loading = false; });
  }

  void _showExercisePicker(
      BuildContext context, List<HiveExercise> exercises) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      useSafeArea:        true,
      builder: (ctx) => _ExercisePickerSheet(
        exercises:   exercises,
        selectedKey: _selectedKey,
        onSelect: (ex) {
          Navigator.pop(ctx);
          _loadHistory(ex.key, ex.name);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final exercises   = context.watch<ExerciseProvider>().exercises;
    final sysBottom   = MediaQuery.of(context).viewPadding.bottom;

    final muscleGroups = [
      'Tutti',
      ...({...exercises.map((e) => e.muscleGroup)}.toList()..sort()),
    ];
    final filtered = _muscleFilter == 'Tutti'
        ? exercises
        : exercises.where((e) => e.muscleGroup == _muscleFilter).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        child: SafeArea(
          bottom: false,
          child: Column(children: [

            // ── Glass AppBar ──────────────────────────────────────
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    border: Border(bottom: BorderSide(
                        color: _cyan.withOpacity(0.12), width: 0.6))),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                              width: 0.7)),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 15, color: Colors.white))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      const Text('Progressi', style: TextStyle(
                          color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                      Text('Statistiche per esercizio', style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11)),
                    ])),
                  ])))),

            // ── Contenuto ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + sysBottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                  // ── Filtro gruppo muscolare ──────────────────────
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: muscleGroups.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final g   = muscleGroups[i];
                        final sel = _muscleFilter == g;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _muscleFilter = g;
                            if (_selectedKey != null && g != 'Tutti') {
                              try {
                                final ex = exercises.firstWhere(
                                    (e) => e.key == _selectedKey);
                                if (ex.muscleGroup != g) {
                                  _selectedKey = null; _history = [];
                                }
                              } catch (_) {
                                _selectedKey = null; _history = [];
                              }
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel
                                  ? _cyan.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel
                                    ? _cyan.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.1),
                                width: sel ? 1.2 : 0.8)),
                            child: Text(g, style: TextStyle(
                                color: sel ? _cyan
                                    : Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w700 : FontWeight.w500))));
                      })),
                  const SizedBox(height: 10),

                  // ── Selettore esercizio ──────────────────────────
                  GestureDetector(
                    onTap: () => _showExercisePicker(context, filtered),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: _indigo.withOpacity(0.3), width: 0.8)),
                          child: Row(children: [
                            Container(width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: _indigo.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(9)),
                              child: const Icon(Icons.fitness_center_rounded,
                                  color: _indigo, size: 17)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Text('Esercizio', style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 10, fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3)),
                              const SizedBox(height: 2),
                              Text(
                                _selectedKey != null
                                    ? _selectedName
                                    : 'Seleziona esercizio...',
                                style: TextStyle(
                                    color: _selectedKey != null
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.3),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            ])),
                            Icon(Icons.expand_more_rounded,
                                color: Colors.white.withOpacity(0.35), size: 20),
                          ])))),
                  ),
                  const SizedBox(height: 16),

                  // ── Area risultati ──────────────────────────────
                  if (_loading)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: CircularProgressIndicator(
                          color: _teal, strokeWidth: 2)))

                  else if (_selectedKey == null)
                    _GlassEmptyState(
                      icon:     Icons.show_chart_rounded,
                      title:    'Seleziona un esercizio',
                      subtitle: 'Scegli un esercizio dal selettore\nper vedere i tuoi progressi',
                      color:    _indigo)

                  else if (_history.isEmpty)
                    _GlassEmptyState(
                      icon:     Icons.inbox_rounded,
                      title:    'Nessun dato',
                      subtitle: 'Nessuna sessione registrata\nper $_selectedName',
                      color:    _orange)

                  else ...[
                    _GlassProgressChart(
                      history:      _history,
                      exerciseName: _selectedName),
                    const SizedBox(height: 12),
                    _GlassHistoryTable(history: _history),
                  ],
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
// _ExercisePickerSheet — bottom sheet Glass con ricerca
// ─────────────────────────────────────────────────────────────

class _ExercisePickerSheet extends StatefulWidget {
  final List<HiveExercise> exercises;
  final dynamic            selectedKey;
  final void Function(HiveExercise) onSelect;
  const _ExercisePickerSheet({
    required this.exercises, required this.selectedKey,
    required this.onSelect});

  @override
  State<_ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final _ctrl = TextEditingController();
  String _search = '';

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.exercises.where((e) =>
        _search.isEmpty ||
        e.name.toLowerCase().contains(_search.toLowerCase()) ||
        e.muscleGroup.toLowerCase().contains(_search.toLowerCase())).toList();
    final sysBottom = MediaQuery.of(context).viewPadding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF0E1520), Color(0xFF080E18)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(
                color: _cyan.withOpacity(0.2), width: 0.8))),
          child: Column(children: [
            // Handle
            Padding(padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2)))),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Column(children: [
                Row(children: [
                  Container(width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _indigo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.fitness_center_rounded,
                        color: _indigo, size: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    const Text('Seleziona esercizio', style: TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w800)),
                    Text('${filtered.length} disponibili', style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 11)),
                  ])),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16))),
                ]),
                const SizedBox(height: 10),
                // Search
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _cyan.withOpacity(0.15), width: 0.8)),
                      child: TextField(
                        controller: _ctrl,
                        keyboardAppearance: Brightness.dark,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText:   'Cerca esercizio o gruppo...',
                          hintStyle:  TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: Colors.white.withOpacity(0.35),
                              size: 18),
                          suffixIcon: _search.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _ctrl.clear();
                                    setState(() => _search = '');
                                  },
                                  child: Icon(Icons.close_rounded,
                                      color: Colors.white.withOpacity(0.35),
                                      size: 16))
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12)),
                        onChanged: (v) => setState(() => _search = v)))),
          )])),

            // Exercise list
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('Nessun risultato',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 14)))
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, sysBottom + 16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final ex    = filtered[i];
                        final isSel = ex.key == widget.selectedKey;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: GestureDetector(
                            onTap: () => widget.onSelect(ex),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? _teal.withOpacity(0.12)
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSel
                                      ? _teal.withOpacity(0.4)
                                      : Colors.white.withOpacity(0.08),
                                  width: isSel ? 1.0 : 0.7)),
                              child: Row(children: [
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  Text(ex.name, style: TextStyle(
                                      color: isSel ? _teal : Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(ex.muscleGroup, style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.4))),
                                ])),
                                if (isSel)
                                  const Icon(Icons.check_circle_rounded,
                                      color: _teal, size: 18),
                              ]))));
                      })),
          ]))));
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassProgressChart
// ─────────────────────────────────────────────────────────────

class _GlassProgressChart extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final String exerciseName;
  const _GlassProgressChart({
      required this.history, required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    // Peso massimo per data
    final Map<String, double> maxByDate = {};
    for (final s in history) {
      final date   = (s['date'] as String).substring(0, 10);
      final weight = (s['weight'] as num).toDouble();
      if (!maxByDate.containsKey(date) || maxByDate[date]! < weight) {
        maxByDate[date] = weight;
      }
    }
    final sortedDates = maxByDate.keys.toList()..sort();
    final allWeights  = maxByDate.values.toList();
    final maxWeight   = allWeights.isEmpty ? 0.0
        : allWeights.reduce((a, b) => a > b ? a : b);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withOpacity(0.07),
              Colors.white.withOpacity(0.02)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _teal.withOpacity(0.2), width: 0.8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Header
            Row(children: [
              Container(width: 30, height: 30,
                decoration: BoxDecoration(
                    color: _teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.show_chart_rounded,
                    color: _teal, size: 15)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Text('Peso massimo per sessione',
                    style: TextStyle(color: Colors.white,
                        fontSize: 13, fontWeight: FontWeight.w700)),
                Text(exerciseName, style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              if (maxWeight > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _orange.withOpacity(0.3), width: 0.7)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('⭐', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      maxWeight % 1 == 0
                          ? '${maxWeight.toInt()} kg'
                          : '$maxWeight kg',
                      style: const TextStyle(color: _orange,
                          fontSize: 10, fontWeight: FontWeight.w700)),
                  ])),
            ]),
            const SizedBox(height: 16),

            // Chart or single session card
            if (sortedDates.length < 2)
              _SingleSessionCard(
                date:   sortedDates.isNotEmpty ? sortedDates.first : '',
                weight: maxWeight)
            else
              SizedBox(
                height: 180,
                child: LineChart(_buildChartData(sortedDates, maxByDate))),
          ])),
      ),
    );
  }

  LineChartData _buildChartData(
      List<String> dates, Map<String, double> maxByDate) {
    final spots = dates.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), maxByDate[e.value]!))
        .toList();
    final maxY  = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY  = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final labels = dates.map((d) {
      final dt = DateTime.parse(d);
      return '${dt.day}/${dt.month}';
    }).toList();

    return LineChartData(
      minY: (minY - 5).clamp(0, double.infinity),
      maxY: maxY + 5,
      gridData: FlGridData(
        show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (v) => FlLine(
            color: Colors.white.withOpacity(0.06), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 46,
          getTitlesWidget: (v, _) => Text('${v.toInt()} kg',
              style: TextStyle(fontSize: 9,
                  color: Colors.white.withOpacity(0.4))))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 28,
          interval: dates.length > 8
              ? (dates.length / 6).ceilToDouble() : 1,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= labels.length) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 4),
              child: Text(labels[i], style: TextStyle(
                  fontSize: 9, color: Colors.white.withOpacity(0.4))));
          })),
        rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false))),
      lineBarsData: [LineChartBarData(
        spots:           spots,
        isCurved:        true,
        curveSmoothness: 0.3,
        color:           _teal,
        barWidth:        2.5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
            radius: 4, color: _teal,
            strokeWidth: 2,
            strokeColor: const Color(0xFF0A0A0E))),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_teal.withOpacity(0.18), _teal.withOpacity(0.0)])))]);
  }
}

class _SingleSessionCard extends StatelessWidget {
  final String date; final double weight;
  const _SingleSessionCard({required this.date, required this.weight});

  @override
  Widget build(BuildContext context) {
    final dt = date.isNotEmpty ? DateTime.tryParse(date) : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _teal.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _teal.withOpacity(0.15), width: 0.8)),
      child: Column(children: [
        const Icon(Icons.emoji_events_rounded, color: _teal, size: 30),
        const SizedBox(height: 10),
        Text(weight % 1 == 0 ? '${weight.toInt()} kg' : '$weight kg',
            style: const TextStyle(color: _teal,
                fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        if (dt != null)
          Text('Prima sessione · ${dt.day}/${dt.month}/${dt.year}',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 12)),
        const SizedBox(height: 8),
        Text('Completa un\'altra sessione per vedere il grafico',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3), fontSize: 11),
            textAlign: TextAlign.center),
      ]));
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassHistoryTable
// ─────────────────────────────────────────────────────────────

class _GlassHistoryTable extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _GlassHistoryTable({required this.history});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> byDate = {};
    for (final s in history) {
      final date = (s['date'] as String).substring(0, 10);
      byDate.putIfAbsent(date, () => []).add(s);
    }
    final sortedDates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 30, height: 30,
          decoration: BoxDecoration(
              color: _indigo.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.history_rounded,
              color: _indigo, size: 15)),
        const SizedBox(width: 10),
        const Text('Storico sessioni', style: TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 10),
      ...sortedDates.map((date) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _SessionCard(date: date, sets: byDate[date]!))),
    ]);
  }
}

class _SessionCard extends StatefulWidget {
  final String date;
  final List<Map<String, dynamic>> sets;
  const _SessionCard({required this.date, required this.sets});
  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = false;

  String _fmtDate(String d) {
    final dt = DateTime.parse(d);
    const m  = ['','Gen','Feb','Mar','Apr','Mag','Giu',
        'Lug','Ago','Set','Ott','Nov','Dic'];
    return '${dt.day} ${m[dt.month]} ${dt.year}';
  }

  String _fmtW(num w) => w % 1 == 0 ? '${w.toInt()} kg' : '$w kg';

  @override
  Widget build(BuildContext context) {
    final weights = widget.sets.map((s) => (s['weight'] as num).toDouble()).toList();
    final maxW    = weights.isEmpty ? 0.0
        : weights.reduce((a, b) => a > b ? a : b);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _indigo.withOpacity(0.2), width: 0.8)),
          child: Column(children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(children: [
                  Container(width: 34, height: 34,
                    decoration: BoxDecoration(
                        color: _indigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.calendar_today_rounded,
                        color: _indigo, size: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(_fmtDate(widget.date), style: const TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w700)),
                    Text('Max: ${_fmtW(maxW)} · ${widget.sets.length} serie',
                        style: TextStyle(fontSize: 11,
                            color: Colors.white.withOpacity(0.4))),
                  ])),
                  Icon(_expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withOpacity(0.35), size: 18),
                ]))),
            if (_expanded) ...[
              Container(height: 0.5, color: Colors.white.withOpacity(0.06)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(children: [
                  Row(children: [
                    SizedBox(width: 28, child: Text('S',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.4)))),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Peso', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.4)))),
                    Expanded(child: Text('Reps', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.4)))),
                    const SizedBox(width: 20),
                  ]),
                  const SizedBox(height: 6),
                  ...widget.sets.map((s) {
                    final setN     = (s['set_number'] as num).toInt();
                    final w        = (s['weight']     as num).toDouble();
                    final reps     = (s['reps']       as num).toInt();
                    final done     = (s['completed']  as num).toInt() == 1;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color: done
                            ? _teal.withOpacity(0.08)
                            : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: done
                              ? _teal.withOpacity(0.2)
                              : Colors.white.withOpacity(0.06),
                          width: 0.7)),
                      child: Row(children: [
                        SizedBox(width: 28, child: Text('$setN',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: done ? _teal
                                    : Colors.white.withOpacity(0.4)))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_fmtW(w),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12,
                                fontWeight: FontWeight.w500))),
                        Expanded(child: Text('$reps',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12,
                                fontWeight: FontWeight.w500))),
                        SizedBox(width: 20, child: Icon(
                            done ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 14,
                            color: done ? _teal
                                : Colors.white.withOpacity(0.2))),
                      ]));
                  }),
                ])),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassEmptyState
// ─────────────────────────────────────────────────────────────

class _GlassEmptyState extends StatelessWidget {
  final IconData icon; final String title, subtitle; final Color color;
  const _GlassEmptyState({required this.icon, required this.title,
      required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15), width: 0.8)),
        child: Column(children: [
          Container(width: 56, height: 56,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26)),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(color: Colors.white,
              fontSize: 15, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(
              color: Colors.white.withOpacity(0.4), fontSize: 13,
              height: 1.5),
              textAlign: TextAlign.center),
        ]))));
}