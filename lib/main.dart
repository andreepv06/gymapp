import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'db/hive_database.dart';
import 'db/goal_database.dart';
import 'db/sport_database.dart';
import 'providers/exercise_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/session_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/sport_provider.dart';
import 'providers/profile_provider.dart';
import 'navigation/navigation_depth_notifier.dart';
import 'screens/home/home_screen.dart';
import 'screens/workouts/allenamenti_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:         Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness:     Brightness.light,
    ),
  );
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
        // Profile image provider — auto-load al boot
        ChangeNotifierProvider(
            create: (_) => ProfileProvider()..loadProfile()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, __) {
          return MaterialApp(
            title: 'MarkFit',
            debugShowCheckedModeBanner: false,
            theme:     _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            themeMode: themeProvider.themeMode,
            builder: (context, child) {
              final theme = Theme.of(context);
              final cs    = theme.colorScheme;
              final isDark = theme.brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                  statusBarBrightness:
                      isDark ? Brightness.dark : Brightness.light,
                ),
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness:
                        isDark ? Brightness.dark : Brightness.light,
                    primaryColor:           cs.primary,
                    scaffoldBackgroundColor: cs.surface,
                    barBackgroundColor:      cs.surface,
                    textTheme: CupertinoTextThemeData(
                      primaryColor: cs.primary),
                  ),
                  child: ColoredBox(color: cs.surface, child: child!),
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
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme:             cs,
      useMaterial3:            true,
      scaffoldBackgroundColor: cs.surface,
      canvasColor:             cs.surface,
      dialogBackgroundColor:   cs.surface,
      textTheme: const TextTheme(
        headlineLarge:  TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineSmall:  TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.3),
        titleLarge:     TextStyle(fontWeight: FontWeight.w600),
        titleMedium:    TextStyle(fontWeight: FontWeight.w600),
        bodyLarge:      TextStyle(letterSpacing: 0.1),
      ),
      cardTheme: CardThemeData(
        elevation: 0, color: cs.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        surfaceTintColor: cs.surfaceTint,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0, scrolledUnderElevation: 1,
        centerTitle: true, backgroundColor: cs.surface,
        surfaceTintColor: cs.surfaceTint,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
                .copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark
                .copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: TextStyle(
          color: cs.onSurface, fontSize: 18,
          fontWeight: FontWeight.w700, letterSpacing: -0.3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outlineVariant, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.error, width: 1)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24))),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
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
    final cs = Theme.of(context).colorScheme;
    if (!_checked) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.fitness_center, size: 48, color: cs.primary),
            const SizedBox(height: 16),
            CircularProgressIndicator(color: cs.primary),
          ]),
        ),
      );
    }
    if (!context.watch<AuthProvider>().isLoggedIn) {
      return LoginScreen(
        onLoginSuccess: () {
          context.read<NavigationDepthNotifier>().reset();
          context.read<AuthProvider>().setLoggedIn(
              context.read<AuthProvider>().userEmail ?? '');
          setState(() {});
        },
      );
    }
    return const MainShell();
  }
}

