import 'dart:io';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/app_settings.dart';
import 'services/api_service.dart';
import 'services/jpush_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 仅开发/测试环境：忽略自签名证书（抓包或本地HTTPS调试时使用）
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 开启自签名证书的全局信任（仅开发/测试环境）
  HttpOverrides.global = MyHttpOverrides();

  // 并行初始化所有服务，大幅缩短启动时间
  await Future.wait([
    ApiService.initialize(),
    ApiService.restoreAuthState(),
    AppSettings.instance.initialize(),
  ]);
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppSettings _settings = AppSettings.instance;
  AppLifecycleState? _lastLifecycleState;
  late final _LifecycleObserver _lifecycleObserver;

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
    _lifecycleObserver = _LifecycleObserver(onResumed: () {
      JPushService.refreshRegistration();
    });
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await JPushService.initialize();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
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
      navigatorKey: JPushService.navigatorKey,
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

class _LifecycleObserver with WidgetsBindingObserver {
  final VoidCallback onResumed;
  _LifecycleObserver({required this.onResumed});
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
