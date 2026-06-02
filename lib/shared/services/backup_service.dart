import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import 'security_service.dart';

/// Create / restore password-encrypted full-data backups.
///
/// File format: `.chaliy` extension
///   [salt(16)] + [iv(16)] + AES-256-CBC(zip(json-dump))
///
/// What's inside the zip:
///   - manifest.json  — version, createdAt, counts
///   - points.json    — all POIs
///   - tracks.json    — all tracks
///   - routes.json    — all routes
///   - zones.json     — all zones
///   - layers.json    — user map layers
///   - settings.json  — app settings
///
/// Photos / audio / mbtiles are NOT included (too big). They stay on the
/// device. Phase 5 will add an optional "deep backup" mode.
class BackupService {
  BackupService._();

  static const _version = 1;

  static Future<File> createBackup(String password) async {
    final prefs = await SharedPreferences.getInstance();

    // Collect everything from SharedPreferences into a manifest.
    final manifest = <String, dynamic>{
      'version': _version,
      'app': AppConstants.appName,
      'createdAt': DateTime.now().toIso8601String(),
    };
    final snapshot = <String, dynamic>{
      'manifest': manifest,
    };
    for (final entry in _keysToInclude.entries) {
      final raw = prefs.getString(entry.value);
      if (raw != null) snapshot[entry.key] = raw;
    }

    // Pack into a zip — one JSON file per section for future-proofing.
    final archive = Archive();
    for (final entry in snapshot.entries) {
      final bytes =
          utf8.encode(entry.value is String ? entry.value : jsonEncode(entry.value));
      archive.addFile(
        ArchiveFile('${entry.key}.json', bytes.length, bytes),
      );
    }
    final zipped = ZipEncoder().encode(archive);
    manifest['sizeUncompressed'] = zipped.length;

    // Encrypt with password.
    final encrypted =
        await SecurityService.instance.encryptWithPassword(zipped, password);

    // Write to app-documents/backups/.
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'backups'));
    if (!await folder.exists()) await folder.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(folder.path, 'chaliynav_$stamp.chaliy'));
    await file.writeAsBytes(encrypted);
    return file;
  }

  /// Decrypt and restore a .chaliy backup with the given password.
  /// Overwrites current SharedPreferences for the included sections.
  static Future<BackupRestoreReport> restoreBackup(
    File file,
    String password,
  ) async {
    final encrypted = await file.readAsBytes();
    final zipped =
        await SecurityService.instance.decryptWithPassword(encrypted, password);

    final archive = ZipDecoder().decodeBytes(zipped);
    final sections = <String, String>{};
    for (final f in archive) {
      if (!f.isFile) continue;
      final name = p.basenameWithoutExtension(f.name);
      sections[name] = utf8.decode(f.content as List<int>);
    }

    Map<String, dynamic>? manifest;
    if (sections['manifest'] != null) {
      manifest = jsonDecode(sections['manifest']!) as Map<String, dynamic>;
    }

    final prefs = await SharedPreferences.getInstance();
    final restored = <String>[];
    for (final entry in _keysToInclude.entries) {
      final json = sections[entry.key];
      if (json == null) continue;
      await prefs.setString(entry.value, json);
      restored.add(entry.key);
    }

    return BackupRestoreReport(
      version: (manifest?['version'] as int?) ?? 0,
      createdAt: manifest?['createdAt'] == null
          ? null
          : DateTime.tryParse(manifest!['createdAt'] as String),
      restoredSections: restored,
    );
  }

  /// Maps our section keys (inside the zip) to SharedPreferences keys.
  /// When adding a new persisted collection, register it here to include it
  /// in future backups.
  static const Map<String, String> _keysToInclude = {
    'points': AppConstants.prefsKeyPoints,
    'tracks': AppConstants.prefsKeyTracks,
    'routes': AppConstants.prefsKeyRoutes,
    'zones': 'zones_v1',
    'layers': 'layers_v1',
    'settings': AppConstants.prefsKeySettings,
  };
}

class BackupRestoreReport {
  const BackupRestoreReport({
    required this.version,
    required this.createdAt,
    required this.restoredSections,
  });

  final int version;
  final DateTime? createdAt;
  final List<String> restoredSections;
}
