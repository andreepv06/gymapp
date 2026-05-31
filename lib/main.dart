import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'db/hive_database.dart';
import 'providers/exercise_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/session_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';

import 'screens/home/home_screen.dart';
import 'screens/workouts/workouts_screen.dart';
import 'screens/session/session_selector_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/auth/login_screen.dart';

import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  await HiveDatabase.instance.init();
  await NotificationService.instance.init();
  runApp(const MyApp());
}

class NavigationNotifier extends ChangeNotifier {
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  void navigateTo(int index) {
    _currentIndex = index;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExerciseProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => NavigationNotifier()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) {
          return MaterialApp(
            title: 'MarkFit',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            themeMode: themeProvider.themeMode,
            // FIX striscia bianca: colore di sfondo durante le transizioni
            builder: (context, child) {
              final cs = Theme.of(context).colorScheme;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness:
                      Theme.of(context).brightness == Brightness.dark
                          ? Brightness.light
                          : Brightness.dark,
                  statusBarBrightness: Theme.of(context).brightness,
                ),
                child: Container(
                  color: cs.surface,
                  child: child!,
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
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      // FIX flash bianco: tutti i colori di sfondo coerenti
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      dialogBackgroundColor: colorScheme.surface,
      textTheme: const TextTheme(
        headlineLarge:
            TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium:
            TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineSmall:
            TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.3),
        titleLarge: TextStyle(fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(letterSpacing: 0.1),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
                .copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark
                .copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            colorScheme.surfaceContainerHighest.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
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

// ── AppEntry ──
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
    setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_checked) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center, size: 48, color: cs.primary),
              const SizedBox(height: 16),
              CircularProgressIndicator(color: cs.primary),
            ],
          ),
        ),
      );
    }

    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;

    if (!isLoggedIn) {
      return LoginScreen(
        onLoginSuccess: () {
          context.read<AuthProvider>().setLoggedIn(
              context.read<AuthProvider>().userEmail ?? '');
          setState(() {});
        },
      );
    }

    return const MainShell();
  }
}

// ── MainShell ──
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    context.read<NavigationNotifier>().navigateTo(index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex =
        context.watch<NavigationNotifier>().currentIndex;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    // FIX striscia bianca: aggiorna system overlay ad ogni rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDark ? Brightness.dark : Brightness.light,
      ));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients &&
          _pageController.page?.round() != currentIndex) {
        _pageController.animateToPage(
          currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    return Scaffold(
      backgroundColor: cs.surface,
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        // FIX: disabilita swipe orizzontale nel PageView — lo swipe
        // back iOS/Android viene gestito dal Navigator (CupertinoPageRoute
        // o swipe sul bordo), non dal PageView. Lasciare physics scrollabili
        // sul PageView causa conflitti con il back gesture.
        onPageChanged: (index) {
          context.read<NavigationNotifier>().navigateTo(index);
        },
        children: const [
          HomeScreen(),
          WorkoutsScreen(),
          SessionSelectorScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _LiquidGlassNavBar(
        currentIndex: currentIndex,
        onTap: _onNavTap,
        isDark: isDark,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LIQUID GLASS NAVBAR
// ─────────────────────────────────────────────

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
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.list_alt_rounded, label: 'Schede'),
    _NavItem(
        icon: Icons.play_circle_fill_rounded, label: 'Sessione'),
    _NavItem(icon: Icons.bar_chart_rounded, label: 'Storico'),
    _NavItem(
        icon: Icons.settings_rounded, label: 'Impostazioni'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final glassBg = isDark
        ? Colors.grey.shade900.withOpacity(0.55)
        : Colors.white.withOpacity(0.6);
    final glassBorder = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.7);

    return Padding(
      padding:
          EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: glassBg,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: glassBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(isDark ? 0.35 : 0.1),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white
                      .withOpacity(isDark ? 0.04 : 0.6),
                  blurRadius: 0,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: List.generate(_items.length, (i) {
                final selected = i == currentIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: _LiquidNavItem(
                      item: _items[i],
                      selected: selected,
                      isDark: isDark,
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
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _LiquidNavItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool isDark;
  final Color primaryColor;

  const _LiquidNavItem({
    required this.item,
    required this.selected,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final unselected = isDark
        ? Colors.white.withOpacity(0.45)
        : Colors.grey.shade600;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: selected
          ? _SelectedItem(
              key: ValueKey('sel_${item.label}'),
              item: item,
              primaryColor: primaryColor,
            )
          : _UnselectedItem(
              key: ValueKey('unsel_${item.label}'),
              item: item,
              color: unselected,
            ),
    );
  }
}

class _SelectedItem extends StatelessWidget {
  final _NavItem item;
  final Color primaryColor;

  const _SelectedItem({
    super.key,
    required this.item,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: Center(
        child: Container(
          width: 56,
          height: 40,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.transparent,
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 3,
                child: Container(
                  width: 28,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Icon(item.icon, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnselectedItem extends StatelessWidget {
  final _NavItem item;
  final Color color;

  const _UnselectedItem({
    super.key,
    required this.item,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}