class AppConstants {
  AppConstants._();

  static const String appName = 'ChaliyNav';
  static const String appTagline = 'Your path. Your marks. Your legacy.';
  static const String appVersion = '1.0.0';

  // Default map
  static const double defaultZoom = 14.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 20.0;
  static const String defaultTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String satelliteTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const String topoTileUrl =
      'https://a.tile.opentopomap.org/{z}/{x}/{y}.png';

  // Fallback center (Moscow) — overridden by geolocation as soon as we get a fix.
  static const double defaultLat = 55.7558;
  static const double defaultLng = 37.6173;

  // Track recording defaults
  static const double defaultTrackMinDistance = 5.0; // meters
  static const int defaultTrackMinInterval = 2; // seconds
  static const double defaultGpsAccuracyThreshold = 20.0; // meters

  // Shake detection
  static const double defaultShakeThreshold = 15.0;
  static const int defaultShakeCooldownMs = 1500;

  // Media
  static const int maxPhotosPerPoint = 10;
  static const int maxAudioDurationSec = 120;

  // Storage keys
  static const String prefsKeyOnboarded = 'onboarded_v1';
  static const String prefsKeySettings = 'settings_v1';
  static const String prefsKeyPoints = 'points_v1';
  static const String prefsKeyTracks = 'tracks_v1';
  static const String prefsKeyRoutes = 'routes_v1';
}
