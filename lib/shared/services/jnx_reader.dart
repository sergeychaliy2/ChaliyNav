import 'dart:io';
import 'dart:typed_data';

import '../models/map_layer.dart';

/// Garmin BirdsEye `.jnx` reader (version 3, unencrypted).
///
/// JNX is a proprietary raster-tile container Garmin handhelds use
/// for scanned / rasterised maps. It's a binary blob with one or more
/// zoom levels, each holding a grid of JPEG tiles; each tile carries
/// its own geographic bounds.
///
/// Memory strategy: the reader NEVER materialises a whole stitched
/// canvas in RAM — that would be `rows × cols × 1024² × 4` bytes of
/// RGBA which easily tops 500 MB for a forestry scan and crashes the
/// app on low-heap Android devices. Instead [read] returns a [JnxPlan]
/// with tile metadata only; the caller pulls each tile's JPEG bytes
/// via [JnxPlan.jpegBytesFor] one at a time, persisting to disk and
/// dropping the reference before moving on. Peak allocation stays
/// around one tile's JPEG size (≈ 50 – 200 KB typically).
///
/// Format facts (reverse-engineered from an actual file + aligned
/// with GPSBabel's `jnx.cc`):
///
///   * Header is **48 bytes** (`0x30`) for v3: version (4), devid (4),
///     top/right/bottom/left (4×4 = 16, int32 Garmin coords — see
///     [_coordToDeg]), num_levels (4), expire (4), product_id (4),
///     crc32 (4), signature (4), sign_offset (4). Level entries
///     start at offset 0x30.
///   * Each level entry is 16 bytes: `count` (uint32), `scale` (int32),
///     `tiles_offset` (uint32), plus one more reserved uint32.
///   * Each tile record is 28 bytes, laid out **width/height first**:
///     int16 width, int16 height, int32 jpeg_size, int32 jpeg_offset,
///     then four int32 coords in top/right/bottom/left order.
///
/// Not supported yet: v4 (encrypted / signature-masked JPEG payloads).
class JnxReader {
  JnxReader._();

