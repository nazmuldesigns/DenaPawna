import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final _newEmail = TextEditingController();
  final _otp = TextEditingController();
  bool _editing = false;
  int _emailStep = 0;
  bool _busy = false;
  int _seconds = 0;
  Timer? _timer;
  String? _message;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().service.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    _name = TextEditingController(text: metadata['full_name'] as String? ?? '');
    _phone = TextEditingController(text: metadata['phone'] as String? ?? '');
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _newEmail.dispose();
    _otp.dispose();
    _timer?.cancel();
    super.dispose();
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

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(() => _message = 'Name and mobile number are required.');
      return;
    }
    final service = context.read<AuthProvider>().service;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await service.updateProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
      );
      if (mounted) {
        setState(() {
          _editing = false;
          _message = 'Profile updated.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startEmailChange() async {
    final currentEmail = context
        .read<AuthProvider>()
        .service
        .currentUser
        ?.email;
    if (currentEmail == null || currentEmail.isEmpty) {
      setState(() => _message = 'No current email is available.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await context.read<AuthProvider>().service.sendCurrentEmailOtp(
        currentEmail,
      );
      if (mounted) {
        setState(() {
          _emailStep = 1;
          _message = 'A verification code was sent to your current email.';
        });
        _startTimer();
      }
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCurrentEmail() async {
    if (_otp.text.trim().length != 6) {
      setState(() => _message = 'Enter the 6-digit OTP.');
      return;
    }
    final service = context.read<AuthProvider>().service;
    setState(() => _busy = true);
    try {
      await service.verifyCurrentEmailOtp(
        email: service.currentUser!.email!,
        token: _otp.text.trim(),
      );
      if (mounted) {
        setState(() {
          _emailStep = 2;
          _message = 'Enter the new email address to continue.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitNewEmail() async {
    final newEmail = _newEmail.text.trim();
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      setState(() => _message = 'Enter a valid new email address.');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().service.updateEmail(newEmail);
      if (mounted) {
        setState(() {
          _emailStep = 3;
          _message = 'A verification code was sent to your new email.';
        });
        _startTimer();
      }
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyNewEmail() async {
    if (_otp.text.trim().length != 6) {
      setState(() => _message = 'Enter the 6-digit OTP.');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().service.verifyEmailChangeOtp(
        email: _newEmail.text.trim(),
        token: _otp.text.trim(),
      );
      if (mounted) {
        setState(() {
          _email.text = _newEmail.text.trim();
          _emailStep = 0;
          _editing = false;
          _message = 'Email updated successfully.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendEmailOtp() async {
    if (_seconds > 0 || _busy) return;
    try {
      if (_emailStep == 1) {
        await context.read<AuthProvider>().service.sendCurrentEmailOtp(
          context.read<AuthProvider>().service.currentUser!.email!,
        );
      } else if (_emailStep == 3) {
        await context.read<AuthProvider>().service.updateEmail(
          _newEmail.text.trim(),
        );
      }
      _startTimer();
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    }
  }

  String _friendly(Object error) => '$error'.replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().service.currentUser;
    final displayName = _name.text.trim().isEmpty
        ? 'Account'
        : _name.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Details'),
        actions: [
          IconButton(
            onPressed: _busy
                ? null
                : () => setState(() => _editing = !_editing),
            icon: Icon(_editing ? Icons.close : Icons.edit),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(radius: 36, child: Text(displayName[0].toUpperCase())),
          const SizedBox(height: 20),
          if (_editing) ...[
            TextField(
              controller: _name,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Email Address'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save Changes'),
            ),
          ] else ...[
            _detail('Full Name', displayName),
            _detail(
              'Mobile Number',
              _phone.text.isEmpty ? 'Not provided' : _phone.text,
            ),
            _detail('Email Address', user?.email ?? 'Not available'),
            _detail(
              'Account Created',
              user == null
                  ? 'Not available'
                  : (DateTime.tryParse(user.createdAt)?.toLocal().toString() ??
                            'Not available')
                        .split('.')
                        .first,
            ),
          ],
          if (_emailStep == 0)
            OutlinedButton(
              onPressed: _busy ? null : _startEmailChange,
              child: const Text('Change Email / ইমেইল পরিবর্তন করুন'),
            ),
          if (_emailStep == 1) ...[
            const Divider(height: 32),
            const Text('Enter the 6-digit OTP sent to your current email.'),
            TextField(
              controller: _otp,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Email OTP'),
            ),
            Text(
              _seconds > 0
                  ? 'Resend OTP in 00:${_seconds.toString().padLeft(2, '0')}'
                  : 'You can resend the OTP now.',
            ),
            FilledButton(
              onPressed: _busy ? null : _verifyCurrentEmail,
              child: const Text('Verify Current Email'),
            ),
            _resendButton(),
          ],
          if (_emailStep == 2) ...[
            const Divider(height: 32),
            TextField(
              controller: _newEmail,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Enter New Email Address',
              ),
            ),
            FilledButton(
              onPressed: _busy ? null : _submitNewEmail,
              child: const Text('Send New Email OTP'),
            ),
          ],
          if (_emailStep == 3) ...[
            const Divider(height: 32),
            const Text('Enter the 6-digit OTP sent to your new email.'),
            TextField(
              controller: _otp,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New Email OTP'),
            ),
            FilledButton(
              onPressed: _busy ? null : _verifyNewEmail,
              child: const Text('Verify New Email'),
            ),
            _resendButton(),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!),
          ],
        ],
      ),
    );
  }

  Widget _resendButton() {
    return TextButton(
      onPressed: _busy || _seconds > 0 ? null : _resendEmailOtp,
      child: Text(
        _seconds > 0
            ? 'Resend OTP in 00:${_seconds.toString().padLeft(2, '0')}'
            : 'Resend OTP',
      ),
    );
  }

  Widget _detail(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(value),
  );
}
