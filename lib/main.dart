import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/ledger_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/auth/lock_screen.dart';
import 'screens/root_shell.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  runApp(const KhataBondhuApp());
}

class KhataBondhuApp extends StatelessWidget {
  const KhataBondhuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LedgerProvider>(create: (_) => LedgerProvider()),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider()..load(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'খাতা বন্ধু',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: settings.isUnlocked
                ? const RootShell()
                : const LockScreen(),
          );
        },
      ),
    );
  }
}
