import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/sport_models.dart';
import '../../providers/sport_provider.dart';
import '../../widgets/glass_card.dart';

class SportStatsScreen extends StatelessWidget {
  final SportType sport;
  const SportStatsScreen({super.key, required this.sport});

  String _fmtDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }

  static const _monthNames = [
    '', 'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
    'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stats = context.watch<SportProvider>().statsFor(sport);
    final months = stats.sessionsByMonth.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: Text('Statistiche · ${sport.label}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Sessioni',
                  value: '${stats.count}',
                  icon: Icons.event_repeat,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Tempo totale',
                  value: _fmtDuration(stats.totalSeconds),
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Distanza totale',
                  value: '${stats.totalKm.toStringAsFixed(1)} km',
                  icon: Icons.straighten,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Media a sessione',
                  value:
                      _fmtDuration(stats.avgSecondsPerSession.round()),
                  icon: Icons.equalizer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Andamento mensile',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (months.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Nessun dato ancora',
                    style: TextStyle(color: cs.outline)),
              ),
            )
          else
            ...months.reversed.map((monthKey) {
              final parts = monthKey.split('-');
              final monthLabel =
                  '${_monthNames[int.parse(parts[1])]} ${parts[0]}';
              final sessionCount = stats.sessionsByMonth[monthKey] ?? 0;
              final km = stats.kmByMonth[monthKey] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(monthLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Text('$sessionCount sessioni',
                          style: TextStyle(fontSize: 12, color: cs.outline)),
                      if (km > 0) ...[
                        const SizedBox(width: 10),
                        Text('${km.toStringAsFixed(1)} km',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.primary)),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 11, color: cs.outline)),
        ],
      ),
    );
  }
}