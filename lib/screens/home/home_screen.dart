import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../models/goal_models.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';
import '../../widgets/workout_icon.dart';
import '../../main.dart';
import '../goals/goals_screen.dart';
import '../session/active_session_screen.dart';
import '../workouts/workout_detail_screen.dart';

// ── Design tokens — identici ad AllenamentiScreen ────────────
const _cyan       = Color(0xFF00E5FF);
const _teal       = Color(0xFF00D4AA);
const _tealDk     = Color(0xFF00A880);
const _indigo     = Color(0xFF6366F1);
const _orange     = Color(0xFFFF8C00);
const _orangeWarm = Color(0xFFFF6B00);
const _red        = Color(0xFFFF3B30);
const _green      = Color(0xFF22C55E);
const _blue       = Color(0xFF3B82F6);
const _purple     = Color(0xFF8A2BE2);

// ─────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late Animation<double>   _ringAnim;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _ringAnim = CurvedAnimation(
        parent: _ringCtrl, curve: Curves.easeOutCubic);
    Future.microtask(() {
      if (!mounted) return;
      context.read<WorkoutProvider>().loadWorkouts();
      context.read<ExerciseProvider>().loadExercises();
      context.read<GoalProvider>().loadGoals();
      _ringCtrl.forward();
    });
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buongiorno';
    if (h < 18) return 'Buon pomeriggio';
    return 'Buonasera';
  }

  String _formattedDate() {
    const days = ['Lunedì','Martedì','Mercoledì','Giovedì',
        'Venerdì','Sabato','Domenica'];
    const months = ['gennaio','febbraio','marzo','aprile','maggio','giugno',
        'luglio','agosto','settembre','ottobre','novembre','dicembre'];
    final now = DateTime.now();
    return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }

  String _fmt(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}min';
    return '${s}s';
  }

  // ── FIX #1: Palestra → tab switch, mai push isolato ─────────

  void _goToAllenamenti() =>
      context.read<NavigationNotifier>().navigateTo(1);

  // ── FIX #2: Logica sessioni in pausa identica ad Allenamenti ─

  Future<void> _handleWorkoutPlay(HiveWorkout workout) async {
    final wp = context.read<WorkoutProvider>();
    final sp = context.read<SessionProvider>();
    wp.loadWorkoutExercises(workout.key);

    // Sessione attiva per questa scheda
    if (sp.hasActiveSession && sp.currentWorkout?.key == workout.key) {
      final result = await showGlassDialog<String>(
        context: context,
        accentColor: _blue,
        icon: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _blue.withOpacity(0.12), shape: BoxShape.circle,
            border: Border.all(color: _blue.withOpacity(0.4)),
          ),
          child: const Icon(Icons.sports_gymnastics_rounded,
              color: Color(0xFF60A5FA), size: 22),
        ),
        title: 'Sessione in corso',
        message: 'Hai una sessione attiva per "${workout.name}".',
        actionsAxis: Axis.vertical,
        actions: [
          GlassDialogAction(
            label: 'Continua sessione', isDefault: true, color: _blue,
            onTap: () => Navigator.pop(context, 'continue'),
          ),
          GlassDialogAction(
            label: 'Avvia nuova sessione', isDestructive: true,
            onTap: () => Navigator.pop(context, 'new'),
          ),
          GlassDialogAction(
            label: 'Annulla',
            onTap: () => Navigator.pop(context, 'cancel'),
          ),
        ],
      );
      if (!mounted) return;
      if (result == null || result == 'cancel') return;
      if (result == 'new') await sp.abandonSession();
      if (!mounted) return;
      pushPage(context, ActiveSessionScreen(workout: workout));
      return;
    }

    // Sessione in pausa per questa scheda
    if (sp.hasPausedSessionForWorkout(workout.key)) {
      final paused = sp.getMostRecentPausedForWorkout(workout.key);
      final result = await showGlassDialog<String>(
        context: context,
        accentColor: _orange,
        icon: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.12), shape: BoxShape.circle,
            border: Border.all(color: _orange.withOpacity(0.4)),
            boxShadow: [BoxShadow(
                color: _orange.withOpacity(0.2), blurRadius: 12)],
          ),
          child: const Icon(Icons.pause_circle_outline_rounded,
              color: _orange, size: 22),
        ),
        title: 'Sessione in pausa',
        message: 'Hai una sessione in pausa per "${workout.name}".',
        actionsAxis: Axis.vertical,
        actions: [
          GlassDialogAction(
            label: 'Riprendi sessione', isDefault: true, color: _orange,
            onTap: () => Navigator.pop(context, 'resume'),
          ),
          GlassDialogAction(
            label: 'Avvia nuova sessione',
            onTap: () => Navigator.pop(context, 'new'),
          ),
          GlassDialogAction(
            label: 'Annulla',
            onTap: () => Navigator.pop(context, 'cancel'),
          ),
        ],
      );
      if (!mounted) return;
      if (result == null || result == 'cancel') return;
      if (result == 'resume' && paused != null) {
        await sp.resumePausedSession(paused['id'] as String);
        if (!mounted) return;
      }
      pushPage(context, ActiveSessionScreen(workout: workout));
      return;
    }

    pushPage(context, ActiveSessionScreen(workout: workout));
  }

  // ── FIX #7: Completamento solo su oggi/passato ──────────────

  void _handleGoalToggle(HiveGoal goal) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel   = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (sel.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Non puoi completare obiettivi futuri.',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF0D1117),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    context.read<GoalProvider>().toggleCompletion(goal, _selectedDate);
  }

  void _showCalendarPopup() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => _GlassCalendarDialog(
        initialDate: _selectedDate,
        onDateSelected: (date) {
          setState(() => _selectedDate = date);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature — prossimamente',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFF0D1117),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SessionProvider>();
    final wp = context.watch<WorkoutProvider>();
    final ep = context.watch<ExerciseProvider>();
    final gp = context.watch<GoalProvider>();

    final workouts     = wp.workouts;
    final exCount      = ep.exercises.length;
    final completed    = sp.completedSetsCount;
    final total        = sp.totalSetsCount;
    final progress     = total > 0 ? completed / total : 0.0;
    final goalsForDay  = gp.goalsForDate(_selectedDate);
    final dayProgress  = gp.completionPercentageForDate(_selectedDate);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ─── 1. Header ────────────────────────────────────
                _HomeHeader(greeting: _greeting(), date: _formattedDate()),
                const SizedBox(height: 14),

                // ─── 2. Paused sessions banner ────────────────────
                if (sp.hasPausedSessions && !sp.hasActiveSession) ...[
                  _PausedSessionsBanner(
                    sp: sp, fmt: _fmt,
                    onGoToAllenamenti: _goToAllenamenti,
                  ),
                  const SizedBox(height: 12),
                ],

                // Active session banner (rimane — utile context)
                if (sp.hasActiveSession) ...[
                  _ActiveSessionBanner(sp: sp, fmt: _fmt),
                  const SizedBox(height: 12),
                ],

                // ─── 3. Calendario settimana ──────────────────────
                _WeekCalendarSection(
                  selectedDate: _selectedDate,
                  onDateSelected: (d) => setState(() => _selectedDate = d),
                  onCalendarOpen: _showCalendarPopup,
                ),
                const SizedBox(height: 14),

                // ─── 4. Obiettivi del giorno ──────────────────────
                _GoalsDaySection(
                  goals: goalsForDay,
                  selectedDate: _selectedDate,
                  dayProgress: dayProgress,
                  isCompleted: (g) =>
                      gp.isCompletedOn(g, _selectedDate),
                  onToggle: _handleGoalToggle,
                  onManage: () => pushPage(context, const GoalsScreen()),
                ),
                const SizedBox(height: 14),

                // ─── 5. Progresso giornaliero ─────────────────────
                _DailyProgressCard(
                  ringAnim: _ringAnim,
                  progress: sp.hasActiveSession ? progress : 0,
                  completedSets: completed,
                  totalSets: total,
                  elapsedSec: sp.elapsedSeconds,
                  workoutCount: workouts.length,
                  exerciseCount: exCount,
                  hasActive: sp.hasActiveSession,
                  fmt: _fmt,
                ),
                const SizedBox(height: 14),

                // ─── 6. Avvio rapido ──────────────────────────────
                // FIX #1: pulsante "Tutte" RIMOSSO per specifica
                _SectionHeader(
                  icon: Icons.bolt_rounded,
                  title: 'Avvio rapido',
                  color: _teal,
                ),
                const SizedBox(height: 10),
                _QuickStartGrid(
                  onPalestra: _goToAllenamenti, // tab switch, non push
                  onRunning:  () => _showComingSoon('Running'),
                  onCiclismo: () => _showComingSoon('Ciclismo'),
                  onNuoto:    () => _showComingSoon('Nuoto'),
                ),
                const SizedBox(height: 14),

// ─── 7. Le tue schede ─────────────────────────────
                if (workouts.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.fitness_center_rounded,
                    title: 'Le tue schede',
                    color: _indigo,
                    trailingLabel: workouts.length > 2 ? 'Vedi tutte' : null,
                    onTrailing: _goToAllenamenti,
                  ),
                  const SizedBox(height: 10),
                  ...workouts.take(2).map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WorkoutMiniCard(
                      workout: w,
                      sp: sp,
                      onEdit: () {
                        context.read<WorkoutProvider>()
                            .loadWorkoutExercises(w.key);
                        pushPage(context, WorkoutDetailScreen(
                          workoutId: w.key,
                          workoutName: w.name,
                        ));
                      },
                      onPlay: () => _handleWorkoutPlay(w),
                    ),
                  )),
                ],

              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _HomeHeader
