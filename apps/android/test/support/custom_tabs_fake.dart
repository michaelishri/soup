import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the production adapter through the plugin's platform channel.
class FakeCustomTabs {
  static const returnChannel = MethodChannel(
    'dev.michaelishri.soup/browser_return',
  );
  static const channel = MethodChannel(
    'plugins.flutter.droibit.github.io/custom_tabs',
  );
  final calls = <MethodCall>[];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(returnChannel, (call) async {
          calls.add(call);
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(returnChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }

  List<String> get launches => calls
      .where((call) => call.method == 'launch')
      .map((call) => (call.arguments as Map)['url'] as String)
      .toList();
  int get closes => calls.where((call) => call.method == 'returnToSoup').length;
}
