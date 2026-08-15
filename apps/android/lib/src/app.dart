import 'package:flutter/material.dart';
import 'package:soup/src/data/appearance/appearance_store.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
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
    super.key,
  });

  final TailscaleClient tailscaleClient;
  final JellyfinClientFactory jellyfinClientFactory;
  final SessionStore sessionStore;
  final AppearanceStore? appearanceStore;

  @override
  State<SoupApp> createState() => _SoupAppState();
}

class _SoupAppState extends State<SoupApp> {
  late final ConnectivityViewModel _viewModel;
  late final AppearanceController _appearanceController;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soup',
      debugShowCheckedModeBanner: false,
      theme: SoupTheme.onboarding,
      home: ListenableBuilder(
        listenable: Listenable.merge([_viewModel, _appearanceController]),
        builder: (context, _) {
          if (!_appearanceController.initialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final session = _viewModel.session;
          if (_viewModel.phase == SetupPhase.ready && session != null) {
            final appearance = _appearanceController.settings;
            if (appearance == null) {
              return AppearanceScreen(
                initialSettings: _appearanceController.effectiveSettings,
                saving: _appearanceController.saving,
                error: _appearanceController.error,
                onContinue: _appearanceController.save,
              );
            }
            return Theme(
              data: SoupTheme.authenticated(appearance),
              child: _AuthenticatedHome(
                key: ValueKey('${session.serverId}:${session.userId}'),
                viewModel: _viewModel,
                session: session,
              ),
            );
          }
          return ConnectivityScreen(viewModel: _viewModel);
        },
      ),
    );
  }
}

class _AuthenticatedHome extends StatelessWidget {
  const _AuthenticatedHome({
    required this.viewModel,
    required this.session,
    super.key,
  });

  final ConnectivityViewModel viewModel;
  final JellyfinSession session;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: viewModel.authenticatedApi(),
      builder: (context, snapshot) {
        final api = snapshot.data;
        if (api != null) {
          return LibraryScreen(
            source: api,
            session: session,
            onSignOut: viewModel.signOut,
            onOpenItem: (item) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DetailsScreen(
                    source: api,
                    artworkSource: api,
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
