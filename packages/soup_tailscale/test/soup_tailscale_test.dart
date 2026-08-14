import 'package:soup_tailscale/soup_tailscale.dart';
import 'package:test/test.dart';

void main() {
  test('unavailable adapter reports disconnected', () {
    final client = UnavailableTailscaleClient();

    expect(client.status.phase, TailscaleConnectionPhase.disconnected);
  });

  test('unavailable adapter fails clearly when connection is attempted', () {
    final client = UnavailableTailscaleClient();

    expect(
      client.connect(authKey: 'tskey-auth-example'),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('parses the authenticated loopback proxy', () {
    final proxy = TailscaleProxy.parse('127.0.0.1:32145', 'secret');

    expect(proxy.host, '127.0.0.1');
    expect(proxy.port, 32145);
    expect(proxy.password, 'secret');
    expect(TailscaleProxy.username, 'tsnet');
  });
}
