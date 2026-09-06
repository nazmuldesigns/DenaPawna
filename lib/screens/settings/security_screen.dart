import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _current = TextEditingController();
  final _resetPassword = TextEditingController();
  final _resetConfirm = TextEditingController();
  final _otp = TextEditingController();
  bool _resetRequested = false;
  bool _busy = false;
  int _seconds = 0;
  Timer? _timer;
  String? _message;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _current.dispose();
    _resetPassword.dispose();
    _resetConfirm.dispose();
    _otp.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_current.text.isEmpty) {
      setState(() => _message = 'Enter your current password.');
      return;
    }
    if (_password.text.length < 6 || _password.text != _confirm.text) {
      setState(
        () => _message = 'Passwords must match and be at least 6 characters.',
      );
      return;
    }
    final service = context.read<AuthProvider>().service;
    final email = service.currentUser?.email;
    if (email == null) {
      setState(() => _message = 'No registered email is available.');
      return;
    }
    await _run(() async {
      await service.verifyCurrentPassword(
        email: email,
        password: _current.text,
      );
      await service.updatePassword(_password.text);
    });
  }

  Future<void> _requestReset() async {
    final email = context.read<AuthProvider>().service.currentUser?.email;
    if (email == null || email.isEmpty) {
      setState(() => _message = 'No registered email is available.');
      return;
    }
    await _run(() async {
      await context.read<AuthProvider>().service.sendPasswordReset(email);
      if (mounted) {
        setState(() {
          _resetRequested = true;
          _message = 'A password reset code has been sent to $email.';
        });
        _startTimer();
      }
    });
  }

  Future<void> _verifyReset() async {
    final email = context.read<AuthProvider>().service.currentUser?.email;
    if (email == null || _otp.text.trim().length != 6) {
      setState(() => _message = 'Enter the 6-digit reset code.');
      return;
    }
    if (_resetPassword.text.length < 6 ||
        _resetPassword.text != _resetConfirm.text) {
      setState(
        () =>
            _message = 'New passwords must match and be at least 6 characters.',
      );
      return;
    }
    await _run(() async {
      await context.read<AuthProvider>().service.verifyRecoveryOtp(
        email: email,
        token: _otp.text.trim(),
      );
      await context.read<AuthProvider>().service.updatePasswordAfterRecovery(
        _resetPassword.text,
      );
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _seconds = 0);
      } else if (mounted) {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted && _message == null) {
        setState(() => _message = 'Security settings updated.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = '$error'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _current,
            obscureText: true,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Current Password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'New Password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Confirm Password'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _changePassword,
            child: const Text('Change Password'),
          ),
          const Divider(height: 32),
          OutlinedButton.icon(
            onPressed: _busy ? null : _requestReset,
            icon: const Icon(Icons.mark_email_read_outlined),
            label: const Text('Forgot Password? Send Code'),
          ),
          if (_resetRequested) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _resetPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            TextField(
              controller: _resetConfirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
              ),
            ),
            TextField(
              controller: _otp,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reset OTP'),
            ),
            Text(
              _seconds > 0
                  ? 'Resend OTP in 00:${_seconds.toString().padLeft(2, '0')}'
                  : 'You can resend the OTP now.',
            ),
            FilledButton(
              onPressed: _busy ? null : _verifyReset,
              child: const Text('Verify Reset Code'),
            ),
            TextButton(
              onPressed: _busy || _seconds > 0 ? null : _requestReset,
              child: const Text('Resend OTP'),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!),
          ],
        ],
      ),
    );
  }
}
