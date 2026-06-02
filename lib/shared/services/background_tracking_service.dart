import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_background_service that keeps the app's
/// isolate alive while a track is being recorded. On Android this promotes
/// the process to a foreground service so the OS doesn't kill it when the
/// screen locks.
///
/// The heavy lifting (GPS stream, accumulation) is done by the Riverpod
/// providers in the main isolate. This service:
///   1. keeps the process alive (foreground mode),
///   2. renders a persistent notification with LIVE distance + time,
///   3. receives progress updates from the main isolate via
///      `FlutterBackgroundService().invoke('progress', {...})`.
class BackgroundTrackingService {
  BackgroundTrackingService._();

  static const _channelId = 'chaliy_nav_tracking';
  static const _notifId = 888;

  static final _notif = FlutterLocalNotificationsPlugin();
  static bool _initialised = false;

  static Future<void> _initNotifications() async {
    if (_initialised) return;
    _initialised = true;
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notif.initialize(init);

    await _notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Запись трека',
            description:
                'Показывает активную запись трека с расстоянием и временем',
            // Raised from Importance.low → defaultImportance so the
            // notification is shown prominently on the lock screen (like
            // Yandex Navigator). `low` hid it in a collapsed tray with
            // no preview, which defeated the "glance to see distance"
            // use case.
            importance: Importance.defaultImportance,
            enableVibration: false,
            playSound: false,
            showBadge: false,
          ),
        );
  }

  /// Initialise the background service once at app startup.
  static Future<void> configure() async {
    await _initNotifications();
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        // Neutral placeholder text — if this is ever seen, it means the
        // service was resurrected by the OS before [start] could set the
        // proper "Запись трека..." title. Previously said "Трек пишется"
        // which was misleading when no recording was actually active.
        initialNotificationTitle: 'ChaliyNav',
        initialNotificationContent: 'Готов к записи',
        foregroundServiceNotificationId: _notifId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// Start the service — called when the user hits "Record" on the map.
  /// Immediately shows the "Запись трека / Ожидание GPS…" notification
  /// by going direct through [updateProgress], so the user never sees
  /// the neutral "Готов к записи" fallback even for a split second.
  static Future<void> start() async {
    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      await service.startService();
    }
    await updateProgress(
      distanceText: 'Ожидание GPS…',
      elapsedText: '00:00',
    );
  }

  /// Called periodically from the main isolate while a recording is
  /// active — updates the persistent notification so the user can see
  /// distance + elapsed time without opening the app.
  ///
  /// **Update path**: we write the notification **directly** via
  /// `flutter_local_notifications` with the same `_notifId` that the
  /// foreground service uses. This replaces the notification content
  /// atomically, without going through the background isolate's event
  /// queue (which was unreliable — events could race the service's
  /// `_onStart` listener or be dropped entirely, leaving users with
  /// the stale "Готов к записи" placeholder).
  ///
  /// `distanceText` is the already-formatted "content" line — can be a
  /// simple "850 м" or a richer "1.2 км · 4.3 км/ч · 42 точек" depending
  /// on user settings.
  /// `elapsedText` — formatted time (may be empty if user disabled it).
  static Future<void> updateProgress({
    required String distanceText,
    required String elapsedText,
  }) async {
    await _initNotifications();
    final title = elapsedText.isEmpty
        ? 'Запись трека'
        : 'Запись трека · $elapsedText';
    try {
      await _notif.show(
        _notifId,
        title,
        distanceText,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Запись трека',
            channelDescription:
                'Показывает активную запись трека с расстоянием и временем',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            // Sticky: user can't swipe-dismiss this mid-recording.
            ongoing: true,
            autoCancel: false,
            // Don't re-play sound/vibration on each 3s update.
            onlyAlertOnce: true,
            showWhen: false,
            icon: '@mipmap/ic_launcher',
            // Without a fixed color the icon appears as the OS default,
            // which looks like a generic alert. Using our accent gives
            // the notification an identifiable visual.
            color: Color(0xFF2ECC71),
          ),
        ),
      );
    } catch (_) {
      // Don't crash the recording loop if the notification plugin
      // hiccups — the recording itself is independent of the UI.
    }
  }

  /// Stop the service — called when the user stops recording.
  /// Also cancels any lingering notification explicitly so the status
  /// bar is left clean even if the service was in a weird state
  /// (crashed, OS-resurrected with stale content, etc.).
  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
    // Belt-and-braces: cancel the notification ourselves. The service
    // normally does this via stopSelf(), but if it was dead or never
    // running, stopSelf would be a no-op while the notification could
    // still be shown by the OS from a previous run.
    try {
      await _initNotifications();
      await _notif.cancel(_notifId);
    } catch (_) {/* best effort */}
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) {
    // Main isolate owns the notification content now — it calls
    // `updateProgress()` directly via flutter_local_notifications on
    // the same `_notifId`, which atomically replaces the display. All
    // this isolate needs to do is stay alive and honour stop().
    service.on('stop').listen((_) {
      service.stopSelf();
    });

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Запись трека',
        content: 'Ожидание GPS…',
      );
    }
  }

  @pragma('vm:entry-point')
  static bool _onIosBackground(ServiceInstance service) => true;
}
