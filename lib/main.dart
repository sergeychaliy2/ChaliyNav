import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'shared/providers/locale_provider.dart';
import 'shared/services/background_tracking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Raise the global image cache ceiling. Default is 1000 entries /
  // ~100 MB, which a single 5000×5000-px forestry scan already
  // exceeds — it gets decoded, flashed onto the screen, then
  // evicted, forcing a full redecode on every repaint (blurry-looking
  // flashes + janky pan/zoom). 500 MB is plenty for a few oversized
  // scan overlays without starving the rest of the app.
  PaintingBinding.instance.imageCache
    ..maximumSize = 2000
    ..maximumSizeBytes = 500 * 1024 * 1024;

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A1410),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Configure background tracking service once on app start.
  // Kill any stale service from a previous run so we don't show a ghost
  // "Трек пишется" notification before the user presses Record.
  await BackgroundTrackingService.configure();
  await BackgroundTrackingService.stop();

  // Pre-load saved locale before the first frame so language persists
  // across sessions without an RU-flash on startup.
  final savedLocale = await loadSavedLocale();

  runApp(
    ProviderScope(
      overrides: [
        initialLocaleProvider.overrideWithValue(savedLocale),
      ],
      child: ChaliyNavApp(),
    ),
  );
}
