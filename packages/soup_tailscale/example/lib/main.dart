import 'package:flutter/material.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = UnavailableTailscaleClient();
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: FutureBuilder<TailscaleStatus>(
            future: client.currentStatus(),
            builder: (context, snapshot) {
              return Text(
                'Tailscale phase: ${snapshot.data?.phase.name ?? 'loading'}',
              );
            },
          ),
        ),
      ),
    );
  }
}
