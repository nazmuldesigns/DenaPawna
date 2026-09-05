import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  SupabaseAuthService(this.client, {this.configurationError});

  final SupabaseClient? client;
  final String? configurationError;

  bool get isConfigured => client != null;
  Session? get currentSession => client?.auth.currentSession;

  Stream<AuthState> get authStateChanges =>
      client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _requireClient().auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (error) {
      if (error.message.toLowerCase().contains('confirm')) {
        throw AuthException(
          'Email not confirmed. Please verify your email first.',
        );
      }
      rethrow;
    }
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) {
    return _requireClient().auth.signUp(
      email: email,
      password: password,
      data: <String, dynamic>{'full_name': name, 'phone': phone},
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return signUpWithEmail(
      email: email,
      password: password,
      name: '',
      phone: '',
    );
  }

  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    return _requireClient().auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );
  }

  Future<void> signOut() => _requireClient().auth.signOut();

  SupabaseClient _requireClient() {
    final configuredClient = client;
    if (configuredClient == null) {
      throw StateError(
        configurationError ??
            'Supabase is not configured. Provide SUPABASE_URL and '
                'SUPABASE_ANON_KEY with --dart-define.',
      );
    }
    return configuredClient;
  }
}
