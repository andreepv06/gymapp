import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/navigation/app_router.dart';
import '../../core/theme/markfit_colors.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../models/goal_models.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/avatar_picker_sheet.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';
import '../../widgets/workout_icon.dart';
import '../../main.dart';
import '../goals/goals_screen.dart';
import '../session/active_session_screen.dart';
import '../workouts/workout_detail_screen.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';

// ── Accent tokens (fissi in entrambi i temi) ─────────────────
const _cyan = Color(0xFF00E5FF);
const _teal = Color(0xFF00D4AA);
const _tealDk = Color(0xFF00A880);
const _indigo = Color(0xFF6366F1);
const _orange = Color(0xFFFF8C00);
const _orangeWarm = Color(0xFFFF6B00);
const _red = Color(0xFFFF3B30);
const _green = Color(0xFF22C55E);
const _blue = Color(0xFF3B82F6);
const _purple = Color(0xFF8A2BE2);

// ─────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<WorkoutProvider>().loadWorkouts();
      context.read<ExerciseProvider>().loadExercises();
      context.read<GoalProvider>().loadGoals();
    });
  }

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

  void _goToAllenamenti() =>
      context.read<NavigationNotifier>().navigateTo(1);

  // FIX MODIFICA 2A — navigazione settimanale Home
  void _shiftWeek(int days) =>
      setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));

  void _goToToday() => setState(() => _selectedDate = DateTime.now());

  // FIX MODIFICA 2B — dati reali del giorno selezionato (non più
  // sempre "oggi"): schede completate, esercizi, serie, durata.
  _DailyJourneyData _computeDailyJourney(DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final sessions = HiveDatabase.instance
        .getSessions()
        .where((s) => s.date.startsWith(dateStr))
        .toList();
    int completedSets = 0, totalSets = 0, totalDuration = 0;
    final exerciseNames = <String>{};
    final workoutNames = <String>[];
    for (final s in sessions) {
      workoutNames.add(s.workoutName);
      totalDuration += s.durationSeconds ?? 0;
      final sets = HiveDatabase.instance.getSessionSets(s.key);
      for (final set in sets) {
        totalSets++;
        if (set.completed) completedSets++;
        exerciseNames.add(set.exerciseName);
      }
    }
    return _DailyJourneyData(
      workoutCount: sessions.length,
      exerciseCount: exerciseNames.length,
      completedSets: completedSets,
      totalSets: totalSets,
      totalDurationSeconds: totalDuration,
      workoutNames: workoutNames,
    );
  }

  Future<void> _handleWorkoutPlay(HiveWorkout workout) async {
    final wp = context.read<WorkoutProvider>();
    final sp = context.read<SessionProvider>();
    wp.loadWorkoutExercises(workout.key);
    if (sp.hasActiveSession && sp.currentWorkout?.key == workout.key) {
      final result = await showGlassDialog<String>(
        context: context, accentColor: _blue,
        icon: Container(width: 44, height: 44,
          decoration: BoxDecoration(
            color: _blue.withOpacity(0.12), shape: BoxShape.circle,
            border: Border.all(color: _blue.withOpacity(0.4))),
          child: const Icon(Icons.sports_gymnastics_rounded,
              color: Color(0xFF60A5FA), size: 22)),
        title: 'Sessione in corso',
        message: 'Hai una sessione attiva per "${workout.name}".',
        actionsAxis: Axis.vertical,
        actions: [
          GlassDialogAction(label: 'Continua sessione', isDefault: true,
              color: _blue, onTap: () => Navigator.pop(context, 'continue')),
          GlassDialogAction(label: 'Avvia nuova sessione', isDestructive: true,
              onTap: () => Navigator.pop(context, 'new')),
          GlassDialogAction(label: 'Annulla',
              onTap: () => Navigator.pop(context, 'cancel')),
        ]);
      if (!mounted) return;
      if (result == null || result == 'cancel') return;
      if (result == 'new') await sp.abandonSession();
      if (!mounted) return;
      pushPage(context, ActiveSessionScreen(workout: workout));
      return;
    }
    if (sp.hasPausedSessionForWorkout(workout.key)) {
      final paused = sp.getMostRecentPausedForWorkout(workout.key);
      final result = await showGlassDialog<String>(
        context: context, accentColor: _orange,
        icon: Container(width: 44, height: 44,
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.12), shape: BoxShape.circle,
            border: Border.all(color: _orange.withOpacity(0.4)),
            boxShadow: [BoxShadow(
                color: _orange.withOpacity(0.2), blurRadius: 12)]),
          child: const Icon(Icons.pause_circle_outline_rounded,
              color: _orange, size: 22)),
        title: 'Sessione in pausa',
        message: 'Hai una sessione in pausa per "${workout.name}".',
        actionsAxis: Axis.vertical,
        actions: [
          GlassDialogAction(label: 'Riprendi sessione', isDefault: true,
              color: _orange, onTap: () => Navigator.pop(context, 'resume')),
          GlassDialogAction(label: 'Avvia nuova sessione',
              onTap: () => Navigator.pop(context, 'new')),
          GlassDialogAction(label: 'Annulla',
              onTap: () => Navigator.pop(context, 'cancel')),
        ]);
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

  void _handleGoalToggle(HiveGoal goal) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (sel.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Non puoi completare obiettivi futuri.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF0D1117),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2)));
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
        }));
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature — prossimamente',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFF0D1117),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SessionProvider>();
    final wp = context.watch<WorkoutProvider>();
    final ep = context.watch<ExerciseProvider>();
    final gp = context.watch<GoalProvider>();
    final workouts = wp.workouts;
    final goalsForDay = gp.goalsForDate(_selectedDate);
    final dayProgress = gp.completionPercentageForDate(_selectedDate);
    final goalsDone =
        goalsForDay.where((g) => gp.isCompletedOn(g, _selectedDate)).length;
    final journey = _computeDailyJourney(_selectedDate);
    final sysBottom = MediaQuery.of(context).viewPadding.bottom;

    return CosmicBackground(
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 20, 20, 88 + sysBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeHeader(
                  greeting: _greeting(),
                  date: _formattedDate()),
              const SizedBox(height: 14),
              if (sp.hasPausedSessions && !sp.hasActiveSession) ...[
                _PausedSessionsBanner(
                    sp: sp, fmt: _fmt,
                    onGoToAllenamenti: _goToAllenamenti),
                const SizedBox(height: 12),
              ],
              if (sp.hasActiveSession) ...[
                _ActiveSessionBanner(sp: sp, fmt: _fmt),
                const SizedBox(height: 12),
              ],
              _WeekCalendarSection(
                selectedDate: _selectedDate,
                onDateSelected: (d) => setState(() => _selectedDate = d),
                onCalendarOpen: _showCalendarPopup,
                onWeekShift: _shiftWeek,
                onGoToToday: _goToToday),
              const SizedBox(height: 14),
              _GoalsDaySection(
                goals: goalsForDay,
                selectedDate: _selectedDate,
                dayProgress: dayProgress,
                isCompleted: (g) => gp.isCompletedOn(g, _selectedDate),
                onToggle: _handleGoalToggle,
                onManage: () => pushPage(context, const GoalsScreen())),
              const SizedBox(height: 14),
              _DailyJourneyCard(
                date: _selectedDate,
                journey: journey,
                goalsDone: goalsDone,
                goalsTotal: goalsForDay.length,
                goalsProgress: dayProgress,
                onOpenDetail: () => _showDailyJourneyDetail(
                    context, _selectedDate, journey, goalsForDay,
                    (g) => gp.isCompletedOn(g, _selectedDate))),
              const SizedBox(height: 14),
              _SectionHeader(
                  icon: Icons.bolt_rounded, title: 'Avvio rapido', color: _teal),
              const SizedBox(height: 10),
              _QuickStartGrid(
                onPalestra: _goToAllenamenti,
                onRunning: () => _showComingSoon('Running'),
                onCiclismo: () => _showComingSoon('Ciclismo'),
                onNuoto: () => _showComingSoon('Nuoto')),
              const SizedBox(height: 14),
              if (workouts.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.fitness_center_rounded,
                  title: 'Le tue schede',
                  color: _indigo,
                  trailingLabel: workouts.length > 2 ? 'Vedi tutte' : null,
                  onTrailing: _goToAllenamenti),
                const SizedBox(height: 10),
                ...workouts.take(2).map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WorkoutMiniCard(
                    workout: w, sp: sp,
                    onEdit: () {
                      context.read<WorkoutProvider>().loadWorkoutExercises(w.key);
                      pushPage(context, WorkoutDetailScreen(
                          workoutId: w.key, workoutName: w.name));
                    },
                    onPlay: () => _handleWorkoutPlay(w)))),
              ],
              // exCount usato solo internamente da altri widget legacy;
              // mantenuto ep watch per triggerare rebuild quando la
              // libreria esercizi cambia (usato da _WorkoutMiniCard).
              if (ep.exercises.isEmpty) const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _HomeHeader — ADATTIVO + avatar tappabile (FIX MODIFICA 1)
