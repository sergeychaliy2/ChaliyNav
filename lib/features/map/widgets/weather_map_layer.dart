import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/rf_regions.dart';
import '../../../shared/models/weather.dart';

/// Small glass pill showing a weather condition icon + temperature. Reused
/// on region cards (catalog) and as map markers.
class WeatherBadge extends StatelessWidget {
  const WeatherBadge({super.key, required this.weather, this.dense = false});

  final RegionWeather weather;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = weather.condition.color;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 7 : 9, vertical: dense ? 3 : 4),
      decoration: BoxDecoration(
        color: AppColors.bgDeepest.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(color: c.withValues(alpha: 0.18), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(weather.condition.icon, color: c, size: dense ? 13 : 15),
          SizedBox(width: dense ? 3 : 5),
          Text(
            weather.tempLabel,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: dense ? 11 : 12.5,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal "weather map": a badge at the centre of every RF region preset
/// showing its (simulated) current weather. Toggled from the map. Computed
/// once per build for the supplied [time] so all badges share one snapshot.
class WeatherMapLayer extends StatelessWidget {
  const WeatherMapLayer({super.key, required this.time});

  /// Snapshot time — passed in (not read here) so the whole overlay reflects
  /// one consistent moment and updates only when the caller refreshes it.
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    for (final preset in RfRegions.all()) {
      final r = preset.region;
      if (r == null) continue;
      final lat = (r.northLat + r.southLat) / 2;
      final lng = (r.westLng + r.eastLng) / 2;
      final weather = WeatherSim.at(lat, lng, time);
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 58,
          height: 30,
          alignment: Alignment.center,
          child: WeatherBadge(weather: weather, dense: true),
        ),
      );
    }
    return MarkerLayer(markers: markers);
  }
}
