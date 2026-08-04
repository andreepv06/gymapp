import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';
import '../../core/theme/markfit_colors.dart';
import '../../db/hive_database.dart';
import '../../models/goal_models.dart';
import '../../models/hive_models.dart';
import '../../models/sport_models.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/sport_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/glass_main_app_bar.dart';
import '../../widgets/shared_sheets.dart';
import '../../widgets/workout_icon.dart';
import '../../main.dart';
import 'session_detail_screen.dart';
import 'exercise_progress_screen.dart';

// ─────────────────────────────────────────────────────────────
// Design tokens (accent fissi — uguali in dark/light)
// ─────────────────────────────────────────────────────────────

const _cyan   = MarkFitColors.cyan;
const _teal   = MarkFitColors.teal;
const _tealDk = MarkFitColors.tealDk;
const _indigo = MarkFitColors.indigo;
const _orange = MarkFitColors.orange;
const _red    = MarkFitColors.red;
const _green  = MarkFitColors.green;
const _blue   = MarkFitColors.blue;

// ─────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────

enum _EntryKind { gym, sport }

class _HistoryEntry {
  final _EntryKind kind; final dynamic key; final String title;
  final DateTime date; final int? durationSeconds;
  final double? distanceKm; final HiveSession? gymSession;
  final HiveSportSession? sportSession; final SportType? sportType;

  _HistoryEntry.fromGym(HiveSession s)
      : kind = _EntryKind.gym, key = s.key, title = s.workoutName,
        date = DateTime.tryParse(s.date) ?? DateTime.now(),
        durationSeconds = s.durationSeconds, distanceKm = null,
        gymSession = s, sportSession = null, sportType = null;

  _HistoryEntry.fromSport(HiveSportSession s)
      : kind = _EntryKind.sport, key = s.key,
        title = SportTypeX.fromId(s.sportType).label,
        date = DateTime.tryParse(s.date) ?? DateTime.now(),
        durationSeconds = s.durationSeconds, distanceKm = s.distanceKm,
        gymSession = null, sportSession = s,
        sportType = SportTypeX.fromId(s.sportType);
}

enum _SportFilter { all, gym, running, cycling, swimming, walking, hiking }

extension _SportFilterExt on _SportFilter {
  String get label {
    switch (this) {
      case _SportFilter.all:      return 'Tutti';
      case _SportFilter.gym:      return 'Palestra';
      case _SportFilter.running:  return 'Corsa';
      case _SportFilter.cycling:  return 'Ciclismo';
      case _SportFilter.swimming: return 'Nuoto';
      case _SportFilter.walking:  return 'Camminata';
      case _SportFilter.hiking:   return 'Hiking';
    }
  }

