import 'package:flutter/widgets.dart';
import 'package:soup/src/app.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SoupApp(tailscaleClient: UnavailableTailscaleClient()));
}
