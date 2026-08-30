import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/goal_provider.dart';
import '../dashboard/widgets/goal_card.dart';

class GoalsCalendarScreen extends StatefulWidget {
  const GoalsCalendarScreen({super.key});

  @override
  State<GoalsCalendarScreen> createState() => _GoalsCalendarScreenState();
}

class _GoalsCalendarScreenState extends State<GoalsCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _monthly = false;

  static const _monthNames = [
    '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final goalProvider = context.watch<GoalProvider>();
    final scheduled = goalProvider.goalsForDate(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario obiettivi'),
        actions: [
          IconButton(
            icon: Icon(_monthly ? Icons.view_week : Icons.calendar_view_month),
            onPressed: () => setState(() => _monthly = !_monthly),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() {
                    _focusedMonth = _monthly
                        ? DateTime(_focusedMonth.year, _focusedMonth.month - 1)
                        : _focusedMonth.subtract(const Duration(days: 7));
                  }),
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[_focusedMonth.month]} ${_focusedMonth.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() {
                    _focusedMonth = _monthly
                        ? DateTime(_focusedMonth.year, _focusedMonth.month + 1)
                        : _focusedMonth.add(const Duration(days: 7));
                  }),
                ),
              ],
            ),
          ),
          _monthly ? _buildMonthGrid(context, goalProvider) : _buildWeekRow(context, goalProvider),
          const Divider(height: 1),
          Expanded(
            child: scheduled.isEmpty
                ? Center(
                    child: Text('Nessun obiettivo per questo giorno',
                        style: TextStyle(color: cs.outline)))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: scheduled
                        .map((g) => GoalCard(
                              goal: g,
                              completed: goalProvider.isCompletedOn(g, _selectedDate),
                              onToggle: () =>
                                  goalProvider.toggleCompletion(g, _selectedDate),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekRow(BuildContext context, GoalProvider provider) {
    final cs = Theme.of(context).colorScheme;
    final monday = _focusedMonth.subtract(Duration(days: _focusedMonth.weekday - 1));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: List.generate(7, (i) {
          final day = monday.add(Duration(days: i));
          final isSelected = _sameDay(day, _selectedDate);
          final count = provider.goalsForDate(day).length;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDate = day),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text('${day.day}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? cs.onPrimary : cs.onSurface)),
                    if (count > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? cs.onPrimary : cs.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Vista mensile migliorata ──
  // Sostituisce la grid minimale (solo numero + puntino) con celle
  // più alte che mostrano fino a 2 titoli di obiettivi schedulati,
  // più leggibile e in linea con lo stile glass del resto dell'app.
  Widget _buildMonthGrid(BuildContext context, GoalProvider provider) {
    final cs = Theme.of(context).colorScheme;
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final offset = (firstDay.weekday - 1) % 7;
    const dayLabels = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: dayLabels
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: cs.outline)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.78,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: offset + daysInMonth,
            itemBuilder: (_, i) {
              if (i < offset) return const SizedBox.shrink();
              final day = DateTime(_focusedMonth.year, _focusedMonth.month, i - offset + 1);
              final isSelected = _sameDay(day, _selectedDate);
              final isToday = _sameDay(day, DateTime.now());
              final goalsForDay = provider.goalsForDate(day);

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = day),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary.withOpacity(0.15)
                        : cs.surfaceContainerHighest.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? cs.primary
                          : isToday
                              ? cs.primary.withOpacity(0.4)
                              : cs.outlineVariant.withOpacity(0.3),
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${day.day}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? cs.primary : cs.onSurface)),
                      const SizedBox(height: 2),
                      ...goalsForDay.take(2).map((g) => Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                g.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 8, color: cs.primary),
                              ),
                            ),
                          )),
                      if (goalsForDay.length > 2)
                        Text('+${goalsForDay.length - 2}',
                            style: TextStyle(fontSize: 8, color: cs.outline)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}