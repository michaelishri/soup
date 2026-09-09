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
import 'package:soup/src/features/connectivity/connectivity_screen.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/features/appearance/appearance_controller.dart';
import 'package:soup/src/features/appearance/appearance_screen.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/details/details_screen.dart';
import 'package:soup/src/features/library/library_screen.dart';
import 'package:soup/src/features/playback/playback_screen.dart';
import 'package:soup/src/features/shared/app_status_screen.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

class SoupApp extends StatefulWidget {
  const SoupApp({
    required this.tailscaleClient,
    this.jellyfinClientFactory = const DefaultJellyfinClientFactory(),
    this.sessionStore = const SecureSessionStore(),
    this.connectionStore,
    this.appearanceStore,
    this.database,
    this.discoveryService,
    super.key,
  });

  final TailscaleClient tailscaleClient;
  final JellyfinClientFactory jellyfinClientFactory;
  final SessionStore sessionStore;
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
  SoupDatabase? _database;
  late final bool _ownsDatabase;
  Object? _navigationIdentity;
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _appearanceController.dispose();
    final database = _database;
    if (_ownsDatabase && database != null) unawaited(database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_viewModel, _appearanceController]),
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
                  !_appearanceController.initialized) {
                final error =
                    _viewModel.initializationError ??
                    _appearanceController.loadError;
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
                        },
                );
              }
              if (session != null && !authenticated) {
                final status = _viewModel.status;
                final waitingForLogin = status.authorizationUrl != null;
                return AppStatusScreen(
                  title: 'Reconnecting to Tailscale',
                  message: waitingForLogin
                      ? 'Sign in to Tailscale to reconnect. Your Jellyfin sign-in is saved.'
                      : status.phase ==
                            TailscaleConnectionPhase.awaitingApproval
                      ? 'Approve this device in Tailscale. Your Jellyfin sign-in is saved.'
                      : _viewModel.connecting
                      ? 'Your server and sign-in are saved. We’ll open your library as soon as you’re connected.'
                      : 'Your server and sign-in are saved. Check your connection, then try again.',
                  busy: _viewModel.connecting,
                  authorizationUrl: status.authorizationUrl,
                  authorizationController: _viewModel.authorization,
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
                  appearanceController: _appearanceController,
                  session: session,
                  database: _database ??= SoupDatabase(),
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
    super.key,
  });

  final ConnectivityViewModel viewModel;
  final JellyfinSession session;
  final AppearanceController appearanceController;
  final SoupDatabase database;

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  late Future<_AuthenticatedDependencies> _dependencies = _loadDependencies();
  _AuthenticatedDependencies? _resolvedDependencies;

  Future<_AuthenticatedDependencies> _loadDependencies() async {
    final api = await widget.viewModel.authenticatedApi();
    final dependencies = _AuthenticatedDependencies(
      api: api,
      metadataRepository: DriftJellyfinMetadataRepository(
        database: widget.database,
        librarySource: api,
        detailsSource: api,
        session: widget.session,
      ),
      artworkRepository: ArtworkCache(
        database: widget.database,
        networkSource: api,
        session: widget.session,
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
            session: widget.session,
            onSignOut: widget.viewModel.signOut,
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
                    session: widget.session,
                    item: item,
                    onPlay: (item, startAt) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PlaybackScreen(
                            api: api,
                            session: widget.session,
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
          return AppStatusScreen(
            title: 'Could not open your library',
            message: 'Your sign-in is saved. Please try again.',
            onRetry: () => setState(() {
              _dependencies = _loadDependencies();
            }),
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
