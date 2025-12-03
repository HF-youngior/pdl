import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/app_settings.dart';
import 'services/api_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化API服务（加载服务器配置）
  await ApiService.initialize();
  await AppSettings.instance.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppSettings _settings = AppSettings.instance;

  ThemeData _buildTheme(Brightness brightness) {
    final Color baseColor = _settings.themeColor;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: baseColor,
      brightness: brightness,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: baseColor,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: baseColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: baseColor,
        unselectedItemColor: brightness == Brightness.dark ? Colors.white70 : Colors.grey[600],
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData lightTheme = _buildTheme(Brightness.light);
    final ThemeData darkTheme = _buildTheme(Brightness.dark);

    return MaterialApp(
      title: _settings.language == 'zh' ? '企业管理系统' : 'Enterprise Management',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _settings.themeMode,
      locale: _settings.locale,
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}