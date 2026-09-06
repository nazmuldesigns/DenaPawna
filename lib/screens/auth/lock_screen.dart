import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

/// Shown at app startup when app lock is enabled. Requires the correct
/// PIN (or biometric if enabled) to proceed into the app.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _input = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    final settings = context.read<SettingsProvider>();
    if (settings.security.isBiometricEnabled) {
      final ok = await settings.security.authenticateWithBiometrics();
      if (ok && mounted) {
        settings.unlock();
      }
    }
  }

  void _onDigit(String digit) {
    if (_input.length >= 4) return;
    setState(() {
      _input += digit;
      _error = null;
    });
    if (_input.length == 4) _verify();
  }

  void _onBackspace() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _verify() {
    final settings = context.read<SettingsProvider>();
    if (settings.security.verifyPin(_input)) {
      settings.unlock();
    } else {
      setState(() {
        _error = 'ভুল PIN, আবার চেষ্টা করুন';
        _input = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      backgroundColor: AppColors.teal,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.lock_outline, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            const Text(
              'দেনা পাওনা লক করা আছে',
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('PIN দিয়ে আনলক করুন',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _input.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? Colors.white : Colors.transparent,
                    border: Border.all(color: Colors.white, width: 1.6),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.white)),
            ],
            const Spacer(),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  _buildKeypad(),
                  if (settings.security.isBiometricEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: IconButton(
                        onPressed: _tryBiometric,
                        icon: const Icon(Icons.fingerprint,
                            size: 32, color: AppColors.teal),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox.shrink();
        return InkWell(
          onTap: () {
            if (key == '⌫') {
              _onBackspace();
            } else {
              _onDigit(key);
            }
          },
          borderRadius: BorderRadius.circular(40),
          child: Center(
            child: Text(
              key,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }).toList(),
    );
  }
}
