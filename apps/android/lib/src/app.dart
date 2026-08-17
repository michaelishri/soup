import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soup/src/data/appearance/appearance_store.dart';
import 'package:soup/src/data/cache/soup_database.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/jellyfin/jellyfin_metadata_repository.dart';
import 'package:soup/src/data/session/session_store.dart';
import 'package:soup/src/features/connectivity/connectivity_screen.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/features/appearance/appearance_controller.dart';
import 'package:soup/src/features/appearance/appearance_screen.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/details/details_screen.dart';
import 'package:soup/src/features/library/library_screen.dart';
import 'package:soup/src/features/playback/playback_screen.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

class SoupApp extends StatefulWidget {
  const SoupApp({
    required this.tailscaleClient,
    this.jellyfinClientFactory = const SocksJellyfinClientFactory(),
    this.sessionStore = const SecureSessionStore(),
    this.appearanceStore,
    this.database,
    super.key,
  });

  final TailscaleClient tailscaleClient;
  final JellyfinClientFactory jellyfinClientFactory;
  final SessionStore sessionStore;
  final AppearanceStore? appearanceStore;
  final SoupDatabase? database;

  @override
  State<SoupApp> createState() => _SoupAppState();
}

class _SoupAppState extends State<SoupApp> {
  late final ConnectivityViewModel _viewModel;
  late final AppearanceController _appearanceController;
  SoupDatabase? _database;
  late final bool _ownsDatabase;

  @override
  void initState() {
    super.initState();
    _database = widget.database;
    _ownsDatabase = widget.database == null;
    _viewModel = ConnectivityViewModel(
      widget.tailscaleClient,
      jellyfinClientFactory: widget.jellyfinClientFactory,
      sessionStore: widget.sessionStore,
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
        return MaterialApp(
          title: 'Soup',
          debugShowCheckedModeBanner: false,
          theme: authenticated && appearance != null
              ? SoupTheme.authenticated(appearance)
              : SoupTheme.onboarding,
          home: Builder(
            builder: (context) {
              if (!_appearanceController.initialized) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
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

class _AuthenticatedHome extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: viewModel.authenticatedApi(),
      builder: (context, snapshot) {
        final api = snapshot.data;
        if (api != null) {
          final metadataRepository = DriftJellyfinMetadataRepository(
            database: database,
            librarySource: api,
            detailsSource: api,
            session: session,
          );
          return LibraryScreen(
            source: api,
            metadataRepository: metadataRepository,
            session: session,
            onSignOut: viewModel.signOut,
            appearance: appearanceController.effectiveSettings,
            onSaveAppearance: appearanceController.save,
            onOpenItem: (item) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DetailsScreen(
                    source: api,
                    artworkSource: api,
                    metadataRepository: metadataRepository,
                    session: session,
                    item: item,
                    onPlay: (item, startAt) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PlaybackScreen(
                            api: api,
                            session: session,
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
          return Scaffold(
            body: Center(
              child: Text('Could not open your library. ${snapshot.error}'),
            ),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