// ─────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final String greeting, date;
  const _HomeHeader({required this.greeting, required this.date});

  static const _phrases = [
    'Ogni rep conta.',
    'Il progresso è costante.',
    'Oggi supera ieri.',
    'Forza e costanza.',
    'Non fermarti mai.',
    'Il corpo segue la mente.',
    'Consistenza batte intensità.',
  ];

  String get _phrase {
    final d = DateTime.now()
        .difference(DateTime(DateTime.now().year))
        .inDays;
    return _phrases[d % _phrases.length];
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(0.09),
                Colors.white.withOpacity(0.03)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cyan.withOpacity(0.2), width: 0.8),
            boxShadow: [BoxShadow(
                color: _teal.withOpacity(0.06), blurRadius: 20,
                spreadRadius: 1)],
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 7, height: 7,
                      decoration: BoxDecoration(color: _teal,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color: _teal.withOpacity(0.7), blurRadius: 5)]),
                    ),
                    const SizedBox(width: 7),
                    Text('MARKFIT', style: TextStyle(color: _teal,
                        fontSize: 10, fontWeight: FontWeight.w800,
                        letterSpacing: 1.8)),
                  ]),
                  const SizedBox(height: 10),
                  Text(greeting, style: const TextStyle(color: Colors.white,
                      fontSize: 26, fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
                  const SizedBox(height: 3),
                  Text(date, style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 12)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _teal.withOpacity(0.18), width: 0.7)),
                    child: Text(_phrase, style: TextStyle(
                        color: _teal.withOpacity(0.85), fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_teal.withOpacity(0.3), _cyan.withOpacity(0.1)]),
                shape: BoxShape.circle,
                border: Border.all(color: _teal.withOpacity(0.6), width: 1.5),
                boxShadow: [BoxShadow(
                    color: _teal.withOpacity(0.3), blurRadius: 16,
                    spreadRadius: 1)],
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 28),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _PausedSessionsBanner  (FIX #3 — grafica Glass UI migliorata)
// ─────────────────────────────────────────────────────────────

class _PausedSessionsBanner extends StatelessWidget {
  final SessionProvider sp;
  final String Function(int) fmt;
  final VoidCallback onGoToAllenamenti;

  const _PausedSessionsBanner({
    required this.sp,
    required this.fmt,
    required this.onGoToAllenamenti,
  });

  @override
  Widget build(BuildContext context) {
    final paused = sp.pausedSessions;
    final count  = paused.length;
    final first  = count > 0 ? paused.first : null;
    final name   = first?['workoutName'] as String? ?? 'Sessione';
    final elapsed =
        (first?['elapsedAtPause'] as num?)?.toInt() ?? 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [_orange.withOpacity(0.18),
                _orangeWarm.withOpacity(0.08)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _orange.withOpacity(0.45), width: 1.3),
            boxShadow: [BoxShadow(
                color: _orange.withOpacity(0.2), blurRadius: 24,
                spreadRadius: 1)],
          ),
          child: Row(children: [
            // Icona con glow
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _orange.withOpacity(0.3),
                  _orangeWarm.withOpacity(0.15),
                ]),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _orange.withOpacity(0.5), width: 1.2),
                boxShadow: [BoxShadow(
                    color: _orange.withOpacity(0.3), blurRadius: 10)],
              ),
              child: const Icon(Icons.pause_circle_filled_rounded,
                  color: _orange, size: 24),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Container(width: 6, height: 6,
                    decoration: BoxDecoration(color: _orange,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: _orange.withOpacity(0.7),
                          blurRadius: 4)]),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    count == 1
                        ? 'SESSIONE IN PAUSA'
                        : '$count SESSIONI IN PAUSA',
                    style: TextStyle(color: _orange, fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1)),
                ]),
                const SizedBox(height: 4),
                Text(name,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                if (elapsed > 0) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.timer_outlined, size: 11,
                        color: _orange.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(fmt(elapsed), style: TextStyle(
                        color: _orange.withOpacity(0.8),
                        fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ]),
            ),
            const SizedBox(width: 10),
            // Pulsante Vedi
            GestureDetector(
              onTap: onGoToAllenamenti,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_orange, _orangeWarm]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: _orange.withOpacity(0.45),
                      blurRadius: 12, offset: const Offset(0, 3))],
                ),
                child: const Text('Riprendi',
                    style: TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ActiveSessionBanner
// ─────────────────────────────────────────────────────────────

class _ActiveSessionBanner extends StatelessWidget {
  final SessionProvider sp;
  final String Function(int) fmt;
  const _ActiveSessionBanner({required this.sp, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final name = sp.currentWorkout?.name ?? 'Sessione attiva';
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _blue.withOpacity(0.25), _blue.withOpacity(0.07)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: _blue.withOpacity(0.45), width: 1.2),
            boxShadow: [BoxShadow(
                color: _blue.withOpacity(0.2), blurRadius: 22)],
          ),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                  color: _blue.withOpacity(0.2),
                  shape: BoxShape.circle),
              child: const Icon(Icons.sports_gymnastics_rounded,
                  color: Color(0xFF60A5FA), size: 23)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('SESSIONE ATTIVA',
                    style: TextStyle(color: const Color(0xFF60A5FA),
                        fontSize: 9, fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 3),
                Text(name,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Row(children: [
                  _MiniStat(icon: Icons.timer_rounded,
                      label: fmt(sp.elapsedSeconds),
                      color: const Color(0xFF60A5FA)),
                  const SizedBox(width: 10),
                  _MiniStat(icon: Icons.check_rounded,
                      label:
                          '${sp.completedSetsCount}/${sp.totalSetsCount} serie',
                      color: const Color(0xFF60A5FA)),
                ]),
              ]),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                final w = sp.currentWorkout;
                if (w == null) return;
                pushPage(context, ActiveSessionScreen(workout: w));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: _blue, borderRadius: BorderRadius.circular(11),
                  boxShadow: [BoxShadow(
                      color: _blue.withOpacity(0.45), blurRadius: 12,
                      offset: const Offset(0, 3))],
                ),
                child: const Text('Riprendi',
                    style: TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _WeekCalendarSection (FIX #5 — clic calendario apre popup Glass)
// ─────────────────────────────────────────────────────────────

class _WeekCalendarSection extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onCalendarOpen;

  const _WeekCalendarSection({
    required this.selectedDate,
    required this.onDateSelected,
    required this.onCalendarOpen,
  });

  @override
  Widget build(BuildContext context) {
    const names  = ['Lun','Mar','Mer','Gio','Ven','Sab','Dom'];
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day);
    final selDay = DateTime(
        selectedDate.year, selectedDate.month, selectedDate.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withOpacity(0.07),
              Colors.white.withOpacity(0.02)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _cyan.withOpacity(0.15), width: 0.8)),
          child: Column(children: [
            // Header con mese e icona calendario
            Row(children: [
              GestureDetector(
                onTap: onCalendarOpen,
                child: Row(children: [
                  Text(
                    _monthLabel(selectedDate),
                    style: const TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      color: _cyan.withOpacity(0.7), size: 18),
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onCalendarOpen,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _cyan.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: _cyan.withOpacity(0.2), width: 0.7)),
                  child: Icon(Icons.calendar_month_rounded,
                      color: _cyan, size: 16),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            // Giorni settimana
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = monday.add(Duration(days: i));
                final dayNorm =
                    DateTime(day.year, day.month, day.day);
                final isSel   = dayNorm == selDay;
                final isToday = dayNorm == today;
                final isPast  = dayNorm.isBefore(today);

                return GestureDetector(
                  onTap: () => onDateSelected(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel
                          ? _teal.withOpacity(0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel
                            ? _teal.withOpacity(0.6)
                            : isToday
                                ? _cyan.withOpacity(0.35)
                                : Colors.transparent,
                        width: 1,
                      ),
                      boxShadow: isSel
                          ? [BoxShadow(
                              color: _teal.withOpacity(0.2),
                              blurRadius: 8)]
                          : null,
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min,
                      children: [
                      Text(names[i], style: TextStyle(
                          color: isSel
                              ? _teal
                              : isToday
                                  ? _cyan
                                  : Colors.white.withOpacity(0.3),
                          fontSize: 9, fontWeight: FontWeight.w700,
                          letterSpacing: 0.3)),
                      const SizedBox(height: 7),
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: isSel ? _teal : Colors.transparent,
                          shape: BoxShape.circle),
                        child: Center(
                          child: Text('${day.day}', style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.7),
                              fontSize: 13,
                              fontWeight: isSel || isToday
                                  ? FontWeight.w800 : FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(
                          color: isToday
                              ? _cyan
                              : isPast
                                  ? _teal.withOpacity(0.4)
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                          boxShadow: isToday
                              ? [BoxShadow(
                                  color: _cyan.withOpacity(0.6),
                                  blurRadius: 3)]
                              : null,
                        ),
                      ),
                    ]),
                  ),
                );
              }),
            ),
          ]),
        ),
      ),
    );
  }

  static String _monthLabel(DateTime d) {
    const months = [
      'Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
      'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassCalendarDialog — popup calendario stile Windows/Jarvis
// Livelli: giorni → mesi → anni → decenni
// ─────────────────────────────────────────────────────────────

class _GlassCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateSelected;
  const _GlassCalendarDialog({
    required this.initialDate,
    required this.onDateSelected,
  });
  @override
  State<_GlassCalendarDialog> createState() =>
      _GlassCalendarDialogState();
}

enum _CalView { days, months, years, decades }

class _GlassCalendarDialogState
    extends State<_GlassCalendarDialog> {
  late DateTime _focus;
  _CalView _view = _CalView.days;

  static const _dayNames = ['L','M','M','G','V','S','D'];
  static const _monthNames = [
    'Gen','Feb','Mar','Apr','Mag','Giu',
    'Lug','Ago','Set','Ott','Nov','Dic'
  ];
  static const _monthNamesFull = [
    'Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
    'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'
  ];

  @override
  void initState() {
    super.initState();
    _focus = widget.initialDate;
  }

  String get _headerLabel {
    switch (_view) {
      case _CalView.days:
        return '${_monthNamesFull[_focus.month - 1]} ${_focus.year}';
      case _CalView.months:
        return '${_focus.year}';
      case _CalView.years:
        final dec = (_focus.year ~/ 10) * 10;
        return '$dec – ${dec + 9}';
      case _CalView.decades:
        final cent = (_focus.year ~/ 100) * 100;
        return '$cent – ${cent + 99}';
    }
  }

  void _prev() {
    setState(() {
      switch (_view) {
        case _CalView.days:
          _focus = DateTime(_focus.year, _focus.month - 1);
          break;
        case _CalView.months:
          _focus = DateTime(_focus.year - 1, _focus.month);
          break;
        case _CalView.years:
          _focus = DateTime(_focus.year - 10, _focus.month);
          break;
        case _CalView.decades:
          _focus = DateTime(_focus.year - 100, _focus.month);
          break;
      }
    });
  }

  void _next() {
    setState(() {
      switch (_view) {
        case _CalView.days:
          _focus = DateTime(_focus.year, _focus.month + 1);
          break;
        case _CalView.months:
          _focus = DateTime(_focus.year + 1, _focus.month);
          break;
        case _CalView.years:
          _focus = DateTime(_focus.year + 10, _focus.month);
          break;
        case _CalView.decades:
          _focus = DateTime(_focus.year + 100, _focus.month);
          break;
      }
    });
  }

  void _drillUp() {
    setState(() {
      switch (_view) {
        case _CalView.days:    _view = _CalView.months;  break;
        case _CalView.months:  _view = _CalView.years;   break;
        case _CalView.years:   _view = _CalView.decades; break;
        case _CalView.decades: break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1117), Color(0xFF060B14)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: _cyan.withOpacity(0.25), width: 1),
              boxShadow: [BoxShadow(
                  color: _cyan.withOpacity(0.06),
                  blurRadius: 28, spreadRadius: 4)],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header navigazione
              Row(children: [
                _CalNavBtn(icon: Icons.chevron_left_rounded,
                    onTap: _prev),
                Expanded(
                  child: GestureDetector(
                    onTap: _drillUp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      child: Text(_headerLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                _CalNavBtn(icon: Icons.chevron_right_rounded,
                    onTap: _next),
              ]),
              const SizedBox(height: 12),
              Container(height: 0.7,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    _cyan.withOpacity(0.3),
                    Colors.transparent]),
                ),
              ),
              const SizedBox(height: 12),
              // Griglia contenuto
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey('${_view}_${_focus.year}_${_focus.month}'),
                  child: _buildGrid(),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    switch (_view) {
      case _CalView.days:    return _buildDaysGrid();
      case _CalView.months:  return _buildMonthsGrid();
      case _CalView.years:   return _buildYearsGrid();
      case _CalView.decades: return _buildDecadesGrid();
    }
  }

  Widget _buildDaysGrid() {
    final firstDay  = DateTime(_focus.year, _focus.month, 1);
    final daysCount = DateTime(_focus.year, _focus.month + 1, 0).day;
    final offset    = (firstDay.weekday - 1) % 7;
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final selNorm   = DateTime(widget.initialDate.year,
        widget.initialDate.month, widget.initialDate.day);

    return Column(children: [
      // Intestazione giorni
      Row(
        children: _dayNames.map((n) => Expanded(
          child: Center(
            child: Text(n, style: TextStyle(
                color: _cyan.withOpacity(0.6), fontSize: 11,
                fontWeight: FontWeight.w700)),
          ),
        )).toList(),
      ),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7, childAspectRatio: 1,
          mainAxisSpacing: 4, crossAxisSpacing: 0),
        itemCount: offset + daysCount,
        itemBuilder: (_, idx) {
          if (idx < offset) return const SizedBox.shrink();
          final day = idx - offset + 1;
          final date = DateTime(_focus.year, _focus.month, day);
          final norm = DateTime(date.year, date.month, date.day);
          final isSel   = norm == selNorm;
          final isToday = norm == today;

          return GestureDetector(
            onTap: () => widget.onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSel
                    ? _teal
                    : isToday
                        ? _cyan.withOpacity(0.15)
                        : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !isSel
                    ? Border.all(
                        color: _cyan.withOpacity(0.5), width: 1)
                    : null,
                boxShadow: isSel
                    ? [BoxShadow(
                        color: _teal.withOpacity(0.4),
                        blurRadius: 8)]
                    : null,
              ),
              child: Center(
                child: Text('$day', style: TextStyle(
                    color: isSel
                        ? Colors.white
                        : Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: isSel || isToday
                        ? FontWeight.w800 : FontWeight.w500)),
              ),
            ),
          );
        },
      ),
    ]);
  }

  Widget _buildMonthsGrid() {
    final now = DateTime.now();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.8,
          mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: 12,
      itemBuilder: (_, i) {
        final isCurrent = _focus.year == now.year && i + 1 == now.month;
        final isSel = i + 1 == widget.initialDate.month &&
            _focus.year == widget.initialDate.year;
        return GestureDetector(
          onTap: () => setState(() {
            _focus = DateTime(_focus.year, i + 1);
            _view  = _CalView.days;
          }),
          child: _CalCell(
            label: _monthNames[i],
            isSelected: isSel,
            isCurrent: isCurrent,
          ),
        );
      },
    );
  }

  Widget _buildYearsGrid() {
    final dec   = (_focus.year ~/ 10) * 10;
    final now   = DateTime.now();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.8,
          mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: 12,
      itemBuilder: (_, i) {
        final year = dec - 1 + i;
        final isCurrent = year == now.year;
        final isSel = year == widget.initialDate.year;
        final isOut = i == 0 || i == 11;
        return GestureDetector(
          onTap: () => setState(() {
            _focus = DateTime(year, _focus.month);
            _view  = _CalView.months;
          }),
          child: _CalCell(
            label: '$year',
            isSelected: isSel,
            isCurrent: isCurrent,
            isOutOfRange: isOut,
          ),
        );
      },
    );
  }

  Widget _buildDecadesGrid() {
    final cent = (_focus.year ~/ 100) * 100;
    final now  = DateTime.now();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.6,
          mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: 12,
      itemBuilder: (_, i) {
        final decStart = cent - 10 + (i * 10);
        final isCurrent = now.year >= decStart &&
            now.year < decStart + 10;
        final isSel = widget.initialDate.year >= decStart &&
            widget.initialDate.year < decStart + 10;
        final isOut = i == 0 || i == 11;
        return GestureDetector(
          onTap: () => setState(() {
            _focus = DateTime(decStart, _focus.month);
            _view  = _CalView.years;
          }),
          child: _CalCell(
            label: '$decStart–${decStart + 9}',
            isSelected: isSel,
            isCurrent: isCurrent,
            isOutOfRange: isOut,
          ),
        );
      },
    );
  }
}

