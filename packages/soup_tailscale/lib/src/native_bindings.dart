import 'dart:ffi';

import 'package:ffi/ffi.dart';

const _assetId = 'package:soup_tailscale/libtailscale.dart';

@Native<Int32 Function(Pointer<Utf8>)>(
  symbol: 'SoupSetInterfaces',
  assetId: _assetId,
)
external int tailscaleSetInterfaces(Pointer<Utf8> interfacesJson);

@Native<Int32 Function(Pointer<Utf8>)>(
  symbol: 'SoupSetLogsDirectory',
  assetId: _assetId,
)
external int tailscaleSetLogsDirectory(Pointer<Utf8> directory);

@Native<Int32 Function()>(symbol: 'tailscale_new', assetId: _assetId)
external int tailscaleNew();

@Native<Int32 Function(Int32)>(symbol: 'tailscale_up', assetId: _assetId)
external int tailscaleUp(int server);

@Native<Int32 Function(Int32)>(symbol: 'tailscale_close', assetId: _assetId)
external int tailscaleClose(int server);

@Native<Int32 Function(Int32, Pointer<Utf8>)>(
  symbol: 'tailscale_set_dir',
  assetId: _assetId,
)
external int tailscaleSetDirectory(int server, Pointer<Utf8> directory);

@Native<Int32 Function(Int32, Pointer<Utf8>)>(
  symbol: 'tailscale_set_hostname',
  assetId: _assetId,
)
external int tailscaleSetHostname(int server, Pointer<Utf8> hostname);

@Native<Int32 Function(Int32, Pointer<Utf8>)>(
  symbol: 'tailscale_set_authkey',
  assetId: _assetId,
)
external int tailscaleSetAuthKey(int server, Pointer<Utf8> authKey);

@Native<Int32 Function(Int32, Int32)>(
  symbol: 'tailscale_set_ephemeral',
  assetId: _assetId,
)
external int tailscaleSetEphemeral(int server, int ephemeral);

@Native<Int32 Function(Int32, Int32)>(
  symbol: 'tailscale_set_logfd',
  assetId: _assetId,
)
external int tailscaleSetLogFileDescriptor(int server, int fileDescriptor);

@Native<Int32 Function(Int32, Pointer<Utf8>, Size)>(
  symbol: 'tailscale_getips',
  assetId: _assetId,
)
external int tailscaleGetIps(
  int server,
  Pointer<Utf8> output,
  int outputLength,
);

@Native<
  Int32 Function(Int32, Pointer<Utf8>, Size, Pointer<Utf8>, Pointer<Utf8>)
>(symbol: 'tailscale_loopback', assetId: _assetId)
external int tailscaleLoopback(
  int server,
  Pointer<Utf8> addressOutput,
  int addressLength,
  Pointer<Utf8> proxyCredentialOutput,
  Pointer<Utf8> localApiCredentialOutput,
);

@Native<Int32 Function(Int32, Pointer<Utf8>, Size)>(
  symbol: 'tailscale_errmsg',
  assetId: _assetId,
)
external int tailscaleErrorMessage(
  int server,
  Pointer<Utf8> output,
  int outputLength,
);
