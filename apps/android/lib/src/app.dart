import 'package:flutter/material.dart';
import 'package:soup/src/features/connectivity/connectivity_screen.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

class SoupApp extends StatefulWidget {
  const SoupApp({required this.tailscaleClient, super.key});

  final TailscaleClient tailscaleClient;

  @override
  State<SoupApp> createState() => _SoupAppState();
}

class _SoupAppState extends State<SoupApp> {
  late final ConnectivityViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ConnectivityViewModel(widget.tailscaleClient)..initialize();
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
      home: ConnectivityScreen(viewModel: _viewModel),
    );
  }
}
