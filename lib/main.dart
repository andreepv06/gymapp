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
      statusBarColor:          Colors.transparent,
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
              final theme  = Theme.of(context);
              final cs     = theme.colorScheme;
              final isDark = theme.brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor:          Colors.transparent,
                  statusBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                  statusBarBrightness:
                      isDark ? Brightness.dark : Brightness.light,
                ),
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness:
                        isDark ? Brightness.dark : Brightness.light,
                    primaryColor:            cs.primary,
                    // FIX: scaffoldBackgroundColor trasparente →
                    // elimina il blocco bianco durante le transizioni
                    // con CupertinoPageRoute.
                    scaffoldBackgroundColor: Colors.transparent,
                    barBackgroundColor:      cs.surface,
                    textTheme: CupertinoTextThemeData(
                        primaryColor: cs.primary),
                  ),
                  // FIX: ColoredBox sostituisce cs.surface con il
                  // colore esatto del tema, evitando qualunque flash.
                  child: ColoredBox(
                      color: isDark
                          ? const Color(0xFF0A0A0E)
                          : const Color(0xFFF4F6FA),
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
    final cs = ColorScheme.fromSeed(
      seedColor:  const Color(0xFF6750A4),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme:             cs,
      useMaterial3:            true,
      // FIX: scaffoldBackgroundColor trasparente impedisce al
      // Scaffold padre di mostrare il suo sfondo nell'area che
      // si crea tra il body rimpicciolito e la tastiera.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor:             isDark
          ? const Color(0xFF0A0A0E)
          : const Color(0xFFF4F6FA),
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
        elevation:        0,
        color:            cs.surface,
        shape:            RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        surfaceTintColor: cs.surfaceTint,
      ),
      appBarTheme: AppBarTheme(
        elevation:              0,
        scrolledUnderElevation: 1,
        centerTitle:            true,
        backgroundColor:        cs.surface,
        surfaceTintColor:       cs.surfaceTint,
        systemOverlayStyle:     isDark
            ? SystemUiOverlayStyle.light
                .copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark
                .copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: TextStyle(
          color:      cs.onSurface,
          fontSize:   18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:     true,
        fillColor:  cs.surfaceContainerHighest.withOpacity(0.4),
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
        // FIX: trasparente → evita il rettangolo bianco nei sheet
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(24))),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? const Color(0xFF0A0A0E)
        : const Color(0xFFF4F6FA);

    if (!_checked) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.fitness_center,
                size: 48,
                color: const Color(0xFF00D4AA)),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
                color: Color(0xFF00D4AA)),
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
// MainShell
// ─────────────────────────────────────────────────────────────

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final currentIndex =
        context.watch<NavigationNotifier>().currentIndex;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // FIX: trasparente → il CosmicBackground delle schermate
      // figlie si vede anche nella zona sotto la navbar,
      // permettendo al BackdropFilter di sfumare il contenuto reale.
      backgroundColor: Colors.transparent,
      // extendBody: true → il body si estende FISICAMENTE
      // dietro la navbar floating. Senza questo il BackdropFilter
      // non ha nulla da sfocare.
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
// _LiquidGlassNavBar — iOS 26 Liquid Glass Tab View
// ─────────────────────────────────────────────────────────────
//
// Architettura layer (bottom → top):
//  1. Content (body con extendBody:true) — sfumato da BackdropFilter
//  2. BackdropFilter(blur 28) — effetto vetro reale
//  3. Container con glassBg opacity RIDOTTA (≤0.38 dark, ≤0.55 light)
//     → il contenuto sfumato è visibile attraverso il vetro
//  4. Specular highlight (bordo superiore luminoso)
//  5. Tab icons
//
// La riduzione di opacity rispetto alla versione precedente
// (era 0.6/0.72) è il fix principale per "contenuto invisibile".
// ─────────────────────────────────────────────────────────────

class _LiquidGlassNavBar extends StatelessWidget {
  final int  currentIndex;
  final void Function(int) onTap;
  final bool isDark;