  bool matches(_HistoryEntry e) {
    switch (this) {
      case _SportFilter.all:      return true;
      case _SportFilter.gym:      return e.kind == _EntryKind.gym;
      case _SportFilter.running:  return e.sportType == SportType.running;
      case _SportFilter.cycling:  return e.sportType == SportType.cycling;
      case _SportFilter.swimming: return e.sportType == SportType.swimming;
      case _SportFilter.walking:  return e.sportType == SportType.walking;
      case _SportFilter.hiking:   return e.sportType == SportType.hiking;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// HistoryScreen
// ─────────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<HiveSession>              _sessions       = [];
  DateTime                       _focusedMonth   = DateTime.now();
  bool                           _loading        = true;
  Map<String, List<HiveSession>> _sessionsByDate = {};
  Map<int, HiveWorkout>          _workoutsCache  = {};
  int                            _lastIndex      = -1;
  String                         _calendarMode   = 'day';
  _SportFilter                   _sportFilter    = _SportFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    Future.microtask(() {
      context.read<GoalProvider>().loadGoals();
      context.read<SportProvider>().loadSessions();
    });
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final idx = context.watch<NavigationNotifier>().currentIndex;
    if (idx == 2 && _lastIndex != 2) _loadData();
    _lastIndex = idx;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final sessions = HiveDatabase.instance.getSessions();
    final byDate   = <String, List<HiveSession>>{};
    for (final s in sessions) {
      byDate.putIfAbsent(s.date.substring(0, 10), () => []).add(s);
    }
    final workouts = HiveDatabase.instance.getWorkouts();
    final wCache   = <int, HiveWorkout>{};
    for (final w in workouts) { wCache[w.key as int] = w; }
    if (mounted) context.read<SportProvider>().loadSessions();
    setState(() {
      _sessions       = sessions;
      _sessionsByDate = byDate;
      _workoutsCache  = wCache;
      _loading        = false;
    });
  }

  HiveWorkout? _getWorkout(int key) => _workoutsCache[key];

  List<_HistoryEntry> _allEntries(BuildContext context) {
    final sport   = context.watch<SportProvider>().sessions;
    final entries = <_HistoryEntry>[
      ..._sessions.map(_HistoryEntry.fromGym),
      ...sport.map(_HistoryEntry.fromSport),
    ];
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  List<_HistoryEntry> _filtered(List<_HistoryEntry> all) =>
      all.where((e) => _sportFilter.matches(e)).toList();

  int _computeStreak(List<DateTime> dates) {
    if (dates.isEmpty) return 0;
    final now    = DateTime.now();
    final wStart = now.subtract(Duration(days: now.weekday - 1));
    int streak   = 0;
    DateTime ws  = DateTime(wStart.year, wStart.month, wStart.day);
    while (true) {
      final we = ws.add(const Duration(days: 6));
      if (!dates.any((d) =>
          !d.isBefore(ws) && d.isBefore(we.add(const Duration(days: 1))))) break;
      streak++;
      ws = ws.subtract(const Duration(days: 7));
      if (streak > 200) break;
    }
    return streak;
  }

  List<bool> _currentWeekDays(List<DateTime> dates) {
    final now    = DateTime.now();
    final wStart = now.subtract(Duration(days: now.weekday - 1));
    final strs   = dates.map((d) =>
        '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}').toSet();
    return List.generate(7, (i) {
      final day = wStart.add(Duration(days: i));
      return strs.contains(
          '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}');
    });
  }

  Future<void> _confirmDeleteSession(HiveSession s) async {
    final dt = DateTime.tryParse(s.date);
    final ts = dt != null
        ? '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}'
        : s.date;
    final ok = await showGlassDialog<bool>(
      context: context, accentColor: _red,
      icon: Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: _red.withOpacity(0.12), shape: BoxShape.circle,
          border: Border.all(color: _red.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: _red.withOpacity(0.2), blurRadius: 12)]),
        child: const Icon(Icons.delete_outline_rounded, color: _red, size: 22)),
      title:   'Elimina sessione',
      message: 'Vuoi eliminare "${s.workoutName}" del $ts?\nL\'operazione è irreversibile.',
      actions: [
        GlassDialogAction(label: 'Annulla',
            onTap: () => Navigator.pop(context, false)),
        GlassDialogAction(label: 'Elimina', isDestructive: true,
            onTap: () => Navigator.pop(context, true)),
      ]);
    if (ok == true) {
      await HiveDatabase.instance.deleteSession(s.key);
      await _loadData();
      if (mounted) _showSnack('Sessione eliminata');
    }
  }

  Future<void> _confirmDeleteSportSession(HiveSportSession s) async {
    final ok = await showGlassDialog<bool>(
      context: context, accentColor: _red,
      icon: Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: _red.withOpacity(0.12), shape: BoxShape.circle,
          border: Border.all(color: _red.withOpacity(0.4))),
        child: const Icon(Icons.delete_outline_rounded, color: _red, size: 22)),
      title:   'Elimina sessione sport',
      message: 'Vuoi eliminare questa sessione di ${SportTypeX.fromId(s.sportType).label}?',
      actions: [
        GlassDialogAction(label: 'Annulla',
            onTap: () => Navigator.pop(context, false)),
        GlassDialogAction(label: 'Elimina', isDestructive: true,
            onTap: () => Navigator.pop(context, true)),
      ]);
    if (ok == true) {
      await context.read<SportProvider>().deleteSession(s.key);
      if (mounted) _showSnack('Sessione eliminata');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFF0D1117),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16)));
  }

  void _showDayDetail(String dateStr, List<HiveSession> sessions) {
    if (sessions.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _GlassDayDetailSheet(
        dateStr:       dateStr,
        sessions:      sessions,
        workoutsCache: _workoutsCache,
        onDelete: (s) { Navigator.pop(ctx); _confirmDeleteSession(s); },
        onOpen: (s) {
          Navigator.pop(ctx);
          pushPage(context, SessionDetailScreen(
              sessionKey: s.key, workoutName: s.workoutName, date: s.date));
        }));
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sysBottom = MediaQuery.of(context).viewPadding.bottom;
    return CosmicBackground(
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          // iOS 26 Glass AppBar
          GlassMainAppBar(
            title:       'Storico',
            subtitle:    'Attività e progressi',
            accentColor: _teal,
            screenIcon:  Icons.bar_chart_rounded,
            primaryActions: [
              GlassToolbarAction(
                icon:    Icons.show_chart_rounded,
                tooltip: 'Progressi esercizi',
                onTap:   () => pushPage(context,
                    ChangeNotifierProvider.value(
                      value: context.read<ExerciseProvider>(),
                      child: const ExerciseProgressScreen()))),
            ],
            onProfileTap: () =>
                context.read<NavigationNotifier>().navigateTo(3)),

          // Glass TabBar
          _GlassTabBar(controller: _tabController),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWorkoutsTab(context, sysBottom),
                _buildGoalsTab(context, sysBottom),
              ])),
        ]),
      ),
    );
  }

  // ── Tab Allenamenti ───────────────────────────────────────

  Widget _buildWorkoutsTab(BuildContext context, double sysBottom) {
    final c = context.mfc;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
          color: _teal, strokeWidth: 2));
    }
    final allEntries = _allEntries(context);
    final allDates   = allEntries.map((e) => e.date).toList();
    final streak     = _computeStreak(allDates);
    final weekDays   = _currentWeekDays(allDates);
    final filtered   = _filtered(allEntries);

    return RefreshIndicator(
      onRefresh:       _loadData,
      color:           _teal,
      backgroundColor: c.glassCardStrong,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 88 + sysBottom),
        children: [
          if (allEntries.isNotEmpty) ...[
            _GlassStatsBar(totalSessions: allEntries.length,
                streak: streak, weekDays: weekDays),
            const SizedBox(height: 12),
          ],
          _GlassCalendar(
            focusedMonth:   _focusedMonth,
            sessionsByDate: _sessionsByDate,
            calendarMode:   _calendarMode,
            onModeChanged:  (m) => setState(() => _calendarMode = m),
            onMonthChanged: (m) => setState(() => _focusedMonth = m),
            onDayTapped:    _showDayDetail),
          const SizedBox(height: 12),

          // Filter chips
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _SportFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final f   = _SportFilter.values[i];
                final sel = _sportFilter == f;
                return GestureDetector(
                  onTap: () => setState(() => _sportFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? _cyan.withOpacity(0.15)
                          : c.glassCardInset,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: sel
                            ? _cyan.withOpacity(0.55)
                            : c.glassBorder,
                        width: sel ? 1.2 : 0.8)),
                    child: Text(f.label, style: TextStyle(
                        color: sel ? _cyan : c.textTertiary,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500))));
              })),
          const SizedBox(height: 12),

          if (filtered.isNotEmpty) ...[
            _SectionHeader(icon: Icons.history_rounded,
                title: 'Sessioni recenti (${filtered.length})',
                color: _teal),
            const SizedBox(height: 8),
            ...filtered.take(30).map((entry) {
              if (entry.kind == _EntryKind.gym) {
                final s = entry.gymSession!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _GymSessionTile(
                    session: s, workout: _getWorkout(s.workoutKey),
                    onTap: () => pushPage(context, SessionDetailScreen(
                        sessionKey: s.key, workoutName: s.workoutName,
                        date: s.date)),
                    onDelete: () => _confirmDeleteSession(s)));
              } else {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SportSessionTile(
                    entry:    entry,
                    onDelete: () =>
                        _confirmDeleteSportSession(entry.sportSession!)));
              }
            }),
          ] else
            _EmptyWorkouts(),
        ],
      ),
    );
  }

  // ── Tab Obiettivi ─────────────────────────────────────────

  Widget _buildGoalsTab(BuildContext context, double sysBottom) {
    final gp    = context.watch<GoalProvider>();
    final goals = gp.goals;
    if (goals.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: _EmptyGoals()));
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 88 + sysBottom),
      itemCount: goals.length,
      itemBuilder: (_, i) {
        final g         = goals[i];
        final totalDone = gp.completionsForGoal(g.key)
            .where((c) => c.completed).length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _GoalHistoryCard(goal: g, totalDone: totalDone));
      });
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassTabBar
// ─────────────────────────────────────────────────────────────

