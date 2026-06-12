import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/hive_models.dart';

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

class WorkoutIcons {
  static const List<WorkoutIconDef> all = [
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
        label: 'Upper',
        icon: Icons.person,
        category: 'Split'),
    WorkoutIconDef(
        id: 'lower',
        label: 'Lower',
        icon: Icons.transfer_within_a_station,
        category: 'Split'),
    WorkoutIconDef(
        id: 'full_body',
        label: 'Full Body',
        icon: Icons.accessibility,
        category: 'Split'),
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
        label: 'Defin.',
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
        label: 'Resist.',
        icon: Icons.timer,
        category: 'Obiettivi'),
    WorkoutIconDef(
        id: 'mobility',
        label: 'Mobilità',
        icon: Icons.self_improvement,
        category: 'Recupero'),
    WorkoutIconDef(
        id: 'stretching',
        label: 'Stretch',
        icon: Icons.spa,
        category: 'Recupero'),
    WorkoutIconDef(
        id: 'recovery',
        label: 'Recupero',
        icon: Icons.healing,
        category: 'Recupero'),
    WorkoutIconDef(
        id: 'cycling',
        label: 'Bici',
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

  static const List<Color> colors = [
    Color(0xFF6750A4),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFF44336),
    Color(0xFFFF9800),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFF9C27B0),
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
    if (index == null ||
        index < 0 ||
        index >= colors.length) return colors[0];
    return colors[index];
  }

  static Map<String, List<WorkoutIconDef>>
      get byCategory {
    final map = <String, List<WorkoutIconDef>>{};
    for (final icon in all) {
      map.putIfAbsent(icon.category, () => []).add(icon);
    }
    return map;
  }
}

/// Avatar della scheda — usato in tutta l'app
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

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(borderRadius),
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

/// Selettore icona completo e riutilizzabile
class WorkoutIconSelector extends StatelessWidget {
  final String? selectedIconId;
  final int selectedColorIndex;
  final String? customImageBase64;
  final void Function(
      String? iconId,
      int colorIndex,
      String? imgBase64) onChanged;

  const WorkoutIconSelector({
    super.key,
    required this.selectedIconId,
    required this.selectedColorIndex,
    required this.customImageBase64,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color =
        WorkoutIcons.getColor(selectedColorIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview + pulsante galleria
        Row(
          children: [
            WorkoutAvatar(
              iconId: selectedIconId,
              iconColorIndex: selectedColorIndex,
              customImagePath: customImageBase64,
              size: 64,
              iconSize: 32,
              borderRadius: 16,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text('Icona scheda',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                              fontWeight:
                                  FontWeight.w600)),
                  const SizedBox(height: 6),
                  _GlassOutlinedSmallButton(
                    onTap: () async {
                      try {
                        final picker = ImagePicker();
                        final file =
                            await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 400,
                          maxHeight: 400,
                          imageQuality: 80,
                        );
                        if (file != null) {
                          final bytes =
                              await file.readAsBytes();
                          onChanged(
                              null,
                              selectedColorIndex,
                              base64Encode(bytes));
                        }
                      } catch (_) {}
                    },
                    label: 'Usa foto galleria',
                    icon: Icons.photo_library_outlined,
                    color: cs.primary,
                  ),
                  if (customImageBase64 != null ||
                      selectedIconId != null) ...[
                    const SizedBox(height: 6),
                    _GlassOutlinedSmallButton(
                      onTap: () =>
                          onChanged(null, selectedColorIndex, null),
                      label: 'Rimuovi',
                      icon: Icons.close,
                      color: Colors.red,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Colori
        Text('Colore',
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: WorkoutIcons.colors.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = WorkoutIcons.colors[i];
              final isSelected = selectedColorIndex == i;
              return GestureDetector(
                onTap: () => onChanged(
                    selectedIconId, i, customImageBase64),
                child: AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 150),
                  width: isSelected ? 40 : 34,
                  height: isSelected ? 40 : 34,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Colors.white, width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: c.withOpacity(0.5),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 18)
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Icone per categoria
        ...WorkoutIcons.byCategory.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  entry.key.toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                          color: cs.outline,
                          letterSpacing: 1.0),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entry.value.map((iconDef) {
                  final isSelected =
                      selectedIconId == iconDef.id;
                  return GestureDetector(
                    onTap: () => onChanged(
                        iconDef.id,
                        selectedColorIndex,
                        null),
                    child: Tooltip(
                      message: iconDef.label,
                      child: AnimatedContainer(
                        duration: const Duration(
                            milliseconds: 150),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.2)
                              : cs.surfaceContainerHighest
                                  .withOpacity(0.5),
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : cs.outlineVariant,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(iconDef.icon,
                                color: isSelected
                                    ? color
                                    : cs.outline,
                                size: 22),
                            const SizedBox(height: 2),
                            Text(
                              iconDef.label,
                              style: TextStyle(
                                  fontSize: 7,
                                  color: isSelected
                                      ? color
                                      : cs.outline),
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }
}

class _GlassOutlinedSmallButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final Color color;

  const _GlassOutlinedSmallButton({
    required this.onTap,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: color.withOpacity(0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

/// Label scheda con icona — usata ovunque compare il nome
class WorkoutLabel extends StatelessWidget {
  final HiveWorkout workout;
  final double avatarSize;
  final TextStyle? nameStyle;
  final int maxLines;

  const WorkoutLabel({
    super.key,
    required this.workout,
    this.avatarSize = 32,
    this.nameStyle,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WorkoutAvatar(
          iconId: workout.iconId,
          iconColorIndex: workout.iconColorIndex,
          customImagePath: workout.customImagePath,
          size: avatarSize,
          iconSize: avatarSize * 0.5,
          borderRadius: avatarSize * 0.25,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            workout.name,
            style: nameStyle,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}