import 'package:flutter/material.dart';

class WeekStrip extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onExpand;

  const WeekStrip({
    super.key,
    required this.selectedDate,
    required this.onSelect,
    required this.onExpand,
  });

  static const _labels = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: today.weekday - 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Questa settimana',
                  style: Theme.of(context).textTheme.labelMedium),
              GestureDetector(
                onTap: onExpand,
                child: Icon(Icons.calendar_month_outlined,
                    size: 18, color: cs.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(7, (i) {
              final day = monday.add(Duration(days: i));
              final isSelected = _sameDay(day, selectedDate);
              final isToday = _sameDay(day, today);
              return GestureDetector(
                onTap: () => onSelect(day),
                child: Container(
                  width: 46,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary
                        : cs.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: isToday && !isSelected
                        ? Border.all(color: cs.primary, width: 1.4)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(_labels[i],
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? cs.onPrimary : cs.outline)),
                      const SizedBox(height: 4),
                      Text('${day.day}',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? cs.onPrimary : cs.onSurface)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}