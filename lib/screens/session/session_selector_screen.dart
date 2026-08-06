import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';
import '../../core/theme/markfit_colors.dart';
import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../providers/session_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';
import '../../widgets/workout_icon.dart';
import '../session/active_session_screen.dart';

const _teal   = MarkFitColors.teal;
const _tealDk = MarkFitColors.tealDk;
const _cyan   = MarkFitColors.cyan;
const _indigo = MarkFitColors.indigo;   // ← AGGIUNTO
const _orange = MarkFitColors.orange;
const _green  = MarkFitColors.green;
const _red    = MarkFitColors.red;
const _blue   = MarkFitColors.blue;

// ─── SessionSelectorScreen ────────────────────────────────────

class SessionSelectorScreen extends StatefulWidget {
  const SessionSelectorScreen({super.key});
  @override
  State<SessionSelectorScreen> createState() => _SessionSelectorScreenState();
}

class _SessionSelectorScreenState extends State<SessionSelectorScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<WorkoutProvider>().loadWorkouts());
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<HiveWorkout> _filtered(List<HiveWorkout> workouts) {
    if (_search.isEmpty) return workouts;
    return workouts.where((w) =>
        w.name.toLowerCase().contains(_search.toLowerCase())).toList();
  }

  Future<void> _startSession(HiveWorkout workout) async {
    final wp = context.read<WorkoutProvider>();
    final sp = context.read<SessionProvider>();
    wp.loadWorkoutExercises(workout.key);

    if (sp.hasActiveSession && sp.currentWorkout?.key == workout.key) {
      final result = await showGlassDialog<String>(
        context:     context,
        accentColor: _blue,
        icon: Container(width: 44, height: 44,
          decoration: BoxDecoration(
            color:  _blue.withOpacity(0.12),
            shape:  BoxShape.circle,
            border: Border.all(color: _blue.withOpacity(0.4))),
          child: const Icon(Icons.sports_gymnastics_rounded,
              color: Color(0xFF60A5FA), size: 22)),
        title:       'Sessione in corso',
        message:     'Hai già una sessione attiva per "${workout.name}".',
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
    } else if (sp.hasPausedSessionForWorkout(workout.key)) {
      final paused = sp.getMostRecentPausedForWorkout(workout.key);
      final result = await showGlassDialog<String>(
        context:     context,
        accentColor: _orange,
        icon: Container(width: 44, height: 44,
          decoration: BoxDecoration(
            color:  _orange.withOpacity(0.12),
            shape:  BoxShape.circle,
            border: Border.all(color: _orange.withOpacity(0.4))),
          child: const Icon(Icons.pause_circle_outline_rounded,
              color: _orange, size: 22)),
        title:       'Sessione in pausa',
        message:     'Hai una sessione in pausa per "${workout.name}".',
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
    }

    if (!mounted) return;
    pushPage(context, ActiveSessionScreen(workout: workout));
  }

  @override
  Widget build(BuildContext context) {
    final c         = context.mfc;
    final isDark    = context.isDarkMode;
    final sysBottom = MediaQuery.of(context).viewPadding.bottom;
    final sp        = context.watch<SessionProvider>();
    final workouts  = context.watch<WorkoutProvider>().workouts;
    final filtered  = _filtered(workouts);

    return Scaffold(
      backgroundColor:          Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: CosmicBackground(
        child: SafeArea(
          child: Column(children: [
            // AppBar
            _buildAppBar(context, c),
            // Body
            Expanded(
              child: workouts.isEmpty
                  ? _buildEmpty(c, sysBottom)
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          16, 12, 16, 88 + sysBottom),
                      children: [
                        // Active session banner
                        if (sp.hasActiveSession) ...[
                          _ActiveBanner(sp: sp, c: c, onResume: () {
                            final w = sp.currentWorkout;
                            if (w != null) {
                              pushPage(context,
                                  ActiveSessionScreen(workout: w));
                            }
                          }),
                          const SizedBox(height: 12),
                        ],

                        // Search bar
                        _SearchBar(ctrl: _searchCtrl, c: c, isDark: isDark,
                            onChanged: (v) => setState(() => _search = v)),
                        const SizedBox(height: 12),

                        // Header
                        _Header(count: filtered.length, c: c),
                        const SizedBox(height: 8),

                        // Workout tiles
                        if (filtered.isEmpty)
                          Center(child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text('Nessuna scheda trovata',
                                style: TextStyle(color: c.textTertiary))))
                        else
                          ...filtered.map((w) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _WorkoutTile(
                              workout: w, sp: sp, c: c,
                              onTap: () => _startSession(w)))),
                      ])),
          ]),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, MarkFitColors c) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: c.glassBlurStrong, sigmaY: c.glassBlurStrong),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            border: Border(bottom: BorderSide(
                color: _teal.withOpacity(0.15), width: 0.6)),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 6,
                    offset: const Offset(0, 2))]
                : null),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.glassCardInset,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: c.glassBorder, width: 0.8)),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15, color: c.iconPrimary))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('Avvia sessione', style: TextStyle(
                  color: c.textPrimary, fontSize: 17,
                  fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              Text('Seleziona una scheda', style: TextStyle(
                  color: c.textTertiary, fontSize: 11)),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmpty(MarkFitColors c, double sysBottom) {
    return Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, sysBottom),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 64, height: 64,
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.fitness_center_rounded,
              color: _teal, size: 28)),
        const SizedBox(height: 16),
        Text('Nessuna scheda', style: TextStyle(
            color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Crea una scheda dalla sezione Allenamenti',
            style: TextStyle(color: c.textTertiary, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _teal.withOpacity(0.3))),
            child: const Text('Torna indietro', style: TextStyle(
                color: _teal, fontSize: 13, fontWeight: FontWeight.w600)))),
      ]));
  }
}

