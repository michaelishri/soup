import 'dart:async';

import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_discovery.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

DiscoveredJellyfinServer discoveryServer([
  int index = 1,
  String version = '10.11.2',
]) => DiscoveredJellyfinServer(
  info: JellyfinServerInfo(
    id: 'server-$index',
    name: index == 1 ? 'Cinema Club' : 'Library $index',
    version: version,
  ),
  url: Uri.parse('https://cinema$index.example.ts.net/'),
  sources: const {DiscoverySource.tailscale},
  rank: 0,
);

class FakeDiscoveryService implements JellyfinDiscoveryService {
  FakeDiscoveryService({this.initial});
  JellyfinDiscoverySnapshot? initial;
  final runs = <FakeDiscoveryRun>[];
  final modes = <ConnectionMode>[];
  @override
  JellyfinDiscoveryRun start(ConnectionMode mode, TailscaleProxy? proxy) {
    modes.add(mode);
    final run = FakeDiscoveryRun();
    runs.add(run);
    if (initial case final value?) scheduleMicrotask(() => run.emit(value));
    return run;
  }

  void dispose() {
    for (final run in runs) {
      run.cancel();
    }
  }
}

class FakeDiscoveryRun implements JellyfinDiscoveryRun {
  final events = StreamController<JellyfinDiscoverySnapshot>();
  bool cancelled = false;
  @override
  Stream<JellyfinDiscoverySnapshot> get snapshots => events.stream;
  void emit(JellyfinDiscoverySnapshot value) {
    if (!cancelled) events.add(value);
  }

  @override
  void cancel() {
    if (!cancelled) {
      cancelled = true;
      unawaited(events.close());
    }
  }
}
