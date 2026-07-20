import 'dart:ui';
import 'package:flutter/material.dart';

const kTeal = Color(0xFF00D4AA);
const kCyan = Color(0xFF00E5FF);
const kRed  = Color(0xFFFF3B30);

const kMuscleGroups = [
  'Petto', 'Schiena', 'Spalle', 'Bicipiti',
  'Tricipiti', 'Gambe', 'Addominali', 'Glutei', 'Polpacci',
];

// ─────────────────────────────────────────────────────────────
// showKeyboardSafeSheet
// ─────────────────────────────────────────────────────────────

Future<T?> showKeyboardSafeSheet<T>(
    BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => GestureDetector(
      onTap: () => FocusScope.of(ctx).unfocus(),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: child,
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// showGlassDialog
//
// [actionsAxis] — Axis.horizontal (default, bottoni in riga)
//              — Axis.vertical   (bottoni in colonna, consigliato
//                                 quando le azioni sono ≥ 3 o i
//                                 label sono lunghi)
// ─────────────────────────────────────────────────────────────

Future<T?> showGlassDialog<T>({
  required BuildContext context,
  Widget? icon,
  required String title,
  required String message,
  required List<GlassDialogAction> actions,
  Color accentColor = kCyan,
  Axis actionsAxis = Axis.horizontal,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.65),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1117), Color(0xFF060B14)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: accentColor.withOpacity(0.25), width: 1),
              boxShadow: [
                BoxShadow(
                    color: accentColor.withOpacity(0.06),
                    blurRadius: 28,
                    spreadRadius: 4),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[icon, const SizedBox(height: 16)],
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2)),
                const SizedBox(height: 10),
                Text(message,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        height: 1.5)),
                const SizedBox(height: 24),
                Container(
                  height: 0.7,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      accentColor.withOpacity(0.25),
                      Colors.transparent,
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                // Azioni — orizzontali o verticali
                if (actionsAxis == Axis.horizontal)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions.map((a) => Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: _GlassDialogBtn(action: a),
                    )).toList(),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: actions.map((a) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _GlassDialogBtn(action: a, fullWidth: true),
                    )).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// GlassDialogAction
// ─────────────────────────────────────────────────────────────

class GlassDialogAction {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isDestructive;
  final bool isDefault;

  const GlassDialogAction({
    required this.label,
    required this.onTap,
    this.color,
    this.isDestructive = false,
    this.isDefault = false,
  });

  Color get resolvedColor {
    if (color != null) return color!;
    if (isDestructive) return kRed;
    if (isDefault) return kTeal;
    return Colors.white;
  }
}

class _GlassDialogBtn extends StatelessWidget {
  final GlassDialogAction action;
  final bool fullWidth;

  const _GlassDialogBtn({
    required this.action,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = action.resolvedColor;
    final isNeutral = !action.isDestructive &&
        !action.isDefault &&
        action.color == null;
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isNeutral
              ? Colors.white.withOpacity(0.07)
              : c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isNeutral
                ? Colors.white.withOpacity(0.15)
                : c.withOpacity(0.4),
            width: 1,
          ),
          boxShadow: !isNeutral
              ? [BoxShadow(color: c.withOpacity(0.15), blurRadius: 8)]
              : null,
        ),
        child: Text(
          action.label,
          textAlign: fullWidth ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: isNeutral ? Colors.white.withOpacity(0.7) : c,
            fontSize: 14,
            fontWeight: (action.isDefault || action.isDestructive)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GlassSheetWrapper
// ─────────────────────────────────────────────────────────────

class GlassSheetWrapper extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Color accentColor;
  final Widget? leadingIcon;

  const GlassSheetWrapper({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.accentColor = kTeal,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF060B14), Color(0xFF03040A)],
        ),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
            color: accentColor.withOpacity(0.3), width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  accentColor.withOpacity(0.3),
                  accentColor.withOpacity(0.6),
                  accentColor.withOpacity(0.3),
                ]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  leadingIcon!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: TextStyle(
                                color: accentColor.withOpacity(0.7),
                                fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GlassTextField
// ─────────────────────────────────────────────────────────────

class GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final String? labelText;
  final bool autofocus;
  final void Function(String)? onChanged;
  final int maxLines;

  const GlassTextField({
    super.key,
    this.controller,
    required this.hintText,
    this.labelText,
    this.autofocus = false,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: kCyan.withOpacity(0.2), width: 0.8),
          ),
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            maxLines: maxLines,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hintText,
              labelText: labelText,
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 14),
              labelStyle:
                  TextStyle(color: Colors.white.withOpacity(0.5)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
            ),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GlassPrimaryButton
