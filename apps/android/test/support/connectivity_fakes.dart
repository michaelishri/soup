import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup/src/data/session/session_store.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

class MemorySessionStore implements SessionStore {
  MemorySessionStore([this.session]);
  JellyfinSession? session;
  @override
  Future<void> clear() async => session = null;
  @override
  Future<String> deviceId() async => 'device-1';
  @override
  Future<JellyfinSession?> read() async => session;
  @override
  Future<void> write(JellyfinSession value) async => session = value;
}

final testSession = JellyfinSession(
  serverUrl: Uri.parse('http://jellyfin:8096'),
  serverId: 'server-1',
  userId: 'user-1',
  userName: 'Michael',
  accessToken: 'token',
);

class FakeJellyfinClientFactory implements JellyfinClientFactory {
  FakeJellyfinClientFactory({this.respond});
  final FutureOr<http.Response> Function(http.Request)? respond;
  final modes = <ConnectionMode>[];
  final requests = <http.Request>[];
  int closed = 0;

  @override
  http.Client create({required ConnectionMode mode, TailscaleProxy? proxy}) {
    if (mode == ConnectionMode.tailscale && proxy == null) {
      throw StateError('missing proxy');
    }
    modes.add(mode);
    return _TrackedClient((request) async {
      requests.add(request);
      return respond == null
          ? defaultResponse(request)
          : await respond!(request);
    }, () => closed++);
  }

  static http.Response defaultResponse(http.Request request) {
    if (request.url.path.endsWith('/System/Info/Public')) {
      return http.Response(
        '{"ServerName":"Living Room","Version":"10.11.2","Id":"server-1"}',
        200,
      );
    }
    if (request.url.path.endsWith('/Users/AuthenticateByName')) {
      return http.Response(
        '{"AccessToken":"token","ServerId":"server-1","User":{"Id":"user-1","Name":"Michael"}}',
        200,
      );
    }
    if (request.url.path.endsWith('/Items/Latest')) {
      return http.Response('[]', 200);
    }
    return http.Response('{"Items":[]}', 200);
  }
}

class _TrackedClient extends MockClient {
  _TrackedClient(super.fn, this.onClose);
  final void Function() onClose;
  bool closed = false;
  @override
  void close() {
    if (!closed) onClose();
    closed = true;
    super.close();
  }
}

class FakeTailscaleClient implements TailscaleClient {
  final _statuses = StreamController<TailscaleStatus>.broadcast(sync: true);
  TailscaleStatus _status = const TailscaleStatus.disconnected();
  int restores = 0;
  int interactiveConnects = 0;
  int disconnects = 0;
  bool restoreConnected = false;
  bool immediateConnect = false;
  bool delayCancellation = false;
  bool preparing = false;
  Object? connectError;
  Completer<void>? _pending;
  @override
  Stream<TailscaleStatus> get statuses => _statuses.stream;
  @override
  TailscaleStatus get status => _status;
  @override
  Future<void> restore() async {
    restores++;
    if (restoreConnected) emit(connectedStatus);
  }

  @override
  Future<void> connectInteractively() async {
    interactiveConnects++;
    if (connectError case final error?) throw error;
    if (immediateConnect) {
      emit(connectedStatus);
      return;
    }
    _pending = Completer<void>();
    if (preparing) {
      emit(const TailscaleStatus.starting());
    } else {
      showQr();
    }
    await _pending!.future;
  }

  void showQr() => emit(
    TailscaleStatus.awaitingLogin(
      Uri.parse('https://login.tailscale.com/a/soup-test-$interactiveConnects'),
    ),
  );
  void complete() {
    emit(connectedStatus);
    finishPending();
  }

  void finishPending() {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  @override
  Future<void> connectWithAuthKey({required String authKey}) =>
      throw StateError('Auth keys must not be used by onboarding');
  @override
  Future<void> disconnect() async {
    disconnects++;
    if (!delayCancellation) finishPending();
    emit(const TailscaleStatus.disconnected());
  }

  void emit(TailscaleStatus value) {
    _status = value;
    if (!_statuses.isClosed) _statuses.add(value);
  }

  static const connectedStatus = TailscaleStatus.connected(
    hostname: 'soup-test',
    tailnetIp: '100.64.0.1',
    proxy: TailscaleProxy(host: '127.0.0.1', port: 32145, password: 'secret'),
  );
  void dispose() {
    finishPending();
    _statuses.close();
  }
}
