import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum AppUpdateLevel { none, optional, required }

class AppVersionStatus {
  const AppVersionStatus({
    required this.level,
    required this.currentVersion,
    this.minimumVersion = '',
    this.latestVersion = '',
    this.updateUrl = '',
  });

  final AppUpdateLevel level;
  final String currentVersion;
  final String minimumVersion;
  final String latestVersion;
  final String updateUrl;

  bool get isRequired => level == AppUpdateLevel.required;
  bool get isOptional => level == AppUpdateLevel.optional;
}

class AppVersionGate {
  static bool _hasPassed = false;
  static bool get hasPassed => _hasPassed;

  AppVersionGate({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig;

  final FirebaseRemoteConfig? _remoteConfig;

  Future<AppVersionStatus> check() async {
    try {
      final remoteConfig = _remoteConfig ?? FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 8),
          minimumFetchInterval: kReleaseMode
              ? const Duration(hours: 6)
              : Duration.zero,
        ),
      );
      await remoteConfig.setDefaults(const <String, Object>{
        'min_version_android': '',
        'latest_version_android': '',
        'update_url_android': '',
        'min_version_ios': '',
        'latest_version_ios': '',
        'update_url_ios': '',
      });
      await remoteConfig.fetchAndActivate();

      final package = await PackageInfo.fromPlatform();
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      final minimum = remoteConfig.getString('min_version_$platform').trim();
      final latest = remoteConfig.getString('latest_version_$platform').trim();
      final configuredUpdateUrl =
          remoteConfig.getString('update_url_$platform').trim();
      final parsedUpdateUrl = Uri.tryParse(configuredUpdateUrl);
      final updateUrl = parsedUpdateUrl != null &&
              parsedUpdateUrl.hasScheme &&
              <String>{'https', 'http', 'market'}.contains(
                parsedUpdateUrl.scheme,
              )
          ? configuredUpdateUrl
          : '';

      if (minimum.isNotEmpty &&
          compareVersions(package.version, minimum) < 0) {
        if (updateUrl.isNotEmpty) {
          _hasPassed = false;
          return AppVersionStatus(
            level: AppUpdateLevel.required,
            currentVersion: package.version,
            minimumVersion: minimum,
            latestVersion: latest,
            updateUrl: updateUrl,
          );
        }
        // Never strand users on a non-dismissible screen if the store URL
        // was omitted or malformed in Remote Config.
        _hasPassed = true;
        return AppVersionStatus(
          level: AppUpdateLevel.optional,
          currentVersion: package.version,
          minimumVersion: minimum,
          latestVersion: latest.isEmpty ? minimum : latest,
          updateUrl: '',
        );
      }
      if (latest.isNotEmpty && compareVersions(package.version, latest) < 0) {
        _hasPassed = true;
        return AppVersionStatus(
          level: AppUpdateLevel.optional,
          currentVersion: package.version,
          minimumVersion: minimum,
          latestVersion: latest,
          updateUrl: updateUrl,
        );
      }
      _hasPassed = true;
      return AppVersionStatus(
        level: AppUpdateLevel.none,
        currentVersion: package.version,
        minimumVersion: minimum,
        latestVersion: latest,
        updateUrl: updateUrl,
      );
    } on Object catch (error, stackTrace) {
      _hasPassed = true;
      debugPrint('Pubget version check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const AppVersionStatus(
        level: AppUpdateLevel.none,
        currentVersion: '',
      );
    }
  }

  static int compareVersions(String current, String required) {
    final left = _versionParts(current);
    final right = _versionParts(required);
    final length = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final a = index < left.length ? left[index] : 0;
      final b = index < right.length ? right[index] : 0;
      if (a != b) {
        return a.compareTo(b);
      }
    }
    return 0;
  }

  static List<int> _versionParts(String value) {
    final numeric = RegExp(r'\d+').allMatches(value);
    return numeric.map((match) => int.parse(match.group(0)!)).toList();
  }
}
