import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/markfit_colors.dart';
import 'db/goal_database.dart';
import 'db/hive_database.dart';
import 'db/sport_database.dart';
import 'navigation/navigation_depth_notifier.dart';
import 'providers/auth_provider.dart';
import 'providers/exercise_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/session_provider.dart';
import 'providers/sport_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/workout_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/workouts/allenamenti_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  await HiveDatabase.instance.init();
  await GoalDatabase.instance.init();
  await SportDatabase.instance.init();
  await NotificationService.instance.init();
  runApp(const MyApp());
}

// ─────────────────────────────────────────────────────────────
// NavigationNotifier
// ─────────────────────────────────────────────────────────────

class NavigationNotifier extends ChangeNotifier {
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  void navigateTo(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  void setIndexSilent(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────
// MyApp
// ─────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExerciseProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => NavigationNotifier()),
        ChangeNotifierProvider(create: (_) => NavigationDepthNotifier()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => SportProvider()),
        ChangeNotifierProvider(
            create: (_) => ProfileProvider()..loadProfile()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, tp, __) {
          return MaterialApp(
            title:                  'MarkFit',
            debugShowCheckedModeBanner: false,
            theme:      _buildTheme(Brightness.light),
            darkTheme:  _buildTheme(Brightness.dark),
            themeMode:  tp.themeMode,
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor:          Colors.transparent,
                  statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                  statusBarBrightness:     isDark ? Brightness.dark  : Brightness.light,
                ),
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: isDark ? Brightness.dark : Brightness.light,
                    scaffoldBackgroundColor: Colors.transparent,
                  ),
                  child: ColoredBox(
                    color: isDark
                        ? const Color(0xFF0A0A0E)
                        : const Color(0xFFF0F4FA),
                    child: child!),
                ),
              );
            },
            home: const AppEntry(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final mfc    = isDark ? MarkFitColors.dark : MarkFitColors.light;
    final cs     = ColorScheme.fromSeed(
      seedColor:  MarkFitColors.teal,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme:             cs,
      useMaterial3:            true,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: isDark ? const Color(0xFF0A0A0E) : const Color(0xFFF0F4FA),
      extensions: [mfc],

      textTheme: TextTheme(
        headlineLarge:  TextStyle(
            fontWeight: FontWeight.w700, letterSpacing: -0.5,
            color: mfc.textPrimary),
        headlineMedium: TextStyle(
            fontWeight: FontWeight.w700, letterSpacing: -0.5,
            color: mfc.textPrimary),
        headlineSmall:  TextStyle(
            fontWeight: FontWeight.w600, color: mfc.textPrimary),
        titleLarge:   TextStyle(fontWeight: FontWeight.w600, color: mfc.textPrimary),
        titleMedium:  TextStyle(fontWeight: FontWeight.w600, color: mfc.textPrimary),
        bodyLarge:    TextStyle(color: mfc.textPrimary),
        bodyMedium:   TextStyle(color: mfc.textSecondary),
        bodySmall:    TextStyle(color: mfc.textTertiary),
      ),

      appBarTheme: AppBarTheme(
        elevation:          0,
        backgroundColor:    Colors.transparent,
        surfaceTintColor:   Colors.transparent,
        iconTheme:          IconThemeData(color: mfc.textPrimary),
        titleTextStyle: TextStyle(
          color:      mfc.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w700, letterSpacing: -0.3),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color:     mfc.glassCard,
        shape:     RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent, elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),

      snackBarTheme: SnackBarThemeData(
        behavior:        SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled:     true,
        fillColor:  mfc.inputBg,
        hintStyle:  TextStyle(color: mfc.inputHint),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: mfc.inputBorder, width: 0.8)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: MarkFitColors.teal, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AppEntry
// ─────────────────────────────────────────────────────────────

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});
  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await context.read<AuthProvider>().checkLogin();
    if (context.read<AuthProvider>().isLoggedIn) {
      await context.read<SessionProvider>().tryRestoreSession();
    }
    if (mounted) setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    if (!_checked) {
      return Scaffold(
        backgroundColor: c.scaffoldBg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.fitness_center, size: 48, color: MarkFitColors.teal),
            const SizedBox(height: 16),
            CircularProgressIndicator(color: MarkFitColors.teal),
          ])));
    }
    if (!context.watch<AuthProvider>().isLoggedIn) {
      return LoginScreen(
        onLoginSuccess: () {
          context.read<NavigationDepthNotifier>().reset();
          setState(() {});
        });
    }
    return const MainShell();
  }
}