// ─── _ActiveBanner ────────────────────────────────────────────

class _ActiveBanner extends StatelessWidget {
  final SessionProvider sp;
  final MarkFitColors   c;
  final VoidCallback    onResume;
  const _ActiveBanner({required this.sp, required this.c,
      required this.onResume});

  @override
  Widget build(BuildContext context) {
    final name = sp.currentWorkout?.name ?? 'Sessione attiva';
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _blue.withOpacity(0.2), _blue.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _blue.withOpacity(0.4), width: 1)),
          child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                  color: _blue.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.sports_gymnastics_rounded,
                  color: Color(0xFF60A5FA), size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SESSIONE ATTIVA', style: TextStyle(
                  color: Color(0xFF60A5FA), fontSize: 9,
                  fontWeight: FontWeight.w800, letterSpacing: 1.1)),
              const SizedBox(height: 2),
              Text(name, style: TextStyle(
                  color: c.textPrimary, fontSize: 13,
                  fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            GestureDetector(
              onTap: onResume,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color:            _blue,
                  borderRadius:     BorderRadius.circular(10),
                  boxShadow: [BoxShadow(
                      color: _blue.withOpacity(0.4), blurRadius: 8,
                      offset: const Offset(0, 2))]),
                child: const Text('Riprendi', style: TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w700)))),
          ]),
        ),
      ),
    );
  }
}
// ─── _SearchBar ───────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  final TextEditingController ctrl;
  final MarkFitColors         c;
  final bool                  isDark;
  final ValueChanged<String>  onChanged;
  const _SearchBar({required this.ctrl, required this.c,
      required this.isDark, required this.onChanged});
  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(13),
    child: BackdropFilter(
      filter: ImageFilter.blur(
          sigmaX: widget.c.glassBlur, sigmaY: widget.c.glassBlur),
      child: Container(
        decoration: BoxDecoration(
          color: widget.c.inputBg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: widget.c.inputBorder,
              width: widget.isDark ? 0.8 : 1.1)),
        child: TextField(
          controller:         widget.ctrl,
          style:              TextStyle(color: widget.c.inputText, fontSize: 14),
          keyboardAppearance: widget.isDark ? Brightness.dark : Brightness.light,
          cursorColor:        _teal,
          decoration: InputDecoration(
            hintText:  'Cerca scheda...',
            hintStyle: TextStyle(color: widget.c.inputHint, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded,
                color: widget.c.iconSecondary, size: 18),
            suffixIcon: widget.ctrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      widget.ctrl.clear();
                      widget.onChanged('');
                      setState(() {});
                    },
                    child: Icon(Icons.close_rounded,
                        color: widget.c.iconSecondary, size: 16))
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13)),
          onChanged: (v) { widget.onChanged(v); setState(() {}); }))));
}