// ─────────────────────────────────────────────────────────────
class _HomeHeader extends StatelessWidget {
  final String greeting, date;
  const _HomeHeader({required this.greeting, required this.date});
  static const _phrases = [
    'Ogni rep conta.', 'Il progresso è costante.',
    'Oggi supera ieri.', 'Forza e costanza.',
    'Non fermarti mai.', 'Il corpo segue la mente.',
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
    final c = context.mfc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cyan.withOpacity(0.2), width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 18,
                    offset: const Offset(0, 3))]
                : [BoxShadow(color: _teal.withOpacity(0.06),
                    blurRadius: 20, spreadRadius: 1)]),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: _teal, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color: _teal.withOpacity(0.7), blurRadius: 5)])),
                    const SizedBox(width: 7),
                    Text('MARKFIT', style: TextStyle(
                        color: _teal, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                  ]),
                  const SizedBox(height: 10),
                  Text(greeting, style: TextStyle(
                      color: c.textPrimary, fontSize: 26,
                      fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 3),
                  Text(date, style: TextStyle(
                      color: c.textTertiary, fontSize: 12)),
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
                        color: _teal.withOpacity(0.85),
                        fontSize: 11, fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic))),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const _ProfileAvatar(),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ProfileAvatar — FIX MODIFICA 1
//
// Fonte unica: AuthProvider.avatarBase64. Ora tappabile: apre
// direttamente lo sheet condiviso (Fotocamera/Galleria/Rimuovi),
// senza dover passare dalle Impostazioni (Parte 8 del fix).
// ─────────────────────────────────────────────────────────────
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final b64 = auth.avatarBase64;
    final hasAvatar = b64 != null && b64.isNotEmpty;
    Widget inner;
    if (hasAvatar) {
      try {
        final bytes = base64Decode(b64!);
        inner = Image.memory(bytes, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.person_rounded,
                    color: Colors.white, size: 28));
      } catch (_) {
        inner = const Icon(Icons.person_rounded,
            color: Colors.white, size: 28);
      }
    } else {
      inner = const Icon(Icons.person_rounded,
          color: Colors.white, size: 28);
    }
    return GestureDetector(
      onTap: () => showAvatarPickerSheet(context),
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: hasAvatar ? null : LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_teal.withOpacity(0.3), _cyan.withOpacity(0.1)]),
          shape: BoxShape.circle,
          border: Border.all(color: _teal.withOpacity(0.6), width: 1.5),
          boxShadow: [BoxShadow(
              color: _teal.withOpacity(0.3), blurRadius: 16, spreadRadius: 1)]),
        child: ClipOval(child: inner)));
  }
}

