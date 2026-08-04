import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';
import '../../core/theme/markfit_colors.dart';
import '../../models/goal_models.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';
import 'new_goal_screen.dart';

// Accent tokens
const _cyan   = MarkFitColors.cyan;
const _teal   = MarkFitColors.teal;
const _tealDk = MarkFitColors.tealDk;
const _indigo = MarkFitColors.indigo;
const _orange = MarkFitColors.orange;
const _red    = MarkFitColors.red;
const _green  = MarkFitColors.green;
const _blue   = MarkFitColors.blue;

const _catColors = <String, Color>{
  'Studio': Color(0xFF6366F1), 'Sport': Color(0xFF00D4AA),
  'Salute': Color(0xFF22C55E), 'Lavoro': Color(0xFF3B82F6),
  'Alimentazione': Color(0xFFFF8C00), 'Benessere': Color(0xFFEC4899),
  'Produttività': Color(0xFF8B5CF6), 'Hobby': Color(0xFFF59E0B),
  'Tempo libero': Color(0xFF06B6D4), 'Finanze': Color(0xFF10B981),
  'Lettura': Color(0xFF6B7280), 'Meditazione': Color(0xFF8A2BE2),
  'Personale': Color(0xFFFF6B6B), 'Altro': Color(0xFF9CA3AF),
};
Color _colorFor(String cat) =>
    _catColors[cat] ?? const Color(0xFF9CA3AF);

String _scheduleLabel(HiveGoal goal) {
  switch (goal.scheduleType) {
    case 'daily':    return 'Ogni giorno';
    case 'weekdays': return 'Feriali';
    case 'weekend':  return 'Weekend';
    case 'specificDays':
      const n = ['','Lun','Mar','Mer','Gio','Ven','Sab','Dom'];
      final days = (goal.scheduleDaysOfWeek ?? [])
          .map((d) => n[d.clamp(1, 7)]).join(', ');
      return days.isEmpty ? 'Giorni specifici' : days;
    case 'dateRange':
      final s = goal.scheduleStartDate ?? '';
      final e = goal.scheduleEndDate   ?? '';
      return 'Dal $s al $e';
    case 'customInterval':
      final n = goal.scheduleCustomInterval ?? 1;
      return 'Ogni $n giorni';
    default: return goal.scheduleType;
  }
}