// ─── _Header ─────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int count; final MarkFitColors c;
  const _Header({required this.count, required this.c});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 26, height: 26,
      decoration: BoxDecoration(
          color: _teal.withOpacity(0.12),
          borderRadius: BorderRadius.circular(7)),
      child: const Icon(Icons.bolt_rounded, size: 14, color: _teal)),
    const SizedBox(width: 8),
    Text('$count schede disponibili', style: TextStyle(
        color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
  ]);
}

// ─── _WorkoutTile ─────────────────────────────────────────────

class _WorkoutTile extends StatelessWidget {
  final HiveWorkout    workout;
  final SessionProvider sp;
  final MarkFitColors  c;
  final VoidCallback   onTap;
  const _WorkoutTile({required this.workout, required this.sp,
      required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasPaused = sp.hasPausedSessionForWorkout(workout.key);
    final hasActive = sp.hasActiveSession &&
        sp.currentWorkout?.key == workout.key;
    final indicator = hasPaused ? _orange : hasActive ? _blue : null;

    final exercises = HiveDatabase.instance
        .getWorkoutExercises(workout.key);
    final freeCount = exercises.where((e) => !e.isInCircuit).length;
    final circuits  = HiveDatabase.instance.getCircuits(workout.key);
    final totalSets = exercises.fold<int>(0, (s, e) => s + e.sets);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.glassCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: indicator != null
                    ? indicator.withOpacity(0.45)
                    : c.glassBorder,
                width: indicator != null ? 1.2 : 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 8,
                      offset: const Offset(0, 2))]
                  : null),
            child: Row(children: [
              // Avatar
              WorkoutAvatar(
                iconId:          workout.iconId ?? 'dumbbell',
                iconColorIndex:  workout.iconColorIndex ?? 0,
                customImagePath: workout.customImagePath,
                size: 48, iconSize: 24, borderRadius: 12),
              const SizedBox(width: 12),
              // Info
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(workout.name, style: TextStyle(
                      color:      c.textPrimary,
                      fontSize:   15,
                      fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (indicator != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: indicator.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        hasPaused ? 'In pausa' : 'In corso',
                        style: TextStyle(color: indicator,
                            fontSize: 10, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  if (freeCount > 0)
                    _Chip('$freeCount esercizi', _teal, c),
                  if (circuits.isNotEmpty)
                    _Chip('${circuits.length} circuiti', _indigo, c),
                  _Chip('$totalSets serie', _cyan, c),
                ]),
              ])),
              const SizedBox(width: 10),
              // Play button
              Container(width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasPaused
                      ? [_orange, const Color(0xFFFF6B00)]   // orangeWarm = 0xFFFF6B00
                      : [_green, const Color(0xFF16A34A)]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: (hasPaused ? _orange : _green)
                          .withOpacity(0.4),
                      blurRadius: 10, offset: const Offset(0, 2))]),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 24)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label; final Color color; final MarkFitColors c;
  const _Chip(this.label, this.color, this.c);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withOpacity(0.2), width: 0.7)),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 10, fontWeight: FontWeight.w600)));
}