// ─────────────────────────────────────────────────────────────
// _PausedSessionsBanner — invariato
// ─────────────────────────────────────────────────────────────
class _PausedSessionsBanner extends StatelessWidget {
  final SessionProvider sp;
  final String Function(int) fmt;
  final VoidCallback onGoToAllenamenti;
  const _PausedSessionsBanner({
    required this.sp, required this.fmt, required this.onGoToAllenamenti});
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    final paused = sp.pausedSessions;
    final count = paused.length;
    final first = count > 0 ? paused.first : null;
    final name = first?['workoutName'] as String? ?? 'Sessione';
    final elapsed = (first?['elapsedAtPause'] as num?)?.toInt() ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_orange.withOpacity(0.18), _orangeWarm.withOpacity(0.08)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _orange.withOpacity(0.45), width: 1.3),
            boxShadow: [BoxShadow(color: _orange.withOpacity(0.2),
                blurRadius: 24, spreadRadius: 1)]),
          child: Row(children: [
            Container(width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _orange.withOpacity(0.3), _orangeWarm.withOpacity(0.15)]),
                shape: BoxShape.circle,
                border: Border.all(color: _orange.withOpacity(0.5), width: 1.2),
                boxShadow: [BoxShadow(
                    color: _orange.withOpacity(0.3), blurRadius: 10)]),
              child: const Icon(Icons.pause_circle_filled_rounded,
                  color: _orange, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(children: [
                Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: _orange, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: _orange.withOpacity(0.7), blurRadius: 4)])),
                const SizedBox(width: 6),
                Text(count == 1 ? 'SESSIONE IN PAUSA' : '$count SESSIONI IN PAUSA',
                    style: TextStyle(color: _orange, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: 1.1)),
              ]),
              const SizedBox(height: 4),
              Text(name, style: TextStyle(
                  color: c.textPrimary, fontSize: 14,
                  fontWeight: FontWeight.w700),
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
            ])),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onGoToAllenamenti,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_orange, _orangeWarm]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _orange.withOpacity(0.45),
                      blurRadius: 12, offset: const Offset(0, 3))]),
                child: const Text('Riprendi', style: TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w700)))),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ActiveSessionBanner — invariato
// ─────────────────────────────────────────────────────────────
class _ActiveSessionBanner extends StatelessWidget {
  final SessionProvider sp;
  final String Function(int) fmt;
  const _ActiveSessionBanner({required this.sp, required this.fmt});
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
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
            border: Border.all(color: _blue.withOpacity(0.45), width: 1.2),
            boxShadow: [BoxShadow(
                color: _blue.withOpacity(0.2), blurRadius: 22)]),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                  color: _blue.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.sports_gymnastics_rounded,
                  color: Color(0xFF60A5FA), size: 23)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text('SESSIONE ATTIVA', style: TextStyle(
                  color: Color(0xFF60A5FA), fontSize: 9,
                  fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(height: 3),
              Text(name, style: TextStyle(
                  color: c.textPrimary, fontSize: 14,
                  fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Row(children: [
                _MiniStat(icon: Icons.timer_rounded,
                    label: fmt(sp.elapsedSeconds),
                    color: const Color(0xFF60A5FA)),
                const SizedBox(width: 10),
                _MiniStat(icon: Icons.check_rounded,
                    label: '${sp.completedSetsCount}/${sp.totalSetsCount} serie',
                    color: const Color(0xFF60A5FA)),
              ]),
            ])),
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
                  color: _blue,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [BoxShadow(color: _blue.withOpacity(0.45),
                      blurRadius: 12, offset: const Offset(0, 3))]),
                child: const Text('Riprendi', style: TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w700)))),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _WeekCalendarSection — FIX MODIFICA 2A
