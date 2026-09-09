import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class FakeUrlLauncher extends UrlLauncherPlatform {
  final launches = <(String, PreferredLaunchMode)>[];
  Future<bool> Function()? handleLaunch;
  bool customTabsSupported = false;

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async =>
      customTabsSupported;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches.add((url, options.mode));
    return handleLaunch == null ? true : await handleLaunch!();
  }
}