// ─────────────────────────────────────────────────────────────
// GoalsScreen
// ─────────────────────────────────────────────────────────────

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'Tutti';
  String _search           = '';
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    Future.microtask(() {
      if (!mounted) return;
      context.read<GoalProvider>().loadGoals();
      _fadeCtrl.forward();
    });
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  List<HiveGoal> _filtered(List<HiveGoal> goals) {
    return goals.where((g) {
      final catMatch    = _selectedCategory == 'Tutti' ||
          g.category == _selectedCategory;
      final searchMatch = _search.isEmpty ||
          g.title.toLowerCase().contains(_search.toLowerCase());
      return catMatch && searchMatch;
    }).toList();
  }

  Future<void> _navigateToEdit(HiveGoal goal) async {
    await pushPage(context, NewGoalScreen(editGoal: goal));
    if (mounted) context.read<GoalProvider>().loadGoals();
  }

  Future<void> _navigateToNew() async {
    await pushPage(context, const NewGoalScreen());
    if (mounted) context.read<GoalProvider>().loadGoals();
  }

  Future<void> _confirmDelete(HiveGoal goal) async {
    final ok = await showGlassDialog<bool>(
      context: context, accentColor: _red,
      icon: Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: _red.withOpacity(0.12), shape: BoxShape.circle,
          border: Border.all(color: _red.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: _red.withOpacity(0.2), blurRadius: 12)]),
        child: const Icon(Icons.delete_outline_rounded, color: _red, size: 22)),
      title:   'Eliminare questo obiettivo?',
      message: '"${goal.title}" — L\'operazione è irreversibile.',
      actions: [
        GlassDialogAction(label: 'Annulla',
            onTap: () => Navigator.pop(context, false)),
        GlassDialogAction(label: 'Elimina', isDestructive: true,
            onTap: () => Navigator.pop(context, true)),
      ]);
    if (ok == true && mounted) {
      await context.read<GoalProvider>().deleteGoal(goal.key);
    }
  }

  void _showGoalActions(HiveGoal goal) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      useSafeArea:        true,
      builder: (ctx) => GlassSheetWrapper(
        title:       goal.title,
        subtitle:    goal.category.isNotEmpty ? goal.category : null,
        accentColor: _colorFor(goal.category),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _ContextMenuBtn(
            icon: Icons.edit_outlined, label: 'Modifica', color: _indigo,
            onTap: () { Navigator.pop(ctx); _navigateToEdit(goal); }),
          const SizedBox(height: 8),
          _ContextMenuBtn(
            icon: Icons.delete_outline_rounded, label: 'Elimina', color: _red,
            onTap: () { Navigator.pop(ctx); _confirmDelete(goal); }),
          const SizedBox(height: 4),
        ])));
  }

  void _toggleGoal(HiveGoal goal, DateTime date) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel   = DateTime(date.year, date.month, date.day);
    if (sel.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Non puoi completare obiettivi futuri.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF0D1117),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16), duration: const Duration(seconds: 2)));
      return;
    }
    context.read<GoalProvider>().toggleCompletion(goal, date);
  }

  @override
  Widget build(BuildContext context) {
    final gp    = context.watch<GoalProvider>();
    final goals = gp.goals;
    final today = DateTime.now();
    final catSet = <String>{'Tutti'};
    for (final g in goals) { if (g.category.isNotEmpty) catSet.add(g.category); }
    final cats     = catSet.toList();
    final filtered = _filtered(goals);
    final completedToday = goals.where((g) => gp.isCompletedOn(g, today)).length;
    final totalStreak    = goals.isEmpty ? 0
        : goals.map((g) => g.currentStreak).reduce((a, b) => a + b);
    final bestStreak     = goals.isEmpty ? 0
        : goals.map((g) => g.bestStreak).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor:          Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: CosmicBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(children: [
              _GoalsAppBar(onBack: () => Navigator.pop(context),
                  onAdd: _navigateToNew),
              Expanded(
                child: goals.isEmpty
                    ? Center(child: _EmptyState(
                        hasGoals: false, onAdd: _navigateToNew))
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(20, 10, 20,
                            40 + MediaQuery.of(context).viewInsets.bottom),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          _StatsBar(
                            total:          goals.length,
                            completedToday: completedToday,
                            totalStreak:    totalStreak,
                            bestStreak:     bestStreak),
                          const SizedBox(height: 12),
                          _GlassSearchField(
                              value:     _search,
                              onChanged: (v) => setState(() => _search = v)),
                          const SizedBox(height: 10),
                          if (cats.length > 1) ...[
                            _CategoryChips(
                              categories: cats,
                              selected:   _selectedCategory,
                              onSelect: (c) =>
                                  setState(() => _selectedCategory = c)),
                            const SizedBox(height: 14),
                          ],
                          _SectionHeader(
                            icon:  Icons.track_changes_rounded,
                            title: filtered.isEmpty
                                ? 'Nessun risultato'
                                : '${filtered.length} obiettiv${filtered.length == 1 ? 'o' : 'i'}',
                            color: _orange),
                          const SizedBox(height: 10),
                          if (filtered.isEmpty)
                            _EmptyState(hasGoals: true, onAdd: _navigateToNew)
                          else
                            ...filtered.map((g) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _GoalCard(
                                goal:      g, gp: gp, today: today,
                                onToggle:  () => _toggleGoal(g, today),
                                onActions: () => _showGoalActions(g)))),
                        ]))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ContextMenuBtn — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _ContextMenuBtn extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final VoidCallback onTap;
  const _ContextMenuBtn({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
              boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8)]),
            child: Row(children: [
              Container(width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 14),
              Text(label, style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: color.withOpacity(0.5)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _GoalsAppBar — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _GoalsAppBar extends StatelessWidget {
  final VoidCallback onBack, onAdd;
  const _GoalsAppBar({required this.onBack, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: c.glassBlurStrong, sigmaY: c.glassBlurStrong),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            border: Border(bottom: BorderSide(
                color: _cyan.withOpacity(0.12), width: 0.6)),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 6,
                    offset: const Offset(0, 2))]
                : null),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); onBack(); },
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.glassCardInset,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: c.glassBorder, width: 0.7)),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15, color: c.iconPrimary))),   // was Colors.white
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('I miei obiettivi', style: TextStyle(
                  color: c.textPrimary,   // was Colors.white
                  fontSize: 17, fontWeight: FontWeight.w800,
                  letterSpacing: -0.3)),
              Text('Monitora i tuoi progressi', style: TextStyle(
                  color: c.textTertiary,  // was Colors.white.withOpacity(0.4)
                  fontSize: 11)),
            ])),
            GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); onAdd(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_teal, _tealDk]),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [BoxShadow(color: _teal.withOpacity(0.4),
                      blurRadius: 10, offset: const Offset(0, 3))]),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 5),
                  Text('Nuovo', style: TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w700)),
                ]))),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// ─────────────────────────────────────────────────────────────