//
// PRIMA: `monday` era sempre calcolato da DateTime.now(), quindi
// la barra mostrava sempre la settimana corrente indipendentemente
// da `selectedDate` — bug esplicito (Parte 16).
// ORA: `monday` è calcolato dalla settimana di `selectedDate`, con
// navigazione ←/→ tra settimane e un'azione rapida "Torna a oggi"
// visibile SOLO quando la settimana visualizzata non è quella
// corrente (Parte 17/18/19).
// ─────────────────────────────────────────────────────────────
class _WeekCalendarSection extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onCalendarOpen;
  final void Function(int days) onWeekShift;
  final VoidCallback onGoToToday;
  const _WeekCalendarSection({
    required this.selectedDate, required this.onDateSelected,
    required this.onCalendarOpen, required this.onWeekShift,
    required this.onGoToToday});
  static String _monthLabel(DateTime d) {
    const months = ['Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
        'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];
    return '${months[d.month - 1]} ${d.year}';
  }
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    const names = ['Lun','Mar','Mer','Gio','Ven','Sab','Dom'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    // FIX: la settimana visualizzata segue SEMPRE selectedDate, non
    // più sempre "oggi".
    final monday = selDay.subtract(Duration(days: selectedDate.weekday - 1));
    final todayMonday = today.subtract(Duration(days: now.weekday - 1));
    final isCurrentWeek = monday == todayMonday;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cyan.withOpacity(0.15), width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 10,
                    offset: const Offset(0, 2))]
                : null),
          child: Column(children: [
            Row(children: [
              GestureDetector(
                onTap: onCalendarOpen,
                child: Row(children: [
                  Text(_monthLabel(selectedDate), style: TextStyle(
                      color: c.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      color: _cyan.withOpacity(0.7), size: 18),
                ])),
              const Spacer(),
              // FIX Parte 18: "Torna a oggi" mostrato SOLO se non
              // siamo già nella settimana corrente.
              if (!isCurrentWeek) ...[
                GestureDetector(
                  onTap: onGoToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: _teal.withOpacity(0.35), width: 0.8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.today_rounded, size: 12, color: _teal),
                      const SizedBox(width: 4),
                      Text('Oggi', style: TextStyle(
                          color: _teal, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                    ]))),
                const SizedBox(width: 8),
              ],
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
                      color: _cyan, size: 16))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              // FIX Parte 17: navigazione settimana precedente
              GestureDetector(
                onTap: () => onWeekShift(-7),
                child: Container(
                  width: 24, height: 24,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: c.glassCardInset,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.glassBorder, width: 0.7)),
                  child: Icon(Icons.chevron_left_rounded,
                      size: 15, color: c.iconSecondary))),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final day = monday.add(Duration(days: i));
                    final dayNorm = DateTime(day.year, day.month, day.day);
                    final isSel = dayNorm == selDay;
                    final isToday = dayNorm == today;
                    final isPast = dayNorm.isBefore(today);
                    return GestureDetector(
                      onTap: () => onDateSelected(day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? _teal.withOpacity(0.18) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel
                                ? _teal.withOpacity(0.6)
                                : isToday
                                    ? _cyan.withOpacity(0.35)
                                    : Colors.transparent,
                            width: 1),
                          boxShadow: isSel
                              ? [BoxShadow(color: _teal.withOpacity(0.2), blurRadius: 8)]
                              : null),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(names[i], style: TextStyle(
                              color: isSel ? _teal
                                  : isToday ? _cyan
                                  : c.textTertiary,
                              fontSize: 9, fontWeight: FontWeight.w700,
                              letterSpacing: 0.3)),
                          const SizedBox(height: 7),
                          Container(width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: isSel ? _teal : Colors.transparent,
                              shape: BoxShape.circle),
                            child: Center(child: Text('${day.day}', style: TextStyle(
                                color: isSel ? Colors.white : c.textPrimary,
                                fontSize: 13,
                                fontWeight: isSel || isToday
                                    ? FontWeight.w800 : FontWeight.w500)))),
                          const SizedBox(height: 5),
                          Container(width: 4, height: 4,
                            decoration: BoxDecoration(
                              color: isToday ? _cyan
                                  : isPast ? _teal.withOpacity(0.4)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              boxShadow: isToday
                                  ? [BoxShadow(color: _cyan.withOpacity(0.6), blurRadius: 3)]
                                  : null)),
                        ]),
                      ));
                  }),
                ),
              ),
              // FIX Parte 17: navigazione settimana successiva
              GestureDetector(
                onTap: () => onWeekShift(7),
                child: Container(
                  width: 24, height: 24,
                  margin: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(
                    color: c.glassCardInset,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.glassBorder, width: 0.7)),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 15, color: c.iconSecondary))),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassCalendarDialog — invariato (già coerente: giorno→mese→
// anno→intervallo anni, senza salti; questa è l'implementazione
// di riferimento usata per correggere quella dello Storico).
// ─────────────────────────────────────────────────────────────
class _GlassCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateSelected;
  const _GlassCalendarDialog({
    required this.initialDate, required this.onDateSelected});
  @override
  State<_GlassCalendarDialog> createState() => _GlassCalendarDialogState();
}
enum _CalView { days, months, years, decades }
class _GlassCalendarDialogState extends State<_GlassCalendarDialog> {
  late DateTime _focus;
  _CalView _view = _CalView.days;
  static const _dayNames = ['L','M','M','G','V','S','D'];
  static const _monthNames = ['Gen','Feb','Mar','Apr','Mag','Giu',
      'Lug','Ago','Set','Ott','Nov','Dic'];
  static const _monthNamesFull = ['Gennaio','Febbraio','Marzo','Aprile',
      'Maggio','Giugno','Luglio','Agosto','Settembre',
      'Ottobre','Novembre','Dicembre'];
  @override
  void initState() { super.initState(); _focus = widget.initialDate; }
  String get _headerLabel {
    switch (_view) {
      case _CalView.days:
        return '${_monthNamesFull[_focus.month - 1]} ${_focus.year}';
      case _CalView.months: return '${_focus.year}';
      case _CalView.years:
        final dec = (_focus.year ~/ 10) * 10; return '$dec – ${dec + 9}';
      case _CalView.decades:
        final cent = (_focus.year ~/ 100) * 100; return '$cent – ${cent + 99}';
    }
  }
  void _prev() => setState(() {
    switch (_view) {
      case _CalView.days: _focus = DateTime(_focus.year, _focus.month - 1); break;
      case _CalView.months: _focus = DateTime(_focus.year - 1, _focus.month); break;
      case _CalView.years: _focus = DateTime(_focus.year - 10, _focus.month); break;
      case _CalView.decades: _focus = DateTime(_focus.year - 100, _focus.month); break;
    }
  });
  void _next() => setState(() {
    switch (_view) {
      case _CalView.days: _focus = DateTime(_focus.year, _focus.month + 1); break;
      case _CalView.months: _focus = DateTime(_focus.year + 1, _focus.month); break;
      case _CalView.years: _focus = DateTime(_focus.year + 10, _focus.month); break;
      case _CalView.decades: _focus = DateTime(_focus.year + 100, _focus.month); break;
    }
  });
  void _drillUp() => setState(() {
    switch (_view) {
      case _CalView.days: _view = _CalView.months; break;
      case _CalView.months: _view = _CalView.years; break;
      case _CalView.years: _view = _CalView.decades; break;
      case _CalView.decades: break;
    }
  });
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D1117), Color(0xFF060B14)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _cyan.withOpacity(0.25), width: 1),
              boxShadow: [BoxShadow(color: _cyan.withOpacity(0.06),
                  blurRadius: 28, spreadRadius: 4)]),
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                _CalNavBtn(icon: Icons.chevron_left_rounded, onTap: _prev),
                Expanded(child: GestureDetector(
                  onTap: _drillUp,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text(_headerLabel, textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.w800))))),
                _CalNavBtn(icon: Icons.chevron_right_rounded, onTap: _next),
              ]),
              const SizedBox(height: 12),
              Container(height: 0.7,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [
                  Colors.transparent, _cyan.withOpacity(0.3), Colors.transparent]))),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey('${_view}_${_focus.year}_${_focus.month}'),
                  child: _buildGrid())),
            ]),
          ),
        ),
      ),
    );
  }
  Widget _buildGrid() {
    switch (_view) {
      case _CalView.days: return _buildDaysGrid();
      case _CalView.months: return _buildMonthsGrid();
      case _CalView.years: return _buildYearsGrid();
      case _CalView.decades: return _buildDecadesGrid();
    }
  }
  Widget _buildDaysGrid() {
    final firstDay = DateTime(_focus.year, _focus.month, 1);
    final daysCount = DateTime(_focus.year, _focus.month + 1, 0).day;
    final offset = (firstDay.weekday - 1) % 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selNorm = DateTime(widget.initialDate.year,
        widget.initialDate.month, widget.initialDate.day);
    return Column(children: [
      Row(children: _dayNames.map((n) => Expanded(
        child: Center(child: Text(n, style: TextStyle(
            color: _cyan.withOpacity(0.6), fontSize: 11,
            fontWeight: FontWeight.w700))))).toList()),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, childAspectRatio: 1, mainAxisSpacing: 4),
        itemCount: offset + daysCount,
        itemBuilder: (_, idx) {
          if (idx < offset) return const SizedBox.shrink();
          final day = idx - offset + 1;
          final date = DateTime(_focus.year, _focus.month, day);
          final norm = DateTime(date.year, date.month, date.day);
          final isSel = norm == selNorm;
          final isToday = norm == today;
          return GestureDetector(
            onTap: () => widget.onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSel ? _teal
                    : isToday ? _cyan.withOpacity(0.15)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !isSel
                    ? Border.all(color: _cyan.withOpacity(0.5), width: 1)
                    : null,
                boxShadow: isSel
                    ? [BoxShadow(color: _teal.withOpacity(0.4), blurRadius: 8)]
                    : null),
              child: Center(child: Text('$day', style: TextStyle(
                  color: isSel ? Colors.white : Colors.white.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: isSel || isToday
                      ? FontWeight.w800 : FontWeight.w500)))));
        }),
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
        final isCur = _focus.year == now.year && i + 1 == now.month;
        final isSel = i + 1 == widget.initialDate.month &&
            _focus.year == widget.initialDate.year;
        return GestureDetector(
          onTap: () => setState(() {
            _focus = DateTime(_focus.year, i + 1); _view = _CalView.days;
          }),
          child: _CalCell(label: _monthNames[i],
              isSelected: isSel, isCurrent: isCur));
      });
  }
  Widget _buildYearsGrid() {
    final dec = (_focus.year ~/ 10) * 10; final now = DateTime.now();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.8,
          mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: 12,
      itemBuilder: (_, i) {
        final year = dec - 1 + i;
        final isCur = year == now.year;
        final isSel = year == widget.initialDate.year;
        final isOut = i == 0 || i == 11;
        return GestureDetector(
          onTap: () => setState(() {
            _focus = DateTime(year, _focus.month); _view = _CalView.months;
          }),
          child: _CalCell(label: '$year',
              isSelected: isSel, isCurrent: isCur, isOutOfRange: isOut));
      });
  }
  Widget _buildDecadesGrid() {
    final cent = (_focus.year ~/ 100) * 100; final now = DateTime.now();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.6,
          mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: 12,
      itemBuilder: (_, i) {
        final decStart = cent - 10 + (i * 10);
        final isCur = now.year >= decStart && now.year < decStart + 10;
        final isSel = widget.initialDate.year >= decStart &&
            widget.initialDate.year < decStart + 10;
        final isOut = i == 0 || i == 11;
        return GestureDetector(
          onTap: () => setState(() {
            _focus = DateTime(decStart, _focus.month); _view = _CalView.years;
          }),
          child: _CalCell(label: '$decStart–${decStart + 9}',
              isSelected: isSel, isCurrent: isCur, isOutOfRange: isOut));
      });
  }
}
class _CalNavBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _CalNavBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 36, height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.8)),
      child: Icon(icon, color: Colors.white, size: 20)));
}
class _CalCell extends StatelessWidget {
  final String label;
  final bool isSelected, isCurrent, isOutOfRange;
  const _CalCell({required this.label,
      this.isSelected = false, this.isCurrent = false,
      this.isOutOfRange = false});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 140),
    decoration: BoxDecoration(
      color: isSelected ? _teal.withOpacity(0.2)
          : isCurrent ? _cyan.withOpacity(0.08)
          : Colors.white.withOpacity(isOutOfRange ? 0.02 : 0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isSelected ? _teal.withOpacity(0.7)
            : isCurrent ? _cyan.withOpacity(0.35)
            : Colors.white.withOpacity(isOutOfRange ? 0.06 : 0.12),
        width: isSelected ? 1.3 : 1),
      boxShadow: isSelected
          ? [BoxShadow(color: _teal.withOpacity(0.25), blurRadius: 8)] : null),
    child: Center(child: Text(label, textAlign: TextAlign.center,
        style: TextStyle(
            color: isOutOfRange ? Colors.white.withOpacity(0.3)
                : isSelected ? _teal : Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: isSelected || isCurrent
                ? FontWeight.w700 : FontWeight.w500))));
}

