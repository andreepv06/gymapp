import 'dart:convert';
import 'package:flutter/material.dart';

/// Definizione di un'icona predefinita per le schede
class WorkoutIconDef {
  final String id;
  final String label;
  final IconData icon;
  final String category;

  const WorkoutIconDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.category,
  });
}

/// Libreria completa di icone fitness
class WorkoutIcons {
  static const List<WorkoutIconDef> all = [
    // Gruppi muscolari specifici
    WorkoutIconDef(
        id: 'chest',
        label: 'Petto',
        icon: Icons.self_improvement,
        category: 'Muscoli'),
    WorkoutIconDef(
        id: 'back',
        label: 'Schiena',
        icon: Icons.accessibility_new,
        category: 'Muscoli'),
    WorkoutIconDef(
        id: 'shoulders',
        label: 'Spalle',
        icon: Icons.sports_gymnastics,
        category: 'Muscoli'),
    WorkoutIconDef(
        id: 'arms',
        label: 'Braccia',
        icon: Icons.fitness_center,
        category: 'Muscoli'),
    WorkoutIconDef(
        id: 'biceps',
        label: 'Bicipiti',
        icon: Icons.sports_handball,
        category: 'Muscoli'),
    WorkoutIconDef(
        id: 'triceps',
        label: 'Tricipiti',
        icon: Icons.sports_volleyball,
        category: 'Muscoli'),
    WorkoutIconDef(
        id: 'legs',
        label: 'Gambe',
        icon: Icons.directions_run,
        category: 'Muscoli'),
    WorkoutIconDef(
        id: 'abs',
        label: 'Addome',
        icon: Icons.grid_on,
        category: 'Muscoli'),
    WorkoutIconDef(
        id: 'glutes',
        label: 'Glutei',
        icon: Icons.airline_seat_recline_extra,
        category: 'Muscoli'),

    // Split
    WorkoutIconDef(
        id: 'push',
        label: 'Push',
        icon: Icons.open_with,
        category: 'Split'),
    WorkoutIconDef(
        id: 'pull',
        label: 'Pull',
        icon: Icons.compress,
        category: 'Split'),
    WorkoutIconDef(
        id: 'push_pull_legs',
        label: 'PPL',
        icon: Icons.loop,
        category: 'Split'),
    WorkoutIconDef(
        id: 'upper',
        label: 'Upper Body',
        icon: Icons.person,
        category: 'Split'),
    WorkoutIconDef(
        id: 'lower',
        label: 'Lower Body',
        icon: Icons.transfer_within_a_station,
        category: 'Split'),
    WorkoutIconDef(
        id: 'full_body',
        label: 'Full Body',
        icon: Icons.accessibility,
        category: 'Split'),

    // Obiettivi
    WorkoutIconDef(
        id: 'strength',
        label: 'Forza',
        icon: Icons.bolt,
        category: 'Obiettivi'),
    WorkoutIconDef(
        id: 'mass',
        label: 'Massa',
        icon: Icons.trending_up,
        category: 'Obiettivi'),
    WorkoutIconDef(
        id: 'definition',
        label: 'Definizione',
        icon: Icons.show_chart,
        category: 'Obiettivi'),
    WorkoutIconDef(
        id: 'cardio',
        label: 'Cardio',
        icon: Icons.favorite,
        category: 'Obiettivi'),
    WorkoutIconDef(
        id: 'hiit',
        label: 'HIIT',
        icon: Icons.local_fire_department,
        category: 'Obiettivi'),
    WorkoutIconDef(
        id: 'endurance',
        label: 'Resistenza',
        icon: Icons.timer,
        category: 'Obiettivi'),

    // Recupero
    WorkoutIconDef(
        id: 'mobility',
        label: 'Mobilità',
        icon: Icons.self_improvement,
        category: 'Recupero'),
    WorkoutIconDef(
        id: 'stretching',
        label: 'Stretching',
        icon: Icons.spa,
        category: 'Recupero'),
    WorkoutIconDef(
        id: 'recovery',
        label: 'Recupero',
        icon: Icons.healing,
        category: 'Recupero'),
    WorkoutIconDef(
        id: 'yoga',
        label: 'Yoga',
        icon: Icons.self_improvement,
        category: 'Recupero'),

    // Sport
    WorkoutIconDef(
        id: 'sport',
        label: 'Sport',
        icon: Icons.sports,
        category: 'Sport'),
    WorkoutIconDef(
        id: 'cycling',
        label: 'Ciclismo',
        icon: Icons.directions_bike,
        category: 'Sport'),
    WorkoutIconDef(
        id: 'running',
        label: 'Corsa',
        icon: Icons.directions_run,
        category: 'Sport'),
    WorkoutIconDef(
        id: 'swimming',
        label: 'Nuoto',
        icon: Icons.pool,
        category: 'Sport'),
    WorkoutIconDef(
        id: 'boxing',
        label: 'Boxe',
        icon: Icons.sports_mma,
        category: 'Sport'),
  ];

  /// Colori disponibili per le icone
  static const List<Color> colors = [
    Color(0xFF6750A4), // Viola (default)
    Color(0xFF2196F3), // Blu
    Color(0xFF4CAF50), // Verde
    Color(0xFFF44336), // Rosso
    Color(0xFFFF9800), // Arancione
    Color(0xFF00BCD4), // Ciano
    Color(0xFFE91E63), // Rosa
    Color(0xFF795548), // Marrone
    Color(0xFF607D8B), // Grigio blu
    Color(0xFF9C27B0), // Viola scuro
  ];

  static WorkoutIconDef? getById(String? id) {
    if (id == null) return null;
    try {
      return all.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  static Color getColor(int? index) {
    if (index == null || index < 0 ||
        index >= colors.length) {
      return colors[0];
    }
    return colors[index];
  }

  static Map<String, List<WorkoutIconDef>>
      get byCategory {
    final map = <String, List<WorkoutIconDef>>{};
    for (final icon in all) {
      map.putIfAbsent(icon.category, () => [])
          .add(icon);
    }
    return map;
  }
}

/// Widget che mostra l'avatar della scheda
class WorkoutAvatar extends StatelessWidget {
  final String? iconId;
  final int? iconColorIndex;
  final String? customImagePath;
  final double size;
  final double iconSize;
  final double borderRadius;

  const WorkoutAvatar({
    super.key,
    this.iconId,
    this.iconColorIndex,
    this.customImagePath,
    this.size = 48,
    this.iconSize = 24,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final color = WorkoutIcons.getColor(iconColorIndex);
    final iconDef = WorkoutIcons.getById(iconId);

    // Immagine custom (base64)
    if (customImagePath != null &&
        customImagePath!.isNotEmpty) {
      try {
        final bytes = base64Decode(customImagePath!);
        return ClipRRect(
          borderRadius:
              BorderRadius.circular(borderRadius),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }

    // Icona predefinita
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius:
            BorderRadius.circular(borderRadius),
        border: Border.all(
            color: color.withOpacity(0.3), width: 1),
      ),
      child: Icon(
        iconDef?.icon ?? Icons.fitness_center,
        color: color,
        size: iconSize,
      ),
    );
  }
}