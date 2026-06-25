import 'package:flutter/material.dart';
import '../../../widgets/glass_card.dart';

class QuickWorkoutPanel extends StatelessWidget {
  final VoidCallback onGym;
  final VoidCallback onRunning;
  final VoidCallback onCycling;
  final VoidCallback onSwimming;

  const QuickWorkoutPanel({
    super.key,
    required this.onGym,
    required this.onRunning,
    required this.onCycling,
    required this.onSwimming,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Avvia rapido',
              style: Theme.of(context).textTheme.labelMedium),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _QuickTile(
                    icon: Icons.fitness_center,
                    label: 'Palestra',
                    color: Colors.deepPurple,
                    onTap: onGym)),
            const SizedBox(width: 8),
            Expanded(
                child: _QuickTile(
                    icon: Icons.directions_run,
                    label: 'Running',
                    color: Colors.orange,
                    onTap: onRunning)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _QuickTile(
                    icon: Icons.directions_bike,
                    label: 'Ciclismo',
                    color: Colors.green,
                    onTap: onCycling)),
            const SizedBox(width: 8),
            Expanded(
                child: _QuickTile(
                    icon: Icons.pool,
                    label: 'Nuoto',
                    color: Colors.blue,
                    onTap: onSwimming)),
          ],
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      tintColor: color.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }
}