// ─────────────────────────────────────────────────────────────
// _GoalsDaySection — invariato
// ─────────────────────────────────────────────────────────────
class _GoalsDaySection extends StatelessWidget {
  final List<HiveGoal> goals;
  final DateTime selectedDate;
  final double dayProgress;
  final bool Function(HiveGoal) isCompleted;
  final void Function(HiveGoal) onToggle;
  final VoidCallback onManage;
  const _GoalsDaySection({
    required this.goals, required this.selectedDate,
    required this.dayProgress, required this.isCompleted,
    required this.onToggle, required this.onManage});
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isFuture = sel.isAfter(today);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _orange.withOpacity(0.18), width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 10,
                    offset: const Offset(0, 2))]
                : null),
          child: Column(children: [
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
                Text('Obiettivi del giorno', style: TextStyle(
                    color: c.textPrimary, fontSize: 15,
                    fontWeight: FontWeight.w800)),
                const Spacer(),
                if (goals.isNotEmpty) ...[
                  _MiniProgressRing(
                      progress: dayProgress,
                      color: _orange,
                      trackColor: c.divider),
                  const SizedBox(width: 8),
                ],
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
                        fontWeight: FontWeight.w700)))),
              ])),
            if (goals.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: c.textTertiary, size: 18),
                  const SizedBox(width: 10),
                  Text(isFuture
                      ? 'Nessun obiettivo per questa data'
                      : 'Nessun obiettivo pianificato',
                      style: TextStyle(color: c.textTertiary, fontSize: 13)),
                ]))
            else
              ...goals.asMap().entries.map((e) {
                final i = e.key;
                final goal = e.value;
                final done = isCompleted(goal);
                return Column(children: [
                  if (i > 0)
                    Divider(height: 0, thickness: 0.5,
                        indent: 16, endIndent: 16, color: c.divider),
                  _GoalTileGlass(
                    goal: goal, completed: done,
                    isFuture: isFuture,
                    onToggle: () => onToggle(goal)),
                  if (i == goals.length - 1) const SizedBox(height: 4),
                ]);
              }),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _GoalTileGlass — invariato