// ─────────────────────────────────────────────────────────────

class GlassPrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const GlassPrimaryButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(colors: [
                  color,
                  Color.lerp(color, Colors.black, 0.2) ?? color,
                ])
              : LinearGradient(colors: [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.03),
                ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? color.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: enabled
                ? Colors.white
                : Colors.white.withOpacity(0.3),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ExerciseFormSheet — unificato creazione + modifica
// ─────────────────────────────────────────────────────────────

class ExerciseFormSheet extends StatefulWidget {
  final String? initialName;
  final String? initialMuscleGroup;
  final String? initialNotes;
  final Set<String> existingNames;
  final void Function(String name, String muscleGroup, String notes)
      onConfirm;

  const ExerciseFormSheet({
    super.key,
    this.initialName,
    this.initialMuscleGroup,
    this.initialNotes,
    required this.existingNames,
    required this.onConfirm,
  });

  bool get isEditing => initialName != null;

  @override
  State<ExerciseFormSheet> createState() => _ExerciseFormSheetState();
}

class _ExerciseFormSheetState extends State<ExerciseFormSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _notesCtrl;
  late String _selectedMuscle;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _notesCtrl =
        TextEditingController(text: widget.initialNotes ?? '');
    _selectedMuscle =
        widget.initialMuscleGroup ?? kMuscleGroups.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Il nome è obbligatorio');
      return;
    }
    if (widget.existingNames.contains(name.toLowerCase())) {
      setState(() => _nameError = 'Esercizio già esistente');
      return;
    }
    setState(() => _nameError = null);
    widget.onConfirm(name, _selectedMuscle, _notesCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm =
        _nameCtrl.text.trim().isNotEmpty && _nameError == null;

    return GlassSheetWrapper(
      title:
          widget.isEditing ? 'Modifica esercizio' : 'Nuovo esercizio',
      subtitle: widget.isEditing ? widget.initialName : null,
      accentColor: kTeal,
      leadingIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kTeal.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.fitness_center_rounded,
            color: kTeal, size: 20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTextField(
            controller: _nameCtrl,
            hintText: 'Es. Panca piana, Squat...',
            labelText: 'Nome esercizio',
            onChanged: (v) {
              setState(() {
                _nameError = widget.existingNames
                        .contains(v.trim().toLowerCase())
                    ? 'Esercizio già esistente'
                    : null;
              });
            },
          ),
          if (_nameError != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_nameError!,
                  style: TextStyle(
                      color: kRed.withOpacity(0.85), fontSize: 11)),
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Gruppo muscolare',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kMuscleGroups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final g = kMuscleGroups[i];
                final sel = _selectedMuscle == g;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMuscle = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? kTeal.withOpacity(0.2)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: sel
                            ? kTeal.withOpacity(0.6)
                            : Colors.white.withOpacity(0.1),
                        width: sel ? 1.2 : 0.8,
                      ),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                  color: kTeal.withOpacity(0.15),
                                  blurRadius: 8)
                            ]
                          : null,
                    ),
                    child: Text(g,
                        style: TextStyle(
                            color: sel
                                ? kTeal
                                : Colors.white.withOpacity(0.55),
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          GlassTextField(
            controller: _notesCtrl,
            hintText: 'Es. Grip neutro, 3 secondi in discesa...',
            labelText: 'Note (opzionale)',
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          GlassPrimaryButton(
            label: widget.isEditing
                ? 'Salva modifiche'
                : 'Aggiungi esercizio',
            color: kTeal,
            onTap: canConfirm ? _submit : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WorkoutCreateSheet — unificato creazione scheda
// ─────────────────────────────────────────────────────────────

class WorkoutCreateSheet extends StatefulWidget {
  final void Function(String name) onConfirm;
  const WorkoutCreateSheet({super.key, required this.onConfirm});

  @override
  State<WorkoutCreateSheet> createState() =>
      _WorkoutCreateSheetState();
}

class _WorkoutCreateSheetState extends State<WorkoutCreateSheet> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasName = _nameCtrl.text.trim().isNotEmpty;

    return GlassSheetWrapper(
      title: 'Nuova scheda',
      accentColor: kTeal,
      leadingIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kTeal.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.add_rounded, color: kTeal, size: 20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTextField(
            controller: _nameCtrl,
            hintText: 'Es. Push Day, Full Body...',
            labelText: 'Nome scheda',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          GlassPrimaryButton(
            label: 'Crea scheda',
            color: kTeal,
            onTap: hasName
                ? () => widget.onConfirm(_nameCtrl.text.trim())
                : null,
          ),
        ],
      ),
    );
  }
}