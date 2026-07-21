import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';
import '../../widgets/workout_icon.dart';
import '../session/active_session_screen.dart';
import '../workouts/allenamenti_screen.dart';
import '../workouts/workout_detail_screen.dart';

// ── Design tokens — identici ad AllenamentiScreen ────────────
const _cyan   = Color(0xFF00E5FF);
const _teal   = Color(0xFF00D4AA);
const _tealDk = Color(0xFF00A880);
const _indigo = Color(0xFF6366F1);
const _orange = Color(0xFFFF8C00);
const _red    = Color(0xFFFF3B30);
const _green  = Color(0xFF22C55E);
const _blue   = Color(0xFF3B82F6);
const _purple = Color(0xFF8A2BE2);

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

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400));
    _ringAnim = CurvedAnimation(
        parent: _ringCtrl, curve: Curves.easeOutCubic);

    Future.microtask(() {
      if (!mounted) return;
      context.read<WorkoutProvider>().loadWorkouts();
      context.read<ExerciseProvider>().loadExercises();
      _ringCtrl.forward();
    });
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  // ── Helper testo ─────────────────────────────────────────────

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buongiorno';
    if (h < 18) return 'Buon pomeriggio';
    return 'Buonasera';
  }

  String _formattedDate() {
    const days = [
      'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì',
      'Venerdì', 'Sabato', 'Domenica',
    ];
    const months = [
      'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
      'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }

  String _fmt(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}min';
    return '${s}s';
  }

  // ── Navigazione ───────────────────────────────────────────────

  void _goToAllenamenti() =>
      pushPage(context, const AllenamentiScreen());

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — prossimamente',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF0D1117),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sp        = context.watch<SessionProvider>();
    final wp        = context.watch<WorkoutProvider>();
    final ep        = context.watch<ExerciseProvider>();
    final workouts  = wp.workouts;
    final exCount   = ep.exercises.length;
    final completed = sp.completedSetsCount;
    final total     = sp.totalSetsCount;
    final progress  = total > 0 ? completed / total : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ────── Header ─────────────────────────────────
                _HomeHeader(
                  greeting: _greeting(),
                  date: _formattedDate(),
                ),
                const SizedBox(height: 16),

                // ────── Sessione attiva ────────────────────────
                if (sp.hasActiveSession) ...[
                  _ActiveSessionBanner(sp: sp, fmt: _fmt),
                  const SizedBox(height: 16),
                ],

                // ────── Sessioni in pausa ──────────────────────
                if (sp.hasPausedSessions && !sp.hasActiveSession) ...[
                  _PausedMini(sp: sp, fmt: _fmt),
                  const SizedBox(height: 16),
                ],

                // ────── Progress card ──────────────────────────
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
                const SizedBox(height: 16),

                // ────── Calendario settimanale ─────────────────
                _SectionHeader(
                  icon: Icons.calendar_month_rounded,
                  title: 'Settimana',
                  color: _cyan,
                ),
                const SizedBox(height: 10),
                const _WeeklyCalendar(),
                const SizedBox(height: 16),

                // ────── Avvio rapido 2×2 ──────────────────────
                _SectionHeader(
                  icon: Icons.bolt_rounded,
                  title: 'Avvio rapido',
                  color: _teal,
                  trailingLabel: workouts.isNotEmpty ? 'Tutte' : null,
                  onTrailing: _goToAllenamenti,
                ),
                const SizedBox(height: 10),
                _QuickStartGrid(
                  onPalestra: _goToAllenamenti,
                  onRunning:  () => _showComingSoon('Running'),
                  onCiclismo: () => _showComingSoon('Ciclismo'),
                  onNuoto:    () => _showComingSoon('Nuoto'),
                ),
                const SizedBox(height: 16),

                // ────── Schede recenti ─────────────────────────
                if (workouts.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.fitness_center_rounded,
                    title: 'Le tue schede',
                    color: _indigo,
                    trailingLabel:
                        workouts.length > 2 ? 'Vedi tutte' : null,
                    onTrailing: _goToAllenamenti,
                  ),
                  const SizedBox(height: 10),
                  ...workouts.take(2).map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WorkoutMiniCard(
                      workout: w,
                      sp: sp,
                      onEdit: () {
                        context
                            .read<WorkoutProvider>()
                            .loadWorkoutExercises(w.key);
                        pushPage(
                          context,
                          WorkoutDetailScreen(
                            workoutId: w.key,
                            workoutName: w.name,
                          ),
                        );
                      },
                      onPlay: () {
                        context
                            .read<WorkoutProvider>()
                            .loadWorkoutExercises(w.key);
                        pushPage(context,
                            ActiveSessionScreen(workout: w));
                      },
                    ),
                  )),
                  const SizedBox(height: 6),
                ],

                // ────── Obiettivi del giorno ───────────────────
                _SectionHeader(
                  icon: Icons.track_changes_rounded,
                  title: 'Obiettivi del giorno',
                  color: _orange,
                ),
                const SizedBox(height: 10),
                const _TodayGoalsSection(),
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.09),
                Colors.white.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: _cyan.withOpacity(0.2), width: 0.8),
            boxShadow: [
              BoxShadow(
                  color: _teal.withOpacity(0.06),
                  blurRadius: 20, spreadRadius: 1)
            ],
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label app
                  Row(children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: _teal, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color: _teal.withOpacity(0.7),
                            blurRadius: 5)],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text('MARKFIT',
                        style: TextStyle(
                            color: _teal, fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8)),
                  ]),
                  const SizedBox(height: 10),
                  // Saluto
                  Text(greeting,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 3),
                  // Data
                  Text(date,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12)),
                  const SizedBox(height: 10),
                  // Frase motivazionale
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _teal.withOpacity(0.18), width: 0.7),
                    ),
                    child: Text(_phrase,
                        style: TextStyle(
                            color: _teal.withOpacity(0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Avatar Jarvis
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _teal.withOpacity(0.3),
                    _cyan.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _teal.withOpacity(0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: _teal.withOpacity(0.3),
                      blurRadius: 16, spreadRadius: 1)
                ],
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
// _ActiveSessionBanner
// ─────────────────────────────────────────────────────────────

class _ActiveSessionBanner extends StatelessWidget {
  final SessionProvider sp;
  final String Function(int) fmt;
  const _ActiveSessionBanner(
      {required this.sp, required this.fmt});

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
              _blue.withOpacity(0.25),
              _blue.withOpacity(0.07),
            ]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: _blue.withOpacity(0.45), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: _blue.withOpacity(0.2), blurRadius: 22)
            ],
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: _blue.withOpacity(0.2),
                  shape: BoxShape.circle),
              child: const Icon(Icons.sports_gymnastics_rounded,
                  color: Color(0xFF60A5FA), size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SESSIONE ATTIVA',
                      style: TextStyle(
                          color: const Color(0xFF60A5FA),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 3),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Row(children: [
                    _MiniStat(
                        icon: Icons.timer_rounded,
                        label: fmt(sp.elapsedSeconds),
                        color: const Color(0xFF60A5FA)),
                    const SizedBox(width: 10),
                    _MiniStat(
                        icon: Icons.check_rounded,
                        label:
                            '${sp.completedSetsCount}/${sp.totalSetsCount} serie',
                        color: const Color(0xFF60A5FA)),
                  ]),
                ],
              ),
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
                  color: _blue,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                        color: _blue.withOpacity(0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: const Text('Riprendi',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _PausedMini
// ─────────────────────────────────────────────────────────────

class _PausedMini extends StatelessWidget {
  final SessionProvider sp;
  final String Function(int) fmt;
  const _PausedMini({required this.sp, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final paused = sp.pausedSessions;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _orange.withOpacity(0.14),
              _orange.withOpacity(0.04),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _orange.withOpacity(0.35), width: 1),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: _orange.withOpacity(0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.pause_rounded,
                  color: _orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${paused.length} session${paused.length == 1 ? 'e' : 'i'} in pausa',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                  Text('Riprendi dalla sezione Allenamenti',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () =>
                  pushPage(context, const AllenamentiScreen()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: _orange.withOpacity(0.4)),
                ),
                child: const Text('Vedi',
                    style: TextStyle(
                        color: _orange, fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
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
    required this.ringAnim,
    required this.progress,
    required this.completedSets,
    required this.totalSets,
    required this.elapsedSec,
    required this.workoutCount,
    required this.exerciseCount,
    required this.hasActive,
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.09),
                Colors.white.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: _cyan.withOpacity(0.22), width: 1),
            boxShadow: [
              BoxShadow(
                  color: _cyan.withOpacity(0.07),
                  blurRadius: 30, spreadRadius: 2)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Row(children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: _cyan, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: _cyan.withOpacity(0.6), blurRadius: 4)],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  hasActive
                      ? 'SESSIONE IN CORSO'
                      : 'PROGRESSO GIORNALIERO',
                  style: TextStyle(
                      color: _cyan, fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2),
                ),
              ]),
              const SizedBox(height: 20),
              // Ring + micro-card stats
              Row(children: [
                // Anello progresso
                _NeonProgressRing(
                  animation: ringAnim,
                  targetProgress: progress,
                  ringColor: ringColor,
                  glowColor: glowColor,
                  size: 118,
                  centerLabel: hasActive ? 'Serie' : 'Pronto',
                ),
                const SizedBox(width: 18),
                // Colonna statistiche
                Expanded(
                  child: Column(children: [
                    _StatMicroCard(
                      icon: Icons.fitness_center_rounded,
                      label: 'Schede',
                      value: hasActive
                          ? '$completedSets/$totalSets'
                          : '$workoutCount',
                      color: _teal,
                    ),
                    const SizedBox(height: 8),
                    _StatMicroCard(
                      icon: Icons.timer_rounded,
                      label: 'Tempo',
                      value: hasActive
                          ? fmt(elapsedSec)
                          : '--',
                      color: _cyan,
                    ),
                    const SizedBox(height: 8),
                    _StatMicroCard(
                      icon: Icons.list_alt_rounded,
                      label: 'Esercizi',
                      value: '$exerciseCount',
                      color: _indigo,
                    ),
                  ]),
                ),
              ]),
            ],
          ),
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
    required this.animation,
    required this.targetProgress,
    required this.ringColor,
    required this.glowColor,
    required this.size,
    required this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final p = (animation.value * targetProgress).clamp(0.0, 1.0);
        return SizedBox(
          width: size, height: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: p,
              ringColor: ringColor,
              glowColor: glowColor,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(p * 100).round()}%',
                    style: TextStyle(
                        color: ringColor,
                        fontSize: size * 0.21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1),
                  ),
                  Text(centerLabel,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: size * 0.09,
                          fontWeight: FontWeight.w500)),
                ],
              ),
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
    required this.progress,
    required this.ringColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const start  = -math.pi / 2;
    final sweep  = 2 * math.pi * progress;

    // Track
    canvas.drawCircle(center, radius,
      Paint()
        ..color = Colors.white.withOpacity(0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9);

    if (progress <= 0.01) return;

    // Outer glow
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start, sweep, false,
      Paint()
        ..color = glowColor.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // Main arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start, sweep, false,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );

    // Neon core
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start, sweep, false,
      Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // Dot endpoint
    if (sweep > 0.05) {
      final ex = center.dx + radius * math.cos(start + sweep);
      final ey = center.dy + radius * math.sin(start + sweep);
      canvas.drawCircle(
        Offset(ex, ey), 5,
        Paint()
          ..color = ringColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
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
                color: color.withOpacity(0.2), width: 0.8),
          ),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          color: color, fontSize: 14,
                          fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(label,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.38),
                          fontSize: 9,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _WeeklyCalendar
// ─────────────────────────────────────────────────────────────

class _WeeklyCalendar extends StatefulWidget {
  const _WeeklyCalendar();

  @override
  State<_WeeklyCalendar> createState() =>
      _WeeklyCalendarState();
}

class _WeeklyCalendarState extends State<_WeeklyCalendar> {
  late int _sel;

  @override
  void initState() {
    super.initState();
    _sel = DateTime.now().weekday - 1;
  }

  @override
  Widget build(BuildContext context) {
    const names = ['Lun','Mar','Mer','Gio','Ven','Sab','Dom'];
    final now = DateTime.now();
    final todayIdx = now.weekday - 1;
    final monday =
        now.subtract(Duration(days: now.weekday - 1));

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withOpacity(0.07),
              Colors.white.withOpacity(0.02),
            ]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: _cyan.withOpacity(0.14), width: 0.8),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day =
                  monday.add(Duration(days: i));
              final isSel   = _sel == i;
              final isToday = i == todayIdx;
              final isPast  = i < todayIdx;

              return GestureDetector(
                onTap: () =>
                    setState(() => _sel = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel
                        ? _teal.withOpacity(0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel
                          ? _teal.withOpacity(0.55)
                          : isToday
                              ? _cyan.withOpacity(0.3)
                              : Colors.transparent,
                      width: 1,
                    ),
                    boxShadow: isSel
                        ? [BoxShadow(
                            color: _teal.withOpacity(0.18),
                            blurRadius: 8)]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nome giorno
                      Text(names[i],
                          style: TextStyle(
                              color: isSel
                                  ? _teal
                                  : isToday
                                      ? _cyan
                                      : Colors.white.withOpacity(0.3),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3)),
                      const SizedBox(height: 7),
                      // Numero
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: isSel ? _teal : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${day.day}',
                              style: TextStyle(
                                  color: isSel
                                      ? Colors.white
                                      : Colors.white
                                          .withOpacity(0.7),
                                  fontSize: 13,
                                  fontWeight:
                                      isSel || isToday
                                          ? FontWeight.w800
                                          : FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Indicatore
                      Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(
                          color: isToday
                              ? _cyan
                              : isPast
                                  ? _teal.withOpacity(0.45)
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                          boxShadow: isToday
                              ? [BoxShadow(
                                  color: _cyan.withOpacity(0.6),
                                  blurRadius: 3)]
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
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
    required this.icon,
    required this.title,
    required this.color,
    this.trailingLabel,
    this.onTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
              color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w800,
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
                  color: color.withOpacity(0.3), width: 0.8),
            ),
            child: Text(trailingLabel!,
                style: TextStyle(
                    color: color, fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// _QuickStartGrid — layout 2×2
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
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _QuickCard(
          icon: Icons.fitness_center_rounded,
          label: 'Palestra',
          sublabel: 'Pesi e circuiti',
          color: _purple,
          onTap: onPalestra,
        ),
        _QuickCard(
          icon: Icons.directions_run_rounded,
          label: 'Running',
          sublabel: 'Corsa e sprint',
          color: _orange,
          onTap: onRunning,
        ),
        _QuickCard(
          icon: Icons.directions_bike_rounded,
          label: 'Ciclismo',
          sublabel: 'Bici e cardio',
          color: _green,
          onTap: onCiclismo,
        ),
        _QuickCard(
          icon: Icons.pool_rounded,
          label: 'Nuoto',
          sublabel: 'Vasche e tecnica',
          color: _blue,
          onTap: onNuoto,
        ),
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.15),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: color.withOpacity(0.35), width: 1),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.14),
                    blurRadius: 18, spreadRadius: 1)
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 10)
                      ],
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(sublabel,
                          style: TextStyle(
                              color:
                                  Colors.white.withOpacity(0.38),
                              fontSize: 10)),
                    ],
                  ),
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
    final indicator = hasPaused
        ? _orange
        : hasActive
            ? _blue
            : null;
    final exercises =
        HiveDatabase.instance.getWorkoutExercises(workout.key);
    final free    = exercises.where((e) => !e.isInCircuit).length;
    final circuits = HiveDatabase.instance.getCircuits(workout.key);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding:
              const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.02),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: indicator != null
                  ? indicator.withOpacity(0.38)
                  : _teal.withOpacity(0.18),
              width: 0.8,
            ),
          ),
          child: Row(children: [
            WorkoutAvatar(
              iconId: workout.iconId ?? 'dumbbell',
              iconColorIndex: workout.iconColorIndex ?? 0,
              customImagePath: workout.customImagePath,
              size: 42, iconSize: 21, borderRadius: 11,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(workout.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (indicator != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: indicator.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hasPaused ? 'In pausa' : 'In corso',
                          style: TextStyle(
                              color: indicator, fontSize: 9,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (free > 0)
                      _TinyPill(label: '$free eserc.'),
                    if (circuits.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _TinyPill(
                          label:
                              '${circuits.length} circuiti'),
                    ],
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Pulsante modifica
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.12)),
                ),
                child: Icon(Icons.edit_outlined,
                    color: Colors.white.withOpacity(0.5), size: 16),
              ),
            ),
            const SizedBox(width: 8),
            // Play
            GestureDetector(
              onTap: onPlay,
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: hasPaused
                      ? [_orange, const Color(0xFFFF6B00)]
                      : [_green, const Color(0xFF16A34A)]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: (hasPaused ? _orange : _green)
                            .withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _TodayGoalsSection — checkbox neon personalizzate
// ─────────────────────────────────────────────────────────────

class _TodayGoalsSection extends StatefulWidget {
  const _TodayGoalsSection();

  @override
  State<_TodayGoalsSection> createState() =>
      _TodayGoalsSectionState();
}

class _TodayGoalsSectionState
    extends State<_TodayGoalsSection> {
  final List<_Goal> _goals = [
    _Goal(
        label: 'Completare allenamento',
        icon: Icons.fitness_center_rounded,
        color: _teal),
    _Goal(
        label: '8.000 passi oggi',
        icon: Icons.directions_walk_rounded,
        color: _green),
    _Goal(
        label: 'Bere 2L di acqua',
        icon: Icons.water_drop_rounded,
        color: _blue),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withOpacity(0.07),
              Colors.white.withOpacity(0.02),
            ]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _orange.withOpacity(0.18), width: 0.8),
          ),
          child: Column(
            children: _goals.asMap().entries.map((e) {
              final i    = e.key;
              final goal = e.value;
              final last = i == _goals.length - 1;
              return Column(children: [
                _GoalTile(
                  goal: goal,
                  onToggle: () => setState(
                      () => _goals[i].completed =
                          !_goals[i].completed),
                ),
                if (!last)
                  Divider(
                    height: 0, thickness: 0.6,
                    indent: 20, endIndent: 20,
                    color: Colors.white.withOpacity(0.05),
                  ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _Goal {
  final String label;
  final IconData icon;
  final Color color;
  bool completed;

  _Goal({
    required this.label,
    required this.icon,
    required this.color,
    this.completed = false,
  });
}

class _GoalTile extends StatelessWidget {
  final _Goal goal;
  final VoidCallback onToggle;
  const _GoalTile({required this.goal, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      child: Row(children: [
        // Icon
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: goal.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(goal.icon, size: 17, color: goal.color),
        ),
        const SizedBox(width: 12),
        // Label
        Expanded(
          child: Text(
            goal.label,
            style: TextStyle(
              color: goal.completed
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: goal.completed
                  ? TextDecoration.lineThrough
                  : null,
              decorationColor:
                  Colors.white.withOpacity(0.3),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Checkbox neon personalizzata
        GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: goal.completed
                  ? goal.color
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: goal.completed
                    ? goal.color
                    : Colors.white.withOpacity(0.22),
                width: 1.5,
              ),
              boxShadow: goal.completed
                  ? [BoxShadow(
                      color: goal.color.withOpacity(0.45),
                      blurRadius: 8)]
                  : null,
            ),
            child: goal.completed
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 14)
                : null,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Micro helpers
// ─────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _MiniStat(
      {required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: color.withOpacity(0.8)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    ],
  );
}

class _TinyPill extends StatelessWidget {
  final String label;
  const _TinyPill({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(
          color: Colors.white.withOpacity(0.12), width: 0.7),
    ),
    child: Text(label,
        style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600)),
  );
}