// ─────────────────────────────────────────────────────────────
class _GoalTileGlass extends StatelessWidget {
  final HiveGoal goal;
  final bool completed, isFuture;
  final VoidCallback onToggle;
  const _GoalTileGlass({
    required this.goal, required this.completed,
    required this.isFuture, required this.onToggle});
  static const _catColors = <String, Color>{
    'Studio': Color(0xFF6366F1), 'Sport': Color(0xFF00D4AA),
    'Salute': Color(0xFF22C55E), 'Lavoro': Color(0xFF3B82F6),
    'Alimentazione': Color(0xFFFF8C00), 'Benessere': Color(0xFFEC4899),
    'Produttività': Color(0xFF8B5CF6), 'Hobby': Color(0xFFF59E0B),
    'Tempo libero': Color(0xFF06B6D4), 'Finanze': Color(0xFF10B981),
    'Lettura': Color(0xFF6B7280), 'Meditazione': Color(0xFF8A2BE2),
    'Personale': Color(0xFFFF6B6B), 'Altro': Color(0xFF9CA3AF),
  };
  Color get _catColor => _catColors[goal.category] ?? const Color(0xFF9CA3AF);
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(
            color: _catColor, shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: _catColor.withOpacity(0.5), blurRadius: 4)])),
        const SizedBox(width: 10),
        Container(width: 32, height: 32,
          decoration: BoxDecoration(
              color: _catColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(Icons.flag_rounded, size: 16, color: _catColor)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(goal.title, style: TextStyle(
              color: completed ? c.textTertiary : c.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w600,
              decoration: completed ? TextDecoration.lineThrough : null,
              decorationColor: c.textTertiary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (goal.category.isNotEmpty)
            Text(goal.category, style: TextStyle(
                color: _catColor.withOpacity(0.7), fontSize: 10,
                fontWeight: FontWeight.w500)),
        ])),
        const SizedBox(width: 10),
        if (goal.currentStreak > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _orange.withOpacity(0.3), width: 0.7)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔥', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 3),
              Text('${goal.currentStreak}', style: const TextStyle(
                  color: _orange, fontSize: 10, fontWeight: FontWeight.w700)),
            ])),
          const SizedBox(width: 8),
        ],
        GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: completed ? _catColor : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isFuture ? c.divider
                    : completed ? _catColor
                    : c.glassBorder,
                width: 1.5),
              boxShadow: completed
                  ? [BoxShadow(color: _catColor.withOpacity(0.45), blurRadius: 8)]
                  : null),
            child: completed
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _MiniProgressRing + _MiniRingPainter — invariati
// ─────────────────────────────────────────────────────────────
class _MiniProgressRing extends StatelessWidget {
  final double progress;
  final Color color;
  final Color trackColor;
  const _MiniProgressRing({
    required this.progress, required this.color, required this.trackColor});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
    Text('${(progress * 100).round()}%', style: TextStyle(
        color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    const SizedBox(width: 6),
    SizedBox(width: 28, height: 28,
      child: CustomPaint(painter: _MiniRingPainter(
          progress: progress, color: color, trackColor: trackColor))),
  ]);
}
class _MiniRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  const _MiniRingPainter({
    required this.progress, required this.color, required this.trackColor});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 3;
    canvas.drawCircle(c, r,
      Paint()..color = trackColor
        ..style = PaintingStyle.stroke ..strokeWidth = 3);
    if (progress > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        -math.pi / 2, 2 * math.pi * progress, false,
        Paint()..color = color ..style = PaintingStyle.stroke
          ..strokeWidth = 3 ..strokeCap = StrokeCap.round);
    }
  }
  @override
  bool shouldRepaint(_MiniRingPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────
// _DailyJourneyData — FIX MODIFICA 2B
// Struttura dati pura per il "Percorso giornaliero", calcolata
// da HomeScreen._computeDailyJourney(date) — sempre relativa alla
// data selezionata (mai fissa su "oggi").
// ─────────────────────────────────────────────────────────────
class _DailyJourneyData {
  final int workoutCount;
  final int exerciseCount;
  final int completedSets;
  final int totalSets;
  final int totalDurationSeconds;
  final List<String> workoutNames;
  const _DailyJourneyData({
    required this.workoutCount,
    required this.exerciseCount,
    required this.completedSets,
    required this.totalSets,
    required this.totalDurationSeconds,
    required this.workoutNames,
  });
  bool get hasActivity => workoutCount > 0;
}

// ─────────────────────────────────────────────────────────────
// _DailyJourneyCard — FIX MODIFICA 2B
//
// Sostituisce il vecchio "Progresso giornaliero" (che mostrava
// sempre e solo lo stato della sessione attiva, senza alcun
// legame con la data selezionata né con gli obiettivi reali).
//
// Ora mostra:
// - percentuale di progresso REALE basata sugli obiettivi del
//   giorno selezionato (goalsDone/goalsTotal — Parte 24, "NON
//   utilizzare una percentuale arbitraria");
// - riepilogo compatto di cosa è successo in quel giorno
//   (allenamento/i, esercizi, serie, durata) letto da Hive per
//   la data selezionata (Parte 30: "collegato alla data
//   attualmente selezionata nella Home");
// - stato esplicito "Nessun allenamento oggi" quando non c'è
//   attività, senza apparire vuoto (Parte 26);
// - tap per aprire il dettaglio (bottom sheet, Parte 28/29).
// ─────────────────────────────────────────────────────────────
class _DailyJourneyCard extends StatelessWidget {
  final DateTime date;
  final _DailyJourneyData journey;
  final int goalsDone, goalsTotal;
  final double goalsProgress;
  final VoidCallback onOpenDetail;
  const _DailyJourneyCard({
    required this.date,
    required this.journey,
    required this.goalsDone,
    required this.goalsTotal,
    required this.goalsProgress,
    required this.onOpenDetail,
  });

  String _fmt(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}min';
    return s > 0 ? '${s}s' : '--';
  }

  String _dayLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(date.year, date.month, date.day);
    final diff = sel.difference(today).inDays;
    if (diff == 0) return 'OGGI';
    if (diff == -1) return 'IERI';
    if (diff == 1) return 'DOMANI';
    const days = ['Lun','Mar','Mer','Gio','Ven','Sab','Dom'];
    return '${days[date.weekday - 1]} ${date.day}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    final hasActivity = journey.hasActivity;
    final ringColor = hasActivity ? _teal : _cyan.withOpacity(0.5);

    return GestureDetector(
      onTap: onOpenDetail,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.glassCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _cyan.withOpacity(0.22), width: 1),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 20,
                      offset: const Offset(0, 3))]
                  : [BoxShadow(color: _cyan.withOpacity(0.07),
                      blurRadius: 30, spreadRadius: 2)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: _cyan, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: _cyan.withOpacity(0.6), blurRadius: 4)])),
                  const SizedBox(width: 8),
                  Text('PERCORSO ${_dayLabel()}',
                    style: TextStyle(color: _cyan, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded,
                      color: c.textTertiary, size: 16),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  _NeonProgressRing(
                    progress: goalsTotal > 0 ? goalsProgress : 0,
                    ringColor: ringColor,
                    glowColor: ringColor,
                    trackColor: c.divider,
                    size: 100,
                    centerLabel: goalsTotal > 0 ? 'Obiettivi' : 'Nessun\nobiettivo'),
                  const SizedBox(width: 18),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    if (!hasActivity)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Icon(Icons.event_busy_rounded,
                              size: 14, color: c.textTertiary),
                          const SizedBox(width: 6),
                          Expanded(child: Text('Nessun allenamento',
                              style: TextStyle(
                                  color: c.textTertiary, fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                        ]),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Icon(Icons.check_circle_rounded,
                              size: 14, color: _teal),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                              journey.workoutNames.take(1).join(', ') +
                                  (journey.workoutCount > 1
                                      ? ' +${journey.workoutCount - 1}' : ''),
                              style: TextStyle(
                                  color: c.textPrimary, fontSize: 12,
                                  fontWeight: FontWeight.w700),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    _JourneyStatRow(
                        icon: Icons.list_alt_rounded, label: 'Esercizi',
                        value: hasActivity ? '${journey.exerciseCount}' : '--',
                        color: _indigo),
                    const SizedBox(height: 6),
                    _JourneyStatRow(
                        icon: Icons.repeat_rounded, label: 'Serie',
                        value: hasActivity
                            ? '${journey.completedSets}/${journey.totalSets}'
                            : '--',
                        color: _teal),
                    const SizedBox(height: 6),
                    _JourneyStatRow(
                        icon: Icons.timer_rounded, label: 'Durata',
                        value: hasActivity
                            ? _fmt(journey.totalDurationSeconds) : '--',
                        color: _cyan),
                    const SizedBox(height: 6),
                    _JourneyStatRow(
                        icon: Icons.track_changes_rounded, label: 'Obiettivi',
                        value: goalsTotal > 0
                            ? '$goalsDone/$goalsTotal' : 'Nessuno',
                        color: _orange),
                  ])),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyStatRow extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _JourneyStatRow({required this.icon, required this.label,
      required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Row(children: [
      Icon(icon, size: 13, color: color.withOpacity(0.8)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(
          color: c.textTertiary, fontSize: 11, fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(value, style: TextStyle(
          color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// _showDailyJourneyDetail — FIX MODIFICA 2B (Parte 28)
// Bottom sheet compatta con il dettaglio del giorno: elenco
// allenamenti effettuati e obiettivi del giorno con relativo stato.
// Nessuna nuova schermata complessa — coerente con l'UI esistente
// (GlassSheetWrapper già usato in tutta l'app).
// ─────────────────────────────────────────────────────────────
void _showDailyJourneyDetail(
  BuildContext context,
  DateTime date,
  _DailyJourneyData journey,
  List<HiveGoal> goals,
  bool Function(HiveGoal) isCompleted,
) {
  const months = ['','Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno',
      'Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];
  final label = '${date.day} ${months[date.month]} ${date.year}';

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final c = ctx.mfc;
      return GlassSheetWrapper(
        title: 'Percorso giornaliero',
        subtitle: label,
        accentColor: _cyan,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ALLENAMENTO', style: TextStyle(
                color: _teal.withOpacity(0.8), fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            if (!journey.hasActivity)
              Text('Nessun allenamento effettuato in questa data.',
                  style: TextStyle(color: c.textTertiary, fontSize: 13))
            else
              ...journey.workoutNames.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(Icons.fitness_center_rounded,
                      size: 15, color: _teal),
                  const SizedBox(width: 8),
                  Expanded(child: Text(n, style: TextStyle(
                      color: c.textPrimary, fontSize: 13,
                      fontWeight: FontWeight.w600))),
                ]))),
            const SizedBox(height: 14),
            Text('OBIETTIVI', style: TextStyle(
                color: _orange.withOpacity(0.8), fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            if (goals.isEmpty)
              Text('Nessun obiettivo pianificato per questa data.',
                  style: TextStyle(color: c.textTertiary, fontSize: 13))
            else
              ...goals.map((g) {
                final done = isCompleted(g);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 15,
                        color: done ? _orange : c.textTertiary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(g.title, style: TextStyle(
                        color: done ? c.textTertiary : c.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null))),
                  ]),
                );
              }),
            const SizedBox(height: 16),
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
                    style: TextStyle(
                        color: c.textPrimary, fontSize: 14,
                        fontWeight: FontWeight.w600)))),
          ],
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────
// _NeonProgressRing + _RingPainter — invariati (riusati anche
// dal nuovo _DailyJourneyCard)
// ─────────────────────────────────────────────────────────────
class _NeonProgressRing extends StatelessWidget {
  final double progress;
  final Color ringColor, glowColor, trackColor;
  final double size;
  final String centerLabel;
  const _NeonProgressRing({
    required this.progress,
    required this.ringColor, required this.glowColor,
    required this.trackColor, required this.size, required this.centerLabel});
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    final p = progress.clamp(0.0, 1.0);
    return SizedBox(width: size, height: size,
      child: CustomPaint(
        painter: _RingPainter(
            progress: p, ringColor: ringColor,
            glowColor: glowColor, trackColor: trackColor),
        child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Text('${(p * 100).round()}%', style: TextStyle(
              color: ringColor, fontSize: size * 0.21,
              fontWeight: FontWeight.w800, letterSpacing: -1)),
          Text(centerLabel, textAlign: TextAlign.center, style: TextStyle(
              color: c.textTertiary,
              fontSize: size * 0.09, fontWeight: FontWeight.w500)),
        ]))));
  }
}
class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor, glowColor, trackColor;
  const _RingPainter({required this.progress, required this.ringColor,
      required this.glowColor, required this.trackColor});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;
    canvas.drawCircle(center, radius,
      Paint()..color = trackColor
        ..style = PaintingStyle.stroke ..strokeWidth = 9);
    if (progress <= 0.01) return;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      start, sweep, false,
      Paint()..color = glowColor.withOpacity(0.22)
        ..style = PaintingStyle.stroke ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      start, sweep, false,
      Paint()..color = ringColor ..style = PaintingStyle.stroke
        ..strokeWidth = 9 ..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      start, sweep, false,
      Paint()..color = Colors.white.withOpacity(0.55)
        ..style = PaintingStyle.stroke ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
    if (sweep > 0.05) {
      final ex = center.dx + radius * math.cos(start + sweep);
      final ey = center.dy + radius * math.sin(start + sweep);
      canvas.drawCircle(Offset(ex, ey), 5,
        Paint()..color = ringColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawCircle(Offset(ex, ey), 3, Paint()..color = Colors.white);
    }
  }
  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────