class _CalNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CalNavBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.white.withOpacity(0.12), width: 0.8)),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class _CalCell extends StatelessWidget {
  final String label;
  final bool isSelected, isCurrent, isOutOfRange;
  const _CalCell({
    required this.label,
    this.isSelected  = false,
    this.isCurrent   = false,
    this.isOutOfRange = false,
  });
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: isSelected
            ? _teal.withOpacity(0.2)
            : isCurrent
                ? _cyan.withOpacity(0.08)
                : Colors.white.withOpacity(isOutOfRange ? 0.02 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? _teal.withOpacity(0.7)
              : isCurrent
                  ? _cyan.withOpacity(0.35)
                  : Colors.white.withOpacity(isOutOfRange ? 0.06 : 0.12),
          width: isSelected ? 1.3 : 1,
        ),
        boxShadow: isSelected
            ? [BoxShadow(
                color: _teal.withOpacity(0.25), blurRadius: 8)]
            : null,
      ),
      child: Center(
        child: Text(label, style: TextStyle(
            color: isOutOfRange
                ? Colors.white.withOpacity(0.3)
                : isSelected
                    ? _teal
                    : Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: isSelected || isCurrent
                ? FontWeight.w700 : FontWeight.w500),
          textAlign: TextAlign.center),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _GoalsDaySection (FIX #6 + #7)
// ─────────────────────────────────────────────────────────────

class _GoalsDaySection extends StatelessWidget {
  final List<HiveGoal> goals;
  final DateTime selectedDate;
  final double dayProgress;
  final bool Function(HiveGoal) isCompleted;
  final void Function(HiveGoal) onToggle;
  final VoidCallback onManage;

  const _GoalsDaySection({
    required this.goals,
    required this.selectedDate,
    required this.dayProgress,
    required this.isCompleted,
    required this.onToggle,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel   = DateTime(
        selectedDate.year, selectedDate.month, selectedDate.day);
    final isFuture = sel.isAfter(today);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withOpacity(0.07),
              Colors.white.withOpacity(0.02)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _orange.withOpacity(0.18), width: 0.8)),
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(children: [
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: _orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.track_changes_rounded,
                      size: 16, color: _orange)),
                const SizedBox(width: 10),
                const Text('Obiettivi del giorno',
                    style: TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const Spacer(),
                // Progresso mini
                if (goals.isNotEmpty)
                  _MiniProgress(progress: dayProgress, color: _orange),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onManage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: _orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _orange.withOpacity(0.3), width: 0.8)),
                    child: Text('Gestisci', style: TextStyle(
                        color: _orange, fontSize: 11,
                        fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
            // Lista obiettivi o placeholder
            if (goals.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: Colors.white.withOpacity(0.25), size: 18),
                  const SizedBox(width: 10),
                  Text(
                    isFuture
                        ? 'Nessun obiettivo per questa data'
                        : 'Nessun obiettivo pianificato',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13)),
                ]),
              )
            else
              ...goals.asMap().entries.map((e) {
                final i    = e.key;
                final goal = e.value;
                final done = isCompleted(goal);
                final last = i == goals.length - 1;
                return Column(children: [
                  if (i > 0)
                    Divider(height: 0, thickness: 0.5,
                        indent: 16, endIndent: 16,
                        color: Colors.white.withOpacity(0.05)),
                  _GoalTileGlass(
                    goal: goal,
                    completed: done,
                    isFuture: isFuture,
                    onToggle: () => onToggle(goal),
                  ),
                  if (last) const SizedBox(height: 4),
                ]);
              }),
          ]),
        ),
      ),
    );
  }
}

