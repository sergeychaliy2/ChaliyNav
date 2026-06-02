import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the set of saved track IDs that should be rendered on the main
/// map. TrackDetailScreen toggles membership when the user taps "Show on
/// map" / "Hide from map". The main MapScreen subscribes via
/// [TracksMapLayer] and draws each track's polyline.
///
/// Kept as a plain StateNotifier over `Set<String>` — visible tracks are
/// ephemeral UI state, not persistent (they reset on app restart).
class VisibleTracksNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  bool contains(String id) => state.contains(id);

  void toggle(String id) {
    state = state.contains(id)
        ? (state.toSet()..remove(id))
        : (state.toSet()..add(id));
  }

  void show(String id) {
    if (state.contains(id)) return;
    state = state.toSet()..add(id);
  }

  void hide(String id) {
    if (!state.contains(id)) return;
    state = state.toSet()..remove(id);
  }

  void clear() => state = <String>{};
}

final visibleTracksProvider =
    NotifierProvider<VisibleTracksNotifier, Set<String>>(
  VisibleTracksNotifier.new,
);
