import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../screens/root_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isRegistering = false;
  bool _showOtp = false;
  String? _otpEmail;
  String? _message;
  Timer? _otpTimer;
  int _otpSeconds = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    if (!_isRegistering) {
      try {
        await auth.service.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) setState(() => _message = null);
      } on AuthException catch (error) {
        if (mounted) {
          setState(() => _message = _friendlyAuthError(error));
        }
      }
      return;
    }

    try {
      await auth.service.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        phone: _mobileController.text.trim(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = _friendlyError(error));
      return;
    }
    if (!mounted) return;
    if (auth.errorMessage == null) {
      setState(() {
        _otpEmail = _emailController.text.trim();
        _showOtp = true;
        _startOtpTimer();
        _message =
            'A confirmation link has been sent to your email. Please verify your email before logging in.';
      });
    }
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    setState(() => _otpSeconds = 60);
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
      } else if (_otpSeconds <= 1) {
        timer.cancel();
        setState(() => _otpSeconds = 0);
      } else {
        setState(() => _otpSeconds--);
      }
    });
  }

  Future<void> _resendSignupOtp() async {
    if (_otpSeconds > 0 || _otpEmail == null) return;
    final auth = context.read<AuthProvider>();
    try {
      await auth.service.signUpWithEmail(
        email: _otpEmail!,
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        phone: _mobileController.text.trim(),
      );
      if (mounted) {
        _startOtpTimer();
        setState(() => _message = 'A new confirmation code was sent.');
      }
    } catch (error) {
      if (mounted) setState(() => _message = _friendlyError(error));
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final email = TextEditingController();
    final otp = TextEditingController();
    final password = TextEditingController();
    final confirm = TextEditingController();
    var seconds = 0;
    Timer? timer;
    var sent = false;
    var verified = false;
    String? message;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Forgot Password?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                enabled: !sent,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              if (sent && !verified) ...[
                TextField(
                  controller: otp,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'OTP'),
                ),
                Text(
                  seconds == 0
                      ? 'You can resend the OTP now.'
                      : 'Resend OTP in 00:${seconds.toString().padLeft(2, '0')}',
                ),
              ],
              if (verified) ...[
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                ),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                ),
              ],
              if (message != null) Text(message!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  if (!sent) {
                    await context
                        .read<AuthProvider>()
                        .service
                        .sendPasswordReset(email.text.trim());
                    refresh(() {
                      sent = true;
                      seconds = 60;
                      message = 'OTP sent to your email.';
                    });
                    timer = Timer.periodic(const Duration(seconds: 1), (tick) {
                      if (seconds <= 1) {
                        tick.cancel();
                        refresh(() => seconds = 0);
                      } else {
                        refresh(() => seconds--);
                      }
                    });
                  } else if (!verified) {
                    await context
                        .read<AuthProvider>()
                        .service
                        .verifyRecoveryOtp(
                          email: email.text.trim(),
                          token: otp.text.trim(),
                        );
                    refresh(() {
                      verified = true;
                      message = 'OTP verified.';
                    });
                  } else {
                    if (password.text.length < 6 ||
                        password.text != confirm.text) {
                      refresh(
                        () => message =
                            'Passwords must match and be at least 6 characters.',
                      );
                      return;
                    }
                    await context
                        .read<AuthProvider>()
                        .service
                        .updatePasswordAfterRecovery(password.text);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  }
                } catch (error) {
                  refresh(() => message = _friendlyError(error));
                }
              },
              child: Text(
                !sent
                    ? 'Send OTP'
                    : verified
                    ? 'Set Password'
                    : 'Verify OTP',
              ),
            ),
            if (sent && !verified)
              TextButton(
                onPressed: seconds > 0
                    ? null
                    : () async {
                        await context
                            .read<AuthProvider>()
                            .service
                            .sendPasswordReset(email.text.trim());
                        refresh(() => seconds = 60);
                      },
                child: const Text('Resend OTP'),
              ),
          ],
        ),
      ),
    );
    timer?.cancel();
    email.dispose();
    otp.dispose();
    password.dispose();
    confirm.dispose();
  }

  Future<void> _verifyOtp() async {
    final token = _otpController.text.trim();
    if (token.length != 6) {
      setState(() => _message = 'Enter the 6-digit confirmation code.');
      return;
    }

    final auth = context.read<AuthProvider>();
    try {
      final response = await auth.service.verifyEmailOtp(
        email: _otpEmail!,
        token: token,
      );
      if (!mounted) return;
      if (response.session != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const RootShell()),
          (_) => false,
        );
      } else {
        setState(
          () => _message = 'The code was accepted. You can now sign in.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = _friendlyError(error));
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.toLowerCase().contains('expired') ||
        message.toLowerCase().contains('invalid')) {
      return 'That confirmation code is invalid or expired. Please try again.';
    }

    return message.replaceFirst('Exception: ', '');
  }

  String _friendlyAuthError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('confirm')) {
      return 'Email not confirmed. Please verify your email first.';
    }
    if (message.contains('invalid login') ||
        message.contains('invalid credentials') ||
        message.contains('password')) {
      return 'Incorrect email or password. Please try again.';
    }
    return error.message;
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label is required' : null;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final error = auth.errorMessage;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _showOtp ? _buildOtpView(auth) : _buildForm(auth, error),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpView(AuthProvider auth) {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify your email',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text('Enter the 6-digit code sent to your email address.'),
        const SizedBox(height: 24),
        TextField(
          controller: _otpController,
          autofocus: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(labelText: 'Verification code'),
        ),
        if (_message != null) ...[const SizedBox(height: 12), Text(_message!)],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: auth.isBusy ? null : _verifyOtp,
          child: const Text('Verify OTP'),
        ),
        TextButton(
          onPressed: auth.isBusy
              ? null
              : () => setState(() {
                  _showOtp = false;
                  _message = null;
                }),
          child: const Text('Back to sign in'),
        ),
        TextButton(
          onPressed: auth.isBusy ? null : _resendSignupOtp,
          child: Text(
            _otpSeconds > 0
                ? 'Resend OTP in 00:${_otpSeconds.toString().padLeft(2, '0')}'
                : 'Resend OTP',
          ),
        ),
      ],
    );
  }

  Widget _buildForm(AuthProvider auth, String? error) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isRegistering ? 'Create your account' : 'Sign in',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          if (_isRegistering) ...[
            TextFormField(
              controller: _nameController,
              enabled: !auth.isBusy && auth.service.isConfigured,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: (value) => _required(value, 'Full Name'),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !auth.isBusy && auth.service.isConfigured,
            decoration: const InputDecoration(labelText: 'Email Address'),
            validator: (value) => _required(value, 'Email Address'),
          ),
          if (_isRegistering) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              enabled: !auth.isBusy && auth.service.isConfigured,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
              validator: (value) => _required(value, 'Mobile Number'),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            enabled: !auth.isBusy && auth.service.isConfigured,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (value) => value == null || value.length < 6
                ? 'Password must be at least 6 characters'
                : null,
          ),
          if (_isRegistering) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              enabled: !auth.isBusy && auth.service.isConfigured,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
              validator: (value) => value != _passwordController.text
                  ? 'Passwords do not match'
                  : null,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (!_isRegistering)
            TextButton(
              onPressed: auth.isBusy ? null : _showForgotPasswordDialog,
              child: const Text('Forgot Password?'),
            ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: auth.isBusy || !auth.service.isConfigured
                ? null
                : _submit,
            child: Text(_isRegistering ? 'Create account' : 'Sign in'),
          ),
          TextButton(
            onPressed: auth.isBusy
                ? null
                : () => setState(() {
                    _isRegistering = !_isRegistering;
                    _message = null;
                  }),
            child: Text(
              _isRegistering
                  ? 'Already have an account? Sign in'
                  : 'Need an account? Register',
            ),
          ),
        ],
      ),
    );
  }
}
