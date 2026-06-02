import 'map_layer.dart';

/// Offline tile download — either active or archived.
/// When complete, becomes a MapLayer of type [MapLayerType.mbtiles].
class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.name,
    required this.tileUrlTemplate,
    required this.northLat,
    required this.southLat,
    required this.westLng,
    required this.eastLng,
    required this.minZoom,
    required this.maxZoom,
    required this.totalTiles,
    required this.createdAt,
    this.downloadedTiles = 0,
    this.status = DownloadStatus.queued,
    this.outputPath,
    this.error,
    this.presetId,
  });

  final String id;
  final String name;
  final String tileUrlTemplate;
  final double northLat;
  final double southLat;
  final double westLng;
  final double eastLng;
  final int minZoom;
  final int maxZoom;
  final int totalTiles;
  final DateTime createdAt;

  final int downloadedTiles;
  final DownloadStatus status;
  final String? outputPath;
  final String? error;

  /// Id of the MapPreset this download was spawned from.
  /// Used to show "СКАЧАНО" / "СКАЧИВАЕТСЯ" badges on catalogue cards.
  final String? presetId;

  double get progress => totalTiles == 0 ? 0 : downloadedTiles / totalTiles;

  DownloadTask copyWith({
    int? downloadedTiles,
    DownloadStatus? status,
    String? outputPath,
    String? error,
  }) =>
      DownloadTask(
        id: id,
        name: name,
        tileUrlTemplate: tileUrlTemplate,
        northLat: northLat,
        southLat: southLat,
        westLng: westLng,
        eastLng: eastLng,
        minZoom: minZoom,
        maxZoom: maxZoom,
        totalTiles: totalTiles,
        createdAt: createdAt,
        downloadedTiles: downloadedTiles ?? this.downloadedTiles,
        status: status ?? this.status,
        outputPath: outputPath ?? this.outputPath,
        error: error ?? this.error,
        presetId: presetId,
      );
}

enum DownloadStatus {
  queued,
  running,
  paused,
  completed,
  failed,
  cancelled;

  String get label => switch (this) {
        DownloadStatus.queued => 'В очереди',
        DownloadStatus.running => 'Скачивание',
        DownloadStatus.paused => 'Пауза',
        DownloadStatus.completed => 'Готово',
        DownloadStatus.failed => 'Ошибка',
        DownloadStatus.cancelled => 'Отменено',
      };
}
