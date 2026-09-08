import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'connectivity_fakes.dart';

/// Protocol fixture only; real Jellyfin acceptance is recorded separately.
class QuickConnectFixture {
  bool enabled = true;
  bool approved = false;
  int initiations = 0;
  int polls = 0;
  int exchanges = 0;
  int? pollStatus;
  Completer<http.Response>? pendingPoll;
  Completer<http.Response>? pendingInitiation;
  Completer<http.Response>? pendingExchange;
  late final factory = FakeJellyfinClientFactory(respond: respond);
  http.Response state({bool? authenticated}) => http.Response(
    jsonEncode({
      'Authenticated': authenticated ?? approved,
      'Code': initiations == 1 ? '123456' : '654321',
      'Secret': 'test-secret-$initiations',
    }),
    200,
  );
  static http.Response session() => http.Response(
    '{"AccessToken":"test-token","ServerId":"server-1","User":{"Id":"user-quick","Name":"Quick user"}}',
    200,
  );
  FutureOr<http.Response> respond(http.Request request) {
    if (request.url.path.endsWith('/QuickConnect/Enabled')) {
      return http.Response('$enabled', 200);
    }
    if (request.url.path.endsWith('/QuickConnect/Initiate')) {
      initiations++;
      return pendingInitiation?.future ?? state();
    }
    if (request.url.path.endsWith('/QuickConnect/Connect')) {
      polls++;
      return pendingPoll?.future ??
          (pollStatus == null
              ? state()
              : http.Response('private test-secret', pollStatus!));
    }
    if (request.url.path.endsWith('/Users/AuthenticateWithQuickConnect')) {
      exchanges++;
      return pendingExchange?.future ?? session();
    }
    return FakeJellyfinClientFactory.defaultResponse(request);
  }
}