// _SectionHeader — invariato
// ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon; final String title; final Color color;
  final String? trailingLabel; final VoidCallback? onTrailing;
  const _SectionHeader({required this.icon, required this.title,
      required this.color, this.trailingLabel, this.onTrailing});
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Row(children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 16, color: color)),
      const SizedBox(width: 10),
      Text(title, style: TextStyle(
          color: c.textPrimary,
          fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
      const Spacer(),
      if (trailingLabel != null && onTrailing != null)
        GestureDetector(
          onTap: onTrailing,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3), width: 0.8)),
            child: Text(trailingLabel!, style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// _QuickStartGrid — invariato
// ─────────────────────────────────────────────────────────────
class _QuickStartGrid extends StatelessWidget {
  final VoidCallback onPalestra, onRunning, onCiclismo, onNuoto;
  const _QuickStartGrid({
    required this.onPalestra, required this.onRunning,
    required this.onCiclismo, required this.onNuoto});
  @override
  Widget build(BuildContext context) => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
    childAspectRatio: 1.35,
    children: [
      _QuickCard(icon: Icons.fitness_center_rounded, label: 'Palestra',
          sublabel: 'Pesi e circuiti', color: _purple, onTap: onPalestra),
      _QuickCard(icon: Icons.directions_run_rounded, label: 'Running',
          sublabel: 'Corsa e sprint', color: _orange, onTap: onRunning),
      _QuickCard(icon: Icons.directions_bike_rounded, label: 'Ciclismo',
          sublabel: 'Bici e cardio', color: _green, onTap: onCiclismo),
      _QuickCard(icon: Icons.pool_rounded, label: 'Nuoto',
          sublabel: 'Vasche e tecnica', color: _blue, onTap: onNuoto),
    ]);
}