  const _LiquidGlassNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
  });

  static const _items = [
    _NavItem(icon: Icons.today_rounded,          label: 'Oggi'),
    _NavItem(icon: Icons.fitness_center_rounded, label: 'Allenamenti'),
    _NavItem(icon: Icons.bar_chart_rounded,      label: 'Storico'),
    _NavItem(icon: Icons.settings_rounded,       label: 'Impostazioni'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    // FIX opacity: ridotta per permettere al contenuto
    // sottostante di essere visibile attraverso il vetro.
    // Dark: 0.38 (era 0.6)   Light: 0.55 (era 0.72)
    final glassBg = isDark
        ? const Color(0xFF111827).withOpacity(0.38)
        : Colors.white.withOpacity(0.55);

    // Bordo speculare (edge highlight)
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.80);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44),
        child: BackdropFilter(
          // Blur aumentato a 32 per effetto vetro più realistico
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Stack(
            children: [
              // ── Corpo vetro ───────────────────────────────
              Container(
                height: 68,
                decoration: BoxDecoration(
                  color:        glassBg,
                  borderRadius: BorderRadius.circular(44),
                  border: Border.all(
                      color: borderColor, width: 0.9),
                  boxShadow: [
                    // Ombra principale morbida
                    BoxShadow(
                      color: Colors.black.withOpacity(
                          isDark ? 0.45 : 0.14),
                      blurRadius:  40,
                      spreadRadius: -6,
                      offset: const Offset(0, 12)),
                    // Glow interno leggero
                    BoxShadow(
                      color: (isDark
                          ? const Color(0xFF00E5FF)
                          : Colors.white).withOpacity(0.04),
                      blurRadius: 0,
                      offset:     const Offset(0, 1)),
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
              // ── Specular highlight — bordo superiore luminoso ─
              // Replica l'effetto iOS 26: una sottile linea bianca
              // in cima alla capsula di vetro simula il riflesso
              // della luce sull'edge del materiale.
              Positioned(
                top: 0, left: 16, right: 16,
                child: Container(
                  height: 0.7,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(
                          isDark ? 0.38 : 0.65),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ],
          ),
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

// ─────────────────────────────────────────────────────────────
// _LiquidNavItem — singolo item con pill animata
// ─────────────────────────────────────────────────────────────

class _LiquidNavItem extends StatefulWidget {
  final _NavItem item;
  final bool     selected, isDark;
  final Color    primaryColor;

  const _LiquidNavItem({
    required this.item,
    required this.selected,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  State<_LiquidNavItem> createState() => _LiquidNavItemState();
}

class _LiquidNavItemState extends State<_LiquidNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  late Animation<double>   _pillWidth;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350));
    _scale     = CurvedAnimation(
        parent: _ctrl, curve: Curves.easeOutBack);
    _pillWidth = CurvedAnimation(
        parent: _ctrl, curve: Curves.easeInOutCubic);
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
          final pillW = 54.0 + 8.0 * _pillWidth.value;
          final iconScale = 0.86 + 0.14 * _scale.value;

          return Center(
            child: widget.selected
                // ── Stato selezionato: pill con glow ──────────
                ? SizedBox(
                    width: pillW, height: 42,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow esterno
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(21),
                            boxShadow: [
                              BoxShadow(
                                color: widget.primaryColor
                                    .withOpacity(0.35),
                                blurRadius:   18,
                                spreadRadius: -2),
                            ],
                          ),
                        ),
                        // Pill
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end:   Alignment.bottomCenter,
                              colors: [
                                widget.primaryColor,
                                Color.lerp(widget.primaryColor,
                                    Colors.black, 0.18) ??
                                    widget.primaryColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(21),
                            boxShadow: [
                              BoxShadow(
                                color: widget.primaryColor
                                    .withOpacity(0.5),
                                blurRadius:  12,
                                offset: const Offset(0, 4)),
                            ],
                          ),
                        ),
                        // Specular highlight sulla pill
                        Positioned(
                          top: 0,
                          child: Container(
                            width:  pillW * 0.5,
                            height: 5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.3),
                                Colors.transparent,
                              ]),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        // Icona
                        Transform.scale(
                          scale: iconScale,
                          child: Icon(widget.item.icon,
                              color: Colors.white, size: 22),
                        ),
                      ],
                    ),
                  )
                // ── Stato deselezionato ────────────────────────
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.item.icon,
                          color: unselectedColor, size: 22),
                      const SizedBox(height: 3),
                      Text(widget.item.label,
                          style: TextStyle(
                              fontSize:   9,
                              fontWeight: FontWeight.w500,
                              color:      unselectedColor)),
                    ],
                  ),
          );
        },
      ),
    );
  }
}