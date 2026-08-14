import 'package:flutter/services.dart';

class AndroidNetworkInterfaces {
  const AndroidNetworkInterfaces();

  static const _channel = MethodChannel(
    'dev.michaelishri.soup/network_interfaces',
  );

  Future<String> getJson() async {
    return await _channel.invokeMethod<String>('getNetworkInterfaces') ?? '[]';
  }
}