class _GlassTabBar extends StatelessWidget {
  final TabController controller;
  const _GlassTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: c.glassCardInset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.glassBorder, width: 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 6)]
                  : null),
            child: TabBar(
              controller:           controller,
              indicator: BoxDecoration(
                color: _teal.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _teal.withOpacity(0.5), width: 1),
                boxShadow: [BoxShadow(color: _teal.withOpacity(0.15), blurRadius: 6)]),
              indicatorSize:        TabBarIndicatorSize.tab,
              dividerColor:         Colors.transparent,
              labelColor:           _teal,
              unselectedLabelColor: c.textTertiary,
              labelStyle:           const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              padding:              const EdgeInsets.all(3),
              tabs: const [
                Tab(text: 'Allenamenti'),
                Tab(text: 'Obiettivi'),
              ])))));
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassStatsBar
// ─────────────────────────────────────────────────────────────

class _GlassStatsBar extends StatelessWidget {
  final int totalSessions, streak;
  final List<bool> weekDays;
  const _GlassStatsBar({
    required this.totalSessions, required this.streak,
    required this.weekDays});

  @override
  Widget build(BuildContext context) {
    final c  = context.mfc;
    const dl = ['L','M','M','G','V','S','D'];
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.glassBorder, width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 10, offset: const Offset(0, 2))]
                : null),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$totalSessions', style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: _teal, height: 1)),
              Text('attività', style: TextStyle(
                  fontSize: 9, color: c.textTertiary)),
            ]),
            const SizedBox(width: 10),
            Container(width: 0.6, height: 30, color: c.divider),
            const SizedBox(width: 10),
            const Text('🔥', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$streak', style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: _orange, height: 1)),
              Text('sett.', style: TextStyle(
                  fontSize: 9, color: c.textTertiary)),
            ]),
            const SizedBox(width: 10),
            Container(width: 0.6, height: 30, color: c.divider),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (i) {
                  final done = weekDays[i];
                  return Column(children: [
                    Text(dl[i], style: TextStyle(
                        fontSize: 8, fontWeight: FontWeight.w600,
                        color: c.textTertiary)),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? _teal : c.glassCardInset,
                        boxShadow: done
                            ? [BoxShadow(color: _teal.withOpacity(0.4), blurRadius: 4)]
                            : null),
                      child: done
                          ? const Icon(Icons.check_rounded, size: 10, color: Colors.white)
                          : null),
                  ]);
                }))),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassCalendar
