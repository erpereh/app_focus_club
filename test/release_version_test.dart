import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Highest build number already published in Google Play and the App Store
/// (`site_config/main` has minAndroidBuild = minIosBuild = 14). Update it
/// after each store release; see docs/production-release-checklist.md.
const _lastPublishedBuild = 14;
const _lastPublishedVersion = [1, 4, 4];

void main() {
  test('pubspec version is newer than the last published store build', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml needs version: x.y.z+n');

    final version = [1, 2, 3].map((i) => int.parse(match!.group(i)!)).toList();
    final build = int.parse(match!.group(4)!);

    // Android versionCode and iOS CFBundleVersion must always increase.
    expect(build, greaterThan(_lastPublishedBuild));

    // iOS rejects a CFBundleShortVersionString that was already released.
    var newer = false;
    for (var i = 0; i < 3 && !newer; i += 1) {
      if (version[i] != _lastPublishedVersion[i]) {
        expect(version[i], greaterThan(_lastPublishedVersion[i]));
        newer = true;
      }
    }
    expect(newer, isTrue, reason: 'version name must be newer than 1.4.4');
  });
}
