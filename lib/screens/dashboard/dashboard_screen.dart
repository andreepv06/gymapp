import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/navigation/app_router.dart';
import '../../providers/goal_provider.dart';
import '../../providers/sport_provider.dart';
import '../../models/sport_models.dart';
import '../goals/goals_screen.dart';
import '../calendar/goals_calendar_screen.dart';
import '../session/session_selector_screen.dart';
import '../sports/sport_session_screen.dart';
import 'widgets/week_strip.dart';
import 'widgets/goal_card.dart';
import 'widgets/progress_ring.dart';
import 'widgets/quick_workout_panel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<GoalProvider>().loadGoals();
      context.read<SportProvider>().loadSessions();
    });
  }

  static const _weekdayNames = [
    '', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'
  ];
  static const _monthNames = [
    '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final goalProvider = context.watch<GoalProvider>();
    final scheduled = goalProvider.goalsForDate(_selectedDate);
    final percentage = goalProvider.completionPercentageForDate(_selectedDate);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_weekdayNames[_selectedDate.weekday],
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w800)),
                            Text(
                              '${_selectedDate.day} ${_monthNames[_selectedDate.month]} ${_selectedDate.year}',
                              style: TextStyle(fontSize: 13, color: cs.outline),
                            ),
                          ],
                        ),
                      ),
                      ProgressRing(
                        progress: percentage,
                        color: cs.primary,
                        center: Text('${(percentage * 100).round()}%',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  WeekStrip(
                    selectedDate: _selectedDate,
                    onSelect: (d) => setState(() => _selectedDate = d),
                    onExpand: () => pushPage(context, const GoalsCalendarScreen()),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Obiettivi',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      TextButton(
                        onPressed: () => pushPage(context, const GoalsScreen()),
                        child: const Text('Gestisci'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (scheduled.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('Nessun obiettivo per questo giorno',
                          style: TextStyle(color: cs.outline)),
                    )
                  else
                    ...scheduled.map((g) => GoalCard(
                          goal: g,
                          completed: goalProvider.isCompletedOn(g, _selectedDate),
                          onToggle: () =>
                              goalProvider.toggleCompletion(g, _selectedDate),
                        )),
                  const SizedBox(height: 24),
                  QuickWorkoutPanel(
                    onGym: () => pushPage(context, const SessionSelectorScreen()),
                    onRunning: () => pushPage(
                        context, const SportSessionScreen(sport: SportType.running)),
                    onCycling: () => pushPage(
                        context, const SportSessionScreen(sport: SportType.cycling)),
                    onSwimming: () => pushPage(
                        context, const SportSessionScreen(sport: SportType.swimming)),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}