import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
          title: 'BINFAE Desktop',
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
