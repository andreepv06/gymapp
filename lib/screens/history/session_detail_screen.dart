import 'dart:ui';
import 'package:flutter/material.dart';

import '../../db/hive_database.dart';
import '../../models/hive_models.dart';
import '../../widgets/cosmic_background.dart';

// ── Design tokens ─────────────────────────────────────────────
const _cyan   = Color(0xFF00E5FF);
const _teal   = Color(0xFF00D4AA);
const _tealDk = Color(0xFF00A880);
const _red    = Color(0xFFFF3B30);
const _green  = Color(0xFF22C55E);

class SessionDetailScreen extends StatefulWidget {
  final dynamic sessionKey;
  final String  workoutName;
  final String  date;
  const SessionDetailScreen({
    super.key,
    required this.sessionKey,
    required this.workoutName,
    required this.date});

  @override
  State<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState
    extends State<SessionDetailScreen> {
  List<HiveSessionSet> _sets    = [];
  bool                 _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final sets = HiveDatabase.instance
        .getSessionSets(widget.sessionKey);
    setState(() { _sets = sets; _loading = false; });
  }

  String _fmtDate(String iso) {
    final dt = DateTime.parse(iso);
    const m  = ['','Gennaio','Febbraio','Marzo','Aprile','Maggio',
        'Giugno','Luglio','Agosto','Settembre','Ottobre',
        'Novembre','Dicembre'];
    return '${dt.day} ${m[dt.month]} ${dt.year}  '
        '${dt.hour.toString().padLeft(2,'0')}:'
        '${dt.minute.toString().padLeft(2,'0')}';
  }

  String _fmtRest(int s) {
    if (s < 60) return '${s}s';
    final m = s ~/ 60; final sec = s % 60;
    return sec == 0 ? '${m}m' : '${m}m${sec}s';
  }

  Map<String, List<HiveSessionSet>> _grouped() {
    final map = <String, List<HiveSessionSet>>{};
    for (final s in _sets) {
      map.putIfAbsent(s.exerciseName, () => []).add(s);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0E),
        body: Center(child: CircularProgressIndicator(
            color: _teal, strokeWidth: 2)));
    }

    final grouped   = _grouped();
    final sysBottom = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        child: SafeArea(
          bottom: false,
          child: Column(children: [

            // ── Glass AppBar ────────────────────────────────────
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
                              color: Colors.white.withOpacity(0.12), width: 0.7)),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 15, color: Colors.white))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(widget.workoutName, style: const TextStyle(
                          color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.w800, letterSpacing: -0.3),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(_fmtDate(widget.date), style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 11)),
                    ])),
                  ])))),

            // ── Content ─────────────────────────────────────────
            Expanded(
              child: grouped.isEmpty
                  ? Center(child: Text('Nessun dato per questa sessione',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 14)))
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + sysBottom),
                      children: grouped.entries.map((entry) {
                        final exName = entry.key;
                        final sets   = entry.value;
                        final muscle = sets.first.muscleGroup;
                        final done   = sets.where((s) => s.completed).length;
                        final total  = sets.length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ExerciseBlock(
                            exerciseName: exName,
                            muscleGroup:  muscle,
                            sets:         sets,
                            completedCount: done,
                            totalCount:     total,
                            fmtRest:      _fmtRest));
                      }).toList())),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ExerciseBlock
// ─────────────────────────────────────────────────────────────

class _ExerciseBlock extends StatefulWidget {
  final String              exerciseName, muscleGroup;
  final List<HiveSessionSet> sets;
  final int                 completedCount, totalCount;
  final String Function(int) fmtRest;
  const _ExerciseBlock({
    required this.exerciseName, required this.muscleGroup,
    required this.sets, required this.completedCount,
    required this.totalCount,   required this.fmtRest});

  @override
  State<_ExerciseBlock> createState() => _ExerciseBlockState();
}

class _ExerciseBlockState extends State<_ExerciseBlock> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.02)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: _teal.withOpacity(0.18), width: 0.8)),
          child: Column(children: [

            // Header
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                child: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.fitness_center_rounded,
                        color: _teal, size: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(widget.exerciseName, style: const TextStyle(
                        color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Row(children: [
                      Text(widget.muscleGroup, style: TextStyle(
                          fontSize: 11, color: Colors.white.withOpacity(0.4))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.completedCount == widget.totalCount
                              ? _green.withOpacity(0.12)
                              : _cyan.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: widget.completedCount == widget.totalCount
                                ? _green.withOpacity(0.3)
                                : _cyan.withOpacity(0.2), width: 0.7)),
                        child: Text(
                          '${widget.completedCount}/${widget.totalCount} serie',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: widget.completedCount == widget.totalCount
                                ? _green : _cyan))),
                    ]),
                  ])),
                  Icon(_expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withOpacity(0.35), size: 18),
                ]))),

            // Sets table
            if (_expanded) ...[
              Container(height: 0.6,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: Colors.white.withOpacity(0.06)),
              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(children: [
                  const SizedBox(width: 30),
                  Expanded(child: Text('Peso', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                          fontWeight: FontWeight.w600))),
                  Expanded(child: Text('Reps', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                          fontWeight: FontWeight.w600))),
                  Expanded(child: Text('Rec.', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                          fontWeight: FontWeight.w600))),
                  const SizedBox(width: 22),
                ])),
              // Set rows
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(children: widget.sets.map((s) {
                  final done = s.completed;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 7),
                    decoration: BoxDecoration(
                      color: done
                          ? _teal.withOpacity(0.1)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: done
                            ? _teal.withOpacity(0.3)
                            : Colors.white.withOpacity(0.07),
                        width: 0.7)),
                    child: Row(children: [
                      SizedBox(width: 30,
                        child: Text('${s.setNumber}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: done ? _teal
                                    : Colors.white.withOpacity(0.4)))),
                      Expanded(child: Text(
                          s.weight % 1 == 0
                              ? '${s.weight.toInt()} kg'
                              : '${s.weight} kg',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13, fontWeight: FontWeight.w500))),
                      Expanded(child: Text('${s.reps}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13, fontWeight: FontWeight.w500))),
                      Expanded(child: Text(
                          s.restSeconds != null
                              ? widget.fmtRest(s.restSeconds!) : '—',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.4)))),
                      SizedBox(width: 22,
                        child: Icon(
                            done ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: done ? _teal
                                : Colors.white.withOpacity(0.25))),
                    ]));
                }).toList())),
            ],
          ]),
        ),
      ),
    );
  }
}