  /// Parse [src] and return a plan describing the highest-detail
  /// zoom level. Each entry in [JnxPlan.tiles] has its own bounds
  /// and a handle to the underlying JPEG payload inside the file
  /// buffer. Call [JnxPlan.jpegBytesFor] per tile to get ready-to-
  /// write JPEG bytes; the plan holds the raw file bytes internally
  /// so those calls are zero-copy views.
  ///
  /// Returns null if the file doesn't look like a JNX at all.
  /// Throws [JnxReadException] when the format is recognised but we
  /// can't handle this particular variant (e.g. encrypted v4).
  static Future<JnxPlan?> read(File src) async {
    final bytes = await src.readAsBytes();
    final reader = _Reader(bytes);

    if (bytes.length < 0x40) return null;

    // --- Fixed header (48 bytes) ---
    final version = reader.readUint32();
    if (version != 3) {
      throw JnxReadException(
        'JNX версии $version пока не поддерживается. '
        'Приложение читает только v3 (без шифрования). '
        'Переконвертируйте в TIFF через GPSBabel / JNXlib.',
      );
    }
    reader.skip(4); // devId
    final topLat = _coordToDeg(reader.readInt32());
    final rightLng = _coordToDeg(reader.readInt32());
    final bottomLat = _coordToDeg(reader.readInt32());
    final leftLng = _coordToDeg(reader.readInt32());
    final levelsCount = reader.readUint32();
    reader.skip(20); // expire, productId, crc, signature, sign_offset

    if (levelsCount == 0 || levelsCount > 32) {
      throw JnxReadException(
        'Повреждённый JNX: прочитано $levelsCount уровней. '
        'Проверьте, что это v3 (GPSBabel → Output format: Garmin JNX v3).',
      );
    }
    if (topLat.abs() > 90 ||
        bottomLat.abs() > 90 ||
        leftLng.abs() > 180 ||
        rightLng.abs() > 180) {
      throw JnxReadException(
        'Повреждённый JNX: координаты вне диапазона '
        '($topLat°, $leftLng° → $bottomLat°, $rightLng°).',
      );
    }

    // --- Level headers ---
    final levels = <_LevelHeader>[];
    for (var i = 0; i < levelsCount; i++) {
      final count = reader.readUint32();
      final scale = reader.readInt32();
      final tilesOffset = reader.readUint32();
      reader.skip(4); // reserved / copyright ptr
      levels.add(_LevelHeader(
        count: count,
        scale: scale,
        tilesOffset: tilesOffset,
      ));
    }

    final usableLevels = levels.where((l) => l.count > 0).toList();
    if (usableLevels.isEmpty) {
      throw JnxReadException(
        'В JNX нет тайлов ни на одном уровне '
        '(уровней заявлено: $levelsCount, общий bbox: '
        '$topLat°N $leftLng°E → $bottomLat°N $rightLng°E).',
      );
    }
    usableLevels.sort((a, b) => a.scale.compareTo(b.scale));
    final bestLevel = usableLevels.first;

    if (bestLevel.tilesOffset >= bytes.length) {
      throw JnxReadException(
        'Повреждённый JNX: смещение тайлов ${bestLevel.tilesOffset} '
        'за пределами файла (${bytes.length} байт).',
      );
    }

    // --- Tile headers ---
    reader.seek(bestLevel.tilesOffset);
    final tiles = <JnxTile>[];
    for (var i = 0; i < bestLevel.count; i++) {
      // Tile record layout (28 bytes), order is important:
      //   int16 width
      //   int16 height
      //   int32 jpeg_size
      //   int32 jpeg_offset
      //   int32 top_lat
      //   int32 right_lng
      //   int32 bottom_lat
      //   int32 left_lng
      final width = reader.readInt16();
      final height = reader.readInt16();
      final size = reader.readInt32();
      final dataOffset = reader.readUint32();
      final tTopLat = _coordToDeg(reader.readInt32());
      final tRightLng = _coordToDeg(reader.readInt32());
      final tBottomLat = _coordToDeg(reader.readInt32());
      final tLeftLng = _coordToDeg(reader.readInt32());

      // Empty slot — JNX reserves a record per grid cell even when
      // the scan doesn't cover it. Skip silently.
      if (width == 0 && height == 0 && size == 0) {
        continue;
      }

      // "Walked off the end" detector: `level.count` is sometimes
      // an upper bound that exceeds the real number of records. Past
      // the end we read JPEG payload bytes which decode as nonsense.
      // Any sanity failure means the record array has ended.
      final dimsOk =
          width > 0 && height > 0 && width <= 4096 && height <= 4096;
      final sizeOk = size > 0 && size < bytes.length;
      final offsetOk =
          dataOffset > 0 && dataOffset + size <= bytes.length;
      const coordMargin = 0.5;
      final coordsOk = tTopLat <= topLat + coordMargin &&
          tBottomLat >= bottomLat - coordMargin &&
          tRightLng <= rightLng + coordMargin &&
          tLeftLng >= leftLng - coordMargin &&
          tTopLat >= tBottomLat &&
          tRightLng >= tLeftLng;

      if (!dimsOk || !sizeOk || !offsetOk || !coordsOk) {
        break;
      }

      tiles.add(JnxTile(
        widthPx: width,
        heightPx: height,
        dataOffset: dataOffset,
        dataSize: size,
        bounds: LayerBounds(
          northLat: tTopLat,
          southLat: tBottomLat,
          westLng: tLeftLng,
          eastLng: tRightLng,
        ),
      ));
    }

    if (tiles.isEmpty) {
      throw JnxReadException(
        'Не найдено ни одного валидного тайла. '
        'Всего записей в уровне: ${bestLevel.count}, '
        'проход остановился на первой же некорректной.',
      );
    }

    return JnxPlan(
      bytes: bytes,
      bounds: LayerBounds(
        northLat: topLat,
        southLat: bottomLat,
        westLng: leftLng,
        eastLng: rightLng,
      ),
      tiles: tiles,
      scale: bestLevel.scale,
    );
  }