// ─────────────────────────────────────────────────────────────

class _GlassCalendar extends StatelessWidget {
  final DateTime                             focusedMonth;
  final Map<String, List<HiveSession>>       sessionsByDate;
  final String                               calendarMode;
  final void Function(String)                onModeChanged;
  final void Function(DateTime)              onMonthChanged;
  final void Function(String, List<HiveSession>) onDayTapped;

  const _GlassCalendar({
    required this.focusedMonth, required this.sessionsByDate,
    required this.calendarMode, required this.onModeChanged,
    required this.onMonthChanged, required this.onDayTapped});

  static const _mShort = ['','Gen','Feb','Mar','Apr','Mag','Giu',
      'Lug','Ago','Set','Ott','Nov','Dic'];
  static const _mFull  = ['','Gennaio','Febbraio','Marzo','Aprile',
      'Maggio','Giugno','Luglio','Agosto','Settembre',
      'Ottobre','Novembre','Dicembre'];

  String get _titleText {
    if (calendarMode == 'day')   return '${_mFull[focusedMonth.month]} ${focusedMonth.year}';
    if (calendarMode == 'month') return '${focusedMonth.year}';
    final dec = (focusedMonth.year ~/ 10) * 10;
    return '$dec – ${dec + 9}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.glassBorder, width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 10, offset: const Offset(0, 2))]
                : null),
          child: Column(children: [
            _buildHeader(context, c),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey('${calendarMode}_${focusedMonth.year}_${focusedMonth.month}'),
                child: calendarMode == 'day'
                    ? _buildDayView(context, c)
                    : calendarMode == 'month'
                        ? _buildMonthView(context, c)
                        : _buildYearView(context, c))),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, MarkFitColors c) {
    return Row(children: [
      _CalBtn(icon: Icons.chevron_left_rounded, c: c, onTap: () {
        if (calendarMode == 'day') {
          onMonthChanged(DateTime(focusedMonth.year, focusedMonth.month - 1));
        } else if (calendarMode == 'month') {
          onMonthChanged(DateTime(focusedMonth.year - 1, focusedMonth.month));
        } else {
          onMonthChanged(DateTime(focusedMonth.year - 10, focusedMonth.month));
        }
      }),
      Expanded(child: GestureDetector(
        onTap: () {
          if (calendarMode == 'day')        onModeChanged('month');
          else if (calendarMode == 'month') onModeChanged('year');
          else                              onModeChanged('day');
        },
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_titleText, style: TextStyle(
              color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Icon(Icons.unfold_more_rounded,
              size: 16, color: _cyan.withOpacity(0.6)),
        ]))),
      _CalBtn(icon: Icons.chevron_right_rounded, c: c, onTap: () {
        if (calendarMode == 'day') {
          onMonthChanged(DateTime(focusedMonth.year, focusedMonth.month + 1));
        } else if (calendarMode == 'month') {
          onMonthChanged(DateTime(focusedMonth.year + 1, focusedMonth.month));
        } else {
          onMonthChanged(DateTime(focusedMonth.year + 10, focusedMonth.month));
        }
      }),
    ]);
  }

  Widget _buildDayView(BuildContext context, MarkFitColors c) {
    final first     = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysCount = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final offset    = (first.weekday - 1) % 7;
    return LayoutBuilder(builder: (ctx, constraints) {
      final cellSize   = constraints.maxWidth / 7;
      final circleSize = (cellSize * 0.72).clamp(28.0, 52.0);
      final fontSize   = (circleSize * 0.38).clamp(10.0, 18.0);
      return Column(children: [
        Row(children: ['L','M','M','G','V','S','D'].map((d) =>
          SizedBox(width: cellSize, height: cellSize * 0.45,
            child: Center(child: Text(d, style: TextStyle(
                fontSize: fontSize * 0.82, fontWeight: FontWeight.w700,
                color: _cyan.withOpacity(0.55)))))).toList()),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, childAspectRatio: 1,
              mainAxisSpacing: 4, crossAxisSpacing: 0),
          itemCount: offset + daysCount,
          itemBuilder: (_, idx) {
            if (idx < offset) return const SizedBox.shrink();
            final day      = idx - offset + 1;
            final date     = DateTime(focusedMonth.year, focusedMonth.month, day);
            final dateStr  =
                '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
            final sessions = sessionsByDate[dateStr] ?? [];
            final isToday  = date.year == DateTime.now().year &&
                date.month == DateTime.now().month &&
                date.day == DateTime.now().day;
            return _GlassDayCell(
              day:         day, hasSessions: sessions.isNotEmpty,
              isToday:     isToday, sessions: sessions,
              circleSize:  circleSize, fontSize: fontSize,
              c:           c,
              onTap: sessions.isNotEmpty
                  ? () => onDayTapped(dateStr, sessions) : null);
          }),
      ]);
    });
  }

  Widget _buildMonthView(BuildContext context, MarkFitColors c) {
    final now     = DateTime.now();
    final byMonth = <int, int>{};
    for (final e in sessionsByDate.entries) {
      final dt = DateTime.tryParse(e.key);
      if (dt != null && dt.year == focusedMonth.year) {
        byMonth[dt.month] = (byMonth[dt.month] ?? 0) + e.value.length;
      }
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.8,
          mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: 12,
      itemBuilder: (_, i) {
        final month = i + 1;
        final isCur = focusedMonth.year == now.year && month == now.month;
        final isSel = month == focusedMonth.month;
        final count = byMonth[month] ?? 0;
        return GestureDetector(
          onTap: () {
            onMonthChanged(DateTime(focusedMonth.year, month));
            onModeChanged('day');
          },
          child: _CalCell(label: _mShort[month],
              subLabel: count > 0 ? '$count' : null,
              isSelected: isSel, isCurrent: isCur, c: c));
      });
  }

  Widget _buildYearView(BuildContext context, MarkFitColors c) {
    final dec    = (focusedMonth.year ~/ 10) * 10;
    final now    = DateTime.now();
    final byYear = <int, int>{};
    for (final e in sessionsByDate.entries) {
      final dt = DateTime.tryParse(e.key);
      if (dt != null) byYear[dt.year] = (byYear[dt.year] ?? 0) + e.value.length;
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.8,
          mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: 12,
      itemBuilder: (_, i) {
        final year  = dec - 1 + i;
        final isCur = year == now.year;
        final isSel = year == focusedMonth.year;
        final isOut = i == 0 || i == 11;
        final count = byYear[year] ?? 0;
        return GestureDetector(
          onTap: () {
            onMonthChanged(DateTime(year, focusedMonth.month));
            onModeChanged('month');
          },
          child: _CalCell(label: '$year',
              subLabel: count > 0 ? '$count' : null,
              isSelected: isSel, isCurrent: isCur,
              isOutOfRange: isOut, c: c));
      });
  }
}

