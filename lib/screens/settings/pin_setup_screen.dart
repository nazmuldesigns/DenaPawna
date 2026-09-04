import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

/// Two-step PIN setup: enter PIN, then confirm.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _firstPin = '';
  String _currentInput = '';
  bool _confirming = false;
  String? _error;

  void _onDigit(String digit) {
    if (_currentInput.length >= 4) return;
    setState(() {
      _currentInput += digit;
      _error = null;
    });
    if (_currentInput.length == 4) {
      _handleComplete();
    }
  }

  void _onBackspace() {
    if (_currentInput.isEmpty) return;
    setState(() => _currentInput = _currentInput.substring(0, _currentInput.length - 1));
  }

  Future<void> _handleComplete() async {
    if (!_confirming) {
      setState(() {
        _firstPin = _currentInput;
        _currentInput = '';
        _confirming = true;
      });
    } else {
      if (_currentInput == _firstPin) {
        final settings = context.read<SettingsProvider>();
        await settings.security.setPin(_firstPin);
        settings.unlock();
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = 'PIN মিলছে না, আবার চেষ্টা করুন';
          _currentInput = '';
          _confirming = false;
          _firstPin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PIN সেট করুন')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              _confirming ? 'PIN আবার লিখুন' : 'নতুন ৪ সংখ্যার PIN দিন',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _currentInput.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.teal : Colors.transparent,
                    border: Border.all(color: AppColors.teal, width: 1.6),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.payableRed)),
            ],
            const Spacer(),
            _buildKeypad(),
            const SizedBox(height: 24),
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
