import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/locale_provider.dart';
import 'features/map/screens/map_screen.dart';
import 'features/points/screens/new_point_screen.dart';
import 'features/points/screens/point_detail_screen.dart';
import 'features/points/screens/points_list_screen.dart';
import 'features/auth/app_lock_screen.dart';
import 'features/downloads/screens/downloads_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/permissions_screen.dart';
import 'features/settings/screens/backup_screen.dart';
import 'features/settings/screens/data_screen.dart';
import 'features/settings/screens/help_screen.dart';
import 'features/settings/screens/language_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/splash/splash_screen.dart';
import 'features/tracks/screens/track_detail_screen.dart';
import 'features/tracks/screens/tracks_list_screen.dart';
import 'features/zones/screens/zone_detail_screen.dart';
import 'shared/models/geo_point.dart';
import 'shared/models/point_of_interest.dart';

class ChaliyNavApp extends ConsumerWidget {
  ChaliyNavApp({super.key});

  final _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, __) => _fadePage(const OnboardingScreen()),
      ),
      GoRoute(
        path: '/lock',
        pageBuilder: (_, __) => _fadePage(const AppLockScreen()),
      ),
      GoRoute(
        path: '/permissions',
        pageBuilder: (_, __) => _fadePage(const PermissionsScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                pageBuilder: (_, __) => _fadePage(const MapScreen()),
                routes: [],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/points',
                pageBuilder: (_, __) => _fadePage(const PointsListScreen()),
                routes: [
                  GoRoute(
                    path: 'new',
                    pageBuilder: (_, state) {
                      final coord = state.extra as GeoPoint?;
                      return _fadePage(
                        NewPointScreen(
                          coord: coord ??
                              GeoPoint(
                                lat: AppConstants.defaultLat,
                                lng: AppConstants.defaultLng,
                                timestamp: DateTime.now(),
                              ),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    pageBuilder: (_, state) => _fadePage(
                      PointDetailScreen(pointId: state.pathParameters['id']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        pageBuilder: (_, state) {
                          final existing = state.extra as PointOfInterest?;
                          if (existing == null) {
                            return _fadePage(const _MissingPointPage());
                          }
                          return _fadePage(
                            NewPointScreen(
                              coord: existing.coord,
                              editing: existing,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tracks',
                pageBuilder: (_, __) => _fadePage(const TracksListScreen()),
                routes: [
                  GoRoute(
                    path: 'zones/:id',
                    pageBuilder: (_, state) => _fadePage(
                      ZoneDetailScreen(zoneId: state.pathParameters['id']!),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    pageBuilder: (_, state) => _fadePage(
                      TrackDetailScreen(trackId: state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (_, __) => _fadePage(const SettingsScreen()),
                routes: [
                  GoRoute(
                    path: 'data',
                    pageBuilder: (_, __) => _fadePage(const DataScreen()),
                  ),
                  GoRoute(
                    path: 'downloads',
                    pageBuilder: (_, __) =>
                        _fadePage(const DownloadsScreen()),
                  ),
                  GoRoute(
                    path: 'help',
                    pageBuilder: (_, __) => _fadePage(const HelpScreen()),
                  ),
                  GoRoute(
                    path: 'backup',
                    pageBuilder: (_, __) => _fadePage(const BackupScreen()),
                  ),
                  GoRoute(
                    path: 'language',
                    pageBuilder: (_, __) =>
                        _fadePage(const LanguageScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  static CustomTransitionPage<void> _fadePage(Widget child) {
    return CustomTransitionPage<void>(
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: appLocale.locale,
      supportedLocales: AppLocale.values.map((l) => l.locale),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
    );
  }
}

class _MissingPointPage extends StatelessWidget {
  const _MissingPointPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.commonError)),
      body: Center(child: Text(l10n.commonNotFound)),
    );
  }
}
