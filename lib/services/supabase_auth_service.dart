import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthNetworkException implements Exception {
  const AuthNetworkException();

  @override
  String toString() => 'Network connection unavailable';
}

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
        email: email.trim(),
        password: password.trim(),
      );
    } on SocketException {
      throw const AuthNetworkException();
    } on ClientException {
      throw const AuthNetworkException();
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
  }) async {
    try {
      return await _requireClient().auth.signUp(
        email: email.trim(),
        password: password,
        data: <String, dynamic>{'full_name': name, 'phone': phone},
      );
    } on AuthException {
      rethrow;
    } on SocketException {
      throw const AuthNetworkException();
    } on TimeoutException {
      throw const AuthNetworkException();
    } on ClientException {
      throw const AuthNetworkException();
    } on Exception {
      rethrow;
    }
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

  Future<void> resendSignupOtp(String email) async {
    try {
      await _requireClient().auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
    } on AuthException {
      rethrow;
    } on SocketException {
      throw const AuthNetworkException();
    } on TimeoutException {
      throw const AuthNetworkException();
    } on ClientException {
      throw const AuthNetworkException();
    } on Exception {
      rethrow;
    }
  }

  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    try {
      return await _requireClient().auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
    } on SocketException {
      throw const AuthNetworkException();
    } on ClientException {
      throw const AuthNetworkException();
    }
  }

  Future<void> signOut() => _requireClient().auth.signOut();

  User? get currentUser => client?.auth.currentUser;

  Future<UserResponse> updatePassword(String password) {
    return _requireClient().auth.updateUser(UserAttributes(password: password));
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _requireClient().auth.resetPasswordForEmail(email.trim());
    } on SocketException {
      throw const AuthNetworkException();
    } on ClientException {
      throw const AuthNetworkException();
    }
  }

  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) {
    return _requireClient().auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
    );
  }

  Future<AuthResponse> verifyEmailChangeOtp({
    required String email,
    required String token,
  }) {
    return _requireClient().auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.emailChange,
    );
  }

  Future<void> sendCurrentEmailOtp(String email) {
    return _requireClient().auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: false,
    );
  }

  Future<AuthResponse> verifyCurrentEmailOtp({
    required String email,
    required String token,
  }) {
    return _requireClient().auth.verifyOTP(
      email: email.trim(),
      token: token,
      type: OtpType.magiclink,
    );
  }

  Future<UserResponse> updateProfile({
    required String name,
    required String phone,
  }) {
    return _requireClient().auth.updateUser(
      UserAttributes(
        data: <String, dynamic>{'full_name': name, 'phone': phone},
      ),
    );
  }

  Future<UserResponse> updateEmail(String email) {
    return _requireClient().auth.updateUser(
      UserAttributes(email: email.trim()),
    );
  }

  Future<void> verifyCurrentPassword({
    required String email,
    required String password,
  }) async {
    await signIn(email: email, password: password);
  }

  Future<UserResponse> updatePasswordAfterRecovery(String password) {
    return _updatePasswordAndSignOut(password);
  }

  Future<UserResponse> _updatePasswordAndSignOut(String password) async {
    final response = await _requireClient().auth.updateUser(
      UserAttributes(password: password),
    );
    await _requireClient().auth.signOut();
    return response;
  }

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
