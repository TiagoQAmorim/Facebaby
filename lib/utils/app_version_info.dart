import 'package:package_info_plus/package_info_plus.dart';

/// Versão instalada (nome + código de build do `pubspec.yaml`).
class AppVersionInfo {
  const AppVersionInfo({
    required this.version,
    required this.buildNumber,
    required this.packageName,
    required this.appName,
  });

  final String version;
  final String buildNumber;
  final String packageName;
  final String appName;

  /// Ex.: `version: 1.0.32(165)`
  String get displayLine => 'version: $version($buildNumber)';

  String get fullDetailText => [
    displayLine,
    'build: $buildNumber',
    'package: $packageName',
    'app: $appName',
  ].join('\n');

  static Future<AppVersionInfo> load() async {
    final info = await PackageInfo.fromPlatform();
    return AppVersionInfo(
      version: info.version,
      buildNumber: info.buildNumber,
      packageName: info.packageName,
      appName: info.appName,
    );
  }
}
