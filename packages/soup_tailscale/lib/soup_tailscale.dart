/// Lifecycle states exposed by Soup's embedded Tailscale node.
enum TailscaleConnectionPhase { disconnected, connecting, connected, failed }

/// Platform-neutral status consumed by the Flutter application.
class TailscaleStatus {
  const TailscaleStatus({
    required this.phase,
    this.hostname,
    this.tailnetIp,
    this.detail,
  });

  const TailscaleStatus.disconnected()
    : this(phase: TailscaleConnectionPhase.disconnected);

  const TailscaleStatus.connecting()
    : this(phase: TailscaleConnectionPhase.connecting);

  const TailscaleStatus.connected({String? hostname, String? tailnetIp})
    : this(
        phase: TailscaleConnectionPhase.connected,
        hostname: hostname,
        tailnetIp: tailnetIp,
      );

  const TailscaleStatus.failed(String detail)
    : this(phase: TailscaleConnectionPhase.failed, detail: detail);

  final TailscaleConnectionPhase phase;
  final String? hostname;
  final String? tailnetIp;
  final String? detail;
}

/// Stable Dart-facing contract for the native libtailscale adapter.
///
/// The production implementation will bind the libtailscale C ABI in this FFI
/// package. Keeping the contract here lets UI and API transport code use fakes
/// without loading a native library during tests.
abstract interface class TailscaleClient {
  Stream<TailscaleStatus> get statuses;

  Future<TailscaleStatus> currentStatus();

  Future<void> connect({required String authKey});

  Future<void> disconnect();
}

/// Development adapter used until the pinned libtailscale binary is packaged.
class UnavailableTailscaleClient implements TailscaleClient {
  static const _status = TailscaleStatus.disconnected();

  @override
  Stream<TailscaleStatus> get statuses => const Stream.empty();

  @override
  Future<TailscaleStatus> currentStatus() async => _status;

  @override
  Future<void> connect({required String authKey}) {
    return Future.error(
      UnsupportedError('The native libtailscale adapter is not linked yet.'),
    );
  }

  @override
  Future<void> disconnect() async {}
}
