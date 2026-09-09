import 'dart:io';

class TailscalePeer {
  const TailscalePeer({
    required this.id,
    required this.hostname,
    required this.addresses,
    this.dnsName,
    this.online = false,
  });
  final String id;
  final String hostname;
  final String? dnsName;
  final List<InternetAddress> addresses;
  final bool online;

  static List<TailscalePeer> parse(Object? value) {
    if (value is! Map) return const [];
    final peers = <TailscalePeer>[];
    for (final entry in value.entries) {
      final data = entry.value;
      if (data is! Map) continue;
      final raw = data['TailscaleIPs'];
      final addresses = raw is List
          ? raw
                .whereType<String>()
                .map(InternetAddress.tryParse)
                .whereType<InternetAddress>()
                .where(
                  (ip) =>
                      !ip.isLoopback &&
                      !ip.isMulticast &&
                      ip.address != '0.0.0.0' &&
                      ip.address != '::',
                )
                .toList()
          : <InternetAddress>[];
      if (addresses.isEmpty) continue;
      final dns = data['DNSName'];
      peers.add(
        TailscalePeer(
          id: entry.key.toString(),
          hostname: data['HostName'] is String
              ? data['HostName'] as String
              : '',
          dnsName: dns is String && dns.isNotEmpty
              ? dns.replaceFirst(RegExp(r'\.$'), '')
              : null,
          addresses: List.unmodifiable(addresses),
          online: data['Online'] == true,
        ),
      );
    }
    peers.sort(
      (a, b) =>
          a.online != b.online ? (a.online ? -1 : 1) : a.id.compareTo(b.id),
    );
    return List.unmodifiable(peers);
  }
}
