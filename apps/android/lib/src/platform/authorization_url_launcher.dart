import 'package:url_launcher/url_launcher.dart';

abstract interface class AuthorizationUrlLauncher {
  Future<bool> open(Uri url);
}

class ExternalAuthorizationUrlLauncher implements AuthorizationUrlLauncher {
  const ExternalAuthorizationUrlLauncher();

  @override
  Future<bool> open(Uri url) {
    if (url.scheme != 'https') return Future.value(false);
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
