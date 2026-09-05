import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this.service) {
    _session = service.currentSession;
    _subscription = service.authStateChanges.listen(_onAuthStateChanged);
  }

  final SupabaseAuthService service;
  late final StreamSubscription<AuthState> _subscription;
  Session? _session;
  String? _errorMessage;
  bool _isBusy = false;

  bool get isAuthenticated => _session != null;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage ?? service.configurationError;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _run(() => service.signIn(email: email, password: password));
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await _run(() => service.signUp(email: email, password: password));
  }

  Future<void> signOut() async {
    await _run(service.signOut);
  }

  Future<void> _run(Future<Object?> Function() operation) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await operation();
    } catch (error) {
      _errorMessage = error is AuthException
          ? error.message
          : error is StateError
              ? error.message
              : 'Authentication failed. Please try again.';
      notifyListeners();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _onAuthStateChanged(AuthState state) {
    _session = state.session;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
