import 'dart:async';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUpdateConfig {
  const AppUpdateConfig({
    required this.latestVersion,
    required this.apkUrl,
    required this.forceUpdate,
  });

  final String latestVersion;
  final String apkUrl;
  final bool forceUpdate;
}

class AppUpdateService {
  const AppUpdateService(this.client);

  final SupabaseClient? client;

  Future<AppUpdateConfig?> checkForUpdate() async {
    final configuredClient = client;
    if (configuredClient == null) return null;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final data = await configuredClient
          .from('app_config')
          .select('latest_version, apk_url, force_update')
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      if (data == null) return null;

      final latestVersion = data['latest_version'];
      final apkUrl = data['apk_url'];
      if (latestVersion is! String ||
          latestVersion.trim().isEmpty ||
          apkUrl is! String ||
          apkUrl.trim().isEmpty) {
        return null;
      }

      final forceUpdate = data['force_update'];
      return _isNewerVersion(packageInfo.version, latestVersion)
          ? AppUpdateConfig(
              latestVersion: latestVersion.trim(),
              apkUrl: apkUrl.trim(),
              forceUpdate: forceUpdate is bool && forceUpdate,
            )
          : null;
    } on TimeoutException {
      return null;
    } on Object {
      return null;
    }
  }

  bool _isNewerVersion(String installed, String latest) {
    final installedParts = _versionParts(installed);
    final latestParts = _versionParts(latest);
    final length = installedParts.length > latestParts.length
        ? installedParts.length
        : latestParts.length;
    for (var index = 0; index < length; index++) {
      final installedPart = index < installedParts.length
          ? installedParts[index]
          : 0;
      final latestPart = index < latestParts.length ? latestParts[index] : 0;
      if (latestPart != installedPart) return latestPart > installedPart;
    }
    return false;
  }

  List<int> _versionParts(String version) {
    return version
        .split('+')
        .first
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }
}