  /// Garmin stores lat / lng as signed 32-bit integers with units of
  /// `180° / 2^31` (the full int32 range covers ±360°). Unpack back
  /// to decimal degrees.
  static double _coordToDeg(int raw) => raw * (180.0 / 0x7FFFFFFF);

  /// Some Garmin encoders omit the `FF D8 FF E0 … JFIF …` SOI + APP0
  /// preamble from the stored JPEG stream, and stock decoders refuse
  /// such files. Prepend a canonical JFIF header when we detect the
  /// payload doesn't already start with SOI. Harmless no-op on
  /// well-formed JPEGs.
  static Uint8List fixupJnxJpeg(Uint8List tile) {
    if (tile.length >= 2 && tile[0] == 0xFF && tile[1] == 0xD8) {
      return tile;
    }
    const prefix = <int>[
      0xFF, 0xD8, 0xFF, 0xE0,
      0x00, 0x10, // APP0 segment length (16 bytes)
      0x4A, 0x46, 0x49, 0x46, 0x00, // "JFIF\0"
      0x01, 0x01, // JFIF version 1.1
      0x00, // no density units
      0x00, 0x01, 0x00, 0x01, // X, Y density = 1
      0x00, 0x00, // no thumbnail
    ];
    final out = Uint8List(prefix.length + tile.length);
    out.setRange(0, prefix.length, prefix);
    out.setRange(prefix.length, out.length, tile);
    return out;
  }
}

/// Metadata + raw bytes of a parsed JNX file. The caller uses this to
/// iterate [tiles] one at a time — fetching each JPEG payload via
/// [jpegBytesFor] and persisting it before moving on — so memory use
/// never exceeds a single tile.
class JnxPlan {
  JnxPlan({
    required this.bytes,
    required this.bounds,
    required this.tiles,
    required this.scale,
  });

  /// Raw file bytes. Views into this buffer back each tile's payload.
  final Uint8List bytes;

  /// Overall geographic bounding box from the JNX header.
  final LayerBounds bounds;

  /// Per-tile metadata (bounds + payload pointer + pixel size).
  final List<JnxTile> tiles;

  /// Garmin "scale" value of the chosen zoom level. Purely diagnostic.
  final int scale;

  /// Ready-to-save JPEG bytes for [tile]. Zero-copy in the common case
  /// (tile already has an SOI marker); if the SOI was stripped by
  /// Garmin's encoder, we allocate a small Uint8List with a canonical
  /// JFIF prefix + the tile view.
  Uint8List jpegBytesFor(JnxTile tile) {
    final view = Uint8List.sublistView(
      bytes,
      tile.dataOffset,
      tile.dataOffset + tile.dataSize,
    );
    return JnxReader.fixupJnxJpeg(view);
  }
}

class JnxTile {
  const JnxTile({
    required this.widthPx,
    required this.heightPx,
    required this.dataOffset,
    required this.dataSize,
    required this.bounds,
  });

  final int widthPx;
  final int heightPx;
  final int dataOffset;
  final int dataSize;
  final LayerBounds bounds;
}

class JnxReadException implements Exception {
  const JnxReadException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _LevelHeader {
  const _LevelHeader({
    required this.count,
    required this.scale,
    required this.tilesOffset,
  });
  final int count;
  final int scale;
  final int tilesOffset;
}

class _Reader {
  _Reader(this._bytes);
  final Uint8List _bytes;
  int _pos = 0;

  void seek(int pos) => _pos = pos;
  void skip(int n) => _pos += n;

  int readUint32() {
    final v = _bytes[_pos] |
        (_bytes[_pos + 1] << 8) |
        (_bytes[_pos + 2] << 16) |
        (_bytes[_pos + 3] << 24);
    _pos += 4;
    return v;
  }

  int readInt32() {
    final v = readUint32();
    return v >= 0x80000000 ? v - 0x100000000 : v;
  }

  int readInt16() {
    final v = _bytes[_pos] | (_bytes[_pos + 1] << 8);
    _pos += 2;
    return v >= 0x8000 ? v - 0x10000 : v;
  }
}
