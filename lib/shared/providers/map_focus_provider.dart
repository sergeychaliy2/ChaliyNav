import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// One-shot request to focus the map on a specific spot. MapScreen listens to
/// changes and animates the camera, then resets the state back to null.
/// Use for "show on map" actions from list screens.
class FocusRequest {
  const FocusRequest({required this.target, this.zoom = 16});
  final LatLng target;
  final double zoom;
}

final mapFocusRequestProvider = StateProvider<FocusRequest?>((_) => null);
