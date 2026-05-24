import 'package:flutter/material.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';

class SessionDetailScreen extends StatefulWidget {
  final dynamic sessionKey;
  final String workoutName;
  final String date;

  const SessionDetailScreen({
    super.key,
    required this.sessionKey,
    required this.workoutName,
    required this.date,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  List<HiveSessionSet> _sets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final sets = HiveDatabase.instance.getSessionSets(widget.sessionKey);
    setState(() {
      _sets = sets;
      _loading = false;
    });
  }

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso);
    const months = ['','Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
        'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  Map<String, List<HiveSessionSet>> _groupByExercise() {
    final Map<String, List<HiveSessionSet>> grouped = {};
    for (final s in _sets) {
      grouped.putIfAbsent(s.exerciseName, () => []).add(s);
    }
    return grouped;
  }

  String _formatRest(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '${m}m' : '${m}m${s}s';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final grouped = _groupByExercise();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.workoutName),
            Text(_formatDate(widget.date),
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7))),
          ],
        ),
      ),
      body: grouped.isEmpty
          ? Center(
              child: Text('Nessun dato per questa sessione',
                  style: Theme.of(context).textTheme.bodyMedium))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: grouped.entries.map((entry) {
                final exerciseName = entry.key;
                final sets = entry.value;
                final muscleGroup = sets.first.muscleGroup;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exerciseName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(muscleGroup,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline)),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              const SizedBox(width: 32),
                              Expanded(
                                  child: Text('Peso',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline))),
                              Expanded(
                                  child: Text('Reps',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline))),
                              Expanded(
                                  child: Text('Rec.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline))),
                              const SizedBox(width: 24),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...sets.map((s) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                            decoration: BoxDecoration(
                              color: s.completed
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withOpacity(0.3)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                    width: 32,
                                    child: Text('${s.setNumber}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: s.completed
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .outline))),
                                Expanded(
                                    child: Text(
                                        s.weight % 1 == 0
                                            ? '${s.weight.toInt()} kg'
                                            : '${s.weight} kg',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500))),
                                Expanded(
                                    child: Text('${s.reps}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500))),
                                Expanded(
                                    child: Text(
                                        s.restSeconds != null
                                            ? _formatRest(s.restSeconds!)
                                            : '—',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline))),
                                SizedBox(
                                    width: 24,
                                    child: Icon(
                                        s.completed
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        size: 16,
                                        color: s.completed
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .outline)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}