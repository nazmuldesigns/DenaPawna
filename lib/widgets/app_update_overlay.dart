import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/version_check_service.dart';

class AppUpdateOverlay extends StatefulWidget {
  const AppUpdateOverlay({
    required this.child,
    required this.service,
    super.key,
  });

  final Widget child;
  final VersionCheckService service;

  @override
  State<AppUpdateOverlay> createState() => _AppUpdateOverlayState();
}

class _AppUpdateOverlayState extends State<AppUpdateOverlay> {
  AppUpdateConfig? _update;
  bool _checking = true;
  bool _openingDownload = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final update = await widget.service.checkForUpdate();
    if (!mounted) return;
    setState(() {
      _update = update;
      _checking = false;
    });
  }

  Future<void> _openDownload() async {
    final update = _update;
    if (update == null || _openingDownload) return;
    setState(() => _openingDownload = true);
    final launched = await launchUrl(
      Uri.parse(update.apkUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    if (!launched) {
      setState(() => _openingDownload = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the update download.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    return Stack(
      children: [
        widget.child,
        if (!_checking && update != null)
          Positioned.fill(
            child: Stack(
              children: [
                const ModalBarrier(dismissible: false, color: Colors.black54),
                Center(
                  child: PopScope(
                    canPop: !update.forceUpdate,
                    child: AlertDialog(
                      title: const Text('Update Available'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Version ${update.latestVersion} is available.'),
                          if (update.releaseNotes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(update.releaseNotes),
                          ],
                          const SizedBox(height: 12),
                          const Text(
                            'Install the latest version to receive improvements '
                            'and important fixes.',
                          ),
                          if (_openingDownload) ...[
                            const SizedBox(height: 20),
                            const LinearProgressIndicator(),
                            const SizedBox(height: 8),
                            const Text('Opening download...'),
                          ],
                        ],
                      ),
                      actions: [
                        if (!update.forceUpdate)
                          TextButton(
                            onPressed: _openingDownload
                                ? null
                                : () => setState(() => _update = null),
                            child: const Text('Later'),
                          ),
                        FilledButton(
                          onPressed: _openingDownload ? null : _openDownload,
                          child: const Text('Update Now'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