class _CalBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final MarkFitColors c;
  const _CalBtn({required this.icon, required this.onTap, required this.c});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 34, height: 34,
      decoration: BoxDecoration(
        color: c.glassCardInset,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.glassBorder, width: 0.8)),
      child: Icon(icon, color: c.iconPrimary, size: 18)));
}

class _CalCell extends StatelessWidget {
  final String label; final String? subLabel;
  final bool isSelected, isCurrent, isOutOfRange;
  final MarkFitColors c;
  const _CalCell({required this.label, this.subLabel,
      this.isSelected = false, this.isCurrent = false,
      this.isOutOfRange = false, required this.c});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 140),
    decoration: BoxDecoration(
      color: isSelected ? _teal.withOpacity(0.2)
          : isCurrent   ? _cyan.withOpacity(0.08)
          : c.glassCardInset.withOpacity(isOutOfRange ? 0.4 : 1.0),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isSelected ? _teal.withOpacity(0.6)
            : isCurrent   ? _cyan.withOpacity(0.3)
            : c.glassBorder.withOpacity(isOutOfRange ? 0.5 : 1.0),
        width: isSelected ? 1.3 : 1),
      boxShadow: isSelected
          ? [BoxShadow(color: _teal.withOpacity(0.2), blurRadius: 8)] : null),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: TextStyle(
          color: isOutOfRange ? c.textTertiary
              : isSelected ? _teal : c.textPrimary,
          fontSize: 12,
          fontWeight: isSelected || isCurrent
              ? FontWeight.w700 : FontWeight.w500),
          textAlign: TextAlign.center),
      if (subLabel != null)
        Text(subLabel!, style: const TextStyle(
            fontSize: 9, color: _teal, fontWeight: FontWeight.w600)),
    ]));
}

// ─────────────────────────────────────────────────────────────
// _GlassDayCell
// ─────────────────────────────────────────────────────────────

class _GlassDayCell extends StatefulWidget {
  final int day; final bool hasSessions, isToday;
  final List<HiveSession> sessions; final VoidCallback? onTap;
  final double circleSize, fontSize; final MarkFitColors c;
  const _GlassDayCell({
    required this.day, required this.hasSessions, required this.isToday,
    required this.sessions, required this.circleSize, required this.fontSize,
    required this.c, this.onTap});
  @override
  State<_GlassDayCell> createState() => _GlassDayCellState();
}

class _GlassDayCellState extends State<_GlassDayCell> {
  bool          _hovered = false;
  OverlayEntry? _overlay;

