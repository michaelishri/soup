import 'package:soup_tailscale/soup_tailscale.dart';
import 'package:test/test.dart';

void main() {
  test('unavailable adapter reports disconnected', () async {
    final client = UnavailableTailscaleClient();

    expect(
      (await client.currentStatus()).phase,
      TailscaleConnectionPhase.disconnected,
    );
  });

  test('unavailable adapter fails clearly when connection is attempted', () {
    final client = UnavailableTailscaleClient();

    expect(
      client.connect(authKey: 'tskey-auth-example'),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
