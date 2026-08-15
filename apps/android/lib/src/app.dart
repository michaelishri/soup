import 'package:flutter/material.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/session/session_store.dart';
import 'package:soup/src/features/connectivity/connectivity_screen.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/features/details/details_screen.dart';
import 'package:soup/src/features/library/library_screen.dart';
import 'package:soup/src/features/playback/playback_screen.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

class SoupApp extends StatefulWidget {
  const SoupApp({
    required this.tailscaleClient,
    this.jellyfinClientFactory = const SocksJellyfinClientFactory(),
    this.sessionStore = const SecureSessionStore(),
    super.key,
  });

  final TailscaleClient tailscaleClient;
  final JellyfinClientFactory jellyfinClientFactory;
  final SessionStore sessionStore;

  @override
  State<SoupApp> createState() => _SoupAppState();
}

class _SoupAppState extends State<SoupApp> {
  late final ConnectivityViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ConnectivityViewModel(
      widget.tailscaleClient,
      jellyfinClientFactory: widget.jellyfinClientFactory,
      sessionStore: widget.sessionStore,
    )..initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soup',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7DD3FC),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF08111F),
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final session = _viewModel.session;
          if (_viewModel.phase == SetupPhase.ready && session != null) {
            return _AuthenticatedHome(
              key: ValueKey('${session.serverId}:${session.userId}'),
              viewModel: _viewModel,
              session: session,
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
