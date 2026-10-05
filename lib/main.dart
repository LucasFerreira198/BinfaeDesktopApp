import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'providers/auth_provider.dart';
import 'providers/stock_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'views/dashboard_view.dart';
import 'views/login_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(960, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Informatica - BINFAE-GL',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final apiService = ApiService();
  final storageService = StorageService();

  final themeProvider = ThemeProvider();
  final authProvider = AuthProvider(apiService);
  final stockProvider = StockProvider(apiService, storageService);

  // Inicializa serviços de persistência e estado em paralelo
  await Future.wait([
    themeProvider.init(),
    authProvider.init(),
    stockProvider.init(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<StockProvider>.value(value: stockProvider),
      ],
      child: const BinfaeDesktopApp(),
    ),
  );
}

class BinfaeDesktopApp extends StatelessWidget {
  const BinfaeDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProv, authProv, child) {
        return MaterialApp(
          title: 'Informatica - BINFAE-GL',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProv.themeMode,
          home: authProv.isLoading
              ? const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : (authProv.isAuthenticated ? const DashboardView() : const LoginView()),
        );
      },
    );
  }
}