// ─────────────────────────────────────────────────────────────
// _QuickCard — invariato
// ─────────────────────────────────────────────────────────────
class _QuickCard extends StatelessWidget {
  final IconData icon; final String label, sublabel;
  final Color color; final VoidCallback onTap;
  const _QuickCard({required this.icon, required this.label,
      required this.sublabel, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
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
                colors: [color.withOpacity(0.15), color.withOpacity(0.04)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.35), width: 1),
              boxShadow: [
                if (c.showElevation)
                  BoxShadow(color: c.elevationColor, blurRadius: 8,
                      offset: const Offset(0, 2)),
                BoxShadow(color: color.withOpacity(0.14), blurRadius: 18,
                    spreadRadius: 1),
              ]),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: color.withOpacity(0.3), blurRadius: 10)]),
                  child: Icon(icon, color: color, size: 22)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(sublabel, style: TextStyle(
                      color: c.textTertiary,
                      fontSize: 10)),
                ]),
              ]))))));
  }
}

// ─────────────────────────────────────────────────────────────
// _WorkoutMiniCard — invariato
// ─────────────────────────────────────────────────────────────
class _WorkoutMiniCard extends StatelessWidget {
  final HiveWorkout workout; final SessionProvider sp;
  final VoidCallback onEdit, onPlay;
  const _WorkoutMiniCard({required this.workout, required this.sp,
      required this.onEdit, required this.onPlay});
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    final hasPaused = sp.hasPausedSessionForWorkout(workout.key);
    final hasActive = sp.hasActiveSession &&
        sp.currentWorkout?.key == workout.key;
    final indicator = hasPaused ? _orange : hasActive ? _blue : null;
    final exercises = HiveDatabase.instance.getWorkoutExercises(workout.key);
    final free = exercises.where((e) => !e.isInCircuit).length;
    final circuits = HiveDatabase.instance.getCircuits(workout.key);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: indicator != null
                  ? indicator.withOpacity(0.38)
                  : _teal.withOpacity(0.18),
              width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 8,
                    offset: const Offset(0, 2))]
                : null),
          child: Row(children: [
            WorkoutAvatar(
              iconId: workout.iconId ?? 'dumbbell',
              iconColorIndex: workout.iconColorIndex ?? 0,
              customImagePath: workout.customImagePath,
              size: 42, iconSize: 21, borderRadius: 11),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(children: [
                Expanded(child: Text(workout.name, style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                          fontSize: 9, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                if (free > 0) _TinyPill(label: '$free eserc.'),
                if (circuits.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _TinyPill(label: '${circuits.length} circuiti')],
              ]),
            ])),
            const SizedBox(width: 10),
            GestureDetector(onTap: onEdit,
              child: Container(width: 34, height: 34,
                decoration: BoxDecoration(
                  color: c.glassCardInset,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: c.glassBorder)),
                child: Icon(Icons.edit_outlined,
                    color: c.iconSecondary, size: 16))),
            const SizedBox(width: 8),
            GestureDetector(onTap: onPlay,
              child: Container(width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: hasPaused
                      ? [_orange, _orangeWarm]
                      : [_green, const Color(0xFF16A34A)]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: (hasPaused ? _orange : _green).withOpacity(0.4),
                      blurRadius: 10, offset: const Offset(0, 2))]),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 20))),
          ]))));
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

// ─────────────────────────────────────────────────────────────
// _TinyPill — invariato
// ─────────────────────────────────────────────────────────────
class _TinyPill extends StatelessWidget {
  final String label;
  const _TinyPill({required this.label});
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.glassCardInset,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.glassBorder, width: 0.7)),
      child: Text(label, style: TextStyle(
          color: c.textTertiary,
          fontSize: 10, fontWeight: FontWeight.w600)));
  }
}