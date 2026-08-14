import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:socks5_proxy/socks_client.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

abstract interface class JellyfinClientFactory {
  http.Client create(TailscaleProxy proxy);
}

class SocksJellyfinClientFactory implements JellyfinClientFactory {
  const SocksJellyfinClientFactory({
    this.securityContext,
    this.badCertificateCallback,
  });

  final SecurityContext? securityContext;
  final bool Function(X509Certificate certificate)? badCertificateCallback;

  @override
  http.Client create(TailscaleProxy proxy) {
    final ioClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    SocksTCPClient.assignToHttpClientWithSecureOptions(
      ioClient,
      [
        ProxySettings(
          InternetAddress(proxy.host),
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