// ─────────────────────────────────────────────────────────────
// MainShell — extendBody per contenuto sotto la navbar
// ─────────────────────────────────────────────────────────────

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final currentIndex =
        context.watch<NavigationNotifier>().currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // extendBody = true → il contenuto scorre sotto la navbar
      // esattamente come iOS 26 TabView Liquid Glass
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: const [
          HomeScreen(),
          AllenamentiScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _LiquidGlassNavBar(
        currentIndex: currentIndex,
        onTap: (i) =>
            context.read<NavigationNotifier>().navigateTo(i),
        isDark: isDark,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _LiquidGlassNavBar
// Replica iOS 26 Liquid Glass TabView:
// • floating sopra il contenuto (extendBody: true)
// • blur del contenuto sottostante visibile
// • pill animata per tab selezionato
// • animazione morbida tra stati
// • dark / light mode differenziati
// ─────────────────────────────────────────────────────────────

class _LiquidGlassNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final bool isDark;

  const _LiquidGlassNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
  });

  static const _items = [
    _NavItem(icon: Icons.today_rounded,           activeIcon: Icons.today_rounded,          label: 'Oggi'),
    _NavItem(icon: Icons.fitness_center_rounded,  activeIcon: Icons.fitness_center_rounded, label: 'Allenamenti'),
    _NavItem(icon: Icons.bar_chart_rounded,       activeIcon: Icons.bar_chart_rounded,      label: 'Storico'),
    _NavItem(icon: Icons.settings_rounded,        activeIcon: Icons.settings_rounded,       label: 'Impostazioni'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs           = Theme.of(context).colorScheme;
    final bottomPad    = MediaQuery.of(context).padding.bottom;

    // Colori Liquid Glass differenziati per dark/light
    final glassBg = isDark
        ? Colors.grey.shade900.withOpacity(0.6)
        : Colors.white.withOpacity(0.72);
    final glassBorder = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.white.withOpacity(0.85);
    final glowColor = isDark
        ? const Color(0xFF00E5FF).withOpacity(0.08)
        : Colors.black.withOpacity(0.04);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          // Blur forte = contenuto scorre "attraverso" la navbar
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: glassBg,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: glassBorder, width: 1),
              boxShadow: [
                // Ombra principale
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                  blurRadius: 36, spreadRadius: -4,
                  offset: const Offset(0, 10)),
                // Glow superiore (effetto iOS 26)
                BoxShadow(
                  color: glowColor,
                  blurRadius: 0,
                  offset: const Offset(0, 1)),
              ],
            ),
            child: Row(
              children: List.generate(_items.length, (i) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(i);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: _LiquidNavItem(
                      item:         _items[i],
                      selected:     i == currentIndex,
                      isDark:       isDark,
                      primaryColor: cs.primary,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  const _NavItem({
    required this.icon, required this.activeIcon,
    required this.label});
}

// ─────────────────────────────────────────────────────────────
// _LiquidNavItem — singolo item con pill animata
// ─────────────────────────────────────────────────────────────

class _LiquidNavItem extends StatefulWidget {
  final _NavItem item;
  final bool selected, isDark;
  final Color primaryColor;

  const _LiquidNavItem({
    required this.item, required this.selected,
    required this.isDark, required this.primaryColor,
  });

  @override
  State<_LiquidNavItem> createState() => _LiquidNavItemState();
}

class _LiquidNavItemState extends State<_LiquidNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  late Animation<double>   _pillW;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _pillW = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    if (widget.selected) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_LiquidNavItem old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _ctrl.forward();
    } else if (!widget.selected && old.selected) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unselectedColor = widget.isDark
        ? Colors.white.withOpacity(0.42)
        : Colors.grey.shade500;

    return SizedBox(
      height: 68,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final pillWidth = 58.0 + 6 * _pillW.value;
          return Center(
            child: widget.selected
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: pillWidth, height: 42,
                      decoration: BoxDecoration(
                        color: widget.primaryColor,
                        borderRadius: BorderRadius.circular(21),
                        boxShadow: [
                          BoxShadow(
                            color: widget.primaryColor.withOpacity(0.5),
                            blurRadius: 14, offset: const Offset(0, 4)),
                        ],
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Stack(alignment: Alignment.center, children: [
                        // Highlight speculare in cima (effetto iOS 26)
                        Positioned(
                          top: 4,
                          child: Container(
                            width: 28, height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.28),
                              borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.88 + 0.12 * _scale.value,
                          child: Icon(widget.item.activeIcon,
                              color: Colors.white, size: 22)),
                      ]),
                    ),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(widget.item.icon,
                        color: unselectedColor, size: 22),
                    const SizedBox(height: 3),
                    Text(widget.item.label,
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w500,
                            color: unselectedColor)),
                  ]),
          );
        },
      ),
    );
  }
}