import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soup/src/data/appearance/appearance_store.dart';
import 'package:soup/src/data/artwork/artwork_cache.dart';
import 'package:soup/src/data/cache/soup_database.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/jellyfin/jellyfin_discovery.dart';
import 'package:soup/src/data/jellyfin/jellyfin_metadata_repository.dart';
import 'package:soup/src/data/session/session_store.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup/src/data/soup/soup_identity_flags.dart';
import 'package:soup/src/data/soup/soup_session_store.dart';
import 'package:soup/src/features/connectivity/connectivity_screen.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/features/appearance/appearance_controller.dart';
import 'package:soup/src/features/appearance/appearance_screen.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/details/details_screen.dart';
import 'package:soup/src/features/library/library_screen.dart';
import 'package:soup/src/features/playback/playback_screen.dart';
import 'package:soup/src/features/shared/app_status_screen.dart';
import 'package:soup/src/features/soup_auth/soup_device_link_screen.dart';
import 'package:soup/src/features/soup_auth/soup_device_link_view_model.dart';
import 'package:soup_identity/soup_identity.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

class SoupApp extends StatefulWidget {
  const SoupApp({
    required this.tailscaleClient,
    this.jellyfinClientFactory = const DefaultJellyfinClientFactory(),
    this.sessionStore = const SecureSessionStore(),
    this.soupSessionStore = const SecureSoupSessionStore(),
    this.soupIdentityFlags = SoupIdentityFlags.fromEnvironment,
    this.soupIdentityClient,
    this.connectionStore,
    this.appearanceStore,
    this.database,
    this.discoveryService,
    super.key,
  });

  final TailscaleClient tailscaleClient;
  final JellyfinClientFactory jellyfinClientFactory;
  final SessionStore sessionStore;
  final SoupSessionStore soupSessionStore;
  final SoupIdentityFlags soupIdentityFlags;
  final SoupIdentityClient? soupIdentityClient;
  final ConnectionPreferencesStore? connectionStore;
  final AppearanceStore? appearanceStore;
  final SoupDatabase? database;
  final JellyfinDiscoveryService? discoveryService;

  @override
  State<SoupApp> createState() => _SoupAppState();
}

class _SoupAppState extends State<SoupApp> {
  late final ConnectivityViewModel _viewModel;
  late final AppearanceController _appearanceController;
  SoupDeviceLinkViewModel? _soupAuth;
  SoupDatabase? _database;
  late final bool _ownsDatabase;
  Object? _navigationIdentity;
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _adoptedSoupTransport = false;
  bool _adoptedSoupJellyfin = false;

