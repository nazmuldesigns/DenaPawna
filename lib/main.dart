import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/ledger_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/root_shell.dart';
import 'services/database_service.dart';
import 'services/supabase_auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  SupabaseClient? client;
  String? configurationError;
  const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pzuohbfalodsiniutecg.supabase.co',
  );
  const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_OmcawzIU_RvW9OMuow9kgQ_iTHBQEbU',
  );
  if (url.isEmpty || anonKey.isEmpty) {
    configurationError = 'Supabase is not configured for this build.';
  } else {
    try {
      await Supabase.initialize(url: url, publishableKey: anonKey);
      client = Supabase.instance.client;
    } on Object catch (error) {
      configurationError = 'Supabase initialization failed: $error';
    }
  }
  runApp(
    KhataBondhuApp(
      authService: SupabaseAuthService(
        client,
        configurationError: configurationError,
      ),
    ),
  );
}

class KhataBondhuApp extends StatelessWidget {
  const KhataBondhuApp({required this.authService, super.key});

  final SupabaseAuthService authService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authService),
        ),
        ChangeNotifierProvider<LedgerProvider>(create: (_) => LedgerProvider()),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider()..load(),
        ),
      ],
      child: Consumer2<SettingsProvider, AuthProvider>(
        builder: (context, settings, auth, _) {
          return MaterialApp(
            title: 'Dena Pawna',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('bn')],
            home: auth.isAuthenticated ? const RootShell() : const AuthScreen(),
          );
        },
      ),
    );
  }
}