// ─────────────────────────────────────────────────────────────
// MainShell
// ─────────────────────────────────────────────────────────────

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final idx = context.watch<NavigationNotifier>().currentIndex;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: IndexedStack(
        index: idx,
        children: const [
          HomeScreen(),
          AllenamentiScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _LiquidGlassNavBar(
        currentIndex: idx,
        onTap: (i) => context.read<NavigationNotifier>().navigateTo(i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _LiquidGlassNavBar — iOS 26 Liquid Glass Tab View
// Adattiva: usa MarkFitColors per tutti i token.
// ─────────────────────────────────────────────────────────────

class _LiquidGlassNavBar extends StatelessWidget {
  final int  currentIndex;
  final void Function(int) onTap;
  const _LiquidGlassNavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(icon: Icons.today_rounded,          label: 'Oggi'),
    _NavItem(icon: Icons.fitness_center_rounded, label: 'Allenamenti'),
    _NavItem(icon: Icons.bar_chart_rounded,      label: 'Storico'),
    _NavItem(icon: Icons.settings_rounded,       label: 'Impostazioni'),
  ];

  @override
  Widget build(BuildContext context) {
    final c          = context.mfc;
    final bottomPad  = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Stack(children: [
            // Corpo vetro
            Container(
              height: 68,
              decoration: BoxDecoration(
                color:        c.navBg,
                borderRadius: BorderRadius.circular(44),
                border: Border.all(color: c.navBorder, width: 0.9),
                boxShadow: c.showElevation
                    ? [BoxShadow(
                        color:       c.elevationColor,
                        blurRadius:  28,
                        spreadRadius: -4,
                        offset: const Offset(0, 8))]
                    : [BoxShadow(
                        color:       Colors.black.withOpacity(0.35),
                        blurRadius:  32,
                        spreadRadius: -4,
                        offset: const Offset(0, 10))],
              ),
              child: Row(
                children: List.generate(_items.length, (i) => Expanded(
                  child: GestureDetector(
                    onTap: () { HapticFeedback.selectionClick(); onTap(i); },
                    behavior: HitTestBehavior.opaque,
                    child: _LiquidNavItem(
                      item:         _items[i],
                      selected:     i == currentIndex,
                      c:            c,
                    ),
                  ),
                )),
              ),
            ),
            // Specular highlight superiore
            Positioned(top: 0, left: 16, right: 16,
              child: Container(height: 0.7,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    c.navSpecular,
                    Colors.transparent,
                  ])))),
          ]),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String   label;
  const _NavItem({required this.icon, required this.label});
}

class _LiquidNavItem extends StatefulWidget {
  final _NavItem      item;
  final bool          selected;
  final MarkFitColors c;
  const _LiquidNavItem({required this.item, required this.selected, required this.c});

  @override
  State<_LiquidNavItem> createState() => _LiquidNavItemState();
}

class _LiquidNavItemState extends State<_LiquidNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale, _width;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 350));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _width = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    if (widget.selected) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_LiquidNavItem old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) _ctrl.forward();
    else if (!widget.selected && old.selected) _ctrl.reverse();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return SizedBox(height: 68,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final pillW     = 52.0 + 8.0 * _width.value;
          final iconScale = 0.85 + 0.15 * _scale.value;
          return Center(
            child: widget.selected
                ? SizedBox(width: pillW, height: 40,
                    child: Stack(alignment: Alignment.center, children: [
                      // Glow
                      Container(decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: MarkFitColors.teal.withOpacity(0.38),
                            blurRadius: 16, spreadRadius: -2)])),
                      // Pill
                      Container(decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: c.navPillGradient,
                            begin: Alignment.topCenter,
                            end:   Alignment.bottomCenter),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: MarkFitColors.teal.withOpacity(0.45),
                            blurRadius: 10, offset: const Offset(0, 3))])),
                      // Specular sulla pill
                      Positioned(top: 1,
                        child: Container(width: pillW * 0.45, height: 5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.3),
                              Colors.transparent]),
                            borderRadius: BorderRadius.circular(3)))),
                      // Icon
                      Transform.scale(scale: iconScale,
                        child: Icon(widget.item.icon,
                            color: Colors.white, size: 21)),
                    ]))
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(widget.item.icon, color: c.navUnselected, size: 21),
                    const SizedBox(height: 3),
                    Text(widget.item.label, style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w500,
                        color: c.navUnselected)),
                  ]),
          );
        },
      ));
  }
}