  void _showPreview(BuildContext ctx) {
    if (!widget.hasSessions) return;
    final box    = ctx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final c = widget.c;
    _overlay = OverlayEntry(builder: (_) => Positioned(
      left: (offset.dx - 60).clamp(8.0, double.infinity),
      top:  offset.dy + box.size.height + 4,
      child: Material(
        elevation: 6, borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 200),
          decoration: BoxDecoration(
            color: c.sheetBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.glassBorder)),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.sessions.map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                const Icon(Icons.fitness_center_rounded, size: 11, color: _teal),
                const SizedBox(width: 6),
                Flexible(child: Text(s.workoutName,
                    style: TextStyle(color: c.textPrimary, fontSize: 12),
                    overflow: TextOverflow.ellipsis)),
              ]))).toList())))));
    Overlay.of(ctx).insert(_overlay!);
  }

  void _hidePreview() { _overlay?.remove(); _overlay = null; }

  @override
  void dispose() { _hidePreview(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    if (!widget.hasSessions && !widget.isToday) {
      return Center(child: Text('${widget.day}', style: TextStyle(
          fontSize: widget.fontSize, color: c.textTertiary)));
    }
    final hoverSize = widget.circleSize * 1.1;
    return MouseRegion(
      cursor: widget.hasSessions
          ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) { setState(() => _hovered = true); _showPreview(context); },
      onExit:  (_) { setState(() => _hovered = false); _hidePreview(); },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width:  _hovered ? hoverSize : widget.circleSize,
            height: _hovered ? hoverSize : widget.circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.hasSessions
                  ? (_hovered ? _teal.withOpacity(0.8) : _teal)
                  : _cyan.withOpacity(0.12),
              border: widget.isToday && !widget.hasSessions
                  ? Border.all(color: _cyan.withOpacity(0.7), width: 1.5)
                  : null,
              boxShadow: _hovered && widget.hasSessions
                  ? [BoxShadow(color: _teal.withOpacity(0.45), blurRadius: 10, spreadRadius: 1)]
                  : widget.hasSessions
                      ? [BoxShadow(color: _teal.withOpacity(0.2), blurRadius: 6)]
                      : null),
            child: Center(child: Text('${widget.day}', style: TextStyle(
                fontSize: widget.fontSize, fontWeight: FontWeight.w700,
                color: widget.hasSessions ? Colors.white : _cyan)))))));
  }
}

// ─────────────────────────────────────────────────────────────
// Session tiles
// ─────────────────────────────────────────────────────────────

class _GymSessionTile extends StatelessWidget {
  final HiveSession session; final HiveWorkout? workout;
  final VoidCallback onTap, onDelete;
  const _GymSessionTile({required this.session, required this.workout,
      required this.onTap, required this.onDelete});

  String _fmtDate(String iso) {
    final dt = DateTime.parse(iso);
    const m  = ['','Gen','Feb','Mar','Apr','Mag','Giu',
        'Lug','Ago','Set','Ott','Nov','Dic'];
    return '${dt.day} ${m[dt.month]} ${dt.year}  '
        '${dt.hour.toString().padLeft(2,'0')}:'
        '${dt.minute.toString().padLeft(2,'0')}';
  }

  String _fmtDur(int? s) {
    if (s == null) return '';
    final m = s ~/ 60;
    return m == 0 ? '${s}s' : '${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final c    = context.mfc;
    final sets = HiveDatabase.instance.getSessionSets(session.key);
    final top  = sets.where((s) => s.completed)
        .fold<Map<String, HiveSessionSet>>(
            {}, (map, s) => map..putIfAbsent(s.exerciseName, () => s))
        .values.take(2).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.glassCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _teal.withOpacity(0.2), width: 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 8, offset: const Offset(0, 2))]
                  : null),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              WorkoutAvatar(
                iconId: workout?.iconId, iconColorIndex: workout?.iconColorIndex,
                customImagePath: workout?.customImagePath,
                size: 44, iconSize: 22, borderRadius: 11),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(session.workoutName, style: TextStyle(
                    color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_fmtDate(session.date), style: TextStyle(
                    fontSize: 11, color: c.textTertiary)),
                if (top.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...top.map((s) => Text(
                    '• ${s.exerciseName}: '
                    '${s.weight > 0 ? '${s.weight % 1 == 0 ? s.weight.toInt() : s.weight} kg × ' : ''}'
                    '${s.reps} reps',
                    style: TextStyle(fontSize: 11, color: c.textTertiary))),
                ],
              ])),
              Column(children: [
                if (session.durationSeconds != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _cyan.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _cyan.withOpacity(0.2), width: 0.7)),
                    child: Text(_fmtDur(session.durationSeconds),
                        style: TextStyle(color: _cyan.withOpacity(0.8),
                            fontSize: 10, fontWeight: FontWeight.w600))),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _red.withOpacity(0.3), width: 0.7)),
                    child: const Icon(Icons.delete_outline_rounded, color: _red, size: 14))),
              ]),
            ])))));
  }
}

class _SportSessionTile extends StatelessWidget {
  final _HistoryEntry entry; final VoidCallback onDelete;
  const _SportSessionTile({required this.entry, required this.onDelete});

