import 'package:package_info_plus/package_info_plus.dart';

abstract class InstalledAppBuildReader {
  Future<int?> readBuildNumber();
}

class PackageInfoInstalledAppBuildReader implements InstalledAppBuildReader {
  const PackageInfoInstalledAppBuildReader();

  @override
  Future<int?> readBuildNumber() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber.trim());
    } catch (_) {
      return null;
    }
  }
}
