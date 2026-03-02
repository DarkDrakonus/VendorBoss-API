import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConnectivityService.instance.init();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? true;
  final isLoggedIn = await AuthService.instance.isLoggedIn;

  runApp(VendorBossApp(
    initialDarkMode: isDark,
    initiallyLoggedIn: isLoggedIn,
  ));
}

class VendorBossApp extends StatefulWidget {
  final bool initialDarkMode;
  final bool initiallyLoggedIn;

  const VendorBossApp({
    super.key,
    required this.initialDarkMode,
    required this.initiallyLoggedIn,
  });

  static _VendorBossAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_VendorBossAppState>();

  @override
  State<VendorBossApp> createState() => _VendorBossAppState();
}

class _VendorBossAppState extends State<VendorBossApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
  }

  void toggleTheme() async {
    setState(() => _isDarkMode = !_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('dark_mode', _isDarkMode);
  }

  bool get isDarkMode => _isDarkMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VendorBoss',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      initialRoute: widget.initiallyLoggedIn ? '/home' : '/login',
      routes: {
        '/login':    (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home':     (_) => const MainShell(),
      },
      // Handle expired token — any 401 navigates back to login
      navigatorObservers: [_AuthObserver()],
    );
  }
}

class _AuthObserver extends NavigatorObserver {}
