import 'package:flutter/foundation.dart';

enum AppStorePlatform { android, ios, other }

enum AppUpdateStatus { allowed, required }

class AppUpdateDecision {
  const AppUpdateDecision({
    required this.status,
    this.storeUrl,
    this.unenforceableBecauseMissingStoreUrl = false,
  });

  static const allowed = AppUpdateDecision(status: AppUpdateStatus.allowed);

  final AppUpdateStatus status;
  final Uri? storeUrl;
  final bool unenforceableBecauseMissingStoreUrl;

  bool get isRequired => status == AppUpdateStatus.required;
}

AppStorePlatform appStorePlatformFor(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android => AppStorePlatform.android,
    TargetPlatform.iOS => AppStorePlatform.ios,
    _ => AppStorePlatform.other,
  };
}

Uri? httpsStoreUri(String? value) {
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}

AppUpdateDecision resolveAppUpdate({
  required int? installedBuild,
  required AppStorePlatform platform,
  required int minAndroidBuild,
  required int minIosBuild,
  String? androidStoreUrl,
  String? iosStoreUrl,
}) {
  if (installedBuild == null || platform == AppStorePlatform.other) {
    return AppUpdateDecision.allowed;
  }

  final minBuild = switch (platform) {
    AppStorePlatform.android => minAndroidBuild,
    AppStorePlatform.ios => minIosBuild,
    AppStorePlatform.other => 0,
  };
  final rawStoreUrl = switch (platform) {
    AppStorePlatform.android => androidStoreUrl,
    AppStorePlatform.ios => iosStoreUrl,
    AppStorePlatform.other => null,
  };
  final storeUrl = httpsStoreUri(rawStoreUrl);

  if (installedBuild >= minBuild) {
    return AppUpdateDecision.allowed;
  }

  if (storeUrl == null) {
    return const AppUpdateDecision(
      status: AppUpdateStatus.allowed,
      unenforceableBecauseMissingStoreUrl: true,
    );
  }

  return AppUpdateDecision(
    status: AppUpdateStatus.required,
    storeUrl: storeUrl,
  );
}