  IconData get _icon {
    switch (entry.sportType) {
      case SportType.running:  return Icons.directions_run_rounded;
      case SportType.cycling:  return Icons.directions_bike_rounded;
      case SportType.swimming: return Icons.pool_rounded;
      case SportType.walking:  return Icons.directions_walk_rounded;
      case SportType.hiking:   return Icons.terrain_rounded;
      default:                 return Icons.sports_rounded;
    }
  }

  Color get _color {
    switch (entry.sportType) {
      case SportType.running:  return _orange;
      case SportType.cycling:  return _green;
      case SportType.swimming: return _blue;
      case SportType.walking:  return _teal;
      case SportType.hiking:   return _indigo;
      default:                 return _cyan;
    }
  }

  String _fmtDate(DateTime dt) {
    const m = ['','Gen','Feb','Mar','Apr','Mag','Giu',
        'Lug','Ago','Set','Ott','Nov','Dic'];
    return '${dt.day} ${m[dt.month]} ${dt.year}  '
        '${dt.hour.toString().padLeft(2,'0')}:'
        '${dt.minute.toString().padLeft(2,'0')}';
  }

  String _fmtDur(int? s) {
    if (s == null) return '';
    final m = s ~/ 60;
    return m == 0 ? '${s}s' : '${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final cl = _color;
    final c  = context.mfc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cl.withOpacity(0.25), width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 8, offset: const Offset(0, 2))]
                : null),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                color: cl.withOpacity(0.15),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: cl.withOpacity(0.3))),
              child: Icon(_icon, color: cl, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.title, style: TextStyle(
                  color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(_fmtDate(entry.date), style: TextStyle(
                  fontSize: 11, color: c.textTertiary)),
              if (entry.distanceKm != null && entry.distanceKm! > 0) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.straighten_rounded, size: 11, color: cl.withOpacity(0.7)),
                  const SizedBox(width: 4),
                  Text('${entry.distanceKm!.toStringAsFixed(1)} km',
                      style: TextStyle(fontSize: 11, color: cl.withOpacity(0.8),
                          fontWeight: FontWeight.w600)),
                ]),
              ],
            ])),
            Column(children: [
              if (entry.durationSeconds != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: cl.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cl.withOpacity(0.2), width: 0.7)),
                  child: Text(_fmtDur(entry.durationSeconds),
                      style: TextStyle(color: cl.withOpacity(0.9),
                          fontSize: 10, fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _red.withOpacity(0.3), width: 0.7)),
                  child: const Icon(Icons.delete_outline_rounded, color: _red, size: 14))),
            ]),
          ]))));
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassDayDetailSheet
// ─────────────────────────────────────────────────────────────

class _GlassDayDetailSheet extends StatefulWidget {
  final String dateStr; final List<HiveSession> sessions;
  final Map<int, HiveWorkout> workoutsCache;
  final void Function(HiveSession) onDelete, onOpen;
  const _GlassDayDetailSheet({
    required this.dateStr, required this.sessions,
    required this.workoutsCache, required this.onDelete,
    required this.onOpen});
  @override
  State<_GlassDayDetailSheet> createState() => _GlassDayDetailSheetState();
}

class _GlassDayDetailSheetState extends State<_GlassDayDetailSheet> {
  final Set<dynamic> _expanded = {};

  String _fmtLabel(String s) {
    final dt = DateTime.parse(s);
    const m  = ['','Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
        'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];
    return '${dt.day} ${m[dt.month]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return GlassSheetWrapper(
      title:       _fmtLabel(widget.dateStr),
      subtitle:    '${widget.sessions.length} session${widget.sessions.length == 1 ? 'e' : 'i'}',
      accentColor: _teal,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ...widget.sessions.map((s) {
          final dt      = DateTime.tryParse(s.date);
          final timeStr = dt != null
              ? '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
              : '';
          final isExp   = _expanded.contains(s.key);
          final sets    = HiveDatabase.instance.getSessionSets(s.key);
          final topMap  = <String, HiveSessionSet>{};
          for (final ss in sets.where((ss) => ss.completed)) {
            topMap.putIfAbsent(ss.exerciseName, () => ss);
          }
          final workout = widget.workoutsCache[s.workoutKey];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.glassCardInset,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _teal.withOpacity(0.2), width: 0.7)),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        WorkoutAvatar(
                          iconId: workout?.iconId, iconColorIndex: workout?.iconColorIndex,
                          customImagePath: workout?.customImagePath,
                          size: 34, iconSize: 17, borderRadius: 9),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.workoutName, style: TextStyle(
                              color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (timeStr.isNotEmpty)
                            Text(timeStr, style: TextStyle(
                                fontSize: 11, color: c.textTertiary)),
                        ])),
                        GestureDetector(
                          onTap: () => setState(() {
                            if (isExp) _expanded.remove(s.key);
                            else       _expanded.add(s.key);
                          }),
                          child: Container(padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: _teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(7)),
                            child: Icon(isExp ? Icons.expand_less : Icons.expand_more,
                                size: 16, color: _teal))),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => widget.onOpen(s),
                          child: Container(padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: _cyan.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(7)),
                            child: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _cyan))),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => widget.onDelete(s),
                          child: Container(padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: _red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(7)),
                            child: const Icon(Icons.delete_outline_rounded, size: 12, color: _red))),
                      ])),
                    if (isExp && topMap.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Divider(height: 0, thickness: 0.5, color: c.divider),
                          const SizedBox(height: 8),
                          ...topMap.values.map((ss) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• ${ss.exerciseName}: '
                              '${ss.weight > 0 ? '${ss.weight % 1 == 0 ? ss.weight.toInt() : ss.weight} kg × ' : ''}'
                              '${ss.reps} reps',
                              style: TextStyle(fontSize: 12, color: c.textSecondary)))),
                        ])),
                  ])))));
        }),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: context.mfc.glassCardInset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.mfc.glassBorder)),
            child: Text('Chiudi', textAlign: TextAlign.center,
                style: TextStyle(color: context.mfc.textPrimary,
                    fontSize: 14, fontWeight: FontWeight.w600)))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _GoalHistoryCard
