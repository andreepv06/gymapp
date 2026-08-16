import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/markfit_colors.dart';
import 'db/goal_database.dart';
import 'db/hive_database.dart';
import 'db/sport_database.dart';
import 'db/training_mode_database.dart';
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
  SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  await HiveDatabase.instance.init();
  await GoalDatabase.instance.init();
  await SportDatabase.instance.init();
  // FASE 1 — Sistema Modalità di Allenamento: registra gli adapter
  // Hive dedicati (TrainingMode/TrainingModeSet). Il box per-utente
  // viene aperto/seminato in AuthProvider.checkLogin/_loginInternal,
  // stesso pattern di GoalDatabase/SportDatabase.
  await TrainingModeDatabase.instance.init();
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
        builder: (context, tp, __) => MaterialApp(
          title:                      'MarkFit',
          debugShowCheckedModeBanner: false,
          theme:     _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: tp.themeMode,
          builder:   _appBuilder,
          home:      const AppEntry(),
        ),
      ),
    );
  }

  Widget _appBuilder(BuildContext context, Widget? child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mfc    = isDark ? MarkFitColors.dark : MarkFitColors.light;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:     isDark ? Brightness.dark  : Brightness.light,
    ));

    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness:              isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
        primaryColor:            MarkFitColors.teal,
        textTheme: CupertinoTextThemeData(
          primaryColor:  mfc.textPrimary,
          textStyle:     TextStyle(color: mfc.textPrimary, fontSize: 16),
          actionTextStyle: const TextStyle(
              color: MarkFitColors.teal, fontSize: 16),
        ),
      ),
      child: ColoredBox(color: mfc.scaffoldBg, child: child!),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final mfc    = isDark ? MarkFitColors.dark : MarkFitColors.light;

    final base = ColorScheme.fromSeed(
        seedColor: MarkFitColors.teal, brightness: brightness);

    final cs = base.copyWith(
      surface:              mfc.scaffoldBg,
      surfaceContainerLow:  mfc.glassCardInset,
      surfaceContainer:     mfc.glassCard,
      surfaceContainerHigh: mfc.glassCardStrong,
      onSurface:            mfc.textPrimary,
      onSurfaceVariant:     mfc.textSecondary,
      outline:              mfc.textTertiary,
      outlineVariant:       mfc.glassBorder,
      error:                MarkFitColors.red,
      onError:              Colors.white,
      primary:              MarkFitColors.teal,
      onPrimary:            Colors.white,
      secondary:            MarkFitColors.cyan,
      onSecondary:          isDark ? Colors.black : Colors.white,
      tertiary:             MarkFitColors.indigo,
      onTertiary:           Colors.white,
    );

    return ThemeData(
      useMaterial3:            true,
      brightness:              brightness,
      colorScheme:             cs,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor:             mfc.scaffoldBg,
      cardColor:               mfc.glassCard,
      dividerColor:            mfc.divider,
      extensions:              [mfc],

      textTheme: TextTheme(
        displayLarge:   _ts(mfc.textPrimary,   FontWeight.w800, -0.8),
        displayMedium:  _ts(mfc.textPrimary,   FontWeight.w700, -0.5),
        displaySmall:   _ts(mfc.textPrimary,   FontWeight.w700, -0.3),
        headlineLarge:  _ts(mfc.textPrimary,   FontWeight.w700, -0.5),
        headlineMedium: _ts(mfc.textPrimary,   FontWeight.w700, -0.3),
        headlineSmall:  _ts(mfc.textPrimary,   FontWeight.w600,  0.0),
        titleLarge:     _ts(mfc.textPrimary,   FontWeight.w700, -0.2),
        titleMedium:    _ts(mfc.textPrimary,   FontWeight.w600,  0.0),
        titleSmall:     _ts(mfc.textSecondary, FontWeight.w600,  0.0),
        bodyLarge:      _ts(mfc.textPrimary,   FontWeight.w400,  0.0),
        bodyMedium:     _ts(mfc.textSecondary, FontWeight.w400,  0.0),
        bodySmall:      _ts(mfc.textTertiary,  FontWeight.w400,  0.0),
        labelLarge:     _ts(mfc.textPrimary,   FontWeight.w600,  0.0),
        labelMedium:    _ts(mfc.textSecondary, FontWeight.w500,  0.0),
        labelSmall:     _ts(mfc.textTertiary,  FontWeight.w500,  0.5),
      ),

      appBarTheme: AppBarTheme(
        elevation:              0,
        scrolledUnderElevation: 0,
        backgroundColor:        Colors.transparent,
        surfaceTintColor:       Colors.transparent,
        foregroundColor:        mfc.textPrimary,
        iconTheme: IconThemeData(color: mfc.iconPrimary, size: 22),
        actionsIconTheme: IconThemeData(
            color: mfc.iconPrimary, size: 22),
        titleTextStyle: TextStyle(
          color: mfc.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w700, letterSpacing: -0.3),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
                .copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark
                .copyWith(statusBarColor: Colors.transparent),
      ),

      // In light mode: elevation ALTA per profondità tramite ombra
      cardTheme: CardThemeData(
        elevation:   isDark ? 0 : 8,
        color:       mfc.glassCard,
        shadowColor: mfc.elevationColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: mfc.glassBorder,
              width: isDark ? 0.8 : 1.1)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled:     true,
        fillColor:  mfc.inputBg,
        hintStyle:  TextStyle(color: mfc.inputHint, fontSize: 14),
        labelStyle: TextStyle(
            color: mfc.textSecondary, fontSize: 14),
        prefixIconColor: mfc.iconSecondary,
        suffixIconColor: mfc.iconSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: mfc.inputBorder, width: isDark ? 0.8 : 1.1)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: mfc.inputBorder, width: isDark ? 0.8 : 1.1)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: mfc.inputBorderFocus,
              width: isDark ? 1.5 : 1.8)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: MarkFitColors.red, width: 1.2)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),

      dividerTheme: DividerThemeData(
          color: mfc.divider, thickness: 0.5, space: 1),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(24))),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior:        SnackBarBehavior.floating,
        // Dark snackbar in entrambi i temi per leggibilità
        backgroundColor: const Color(0xFF0F1C2E),
        contentTextStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor:  mfc.sheetBg,
        surfaceTintColor: Colors.transparent,
        // Elevazione alta in light per distinguere il dialog
        elevation:        isDark ? 0 : 32,
        shadowColor:      mfc.elevationColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: mfc.glassBorder,
              width: isDark ? 0.8 : 1.1)),
      ),

      listTileTheme: ListTileThemeData(
        iconColor:      mfc.iconSecondary,
        textColor:      mfc.textPrimary,
        titleTextStyle: TextStyle(
            color: mfc.textPrimary, fontWeight: FontWeight.w500),
        subtitleTextStyle: TextStyle(
            color: mfc.textTertiary, fontSize: 12),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? MarkFitColors.teal
                : (isDark ? Colors.white54 : Colors.grey.shade400)),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? MarkFitColors.teal.withOpacity(0.4)
                : mfc.glassBorder),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color:            mfc.glassCardStrong,
        surfaceTintColor: Colors.transparent,
        elevation:        isDark ? 0 : 10,
        shadowColor:      mfc.elevationColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: mfc.glassBorder,
              width: isDark ? 0.8 : 1.0)),
        labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: mfc.textPrimary)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor:  mfc.glassCard,
        selectedColor:    MarkFitColors.teal.withOpacity(0.15),
        side: BorderSide(color: mfc.glassBorder,
            width: isDark ? 0.8 : 1.0),
        labelStyle: TextStyle(color: mfc.textPrimary, fontSize: 12),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MarkFitColors.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          elevation:   isDark ? 0 : 5,
          shadowColor: MarkFitColors.teal.withOpacity(0.45),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: mfc.textPrimary,
          side: BorderSide(color: mfc.glassBorder,
              width: isDark ? 0.8 : 1.1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 12),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MarkFitColors.teal,
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color:            MarkFitColors.teal,
        linearTrackColor: mfc.divider,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor:   MarkFitColors.teal,
        thumbColor:         MarkFitColors.teal,
        overlayColor:       MarkFitColors.teal.withOpacity(0.12),
        inactiveTrackColor: mfc.divider,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor:           MarkFitColors.teal,
        unselectedLabelColor: mfc.textTertiary,
        indicatorColor:       MarkFitColors.teal,
        dividerColor:         Colors.transparent,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500, fontSize: 12),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
            foregroundColor: mfc.iconPrimary)),
    );
  }

  TextStyle _ts(Color color, FontWeight w, double ls) =>
      TextStyle(color: color, fontWeight: w, letterSpacing: ls);
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
        body: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Icon(Icons.fitness_center_rounded,
              size: 48, color: MarkFitColors.teal),
          const SizedBox(height: 16),
          CircularProgressIndicator(
              color: MarkFitColors.teal, strokeWidth: 2),
        ])));
    }
    if (!context.watch<AuthProvider>().isLoggedIn) {
      return LoginScreen(onLoginSuccess: () {
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
      extendBody:      true,
      body: IndexedStack(index: idx, children: const [
        HomeScreen(),
        AllenamentiScreen(),
        HistoryScreen(),
        SettingsScreen(),
      ]),
      bottomNavigationBar: _LiquidGlassNavBar(
        currentIndex: idx,
        onTap: (i) =>
            context.read<NavigationNotifier>().navigateTo(i)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _LiquidGlassNavBar
// ─────────────────────────────────────────────────────────────

class _LiquidGlassNavBar extends StatelessWidget {
  final int  currentIndex;
  final void Function(int) onTap;
  const _LiquidGlassNavBar(
      {required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(icon: Icons.today_rounded,          label: 'Oggi'),
    _NavItem(icon: Icons.fitness_center_rounded, label: 'Allenamenti'),
    _NavItem(icon: Icons.bar_chart_rounded,      label: 'Storico'),
    _NavItem(icon: Icons.settings_rounded,       label: 'Impostazioni'),
  ];

  @override
  Widget build(BuildContext context) {
    final c         = context.mfc;
    final isDark    = context.isDarkMode;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Stack(children: [
            Container(
              height: 68,
              decoration: BoxDecoration(
                color:        c.navBg,
                borderRadius: BorderRadius.circular(44),
                border: Border.all(
                    color: c.navBorder,
                    width: isDark ? 0.9 : 1.5),
                boxShadow: [
                  BoxShadow(
                    color:        c.navShadow,
                    blurRadius:   isDark ? 32 : 28,
                    spreadRadius: -4,
                    offset:       const Offset(0, 8)),
                ],
              ),
              child: Row(children: List.generate(
                _items.length, (i) => Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(i);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: _LiquidNavItem(
                      item:     _items[i],
                      selected: i == currentIndex,
                      c:        c))))),
            ),
            Positioned(top: 0, left: 20, right: 20,
              child: Container(
                height: isDark ? 0.7 : 1.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    c.navSpecular,
                    Colors.transparent])))),
          ]),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon; final String label;
  const _NavItem({required this.icon, required this.label});
}

class _LiquidNavItem extends StatefulWidget {
  final _NavItem      item;
  final bool          selected;
  final MarkFitColors c;
  const _LiquidNavItem({required this.item, required this.selected,
      required this.c});
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
                      Container(decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: MarkFitColors.teal.withOpacity(0.40),
                            blurRadius: 14, spreadRadius: -2)])),
                      Container(decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: c.navPillGradient,
                            begin: Alignment.topCenter,
                            end:   Alignment.bottomCenter),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: MarkFitColors.teal.withOpacity(0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 3))])),
                      Positioned(top: 1,
                        child: Container(
                          width: pillW * 0.4, height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.35),
                              Colors.transparent]),
                            borderRadius: BorderRadius.circular(2)))),
                      Transform.scale(scale: iconScale,
                        child: Icon(widget.item.icon,
                            color: Colors.white, size: 21)),
                    ]))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    Icon(widget.item.icon,
                        color: c.navUnselected, size: 21),
                    const SizedBox(height: 3),
                    Text(widget.item.label, style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w500,
                        color: c.navUnselected)),
                  ]),
          );
        }));
  }
}