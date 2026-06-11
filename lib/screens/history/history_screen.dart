import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import 'session_detail_screen.dart';
import 'exercise_progress_screen.dart';
import '../../main.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() =>
      _HistoryScreenState();
}

class _HistoryScreenState
    extends State<HistoryScreen> {
  List<HiveSession> _sessions = [];
  DateTime _focusedMonth = DateTime.now();
  bool _loading = true;
  Map<String, List<HiveSession>> _sessionsByDate = {};
  int _lastIndex = -1;

  // Modalità calendario: 'day' | 'month' | 'year'
  String _calendarMode = 'day';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentIndex =
        context.watch<NavigationNotifier>().currentIndex;
    if (currentIndex == 3 && _lastIndex != 3)
      _loadData();
    _lastIndex = currentIndex;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final sessions =
        HiveDatabase.instance.getSessions();
    final Map<String, List<HiveSession>> byDate = {};
    for (final s in sessions) {
      final dateStr = s.date.substring(0, 10);
      byDate.putIfAbsent(dateStr, () => []).add(s);
    }
    setState(() {
      _sessions = sessions;
      _sessionsByDate = byDate;
      _loading = false;
    });
  }

  Future<void> _confirmDeleteSession(
      BuildContext ctx, HiveSession session) async {
    final dt = DateTime.tryParse(session.date);
    final timeStr = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} alle ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : session.date;

    final confirm = await showGlassDialog<bool>(
      context: ctx,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.delete_outline,
                    color: Colors.red, size: 22),
                SizedBox(width: 10),
                Text('Elimina sessione',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
                'Eliminare "${session.workoutName}" del $timeStr?'),
            const SizedBox(height: 24),
            GlassDialogActions(
              cancelLabel: 'Annulla',
              confirmLabel: 'Elimina',
              confirmColor: Colors.red,
              onCancel: () =>
                  Navigator.pop(ctx, false),
              onConfirm: () =>
                  Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await HiveDatabase.instance
          .deleteSession(session.key);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sessione eliminata')),
        );
      }
    }
  }

  int _computeStreak() {
    if (_sessions.isEmpty) return 0;
    final now = DateTime.now();
    final currentWeekStart =
        now.subtract(Duration(days: now.weekday - 1));
    int streak = 0;
    DateTime weekStart = DateTime(
        currentWeekStart.year,
        currentWeekStart.month,
        currentWeekStart.day);
    while (true) {
      final weekEnd =
          weekStart.add(const Duration(days: 6));
      final hasSession = _sessions.any((s) {
        final date = DateTime.parse(s.date);
        return date.isAfter(weekStart.subtract(
                const Duration(seconds: 1))) &&
            date.isBefore(
                weekEnd.add(const Duration(days: 1)));
      });
      if (!hasSession) break;
      streak++;
      weekStart = weekStart
          .subtract(const Duration(days: 7));
      if (streak > 200) break;
    }
    return streak;
  }

  List<bool> _currentWeekDays() {
    final now = DateTime.now();
    final weekStart =
        now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      final dateStr =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return _sessionsByDate.containsKey(dateStr);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator()));
    }

    final streak = _computeStreak();
    final weekDays = _currentWeekDays();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storico'),
        actions: [
          IconButton(
            tooltip: 'Progressi per esercizio',
            icon: const Icon(Icons.show_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ChangeNotifierProvider.value(
                  value:
                      context.read<ExerciseProvider>(),
                  child: const ExerciseProgressScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              16, 12, 16, 100),
          children: [
            if (_sessions.isNotEmpty)
              _CompactStatsBar(
                totalSessions: _sessions.length,
                streak: streak,
                weekDays: weekDays,
              ),
            if (_sessions.isNotEmpty)
              const SizedBox(height: 14),

            // Calendario con modalità avanzata
            _AdvancedCalendar(
              focusedMonth: _focusedMonth,
              sessionsByDate: _sessionsByDate,
              calendarMode: _calendarMode,
              onModeChanged: (mode) =>
                  setState(() => _calendarMode = mode),
              onMonthChanged: (month) =>
                  setState(() => _focusedMonth = month),
              onDayTapped: (dateStr, sessions) =>
                  _showDayDetail(
                      context, dateStr, sessions),
            ),

            const SizedBox(height: 16),
            if (_sessions.isNotEmpty) ...[
              Text('Sessioni recenti',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium),
              const SizedBox(height: 8),
              ..._sessions.take(20).map((s) =>
                  _SessionTile(
                    session: s,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SessionDetailScreen(
                          sessionKey: s.key,
                          workoutName: s.workoutName,
                          date: s.date,
                        ),
                      ),
                    ),
                    onDelete: () =>
                        _confirmDeleteSession(
                            context, s),
                  )),
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.history,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .outline),
                      const SizedBox(height: 12),
                      Text('Nessuna sessione ancora',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall),
                      const SizedBox(height: 4),
                      Text(
                          'Completa il tuo primo allenamento!',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(
                                          context)
                                      .colorScheme
                                      .outline)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDayDetail(BuildContext context,
      String dateStr, List<HiveSession> sessions) {
    if (sessions.isEmpty) return;
    showGlassDialog(
      context: context,
      child: _DayDetailDialog(
        dateStr: dateStr,
        sessions: sessions,
        onDelete: (s) {
          Navigator.pop(context);
          _confirmDeleteSession(context, s);
        },
        onOpen: (s) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionDetailScreen(
                sessionKey: s.key,
                workoutName: s.workoutName,
                date: s.date,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dialog compatto con espansione per ogni sessione
class _DayDetailDialog extends StatefulWidget {
  final String dateStr;
  final List<HiveSession> sessions;
  final void Function(HiveSession) onDelete;
  final void Function(HiveSession) onOpen;

  const _DayDetailDialog({
    required this.dateStr,
    required this.sessions,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  State<_DayDetailDialog> createState() =>
      _DayDetailDialogState();
}

class _DayDetailDialogState
    extends State<_DayDetailDialog> {
  final Set<dynamic> _expanded = {};

  String _formatDateLabel(String dateStr) {
    final dt = DateTime.parse(dateStr);
    const months = [
      '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile',
      'Maggio', 'Giugno', 'Luglio', 'Agosto',
      'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_formatDateLabel(widget.dateStr),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                      fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...widget.sessions.map((s) {
            final dt = DateTime.tryParse(s.date);
            final timeStr = dt != null
                ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                : '';
            final isExpanded =
                _expanded.contains(s.key);
            final sets =
                HiveDatabase.instance.getSessionSets(s.key);
            final completedSets =
                sets.where((ss) => ss.completed).toList();

            // Raggruppa per esercizio
            final Map<String, HiveSessionSet>
                topByExercise = {};
            for (final ss in completedSets) {
              topByExercise.putIfAbsent(
                  ss.exerciseName, () => ss);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: cs.outlineVariant
                        .withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  // Riga compatta sempre visibile
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.fitness_center,
                            size: 16,
                            color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(s.workoutName,
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w600,
                                      fontSize: 14)),
                              if (timeStr.isNotEmpty)
                                Text(timeStr,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            cs.outline)),
                            ],
                          ),
                        ),
                        // Bottone espandi
                        GestureDetector(
                          onTap: () => setState(() {
                            if (isExpanded) {
                              _expanded.remove(s.key);
                            } else {
                              _expanded.add(s.key);
                            }
                          }),
                          child: Container(
                            padding:
                                const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: cs.primary
                                  .withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(
                                      8),
                            ),
                            child: Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                              color: cs.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Vai ai dettagli
                        GestureDetector(
                          onTap: () =>
                              widget.onOpen(s),
                          child: Container(
                            padding:
                                const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: cs.primary
                                  .withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(
                                      8),
                            ),
                            child: Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: cs.primary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Elimina
                        GestureDetector(
                          onTap: () =>
                              widget.onDelete(s),
                          child: Container(
                            padding:
                                const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red
                                  .withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(
                                      8),
                            ),
                            child: const Icon(
                                Icons.delete_outline,
                                size: 14,
                                color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dettagli espansi
                  if (isExpanded &&
                      topByExercise.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          12, 0, 12, 10),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Divider(
                              color: cs.outlineVariant
                                  .withOpacity(0.5)),
                          ...topByExercise.values
                              .map((ss) => Padding(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                            vertical: 2),
                                    child: Text(
                                      '• ${ss.exerciseName}: ${ss.weight > 0 ? '${ss.weight % 1 == 0 ? ss.weight.toInt() : ss.weight} kg × ' : ''}${ss.reps} reps',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              cs.outline),
                                    ),
                                  )),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          GlassOutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }
}

/// Calendario avanzato con modalità giorno/mese/anno
class _AdvancedCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final Map<String, List<HiveSession>> sessionsByDate;
  final String calendarMode;
  final void Function(String) onModeChanged;
  final void Function(DateTime) onMonthChanged;
  final void Function(String, List<HiveSession>)
      onDayTapped;

  const _AdvancedCalendar({
    required this.focusedMonth,
    required this.sessionsByDate,
    required this.calendarMode,
    required this.onModeChanged,
    required this.onMonthChanged,
    required this.onDayTapped,
  });

  static const _monthNames = [
    '', 'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
    'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
  ];
  static const _monthNamesFull = [
    '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile',
    'Maggio', 'Giugno', 'Luglio', 'Agosto',
    'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            if (calendarMode == 'day')
              _buildDayView(context)
            else if (calendarMode == 'month')
              _buildMonthView(context)
            else
              _buildYearView(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String titleText;
    if (calendarMode == 'day') {
      titleText =
          '${_monthNamesFull[focusedMonth.month]} ${focusedMonth.year}';
    } else if (calendarMode == 'month') {
      titleText = '${focusedMonth.year}';
    } else {
      final decade =
          (focusedMonth.year ~/ 10) * 10;
      titleText = '$decade – ${decade + 9}';
    }

    return Row(
      children: [
        // Freccia sinistra
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            if (calendarMode == 'day') {
              onMonthChanged(DateTime(
                  focusedMonth.year,
                  focusedMonth.month - 1));
            } else if (calendarMode == 'month') {
              onMonthChanged(DateTime(
                  focusedMonth.year - 1,
                  focusedMonth.month));
            } else {
              onMonthChanged(DateTime(
                  focusedMonth.year - 10,
                  focusedMonth.month));
            }
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: 22,
        ),
        // Titolo cliccabile per cambiare modalità
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (calendarMode == 'day') {
                onModeChanged('month');
              } else if (calendarMode == 'month') {
                onModeChanged('year');
              } else {
                onModeChanged('day');
              }
            },
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(titleText,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                            fontWeight:
                                FontWeight.w700)),
                const SizedBox(width: 4),
                Icon(Icons.unfold_more,
                    size: 16, color: cs.outline),
              ],
            ),
          ),
        ),
        // Freccia destra
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            if (calendarMode == 'day') {
              onMonthChanged(DateTime(
                  focusedMonth.year,
                  focusedMonth.month + 1));
            } else if (calendarMode == 'month') {
              onMonthChanged(DateTime(
                  focusedMonth.year + 1,
                  focusedMonth.month));
            } else {
              onMonthChanged(DateTime(
                  focusedMonth.year + 10,
                  focusedMonth.month));
            }
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          iconSize: 22,
        ),
      ],
    );
  }

  Widget _buildDayView(BuildContext context) {
    final firstDay = DateTime(
        focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(
            focusedMonth.year, focusedMonth.month + 1, 0)
        .day;
    final startOffset = (firstDay.weekday - 1) % 7;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth / 7;
        final circleSize =
            (cellSize * 0.72).clamp(28.0, 52.0);
        final fontSize =
            (circleSize * 0.38).clamp(10.0, 18.0);

        return Column(
          children: [
            Row(
              children: ['L', 'M', 'M', 'G', 'V', 'S', 'D']
                  .map((d) => SizedBox(
                        width: cellSize,
                        height: cellSize * 0.45,
                        child: Center(
                          child: Text(d,
                              style: TextStyle(
                                fontSize: fontSize * 0.85,
                                fontWeight:
                                    FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline,
                              )),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                mainAxisSpacing: 4,
                crossAxisSpacing: 0,
              ),
              itemCount: startOffset + daysInMonth,
              itemBuilder: (_, index) {
                if (index < startOffset)
                  return const SizedBox.shrink();
                final day =
                    index - startOffset + 1;
                final date = DateTime(
                    focusedMonth.year,
                    focusedMonth.month,
                    day);
                final dateStr =
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                final sessions =
                    sessionsByDate[dateStr] ?? [];
                final hasSession =
                    sessions.isNotEmpty;
                final isToday =
                    date.year == DateTime.now().year &&
                        date.month ==
                            DateTime.now().month &&
                        date.day == DateTime.now().day;

                return _DayCell(
                  day: day,
                  hasSession: hasSession,
                  isToday: isToday,
                  sessions: sessions,
                  circleSize: circleSize,
                  fontSize: fontSize,
                  onTap: hasSession
                      ? () => onDayTapped(
                          dateStr, sessions)
                      : null,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();

    // Conta sessioni per mese
    final sessionsByMonth = <int, int>{};
    for (final entry in sessionsByDate.entries) {
      final dt = DateTime.tryParse(entry.key);
      if (dt != null &&
          dt.year == focusedMonth.year) {
        sessionsByMonth[dt.month] =
            (sessionsByMonth[dt.month] ?? 0) +
                entry.value.length;
      }
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (_, i) {
        final month = i + 1;
        final isCurrentMonth =
            focusedMonth.year == now.year &&
                month == now.month;
        final isSelected =
            month == focusedMonth.month;
        final count = sessionsByMonth[month] ?? 0;

        return GestureDetector(
          onTap: () {
            onMonthChanged(DateTime(
                focusedMonth.year, month));
            onModeChanged('day');
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.primary.withOpacity(0.15)
                  : isCurrentMonth
                      ? cs.primaryContainer
                          .withOpacity(0.3)
                      : cs.surfaceContainerHighest
                          .withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? cs.primary
                    : isCurrentMonth
                        ? cs.primary.withOpacity(0.3)
                        : cs.outlineVariant
                            .withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(_monthNames[month],
                    style: TextStyle(
                      fontWeight: isSelected ||
                              isCurrentMonth
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 13,
                      color: isSelected
                          ? cs.primary
                          : cs.onSurface,
                    )),
                if (count > 0)
                  Text('$count',
                      style: TextStyle(
                          fontSize: 10,
                          color: cs.primary,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildYearView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final decade =
        (focusedMonth.year ~/ 10) * 10;

    // Conta sessioni per anno
    final sessionsByYear = <int, int>{};
    for (final entry in sessionsByDate.entries) {
      final dt = DateTime.tryParse(entry.key);
      if (dt != null) {
        sessionsByYear[dt.year] =
            (sessionsByYear[dt.year] ?? 0) +
                entry.value.length;
      }
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (_, i) {
        final year = decade - 1 + i;
        final isCurrentYear = year == now.year;
        final isSelected =
            year == focusedMonth.year;
        final count = sessionsByYear[year] ?? 0;
        final isOutOfRange = i == 0 || i == 11;

        return GestureDetector(
          onTap: () {
            onMonthChanged(
                DateTime(year, focusedMonth.month));
            onModeChanged('month');
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.primary.withOpacity(0.15)
                  : isCurrentYear
                      ? cs.primaryContainer
                          .withOpacity(0.3)
                      : isOutOfRange
                          ? cs.surfaceContainerHighest
                              .withOpacity(0.15)
                          : cs.surfaceContainerHighest
                              .withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? cs.primary
                    : cs.outlineVariant.withOpacity(
                        isOutOfRange ? 0.15 : 0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text('$year',
                    style: TextStyle(
                      fontWeight: isSelected ||
                              isCurrentYear
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 13,
                      color: isOutOfRange
                          ? cs.outline.withOpacity(0.4)
                          : isSelected
                              ? cs.primary
                              : cs.onSurface,
                    )),
                if (count > 0)
                  Text('$count',
                      style: TextStyle(
                          fontSize: 10,
                          color: cs.primary,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Stats bar, DayCell, SessionTile ──

class _CompactStatsBar extends StatelessWidget {
  final int totalSessions;
  final int streak;
  final List<bool> weekDays;

  const _CompactStatsBar({
    required this.totalSessions,
    required this.streak,
    required this.weekDays,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const dayLabels = [
      'L', 'M', 'M', 'G', 'V', 'S', 'D'
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text('$totalSessions',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      height: 1)),
              Text('allenamenti',
                  style: TextStyle(
                      fontSize: 10, color: cs.outline)),
            ],
          ),
          const SizedBox(width: 12),
          Container(
              width: 1,
              height: 36,
              color: cs.outlineVariant),
          const SizedBox(width: 12),
          const Text('🔥',
              style: TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text('$streak',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      height: 1)),
              Text(
                  streak == 1
                      ? 'settimana'
                      : 'settimane',
                  style: TextStyle(
                      fontSize: 10, color: cs.outline)),
            ],
          ),
          const SizedBox(width: 12),
          Container(
              width: 1,
              height: 36,
              color: cs.outlineVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceAround,
              children: List.generate(7, (i) {
                final done = weekDays[i];
                return Column(
                  children: [
                    Text(dayLabels[i],
                        style: TextStyle(
                            fontSize: 8,
                            color: cs.outline,
                            fontWeight:
                                FontWeight.w600)),
                    const SizedBox(height: 3),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? cs.primary
                            : cs.outlineVariant,
                      ),
                      child: done
                          ? Icon(Icons.check,
                              size: 10,
                              color: cs.onPrimary)
                          : null,
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatefulWidget {
  final int day;
  final bool hasSession;
  final bool isToday;
  final List<HiveSession> sessions;
  final VoidCallback? onTap;
  final double circleSize;
  final double fontSize;

  const _DayCell({
    required this.day,
    required this.hasSession,
    required this.isToday,
    required this.sessions,
    required this.circleSize,
    required this.fontSize,
    this.onTap,
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovered = false;
  OverlayEntry? _overlayEntry;

  void _showPreview(BuildContext context) {
    if (!widget.hasSession) return;
    final box =
        context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: (offset.dx - 60)
            .clamp(8.0, double.infinity),
        top: offset.dy + box.size.height + 4,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            constraints:
                const BoxConstraints(maxWidth: 200),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: widget.sessions
                  .map((s) => Padding(
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 3),
                        child: Row(
                          children: [
                            Icon(Icons.fitness_center,
                                size: 13,
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .primary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                  s.workoutName,
                                  style: const TextStyle(
                                      fontSize: 13),
                                  overflow: TextOverflow
                                      .ellipsis),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hidePreview() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hidePreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hoverSize = widget.circleSize * 1.12;

    if (!widget.hasSession && !widget.isToday) {
      return Center(
        child: Text('${widget.day}',
            style: TextStyle(
                fontSize: widget.fontSize,
                color: cs.onSurface.withOpacity(0.6))),
      );
    }

    return MouseRegion(
      cursor: widget.hasSession
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        setState(() => _hovered = true);
        _showPreview(context);
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _hidePreview();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Center(
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 150),
            width: _hovered
                ? hoverSize
                : widget.circleSize,
            height: _hovered
                ? hoverSize
                : widget.circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.hasSession
                  ? _hovered
                      ? cs.primary.withOpacity(0.8)
                      : cs.primary
                  : cs.primaryContainer,
              border: widget.isToday &&
                      !widget.hasSession
                  ? Border.all(
                      color: cs.primary, width: 1.5)
                  : null,
              boxShadow: _hovered && widget.hasSession
                  ? [
                      BoxShadow(
                        color:
                            cs.primary.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: Text('${widget.day}',
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.bold,
                    color: widget.hasSession
                        ? cs.onPrimary
                        : cs.primary,
                  )),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final HiveSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso);
    const months = [
      '', 'Gen', 'Feb', 'Mar', 'Apr', 'Mag',
      'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '';
    final m = seconds ~/ 60;
    if (m == 0) return '${seconds}s';
    return '${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sets = HiveDatabase.instance
        .getSessionSets(session.key);
    final topSets = sets
        .where((s) => s.completed)
        .fold<Map<String, HiveSessionSet>>(
            {},
            (map, s) =>
                map..putIfAbsent(s.exerciseName, () => s))
        .values
        .take(2)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: cs.primaryContainer,
                radius: 20,
                child: Icon(Icons.fitness_center,
                    color: cs.onPrimaryContainer,
                    size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(session.workoutName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(_formatDate(session.date),
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.outline)),
                    if (topSets.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ...topSets.map((s) => Text(
                            '• ${s.exerciseName}: ${s.weight > 0 ? '${s.weight % 1 == 0 ? s.weight.toInt() : s.weight} kg × ' : ''}${s.reps} reps',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.outline),
                          )),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  if (session.durationSeconds != null)
                    Text(
                        _formatDuration(
                            session.durationSeconds),
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.outline)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color:
                            Colors.red.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red
                                .withOpacity(0.3),
                            width: 1),
                      ),
                      child: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}