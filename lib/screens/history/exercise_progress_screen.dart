import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';

class ExerciseProgressScreen extends StatefulWidget {
  const ExerciseProgressScreen({super.key});

  @override
  State<ExerciseProgressScreen> createState() =>
      _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState
    extends State<ExerciseProgressScreen> {
  dynamic _selectedExerciseKey;
  String _selectedExerciseName = '';
  List<Map<String, dynamic>> _history = [];
  bool _loading = false;
  String _muscleFilter = 'Tutti';

  Future<void> _loadHistory(dynamic exerciseKey, String name) async {
    setState(() {
      _selectedExerciseKey = exerciseKey;
      _selectedExerciseName = name;
      _loading = true;
    });
    final history =
        HiveDatabase.instance.getExerciseHistory(exerciseKey);
    final sessions = HiveDatabase.instance.getSessions();
    final sessionMap = {for (final s in sessions) s.key: s};

    final historyMaps = history.map((s) {
      final session = sessionMap[s.sessionKey];
      return {
        'date': session?.date ?? '',
        'weight': s.weight,
        'reps': s.reps,
        'set_number': s.setNumber,
        'completed': s.completed ? 1 : 0,
      };
    }).where((m) => (m['date'] as String).isNotEmpty).toList();

    setState(() {
      _history = historyMaps;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final exercises = context.watch<ExerciseProvider>().exercises;

    final muscleGroups = [
      'Tutti',
      ...({...exercises.map((e) => e.muscleGroup)}.toList()..sort())
    ];

    final filteredExercises = _muscleFilter == 'Tutti'
        ? exercises
        : exercises
            .where((e) => e.muscleGroup == _muscleFilter)
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Progressi per esercizio')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              itemCount: muscleGroups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final g = muscleGroups[i];
                return ChoiceChip(
                  label: Text(g),
                  selected: _muscleFilter == g,
                  onSelected: (_) => setState(() {
                    _muscleFilter = g;
                    if (_selectedExerciseKey != null && g != 'Tutti') {
                      try {
                        final ex = exercises.firstWhere(
                            (e) => e.key == _selectedExerciseKey);
                        if (ex.muscleGroup != g) {
                          _selectedExerciseKey = null;
                          _history = [];
                        }
                      } catch (_) {
                        _selectedExerciseKey = null;
                        _history = [];
                      }
                    }
                  }),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: DropdownButtonFormField<dynamic>(
              value: _selectedExerciseKey,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Seleziona esercizio',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: filteredExercises
                  .map((e) => DropdownMenuItem<dynamic>(
                        value: e.key,
                        child: Text(e.name,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (key) {
                if (key == null) return;
                final ex =
                    exercises.firstWhere((e) => e.key == key);
                _loadHistory(key, ex.name);
              },
            ),
          ),
          if (_loading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else if (_selectedExerciseKey == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.show_chart,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      _muscleFilter == 'Tutti'
                          ? 'Seleziona un esercizio'
                          : 'Seleziona un esercizio di $_muscleFilter',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            )
          else if (_history.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Nessun dato per $_selectedExerciseName',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _ProgressChart(
                    history: _history,
                    exerciseName: _selectedExerciseName,
                  ),
                  const SizedBox(height: 16),
                  _HistoryTable(history: _history),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressChart extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final String exerciseName;

  const _ProgressChart(
      {required this.history, required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    final Map<String, double> maxBySession = {};
    for (final s in history) {
      final sessionKey = s['date'] as String;
      if (sessionKey.isEmpty) continue;
      final weight = (s['weight'] as num?)?.toDouble() ?? 0;
      if (!maxBySession.containsKey(sessionKey) ||
          maxBySession[sessionKey]! < weight) {
        maxBySession[sessionKey] = weight;
      }
    }

    final sortedKeys = maxBySession.keys.toList()..sort();

    if (sortedKeys.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('Nessun dato disponibile',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline)),
          ),
        ),
      );
    }

    if (sortedKeys.length == 1) {
      final weight = maxBySession[sortedKeys.first]!;
      final dt = DateTime.parse(sortedKeys.first);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.bar_chart,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text('Prima sessione registrata',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '${weight % 1 == 0 ? weight.toInt() : weight} kg',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold),
              ),
              Text('${dt.day}/${dt.month}/${dt.year}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline)),
              const SizedBox(height: 8),
              Text('Fai un\'altra sessione per vedere il grafico',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline)),
            ],
          ),
        ),
      );
    }

    final spots = sortedKeys
        .asMap()
        .entries
        .map((e) =>
            FlSpot(e.key.toDouble(), maxBySession[e.value]!))
        .toList();
    final maxY =
        spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY =
        spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final xLabels = sortedKeys.map((k) {
      final dt = DateTime.parse(k);
      final sameDay = sortedKeys
              .where((o) => o.substring(0, 10) == k.substring(0, 10))
              .length >
          1;
      return sameDay
          ? '${dt.day}/${dt.month}\n${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : '${dt.day}/${dt.month}';
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text('Peso massimo per sessione',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            SizedBox(
              height: 200,
              child: LineChart(LineChartData(
                minY: (minY - 5).clamp(0, double.infinity),
                maxY: maxY + 5,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withOpacity(0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, _) => Text(
                          '${v.toInt()} kg',
                          style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: sortedKeys.length > 8
                          ? (sortedKeys.length / 6).ceilToDouble()
                          : 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= xLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(xLabels[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline)),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 2,
                        strokeColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                    ),
                  ),
                ],
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTable extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _HistoryTable({required this.history});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> byDate = {};
    for (final s in history) {
      final date = (s['date'] as String).substring(0, 10);
      byDate.putIfAbsent(date, () => []).add(s);
    }
    final sortedDates = byDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Storico sessioni',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...sortedDates.map((date) {
          final sets = byDate[date]!;
          final dt = DateTime.parse(date);
          final weights = sets
              .map((s) => (s['weight'] as num?)?.toDouble() ?? 0.0)
              .toList();
          final maxWeight = weights.isEmpty
              ? 0.0
              : weights.reduce((a, b) => a > b ? a : b);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              title: Text('${dt.day}/${dt.month}/${dt.year}',
                  style:
                      const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(
                  'Max: ${maxWeight % 1 == 0 ? maxWeight.toInt() : maxWeight} kg · ${sets.length} serie',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline)),
              children: sets.map((s) {
                final weight =
                    (s['weight'] as num?)?.toDouble() ?? 0.0;
                final reps = (s['reps'] as num?)?.toInt() ?? 0;
                final setNum =
                    (s['set_number'] as num?)?.toInt() ?? 0;
                final completed =
                    (s['completed'] as num?)?.toInt() == 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text('S$setNum',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary)),
                      ),
                      Expanded(
                        child: Text(
                            '${weight % 1 == 0 ? weight.toInt() : weight} kg × $reps reps',
                            overflow: TextOverflow.ellipsis),
                      ),
                      Icon(
                          completed
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: completed
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .outline),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }
}