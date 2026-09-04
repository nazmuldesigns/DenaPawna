import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/backup_service.dart';
import '../../theme/app_theme.dart';
import 'pin_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BackupService _backupService = BackupService();
  bool _busy = false;

  Future<void> _backupJson() async {
    setState(() => _busy = true);
    try {
      final file = await _backupService.exportToJsonFile();
      await _backupService.shareFile(file, text: 'খাতা বন্ধু ব্যাকআপ ফাইল');
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    try {
      final file = await _backupService.exportToCsvFile();
      await _backupService.shareFile(file, text: 'খাতা বন্ধু CSV এক্সপোর্ট');
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ব্যাকআপ পুনরুদ্ধার করুন'),
        content: const Text(
          'একটি JSON ব্যাকআপ ফাইল নির্বাচন করুন। বিদ্যমান তথ্যের সাথে '
          'মিলিয়ে নেওয়া হবে (কোনো ডুপ্লিকেট তৈরি হবে না)।',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('বাতিল')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ফাইল নির্বাচন করুন')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      if (files.isEmpty || files.single.path == null) return;
      setState(() => _busy = true);
      final file = File(files.single.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      await _backupService.restoreFromJsonMap(data);
      if (mounted) {
        context.read<LedgerProvider>().refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('পুনরুদ্ধার সম্পন্ন হয়েছে')),
        );
      }
    } catch (e) {
      _showError('পুনরুদ্ধার ব্যর্থ হয়েছে: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final security = settings.security;

    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: SafeArea(
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _sectionTitle('থিম'),
                  RadioListTile<ThemeMode>(
                    title: const Text('সিস্টেম ডিফল্ট'),
                    value: ThemeMode.system,
                    groupValue: settings.themeMode,
                    onChanged: (v) => settings.setThemeMode(v!),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('লাইট মোড'),
                    value: ThemeMode.light,
                    groupValue: settings.themeMode,
                    onChanged: (v) => settings.setThemeMode(v!),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('ডার্ক মোড'),
                    value: ThemeMode.dark,
                    groupValue: settings.themeMode,
                    onChanged: (v) => settings.setThemeMode(v!),
                  ),
                  const Divider(),
                  _sectionTitle('সুরক্ষা'),
                  SwitchListTile(
                    title: const Text('অ্যাপ লক (PIN)'),
                    subtitle: Text(security.hasPinSet
                        ? 'PIN সেট করা আছে'
                        : 'PIN সেট করা নেই'),
                    value: security.isAppLockEnabled,
                    onChanged: (enable) async {
                      if (enable) {
                        final result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                              builder: (_) => const PinSetupScreen()),
                        );
                        if (result == true) setState(() {});
                      } else {
                        await security.clearPin();
                        setState(() {});
                      }
                    },
                  ),
                  FutureBuilder<bool>(
                    future: security.isBiometricAvailable(),
                    builder: (context, snapshot) {
                      final available = snapshot.data ?? false;
                      if (!available || !security.isAppLockEnabled) {
                        return const SizedBox.shrink();
                      }
                      return SwitchListTile(
                        title: const Text('বায়োমেট্রিক লক'),
                        subtitle: const Text('ফিঙ্গারপ্রিন্ট/ফেস দিয়ে আনলক করুন'),
                        value: security.isBiometricEnabled,
                        onChanged: (v) async {
                          await security.setBiometricEnabled(v);
                          setState(() {});
                        },
                      );
                    },
                  ),
                  const Divider(),
                  _sectionTitle('ডেটা ব্যবস্থাপনা'),
                  ListTile(
                    leading: const Icon(Icons.backup_outlined,
                        color: AppColors.teal),
                    title: const Text('ব্যাকআপ (JSON) শেয়ার করুন'),
                    onTap: _backupJson,
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore, color: AppColors.teal),
                    title: const Text('ব্যাকআপ পুনরুদ্ধার করুন'),
                    onTap: _restoreBackup,
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.table_chart_outlined, color: AppColors.teal),
                    title: const Text('CSV এক্সপোর্ট করুন'),
                    onTap: _exportCsv,
                  ),
                  const Divider(),
                  _sectionTitle('অ্যাপ তথ্য'),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('খাতা বন্ধু'),
                    subtitle: Text('সংস্করণ ১.০.০ • ব্যক্তিগত দেনা-পাওনার খাতা'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.teal,
        ),
      ),
    );
  }
}
