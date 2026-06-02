import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/point_of_interest.dart';

/// Currently selected navigation target (a POI the user is navigating to).
/// `null` means navigation is off. Map screen listens to this and shows the
/// arrow / distance HUD / speaks TTS hints.
final navigationTargetProvider = StateProvider<PointOfInterest?>((_) => null);
