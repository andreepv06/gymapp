import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/hive_models.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_bottom_sheet.dart';
import '../../widgets/workout_icon.dart';
import '../../db/hive_database.dart';
import 'workout_detail_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() =>
      _WorkoutsScreenState();
}

class _WorkoutsScreenState
    extends State<WorkoutsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<WorkoutProvider>().loadWorkouts());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Le mie schede'),
      ),
      body: provider.workouts.isEmpty
          ? _EmptyState(
              onAdd: () =>
                  _showAddWorkoutSheet(context))
          : _WorkoutList(
              workouts: provider.workouts,
              onAdd: () =>
                  _showAddWorkoutSheet(context),
            ),
    );
  }

  void _showAddWorkoutSheet(BuildContext context) {
    final controller = TextEditingController();
    String? selectedIconId;
    int selectedColorIndex = 0;
    String? customImageBase64;

    showGlassBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const GlassSheetHandle(),
                const SizedBox(height: 20),
                Text('Nuova scheda',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge),
                const SizedBox(height: 4),
                Text('Dai un nome alla tua scheda',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .outline)),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: false,
                  textCapitalization:
                      TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nome scheda',
                    hintText: 'Es. Push A, Gambe...',
                    prefixIcon:
                        Icon(Icons.edit_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                // Preview avatar
                Row(
                  children: [
                    WorkoutAvatar(
                      iconId: selectedIconId,
                      iconColorIndex:
                          selectedColorIndex,
                      customImagePath: customImageBase64,
                      size: 56,
                      iconSize: 28,
                      borderRadius: 14,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          GlassOutlinedButton(
                            onPressed: () async {
                              final result =
                                  await _showIconPickerSheet(
                                      ctx,
                                      selectedIconId,
                                      selectedColorIndex);
                              if (result != null) {
                                setModalState(() {
                                  selectedIconId =
                                      result['iconId'];
                                  selectedColorIndex =
                                      result['colorIndex'];
                                  customImageBase64 =
                                      null;
                                });
                              }
                            },
                            child: const Text(
                                'Scegli icona'),
                          ),
                          const SizedBox(height: 8),
                          GlassOutlinedButton(
                            onPressed: () async {
                              final img =
                                  await _pickImage();
                              if (img != null) {
                                setModalState(() {
                                  customImageBase64 = img;
                                  selectedIconId = null;
                                });
                              }
                            },
                            child: const Text(
                                'Usa foto'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GlassDialogActions(
                  cancelLabel: 'Annulla',
                  confirmLabel: 'Crea',
                  onCancel: () => Navigator.pop(ctx),
                  onConfirm: () async {
                    Navigator.pop(ctx);
                    if (controller.text
                        .trim()
                        .isNotEmpty) {
                      final id = await context
                          .read<WorkoutProvider>()
                          .addWorkout(
                              controller.text.trim());
                      // Salva icona
                      await HiveDatabase.instance
                          .updateWorkoutIcon(
                        id,
                        iconId: selectedIconId,
                        iconColorIndex:
                            selectedColorIndex,
                        customImagePath:
                            customImageBase64,
                      );
                      if (context.mounted) {
                        context
                            .read<WorkoutProvider>()
                            .loadWorkouts();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                WorkoutDetailScreen(
                              workoutId: id,
                              workoutName:
                                  controller.text
                                      .trim(),
                            ),
                          ),
                        ).then((_) {
                          if (context.mounted) {
                            context
                                .read<WorkoutProvider>()
                                .loadWorkouts();
                          }
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _pickImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _showIconPickerSheet(
      BuildContext ctx,
      String? currentIconId,
      int currentColorIndex) async {
    String? selectedId = currentIconId;
    int selectedColor = currentColorIndex;
    final result =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (bCtx, setInner) =>
            _IconPickerSheet(
          selectedIconId: selectedId,
          selectedColorIndex: selectedColor,
          onChanged: (id, colorIdx) {
            setInner(() {
              selectedId = id;
              selectedColor = colorIdx;
            });
          },
          onConfirm: () {
            Navigator.pop(bCtx,
                {'iconId': selectedId, 'colorIndex': selectedColor});
          },
          onCancel: () => Navigator.pop(bCtx),
        ),
      ),
    );
    return result;
  }
}

class _WorkoutList extends StatelessWidget {
  final List<HiveWorkout> workouts;
  final VoidCallback onAdd;

  const _WorkoutList(
      {required this.workouts, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                16, 16, 16, 12),
            itemCount: workouts.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
            itemBuilder: (_, i) =>
                _WorkoutCard(workout: workouts[i]),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              32, 8, 32, bottomPadding + 100),
          child: GlassButton(
            onTap: onAdd,
            icon: Icons.add_rounded,
            label: 'Nuova scheda',
          ),
        ),
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final HiveWorkout workout;
  const _WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final iconColor =
        WorkoutIcons.getColor(workout.iconColorIndex);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? cs.surface.withOpacity(0.7)
                : cs.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : cs.outlineVariant.withOpacity(0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                    isDark ? 0.2 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
              leading: WorkoutAvatar(
                iconId: workout.iconId,
                iconColorIndex: workout.iconColorIndex,
                customImagePath:
                    workout.customImagePath,
                size: 48,
                iconSize: 24,
                borderRadius: 12,
              ),
              title: Text(workout.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600)),
              subtitle: Text(
                  _formatDate(workout.createdAt),
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.outline)),
              trailing: IconButton(
                icon: Icon(Icons.more_vert,
                    color: cs.outline),
                onPressed: () =>
                    _showOptionsSheet(context),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkoutDetailScreen(
                    workoutId: workout.key,
                    workoutName: workout.name,
                  ),
                ),
              ).then((_) {
                if (context.mounted) {
                  context
                      .read<WorkoutProvider>()
                      .loadWorkouts();
                }
              }),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showOptionsSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showGlassBottomSheet(
      context: context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GlassSheetHandle(),
            const SizedBox(height: 16),
            Row(
              children: [
                WorkoutAvatar(
                  iconId: workout.iconId,
                  iconColorIndex: workout.iconColorIndex,
                  customImagePath:
                      workout.customImagePath,
                  size: 36,
                  iconSize: 18,
                  borderRadius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    workout.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                            fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _OptionTile(
              icon: Icons.edit_outlined,
              label: 'Rinomina scheda',
              color: cs.primary,
              onTap: () {
                Navigator.pop(context);
                _showRenameSheet(context);
              },
            ),
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.image_outlined,
              label: 'Cambia icona / immagine',
              color: cs.tertiary,
              onTap: () {
                Navigator.pop(context);
                _showChangeIconSheet(context);
              },
            ),
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.delete_outline,
              label: 'Elimina scheda',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeIconSheet(BuildContext context) {
    String? selectedIconId = workout.iconId;
    int selectedColorIndex =
        workout.iconColorIndex ?? 0;
    String? customImageBase64 = workout.customImagePath;

    showGlassBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const GlassSheetHandle(),
                const SizedBox(height: 16),
                Text('Cambia icona',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                            fontWeight:
                                FontWeight.w700)),
                const SizedBox(height: 20),
                // Preview
                Center(
                  child: WorkoutAvatar(
                    iconId: selectedIconId,
                    iconColorIndex: selectedColorIndex,
                    customImagePath: customImageBase64,
                    size: 80,
                    iconSize: 40,
                    borderRadius: 20,
                  ),
                ),
                const SizedBox(height: 20),
                // Selezione colore
                Text('Colore',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: WorkoutIcons.colors.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final color = WorkoutIcons.colors[i];
                      final isSelected =
                          selectedColorIndex == i;
                      return GestureDetector(
                        onTap: () => setModal(() =>
                            selectedColorIndex = i),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Colors.white,
                                    width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                        color: color
                                            .withOpacity(
                                                0.5),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white,
                                  size: 18)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Icone predefinite
                Text('Icone predefinite',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium),
                const SizedBox(height: 8),
                ...WorkoutIcons.byCategory.entries
                    .map((entry) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: 6, top: 4),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color:
                                      Theme.of(context)
                                          .colorScheme
                                          .outline,
                                  letterSpacing: 1.0),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: entry.value
                            .map((iconDef) {
                          final isSelected =
                              selectedIconId ==
                                  iconDef.id;
                          final color =
                              WorkoutIcons.getColor(
                                  selectedColorIndex);
                          return GestureDetector(
                            onTap: () => setModal(() {
                              selectedIconId = iconDef.id;
                              customImageBase64 = null;
                            }),
                            child: Tooltip(
                              message: iconDef.label,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color
                                          .withOpacity(0.2)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withOpacity(0.5),
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                  border: isSelected
                                      ? Border.all(
                                          color: color,
                                          width: 2)
                                      : Border.all(
                                          color: Theme.of(
                                                  context)
                                              .colorScheme
                                              .outlineVariant,
                                          width: 1),
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  children: [
                                    Icon(iconDef.icon,
                                        color: isSelected
                                            ? color
                                            : Theme.of(context)
                                                .colorScheme
                                                .outline,
                                        size: 22),
                                    const SizedBox(
                                        height: 2),
                                    Text(
                                      iconDef.label,
                                      style: TextStyle(
                                          fontSize: 7,
                                          color: isSelected
                                              ? color
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .outline),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      textAlign:
                                          TextAlign.center,
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
                const SizedBox(height: 8),
                // Foto personale
                GlassOutlinedButton(
                  onPressed: () async {
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
                        setModal(() {
                          customImageBase64 =
                              base64Encode(bytes);
                          selectedIconId = null;
                        });
                      }
                    } catch (_) {}
                  },
                  child: const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: 18),
                      SizedBox(width: 8),
                      Text('Carica foto dalla galleria'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassDialogActions(
                  cancelLabel: 'Annulla',
                  confirmLabel: 'Salva',
                  onCancel: () => Navigator.pop(ctx),
                  onConfirm: () async {
                    await HiveDatabase.instance
                        .updateWorkoutIcon(
                      workout.key,
                      iconId: selectedIconId,
                      iconColorIndex: selectedColorIndex,
                      customImagePath: customImageBase64,
                    );
                    if (ctx.mounted) {
                      context
                          .read<WorkoutProvider>()
                          .loadWorkouts();
                      Navigator.pop(ctx);
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRenameSheet(BuildContext context) {
    final controller =
        TextEditingController(text: workout.name);
    showGlassBottomSheet(
      context: context,
      child: Padding(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GlassSheetHandle(),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Rinomina scheda',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: false,
              textCapitalization:
                  TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Nome scheda'),
            ),
            const SizedBox(height: 16),
            GlassDialogActions(
              cancelLabel: 'Annulla',
              confirmLabel: 'Salva',
              onCancel: () => Navigator.pop(context),
              onConfirm: () {
                if (controller.text
                    .trim()
                    .isNotEmpty) {
                  context
                      .read<WorkoutProvider>()
                      .renameWorkout(workout.key,
                          controller.text.trim());
                }
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showGlassDialog(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.delete_outline,
                    color: Colors.red, size: 22),
                SizedBox(width: 10),
                Text('Elimina scheda',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
                'Vuoi eliminare "${workout.name}"? Questa azione è permanente.'),
            const SizedBox(height: 24),
            GlassDialogActions(
              cancelLabel: 'Annulla',
              confirmLabel: 'Elimina',
              confirmColor: Colors.red,
              onCancel: () => Navigator.pop(context),
              onConfirm: () {
                context
                    .read<WorkoutProvider>()
                    .deleteWorkout(workout.key);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: color.withOpacity(0.25), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: color)),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: color.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }
}

class _IconPickerSheet extends StatelessWidget {
  final String? selectedIconId;
  final int selectedColorIndex;
  final void Function(String? id, int colorIdx)
      onChanged;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _IconPickerSheet({
    required this.selectedIconId,
    required this.selectedColorIndex,
    required this.onChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            24, 20, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const GlassSheetHandle(),
              const SizedBox(height: 16),
              Text('Scegli icona',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium),
              const SizedBox(height: 16),
              GlassDialogActions(
                cancelLabel: 'Annulla',
                confirmLabel: 'Conferma',
                onCancel: onCancel,
                onConfirm: onConfirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: cs.primary.withOpacity(0.3),
                    width: 1.5),
              ),
              child: Icon(Icons.list_alt_outlined,
                  size: 40, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text('Nessuna scheda ancora',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                        fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Crea la tua prima scheda\nper iniziare ad allenarti',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 28),
            GlassButton(
              onTap: onAdd,
              icon: Icons.add_rounded,
              label: 'Crea scheda',
              minWidth: 220,
            ),
          ],
        ),
      ),
    );
  }
}