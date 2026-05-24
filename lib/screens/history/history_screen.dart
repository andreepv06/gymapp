import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import 'session_detail_screen.dart';
import 'exercise_progress_screen.dart';
import '../../main.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HiveSession> _sessions = [];
  DateTime _focusedMonth = DateTime.now();
  bool _loading = true;
  Map<String, List<HiveSession>> _sessionsByDate = {};
  int _lastIndex = -1;

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
    if (currentIndex == 3 && _lastIndex != 3) {
      _loadData();
    }
    _lastIndex = currentIndex;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final sessions = HiveDatabase.instance.getSessions();
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

  int _computeStreak() {
    if (_sessions.isEmpty) return 0;
    final now = DateTime.now();
    final currentWeekStart =
        now.subtract(Duration(days: now.weekday - 1));
    int streak = 0;
    DateTime weekStart = DateTime(currentWeekStart.year,
        currentWeekStart.month, currentWeekStart.day);
    while (true) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final hasSession = _sessions.any((s) {
        final date = DateTime.parse(s.date);
        return date.isAfter(
                weekStart.subtract(const Duration(seconds: 1))) &&
            date.isBefore(weekEnd.add(const Duration(days: 1)));
      });
      if (!hasSession) break;
      streak++;
      weekStart = weekStart.subtract(const Duration(days: 7));
      if (streak > 200) break;
    }
    return streak;
  }

  List<bool> _currentWeekDays() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
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
          body: Center(child: CircularProgressIndicator()));
    }

    final streak = _computeStreak();
    final weekDays = _currentWeekDays();
    const dayLabels = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

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
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<ExerciseProvider>(),
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
          padding: const EdgeInsets.all(16),
          children: [
            if (streak > 0) ...[
              _StreakCard(
                  streak: streak,
                  weekDays: weekDays,
                  dayLabels: dayLabels),
              const SizedBox(height: 16),
            ],
            _CalendarCard(
              focusedMonth: _focusedMonth,
              sessionsByDate: _sessionsByDate,
              onMonthChanged: (month) =>
                  setState(() => _focusedMonth = month),
              onDayTapped: (dateStr, sessions) =>
                  _showDayDetail(context, dateStr, sessions),
            ),
            const SizedBox(height: 16),
            if (_sessions.isNotEmpty) ...[
              Text('Sessioni recenti',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._sessions.take(10).map((s) => _SessionTile(
                    session: s,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionDetailScreen(
                          sessionKey: s.key,
                          workoutName: s.workoutName,
                          date: s.date,
                        ),
                      ),
                    ),
                  )),
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.history,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      Text('Nessuna sessione ancora',
                          style:
                              Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        'Completa il tuo primo allenamento!',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDayDetail(BuildContext context, String dateStr,
      List<HiveSession> sessions) {
    if (sessions.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_formatDateLabel(dateStr)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: sessions
              .map((s) => ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(s.workoutName),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 14),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
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
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  String _formatDateLabel(String dateStr) {
    final dt = DateTime.parse(dateStr);
    const months = [
      '',
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  final List<bool> weekDays;
  final List<String> dayLabels;

  const _StreakCard({
    required this.streak,
    required this.weekDays,
    required this.dayLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  '$streak ${streak == 1 ? 'settimana' : 'settimane'} di fila!',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final dotSize =
                  (constraints.maxWidth / 7 * 0.6).clamp(20.0, 36.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (i) {
                  final done = weekDays[i];
                  return Column(
                    children: [
                      Text(dayLabels[i],
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withOpacity(0.7),
                          )),
                      const SizedBox(height: 4),
                      Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withOpacity(0.1),
                        ),
                        child: done
                            ? Icon(Icons.check,
                                size: dotSize * 0.55,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimary)
                            : null,
                      ),
                    ],
                  );
                }),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  final DateTime focusedMonth;
  final Map<String, List<HiveSession>> sessionsByDate;
  final void Function(DateTime) onMonthChanged;
  final void Function(String, List<HiveSession>) onDayTapped;

  const _CalendarCard({
    required this.focusedMonth,
    required this.sessionsByDate,
    required this.onMonthChanged,
    required this.onDayTapped,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay =
        DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final startOffset = (firstDay.weekday - 1) % 7;
    const months = [
      '',
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre'
    ];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => onMonthChanged(DateTime(
                      focusedMonth.year, focusedMonth.month - 1)),
                ),
                Text(
                  '${months[focusedMonth.month]} ${focusedMonth.year}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => onMonthChanged(DateTime(
                      focusedMonth.year, focusedMonth.month + 1)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
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
                                        fontWeight: FontWeight.bold,
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
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 0,
                      ),
                      itemCount: startOffset + daysInMonth,
                      itemBuilder: (_, index) {
                        if (index < startOffset) {
                          return const SizedBox.shrink();
                        }
                        final day = index - startOffset + 1;
                        final date = DateTime(focusedMonth.year,
                            focusedMonth.month, day);
                        final dateStr =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        final sessions =
                            sessionsByDate[dateStr] ?? [];
                        final hasSession = sessions.isNotEmpty;
                        final isToday =
                            date.year == DateTime.now().year &&
                                date.month == DateTime.now().month &&
                                date.day == DateTime.now().day;

                        return _DayCell(
                          day: day,
                          hasSession: hasSession,
                          isToday: isToday,
                          sessions: sessions,
                          circleSize: circleSize,
                          fontSize: fontSize,
                          onTap: hasSession
                              ? () => onDayTapped(dateStr, sessions)
                              : null,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
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
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: (offset.dx - 60).clamp(8.0, double.infinity),
        top: offset.dy + box.size.height + 4,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color:
                      Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.sessions
                  .map((s) => Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(Icons.fitness_center,
                                size: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                s.workoutName,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface),
                                overflow: TextOverflow.ellipsis,
                              ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final hoverSize = widget.circleSize * 1.12;

    if (!widget.hasSession && !widget.isToday) {
      return Center(
        child: Text('${widget.day}',
            style: TextStyle(
                fontSize: widget.fontSize,
                color: colorScheme.onSurface.withOpacity(0.6))),
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
            duration: const Duration(milliseconds: 150),
            width: _hovered ? hoverSize : widget.circleSize,
            height: _hovered ? hoverSize : widget.circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.hasSession
                  ? _hovered
                      ? colorScheme.primary.withOpacity(0.8)
                      : colorScheme.primary
                  : colorScheme.primaryContainer,
              border: widget.isToday && !widget.hasSession
                  ? Border.all(color: colorScheme.primary, width: 1.5)
                  : null,
              boxShadow: _hovered && widget.hasSession
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.4),
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
                        ? colorScheme.onPrimary
                        : colorScheme.primary,
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
  const _SessionTile({required this.session, required this.onTap});

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso);
    const months = [
      '',
      'Gen',
      'Feb',
      'Mar',
      'Apr',
      'Mag',
      'Giu',
      'Lug',
      'Ago',
      'Set',
      'Ott',
      'Nov',
      'Dic'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}min ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.fitness_center,
              color:
                  Theme.of(context).colorScheme.onPrimaryContainer,
              size: 18),
        ),
        title: Text(session.workoutName,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(_formatDate(session.date)),
        trailing: session.durationSeconds != null
            ? Text(_formatDuration(session.durationSeconds),
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline))
            : null,
        onTap: onTap,
      ),
    );
  }
}