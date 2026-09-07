import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:socks5_proxy/socks_client.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

abstract interface class JellyfinClientFactory {
  http.Client create({required ConnectionMode mode, TailscaleProxy? proxy});
}

class DefaultJellyfinClientFactory implements JellyfinClientFactory {
  const DefaultJellyfinClientFactory({
    this.securityContext,
    this.badCertificateCallback,
  });

  final SecurityContext? securityContext;
  final bool Function(X509Certificate certificate)? badCertificateCallback;

  @override
  http.Client create({required ConnectionMode mode, TailscaleProxy? proxy}) {
    if (mode == ConnectionMode.tailscale && proxy == null) {
      throw StateError('A connected Tailscale proxy is required.');
    }
    final ioClient = HttpClient(context: securityContext)
      ..connectionTimeout = const Duration(seconds: 15);
    if (mode == ConnectionMode.direct) return IOClient(ioClient);
    SocksTCPClient.assignToHttpClientWithSecureOptions(
      ioClient,
      [
        ProxySettings(
          InternetAddress(proxy!.host),
          proxy.port,
          username: TailscaleProxy.username,
          password: proxy.password,
        ),
      ],
      context: securityContext,
      onBadCertificate: badCertificateCallback,
    );
    return IOClient(ioClient);
  }
}