// _StatsBar — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int total, completedToday, totalStreak, bestStreak;
  const _StatsBar({required this.total, required this.completedToday,
      required this.totalStreak, required this.bestStreak});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _cyan.withOpacity(0.15), width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 8,
                    offset: const Offset(0, 2))]
                : null),
          child: Row(children: [
            _Stat('$total',          'Totale',  _teal),
            _StatDiv(c: c),
            _Stat('$completedToday', 'Oggi',    _green),
            _StatDiv(c: c),
            _Stat('🔥 $totalStreak', 'Streak',  _orange),
            _StatDiv(c: c),
            _Stat('⭐ $bestStreak',   'Record',  _cyan),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label; final Color color;
  const _Stat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Expanded(child: Column(children: [
      Text(value, style: TextStyle(
          color: color, fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(
          color: c.textTertiary,   // was Colors.white.withOpacity(0.4)
          fontSize: 9, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center),
    ]));
  }
}

class _StatDiv extends StatelessWidget {
  final MarkFitColors c;
  const _StatDiv({required this.c});
  @override
  Widget build(BuildContext context) =>
      Container(width: 0.6, height: 28, color: c.divider);  // was Colors.white.withOpacity(0.08)
}

// ─────────────────────────────────────────────────────────────
// _GlassSearchField — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _GlassSearchField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _GlassSearchField({required this.value, required this.onChanged});
  @override
  State<_GlassSearchField> createState() => _GlassSearchFieldState();
}

class _GlassSearchFieldState extends State<_GlassSearchField> {
  late TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c      = context.mfc;
    final isDark = context.isDarkMode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: c.inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.inputBorder, width: isDark ? 0.8 : 1.0)),
          child: TextField(
            controller:         _ctrl,
            style:              TextStyle(color: c.inputText, fontSize: 14),
            keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
            decoration: InputDecoration(
              hintText:  'Cerca obiettivo...',
              hintStyle: TextStyle(color: c.inputHint, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded,
                  color: c.iconSecondary, size: 18),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        widget.onChanged('');
                        setState(() {});
                      },
                      child: Icon(Icons.close_rounded,
                          color: c.iconSecondary, size: 16))
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13)),
            onChanged: (v) { widget.onChanged(v); setState(() {}); }))));
  }
}

// ─────────────────────────────────────────────────────────────
// _CategoryChips — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String       selected;
  final ValueChanged<String> onSelect;
  const _CategoryChips({required this.categories, required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount:       categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cat   = categories[i];
          final isSel = cat == selected;
          final color = cat == 'Tutti' ? _cyan : _colorFor(cat);
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSel
                    ? color.withOpacity(0.18) : c.glassCardInset,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isSel ? color.withOpacity(0.55) : c.glassBorder,
                  width: isSel ? 1.2 : 0.8),
                boxShadow: isSel && c.showElevation
                    ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 6)]
                    : null),
              child: Text(cat, style: TextStyle(
                  color: isSel ? color : c.textTertiary,
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500))));
        }));
  }
}