class _GoalTileGlass extends StatelessWidget {
  final HiveGoal goal;
  final bool completed, isFuture;
  final VoidCallback onToggle;
  const _GoalTileGlass({
    required this.goal,
    required this.completed,
    required this.isFuture,
    required this.onToggle,
  });

  static const _categoryColors = {
    'Studio':       Color(0xFF6366F1),
    'Sport':        Color(0xFF00D4AA),
    'Salute':       Color(0xFF22C55E),
    'Lavoro':       Color(0xFF3B82F6),
    'Alimentazione':Color(0xFFFF8C00),
    'Benessere':    Color(0xFFEC4899),
    'Produttività': Color(0xFF8B5CF6),
    'Hobby':        Color(0xFFF59E0B),
    'Finanze':      Color(0xFF10B981),
    'Lettura':      Color(0xFF6B7280),
    'Meditazione':  Color(0xFF8A2BE2),
    'Personale':    Color(0xFFFF6B6B),
    'Altro':        Color(0xFF9CA3AF),
  };

  Color get _catColor =>
      _categoryColors[goal.category] ?? const Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        // Categoria dot
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: _catColor, shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: _catColor.withOpacity(0.5), blurRadius: 4)]),
        ),
        const SizedBox(width: 10),
        // Icona categoria
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _catColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9)),
          child: Icon(Icons.flag_rounded, size: 16, color: _catColor),
        ),
        const SizedBox(width: 10),
        // Testo
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(goal.title,
              style: TextStyle(
                color: completed
                    ? Colors.white.withOpacity(0.35)
                    : Colors.white,
                fontSize: 13, fontWeight: FontWeight.w600,
                decoration: completed
                    ? TextDecoration.lineThrough : null,
                decorationColor: Colors.white.withOpacity(0.3)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            if (goal.category.isNotEmpty)
              Text(goal.category,
                style: TextStyle(
                    color: _catColor.withOpacity(0.7), fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
        const SizedBox(width: 10),
        // Streak badge
        if (goal.currentStreak > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _orange.withOpacity(0.3), width: 0.7)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔥', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 3),
              Text('${goal.currentStreak}',
                style: const TextStyle(color: _orange,
                    fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 8),
        ],
        // Checkbox neon personalizzata
        GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: completed ? _catColor : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isFuture
                    ? Colors.white.withOpacity(0.12)
                    : completed
                        ? _catColor
                        : Colors.white.withOpacity(0.25),
                width: 1.5),
              boxShadow: completed
                  ? [BoxShadow(
                      color: _catColor.withOpacity(0.45),
                      blurRadius: 8)]
                  : null,
            ),
            child: completed
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 14)
                : null,
          ),
        ),
      ]),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final double progress;
  final Color color;
  const _MiniProgress({required this.progress, required this.color});
  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$pct%', style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      const SizedBox(width: 6),
      SizedBox(
        width: 28, height: 28,
        child: CustomPaint(
          painter: _MiniRingPainter(
              progress: progress, color: color)),
      ),
    ]);
  }
}