// ─────────────────────────────────────────────────────────────

class _GoalHistoryCard extends StatelessWidget {
  final HiveGoal goal; final int totalDone;
  const _GoalHistoryCard({required this.goal, required this.totalDone});

  static const _catColors = <String, Color>{
    'Studio': Color(0xFF6366F1), 'Sport': Color(0xFF00D4AA),
    'Salute': Color(0xFF22C55E), 'Lavoro': Color(0xFF3B82F6),
    'Alimentazione': Color(0xFFFF8C00), 'Benessere': Color(0xFFEC4899),
    'Produttività': Color(0xFF8B5CF6), 'Hobby': Color(0xFFF59E0B),
    'Finanze': Color(0xFF10B981), 'Lettura': Color(0xFF6B7280),
    'Meditazione': Color(0xFF8A2BE2), 'Personale': Color(0xFFFF6B6B),
    'Altro': Color(0xFF9CA3AF),
  };

  Color get _catColor => _catColors[goal.category] ?? const Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    final cl = _catColor;
    final c  = context.mfc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left:   BorderSide(color: cl.withOpacity(0.6), width: 3),
              top:    BorderSide(color: cl.withOpacity(0.12), width: 0.7),
              right:  BorderSide(color: cl.withOpacity(0.12), width: 0.7),
              bottom: BorderSide(color: cl.withOpacity(0.12), width: 0.7)),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 8, offset: const Offset(0, 2))]
                : null),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(goal.title, style: TextStyle(
                  color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: cl.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: cl.withOpacity(0.25), width: 0.7)),
                  child: Text(goal.category.isNotEmpty ? goal.category : 'Nessuna',
                      style: TextStyle(color: cl, fontSize: 10, fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                Text('Completati: $totalDone',
                    style: TextStyle(fontSize: 11, color: c.textTertiary)),
              ]),
              if (goal.bestStreak > 0) ...[
                const SizedBox(height: 4),
                Text('Record streak: ${goal.bestStreak}',
                    style: TextStyle(fontSize: 11,
                        color: _cyan.withOpacity(0.8), fontWeight: FontWeight.w500)),
              ],
            ])),
            if (goal.currentStreak > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _orange.withOpacity(0.3), width: 0.7)),
                child: Column(children: [
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  Text('${goal.currentStreak}', style: const TextStyle(
                      color: _orange, fontSize: 12, fontWeight: FontWeight.w800)),
                ])),
            ],
          ]))));
  }
}

// ─────────────────────────────────────────────────────────────
// _SectionHeader
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon; final String title; final Color color;
  const _SectionHeader({required this.icon, required this.title,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Row(children: [
      Container(width: 30, height: 30,
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: color)),
      const SizedBox(width: 9),
      Text(title, style: TextStyle(
          color: c.textPrimary, fontSize: 15,
          fontWeight: FontWeight.w800, letterSpacing: -0.2)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Empty states
// ─────────────────────────────────────────────────────────────

class _EmptyWorkouts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Center(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 56, height: 56,
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.history_rounded, color: _teal, size: 26)),
        const SizedBox(height: 14),
        Text('Nessuna sessione ancora',
            style: TextStyle(color: c.textPrimary,
                fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Completa il tuo primo allenamento!',
            style: TextStyle(color: c.textTertiary, fontSize: 13)),
      ])));
  }
}

class _EmptyGoals extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: c.glassCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _orange.withOpacity(0.15), width: 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 10)]
                  : null),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.track_changes_rounded, color: _orange, size: 26)),
              const SizedBox(height: 14),
              Text('Nessun obiettivo ancora',
                  style: TextStyle(color: c.textPrimary,
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Crea i tuoi obiettivi dalla sezione Home',
                  style: TextStyle(color: c.textTertiary, fontSize: 13),
                  textAlign: TextAlign.center),
            ])))));
  }
}