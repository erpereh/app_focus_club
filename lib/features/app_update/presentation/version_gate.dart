import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../client/application/portal_scope.dart';
import '../../client/domain/portal_models.dart';
import '../data/installed_app_build_reader.dart';
import '../domain/app_update_decision.dart';
import 'force_update_screen.dart';

class VersionGate extends StatefulWidget {
  const VersionGate({
    required this.child,
    super.key,
    this.buildReader,
    this.platform,
    this.urlLauncher,
  });

  final Widget child;
  final InstalledAppBuildReader? buildReader;
  final AppStorePlatform? platform;
  final Future<bool> Function(Uri)? urlLauncher;

  @override
  State<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends State<VersionGate> {
  StreamSubscription<SiteConfig?>? _subscription;
  int? _installedBuild;
  SiteConfig? _siteConfig;
  bool _loggedMissingStoreUrl = false;

  InstalledAppBuildReader get _buildReader {
    return widget.buildReader ?? const PackageInfoInstalledAppBuildReader();
  }

  AppStorePlatform get _platform {
    return widget.platform ?? appStorePlatformFor(defaultTargetPlatform);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_readInstalledBuild());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscription ??= PortalScope.of(context).watchSiteConfig().listen(
      (config) {
        if (!mounted) return;
        setState(() => _siteConfig = config);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _siteConfig = null);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _readInstalledBuild() async {
    final buildNumber = await _buildReader.readBuildNumber();
    if (!mounted) return;
    setState(() => _installedBuild = buildNumber);
  }

  Future<bool> _openStore(Uri url) {
    final launcher = widget.urlLauncher;
    if (launcher != null) return launcher(url);
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }

  AppUpdateDecision get _decision {
    final config = _siteConfig;
    if (config == null) return AppUpdateDecision.allowed;
    return resolveAppUpdate(
      installedBuild: _installedBuild,
      platform: _platform,
      minAndroidBuild: config.minAndroidBuild,
      minIosBuild: config.minIosBuild,
      androidStoreUrl: config.androidStoreUrl,
      iosStoreUrl: config.iosStoreUrl,
    );
  }

  void _logUnenforceableIfNeeded(AppUpdateDecision decision) {
    if (!decision.unenforceableBecauseMissingStoreUrl ||
        _loggedMissingStoreUrl) {
      return;
    }
    _loggedMissingStoreUrl = true;
    debugPrint(
      'Focus Club: hay una actualizacion obligatoria configurada '
      '(installedBuild=$_installedBuild) pero falta una URL de tienda '
      'https valida. La app no se bloquea.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decision;
    _logUnenforceableIfNeeded(decision);
    if (decision.isRequired && decision.storeUrl != null) {
      return ForceUpdateScreen(
        storeUrl: decision.storeUrl!,
        onOpenStore: _openStore,
      );
    }
    return widget.child;
  }
}
