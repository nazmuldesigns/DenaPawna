import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUpdateConfig {
  const AppUpdateConfig({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.apkUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  final String latestVersion;
  final int latestBuildNumber;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;
}

class VersionCheckService {
  const VersionCheckService(this.client);

  final SupabaseClient? client;

  Future<AppUpdateConfig?> checkForUpdate() async {
    final configuredClient = client;
    if (configuredClient == null) return null;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final data = await configuredClient
          .from('version_control')
          .select(
            'latest_version, latest_build_number, apk_url, release_notes, '
            'force_update',
          )
          .order('created_at', ascending: false)
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
      final latestBuildNumber = _asBuildNumber(data['latest_build_number']);
      if (latestBuildNumber == null) return null;
      final releaseNotes = data['release_notes'];
      final packageBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      return _isNewer(
        installedVersion: packageInfo.version,
        installedBuildNumber: packageBuildNumber,
        latestVersion: latestVersion,
        latestBuildNumber: latestBuildNumber,
      )
          ? AppUpdateConfig(
              latestVersion: latestVersion.trim(),
              latestBuildNumber: latestBuildNumber,
              apkUrl: apkUrl.trim(),
              releaseNotes: releaseNotes is String ? releaseNotes.trim() : '',
              forceUpdate: data['force_update'] == true,
            )
          : null;
    } on TimeoutException {
      return null;
    } on PostgrestException catch (error) {
      debugPrint('Version check failed: ${error.message}');
      return null;
    } on Object catch (error) {
      debugPrint('Version check unavailable: $error');
      return null;
    }
  }

  bool _isNewer({
    required String installedVersion,
    required int installedBuildNumber,
    required String latestVersion,
    required int latestBuildNumber,
  }) {
    final versionComparison = _compareVersions(installedVersion, latestVersion);
    if (versionComparison != 0) return versionComparison < 0;
    return latestBuildNumber > installedBuildNumber;
  }

  int _compareVersions(String installed, String latest) {
    final installedParts = _versionParts(installed);
    final latestParts = _versionParts(latest);
    final length = installedParts.length > latestParts.length
        ? installedParts.length
        : latestParts.length;
    for (var index = 0; index < length; index++) {
      final installedPart =
          index < installedParts.length ? installedParts[index] : 0;
      final latestPart = index < latestParts.length ? latestParts[index] : 0;
      if (latestPart != installedPart) {
        return installedPart < latestPart ? -1 : 1;
      }
    }
    return 0;
  }

  List<int> _versionParts(String version) => version
      .split('+')
      .first
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();

  int? _asBuildNumber(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