// ─────────────────────────────────────────────────────────────
// _SectionHeader — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon; final String title; final Color color;
  const _SectionHeader({required this.icon, required this.title,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Row(children: [
      Container(width: 30, height: 30,
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: color)),
      const SizedBox(width: 9),
      Text(title, style: TextStyle(
          color: c.textPrimary,   // was Colors.white
          fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// _GoalCard — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final HiveGoal     goal;
  final GoalProvider gp;
  final DateTime     today;
  final VoidCallback onToggle, onActions;
  const _GoalCard({required this.goal, required this.gp, required this.today,
      required this.onToggle, required this.onActions});

  @override
  Widget build(BuildContext context) {
    final c         = context.mfc;
    final completed = gp.isCompletedOn(goal, today);
    final catColor  = _colorFor(goal.category);
    final totalDone = gp.completionsForGoal(goal.key)
        .where((c) => c.completed).length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(18),
            border: Border(
              left:   BorderSide(color: catColor.withOpacity(0.65), width: 3),
              top:    BorderSide(color: catColor.withOpacity(0.12), width: 0.8),
              right:  BorderSide(color: catColor.withOpacity(0.12), width: 0.8),
              bottom: BorderSide(color: catColor.withOpacity(0.12), width: 0.8)),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 8,
                    offset: const Offset(0, 2))]
                : null),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
            child: Row(children: [
              // Checkbox
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: completed ? catColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: completed ? catColor : c.glassBorder,
                      width: 1.5),
                    boxShadow: completed
                        ? [BoxShadow(color: catColor.withOpacity(0.5), blurRadius: 8)]
                        : null),
                  child: completed
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14) : null)),
              const SizedBox(width: 12),
              // Info
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(goal.title, style: TextStyle(
                    color: completed ? c.textTertiary : c.textPrimary,
                    fontSize: 14, fontWeight: FontWeight.w700,
                    decoration: completed ? TextDecoration.lineThrough : null,
                    decorationColor: c.textTertiary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _MiniChip(text: goal.category.isNotEmpty
                      ? goal.category : 'Nessuna', color: catColor),
                  _MiniChip(text: _scheduleLabel(goal),
                      color: c.textTertiary),
                  if (totalDone > 0)
                    _MiniChip(text: '✓ $totalDone',
                        color: _green.withOpacity(0.8)),
                ]),
              ])),
              // Streak badge
              if (goal.currentStreak > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: _orange.withOpacity(0.3), width: 0.7)),
                  child: Column(children: [
                    const Text('🔥', style: TextStyle(fontSize: 10)),
                    Text('${goal.currentStreak}', style: const TextStyle(
                        color: _orange, fontSize: 10,
                        fontWeight: FontWeight.w700)),
                  ])),
              ],
              // more_vert
              GestureDetector(
                onTap: onActions,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Icon(Icons.more_vert_rounded,
                      color: c.iconSecondary, size: 20))),  // was Colors.white.withOpacity(0.4)
            ]),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String text; final Color color;
  const _MiniChip({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withOpacity(0.25), width: 0.7)),
    child: Text(text, style: TextStyle(
        color: color.withOpacity(0.9), fontSize: 10,
        fontWeight: FontWeight.w600)));
}

// ─────────────────────────────────────────────────────────────
// _EmptyState — ADATTIVO
// ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasGoals; final VoidCallback onAdd;
  const _EmptyState({required this.hasGoals, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
          child: Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: c.glassCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: _orange.withOpacity(0.18), width: 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 10)]
                  : null),
            child: Column(
              mainAxisSize:      MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Container(width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.1), shape: BoxShape.circle,
                  border: Border.all(
                      color: _orange.withOpacity(0.2), width: 1)),
                child: const Icon(Icons.track_changes_rounded,
                    color: _orange, size: 30)),
              const SizedBox(height: 18),
              Text(hasGoals ? 'Nessun risultato' : 'Nessun obiettivo',
                  style: TextStyle(color: c.textPrimary,
                      fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(hasGoals
                  ? 'Prova a cambiare filtri o ricerca'
                  : 'Inizia aggiungendo il tuo\nprimo obiettivo',
                  style: TextStyle(color: c.textTertiary,
                      fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center),
              if (!hasGoals) ...[
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_teal, _tealDk]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: _teal.withOpacity(0.45),
                          blurRadius: 14, offset: const Offset(0, 4))]),
                    child: const Row(mainAxisSize: MainAxisSize.min,
                      children: [
                      Icon(Icons.add_circle_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Crea obiettivo', style: TextStyle(
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w700)),
                    ]))),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}