  @override
  void initState() {
    super.initState();
    _database = widget.database;
    _ownsDatabase = widget.database == null;
    _viewModel = ConnectivityViewModel(
      widget.tailscaleClient,
      jellyfinClientFactory: widget.jellyfinClientFactory,
      sessionStore: widget.sessionStore,
      connectionStore:
          widget.connectionStore ?? SharedPreferencesConnectionStore(),
      discoveryService: widget.discoveryService,
    )..initialize();
    _appearanceController = AppearanceController(
      widget.appearanceStore ?? SharedPreferencesAppearanceStore(),
    )..initialize();
    if (widget.soupIdentityFlags.enabled) {
      final client =
          widget.soupIdentityClient ??
          (widget.soupIdentityFlags.useMock
              ? MockSoupIdentityClient()
              : HttpSoupIdentityClient(
                  baseUrl: widget.soupIdentityFlags.baseUri,
                ));
      _soupAuth = SoupDeviceLinkViewModel(
        client: client,
        sessionStore: widget.soupSessionStore,
        jellyfinSessionStore: widget.sessionStore,
        jellyfinApiProvider: () => _viewModel.authenticatedApi(),
        tailscaleClient: widget.tailscaleClient,
        connectTransportGrants:
            widget.soupIdentityFlags.connectTransportGrants,
      )..initialize();
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _appearanceController.dispose();
    _soupAuth?.dispose();
    final database = _database;
    if (_ownsDatabase && database != null) unawaited(database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soupAuth = _soupAuth;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _viewModel,
        _appearanceController,
        ?soupAuth,
      ]),
      builder: (context, _) {
        final session = _viewModel.session;
        final authenticated =
            _viewModel.phase == SetupPhase.ready && session != null;
        final appearance = _appearanceController.settings;
        // Routes and their API clients belong to one account and transport.
        // Remove detail/player routes when that transport is replaced.
        final identity = authenticated
            ? (session.serverId, session.userId, _viewModel.transportRevision)
            : null;
        if (identity != _navigationIdentity) {
          _navigationIdentity = identity;
          _navigatorKey = GlobalKey<NavigatorState>();
        }
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Soup',
          debugShowCheckedModeBanner: false,
          theme: session != null && appearance != null
              ? SoupTheme.authenticated(appearance)
              : SoupTheme.onboarding,
          home: Builder(
            builder: (context) {
              if (!_viewModel.initialized ||
                  !_appearanceController.initialized ||
                  (soupAuth != null && !soupAuth.initialized)) {
                final error =
                    _viewModel.initializationError ??
                    _appearanceController.loadError ??
                    soupAuth?.error;
                return AppStatusScreen(
                  title: error == null
                      ? 'Opening Soup'
                      : 'Let’s try that again',
                  message: error ?? 'Loading your saved setup…',
                  busy: error == null,
                  onRetry: error == null
                      ? null
                      : () {
                          _viewModel.initialize();
                          _appearanceController.initialize();
                          unawaited(soupAuth?.initialize());
                        },
                );
              }
              // Wave 3: Soup Identity gate beside legacy onboarding.
              if (soupAuth != null && soupAuth.showsAuthShell) {
                return SoupDeviceLinkScreen(viewModel: soupAuth);
              }
              if (soupAuth != null &&
                  soupAuth.transportConnected &&
                  !_adoptedSoupTransport &&
                  _viewModel.initialized) {
                _adoptedSoupTransport = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  unawaited(_viewModel.adoptSoupAuthKeyTransport());
                });
              }
              final soupJellyfin = soupAuth?.jellyfinSession;
              if (soupAuth != null &&
                  soupJellyfin != null &&
                  !_adoptedSoupJellyfin &&
                  _viewModel.initialized) {
                _adoptedSoupJellyfin = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  unawaited(
                    _viewModel.adoptSoupJellyfinSession(soupJellyfin),
                  );
                });
              }
              if (soupAuth != null && soupJellyfin != null && session == null) {
                return const AppStatusScreen(
                  title: 'Opening Soup',
                  message: 'Finishing your Jellyfin sign-in…',
                  busy: true,
                );
              }
              if (session != null && !authenticated) {
                final status = _viewModel.status;
                final waitingForLogin = status.authorizationUrl != null;
                return AppStatusScreen(
                  title: 'Reconnecting to Tailscale',
                  message: waitingForLogin
                      ? 'Scan to reconnect. Your Jellyfin sign-in is saved.'
                      : status.phase ==
                            TailscaleConnectionPhase.awaitingApproval
                      ? 'Approve this device in Tailscale. Your Jellyfin sign-in is saved.'
                      : _viewModel.connecting
                      ? 'Your server and sign-in are saved. We’ll open your library as soon as you’re connected.'
                      : 'Your server and sign-in are saved. Check your connection, then try again.',
                  busy: _viewModel.connecting,
                  authorizationUrl: status.authorizationUrl,
                  onRetry: _viewModel.connecting
                      ? null
                      : _viewModel.reconnectSession,
                );
              }
              if (authenticated) {
                if (appearance == null) {
                  return AppearanceScreen(
                    initialSettings: _appearanceController.effectiveSettings,
                    saving: _appearanceController.saving,
                    error: _appearanceController.error,
                    onContinue: _appearanceController.save,
                  );
                }
                return _AuthenticatedHome(
                  key: ValueKey('${session.serverId}:${session.userId}'),
                  viewModel: _viewModel,
                  soupAuth: soupAuth,
                  appearanceController: _appearanceController,
                  session: session,
                  database: _database ??= SoupDatabase(),
                  onSignOut: () async {
                    await _viewModel.signOut();
                    await soupAuth?.clearSession();
                    _adoptedSoupTransport = false;
                    _adoptedSoupJellyfin = false;
                  },
                );
              }
              return ConnectivityScreen(viewModel: _viewModel);
            },
          ),
        );
      },
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome({
    required this.viewModel,
    required this.session,
    required this.appearanceController,
    required this.database,
    required this.onSignOut,
    this.soupAuth,
    super.key,
  });

  final ConnectivityViewModel viewModel;
  final SoupDeviceLinkViewModel? soupAuth;
  final JellyfinSession session;
  final AppearanceController appearanceController;
  final SoupDatabase database;
  final Future<void> Function() onSignOut;

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  late Future<_AuthenticatedDependencies> _dependencies = _loadDependencies();
  _AuthenticatedDependencies? _resolvedDependencies;
  late JellyfinSession _session = widget.session;

  Future<_AuthenticatedDependencies> _loadDependencies() async {
    var session = widget.session;
    final soupAuth = widget.soupAuth;
    if (soupAuth != null && soupAuth.performJellyfinExchange) {
      try {
        final ok = await soupAuth.ensureJellyfinSessionValid();
        if (!ok) {
          throw const JellyfinApiException(
            'Your Soup sign-in expired. Sign in with Google again.',
            statusCode: 401,
          );
        }
        session = soupAuth.jellyfinSession ?? session;
        if (!identical(session, widget.viewModel.session) &&
            soupAuth.jellyfinSession != null) {
          await widget.viewModel.adoptSoupJellyfinSession(
            soupAuth.jellyfinSession!,
          );
          session = soupAuth.jellyfinSession!;
        }
      } on JellyfinApiException {
        rethrow;
      }
    }
    _session = session;
    final api = await widget.viewModel.authenticatedApi();
    final dependencies = _AuthenticatedDependencies(
      api: api,
      metadataRepository: DriftJellyfinMetadataRepository(
        database: widget.database,
        librarySource: api,
        detailsSource: api,
        session: session,
      ),
      artworkRepository: ArtworkCache(
        database: widget.database,
        networkSource: api,
        session: session,
      ),
    );
    if (!mounted) {
      await dependencies.metadataRepository.close();
      return dependencies;
    }
    _resolvedDependencies = dependencies;
    return dependencies;
  }

  @override
  void dispose() {
    final dependencies = _resolvedDependencies;
    if (dependencies != null) {
      unawaited(dependencies.metadataRepository.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _dependencies,
      builder: (context, snapshot) {
        final dependencies = snapshot.data;
        if (dependencies != null) {
          final api = dependencies.api;
          return LibraryScreen(
            source: api,
            metadataRepository: dependencies.metadataRepository,
            artworkRepository: dependencies.artworkRepository,
            session: _session,
            onSignOut: widget.onSignOut,
            appearance: widget.appearanceController.effectiveSettings,
            onSaveAppearance: widget.appearanceController.save,
            onOpenItem: (item) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DetailsScreen(
                    source: api,
                    artworkSource: api,
                    metadataRepository: dependencies.metadataRepository,
                    artworkRepository: dependencies.artworkRepository,
                    session: _session,
                    item: item,
                    onPlay: (item, startAt) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PlaybackScreen(
                            api: api,
                            session: _session,
                            item: item,
                            startAt: startAt,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          final expired =
              error is JellyfinApiException && error.statusCode == 401;
          return AppStatusScreen(
            title: expired
                ? 'Soup sign-in needed'
                : 'Could not open your library',
            message: expired
                ? 'Your Soup session expired. Sign in with Google again.'
                : 'Your sign-in is saved. Please try again.',
            onRetry: () {
              if (expired) {
                unawaited(widget.onSignOut());
                return;
              }
              setState(() {
                _dependencies = _loadDependencies();
              });
            },
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class _AuthenticatedDependencies {
  const _AuthenticatedDependencies({
    required this.api,
    required this.metadataRepository,
    required this.artworkRepository,
  });

  final JellyfinApi api;
  final DriftJellyfinMetadataRepository metadataRepository;
  final ArtworkCache artworkRepository;
}
