import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

class ConnectivityViewModel extends ChangeNotifier {
  ConnectivityViewModel(this._client);

  final TailscaleClient _client;
  StreamSubscription<TailscaleStatus>? _statusSubscription;

  TailscaleStatus _status = const TailscaleStatus.disconnected();
  TailscaleStatus get status => _status;

  bool get isBusy => _status.phase == TailscaleConnectionPhase.connecting;

  Future<void> initialize() async {
    _statusSubscription = _client.statuses.listen(_setStatus);
    _setStatus(await _client.currentStatus());
  }

  Future<void> connect(String authKey) async {
    final trimmedKey = authKey.trim();
    if (trimmedKey.isEmpty || isBusy) return;

    _setStatus(const TailscaleStatus.connecting());
    try {
      await _client.connect(authKey: trimmedKey);
      _setStatus(await _client.currentStatus());
    } on Object catch (error) {
      _setStatus(TailscaleStatus.failed(error.toString()));
    }
  }

  void _setStatus(TailscaleStatus value) {
    _status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}
