import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';

class AndroidNetworkInterfaces {
  const AndroidNetworkInterfaces();

  static const _channel = MethodChannel(
    'dev.michaelishri.soup/network_interfaces',
  );

  Future<String> getJson() async {
    return await _channel.invokeMethod<String>('getNetworkInterfaces') ?? '[]';
  }

  Future<List<({InternetAddress address, InternetAddress broadcast})>>
  broadcasts() async {
    final json = jsonDecode(await getJson());
    if (json is! List) return const [];
    final result = <({InternetAddress address, InternetAddress broadcast})>[];
    for (final interface in json.whereType<Map>()) {
      if (interface['up'] != true ||
          interface['loopback'] == true ||
          interface['pointToPoint'] == true) {
        continue;
      }
      final addresses = interface['addrs'];
      if (addresses is! List) continue;
      for (final entry in addresses.whereType<Map>()) {
        final address = InternetAddress.tryParse(entry['ip']?.toString() ?? '');
        final broadcast = InternetAddress.tryParse(
          entry['broadcastAddress']?.toString() ?? '',
        );
        if (address?.type == InternetAddressType.IPv4 && broadcast != null) {
          result.add((address: address!, broadcast: broadcast));
        }
      }
    }
    return result;
  }
}