class _MiniRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _MiniRingPainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 3;
    canvas.drawCircle(c, r,
      Paint()
        ..color = Colors.white.withOpacity(0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2, 2 * math.pi * progress, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
    }
  }
  @override
  bool shouldRepaint(_MiniRingPainter old) =>
      old.progress != progress;
}

// ─────────────────────────────────────────────────────────────
// _DailyProgressCard
// ─────────────────────────────────────────────────────────────

class _DailyProgressCard extends StatelessWidget {
  final Animation<double> ringAnim;
  final double progress;
  final int completedSets, totalSets, elapsedSec;
  final int workoutCount, exerciseCount;
  final bool hasActive;
  final String Function(int) fmt;

  const _DailyProgressCard({
    required this.ringAnim, required this.progress,
    required this.completedSets, required this.totalSets,
    required this.elapsedSec, required this.workoutCount,
    required this.exerciseCount, required this.hasActive,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = hasActive ? _teal : _cyan.withOpacity(0.4);
    final glowColor = hasActive ? _teal : _cyan;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(0.09),
                Colors.white.withOpacity(0.03)]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: _cyan.withOpacity(0.22), width: 1),
            boxShadow: [BoxShadow(
                color: _cyan.withOpacity(0.07), blurRadius: 30,
                spreadRadius: 2)],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Container(width: 7, height: 7,
                decoration: BoxDecoration(color: _cyan,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: _cyan.withOpacity(0.6), blurRadius: 4)]),
              ),
              const SizedBox(width: 8),
              Text(hasActive
                  ? 'SESSIONE IN CORSO'
                  : 'PROGRESSO GIORNALIERO',
                style: TextStyle(color: _cyan, fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              _NeonProgressRing(
                animation: ringAnim,
                targetProgress: progress,
                ringColor: ringColor,
                glowColor: glowColor,
                size: 118,
                centerLabel: hasActive ? 'Serie' : 'Pronto'),
              const SizedBox(width: 18),
              Expanded(
                child: Column(children: [
                  _StatMicroCard(
                    icon: Icons.fitness_center_rounded,
                    label: 'Schede',
                    value: hasActive
                        ? '$completedSets/$totalSets'
                        : '$workoutCount',
                    color: _teal),
                  const SizedBox(height: 8),
                  _StatMicroCard(
                    icon: Icons.timer_rounded, label: 'Tempo',
                    value: hasActive ? fmt(elapsedSec) : '--',
                    color: _cyan),
                  const SizedBox(height: 8),
                  _StatMicroCard(
                    icon: Icons.list_alt_rounded, label: 'Esercizi',
                    value: '$exerciseCount', color: _indigo),
                ]),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _NeonProgressRing
// ─────────────────────────────────────────────────────────────

class _NeonProgressRing extends StatelessWidget {
  final Animation<double> animation;
  final double targetProgress;
  final Color ringColor, glowColor;
  final double size;
  final String centerLabel;
  const _NeonProgressRing({
    required this.animation, required this.targetProgress,
    required this.ringColor, required this.glowColor,
    required this.size, required this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final p =
            (animation.value * targetProgress).clamp(0.0, 1.0);
        return SizedBox(
          width: size, height: size,
          child: CustomPaint(
            painter: _RingPainter(
                progress: p, ringColor: ringColor,
                glowColor: glowColor),
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text('${(p * 100).round()}%',
                    style: TextStyle(color: ringColor,
                        fontSize: size * 0.21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1)),
                Text(centerLabel,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: size * 0.09,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor, glowColor;
  const _RingPainter({
    required this.progress, required this.ringColor,
    required this.glowColor,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const start  = -math.pi / 2;
    final sweep  = 2 * math.pi * progress;
    canvas.drawCircle(center, radius,
      Paint()
        ..color = Colors.white.withOpacity(0.07)
        ..style = PaintingStyle.stroke ..strokeWidth = 9);
    if (progress <= 0.01) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start, sweep, false,
      Paint()
        ..color = glowColor.withOpacity(0.22)
        ..style = PaintingStyle.stroke ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start, sweep, false,
      Paint()
        ..color = ringColor ..style = PaintingStyle.stroke
        ..strokeWidth = 9 ..strokeCap = StrokeCap.round);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start, sweep, false,
      Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..style = PaintingStyle.stroke ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter =
            const MaskFilter.blur(BlurStyle.normal, 1.5));
    if (sweep > 0.05) {
      final ex = center.dx + radius * math.cos(start + sweep);
      final ey = center.dy + radius * math.sin(start + sweep);
      canvas.drawCircle(Offset(ex, ey), 5,
        Paint()..color = ringColor
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawCircle(
          Offset(ex, ey), 3, Paint()..color = Colors.white);
    }
  }
  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress;
}

// ─────────────────────────────────────────────────────────────
// _StatMicroCard
// ─────────────────────────────────────────────────────────────

class _StatMicroCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatMicroCard({
    required this.icon, required this.label,
    required this.value, required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withOpacity(0.2), width: 0.8)),
          child: Row(children: [
            Container(width: 28, height: 28,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, size: 14, color: color)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(value,
                    style: TextStyle(color: color, fontSize: 14,
                        fontWeight: FontWeight.w800),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(label, style: TextStyle(
                    color: Colors.white.withOpacity(0.38),
                    fontSize: 9, fontWeight: FontWeight.w500)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SectionHeader
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String? trailingLabel;
  final VoidCallback? onTrailing;
  const _SectionHeader({
    required this.icon, required this.title, required this.color,
    this.trailingLabel, this.onTrailing,
  });
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 16, color: color)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(color: Colors.white,
          fontSize: 16, fontWeight: FontWeight.w800,
          letterSpacing: -0.2)),
      const Spacer(),
      if (trailingLabel != null && onTrailing != null)
        GestureDetector(
          onTap: onTrailing,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: color.withOpacity(0.3), width: 0.8)),
            child: Text(trailingLabel!, style: TextStyle(
                color: color, fontSize: 11,
                fontWeight: FontWeight.w700)),
          ),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// _QuickStartGrid — FIX #1: nessun push isolato, tab switch
// ─────────────────────────────────────────────────────────────

class _QuickStartGrid extends StatelessWidget {
  final VoidCallback onPalestra, onRunning, onCiclismo, onNuoto;
  const _QuickStartGrid({
    required this.onPalestra, required this.onRunning,
    required this.onCiclismo, required this.onNuoto,
  });
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12, crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _QuickCard(icon: Icons.fitness_center_rounded,
            label: 'Palestra', sublabel: 'Pesi e circuiti',
            color: _purple, onTap: onPalestra),
        _QuickCard(icon: Icons.directions_run_rounded,
            label: 'Running', sublabel: 'Corsa e sprint',
            color: _orange, onTap: onRunning),
        _QuickCard(icon: Icons.directions_bike_rounded,
            label: 'Ciclismo', sublabel: 'Bici e cardio',
            color: _green, onTap: onCiclismo),
        _QuickCard(icon: Icons.pool_rounded,
            label: 'Nuoto', sublabel: 'Vasche e tecnica',
            color: _blue, onTap: onNuoto),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final Color color;
  final VoidCallback onTap;
  const _QuickCard({
    required this.icon, required this.label,
    required this.sublabel, required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.15),
                  Colors.white.withOpacity(0.02)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: color.withOpacity(0.35), width: 1),
              boxShadow: [BoxShadow(
                  color: color.withOpacity(0.14),
                  blurRadius: 18, spreadRadius: 1)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 10)]),
                    child: Icon(icon, color: color, size: 22)),
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(label, style: const TextStyle(
                        color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(sublabel, style: TextStyle(
                        color: Colors.white.withOpacity(0.38),
                        fontSize: 10)),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _WorkoutMiniCard
// ─────────────────────────────────────────────────────────────

class _WorkoutMiniCard extends StatelessWidget {
  final HiveWorkout workout;
  final SessionProvider sp;
  final VoidCallback onEdit, onPlay;
  const _WorkoutMiniCard({
    required this.workout, required this.sp,
    required this.onEdit, required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final hasPaused = sp.hasPausedSessionForWorkout(workout.key);
    final hasActive = sp.hasActiveSession &&
        sp.currentWorkout?.key == workout.key;
    final indicator = hasPaused ? _orange
        : hasActive  ? _blue  : null;
    final exercises = HiveDatabase.instance
        .getWorkoutExercises(workout.key);
    final free = exercises.where((e) => !e.isInCircuit).length;
    final circuits =
        HiveDatabase.instance.getCircuits(workout.key);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.02)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: indicator != null
                  ? indicator.withOpacity(0.38)
                  : _teal.withOpacity(0.18),
              width: 0.8)),
          child: Row(children: [
            WorkoutAvatar(
              iconId: workout.iconId ?? 'dumbbell',
              iconColorIndex: workout.iconColorIndex ?? 0,
              customImagePath: workout.customImagePath,
              size: 42, iconSize: 21, borderRadius: 11),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                    child: Text(workout.name,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                  if (indicator != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: indicator.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        hasPaused ? 'In pausa' : 'In corso',
                        style: TextStyle(color: indicator,
                            fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  if (free > 0) _TinyPill(label: '$free eserc.'),
                  if (circuits.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _TinyPill(label: '${circuits.length} circuiti'),
                  ],
                ]),
              ]),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.12))),
                child: Icon(Icons.edit_outlined,
                    color: Colors.white.withOpacity(0.5), size: 16)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onPlay,
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: hasPaused
                      ? [_orange, _orangeWarm]
                      : [_green, const Color(0xFF16A34A)]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: (hasPaused ? _orange : _green)
                          .withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 2))]),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 20)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Micro helpers
// ─────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _MiniStat({required this.icon, required this.label,
      required this.color});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: color.withOpacity(0.8)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
          color: color.withOpacity(0.9), fontSize: 11,
          fontWeight: FontWeight.w600)),
    ]);
}

class _TinyPill extends StatelessWidget {
  final String label;
  const _TinyPill({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(
          color: Colors.white.withOpacity(0.12), width: 0.7)),
    child: Text(label, style: TextStyle(
        color: Colors.white.withOpacity(0.5), fontSize: 10,
        fontWeight: FontWeight.w600)));
}