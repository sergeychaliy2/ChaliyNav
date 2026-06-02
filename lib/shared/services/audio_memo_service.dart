import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Thin wrapper around the `record` package. One recorder per service
/// instance; callers own the lifecycle (create → startRecording → stop → dispose).
class AudioMemoService {
  AudioMemoService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  String? _currentPath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<String?> start() async {
    if (!await _recorder.hasPermission()) return null;

    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(dir.path, 'audio_memos'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    final path = p.join(audioDir.path, '${const Uuid().v4()}.m4a');

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 96000,
        sampleRate: 44100,
      ),
      path: path,
    );

    _currentPath = path;
    return path;
  }

  Future<String?> stop() async {
    final stopped = await _recorder.stop();
    final path = stopped ?? _currentPath;
    _currentPath = null;
    return path;
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    if (_currentPath != null) {
      try {
        await File(_currentPath!).delete();
      } catch (_) {}
      _currentPath = null;
    }
  }

  Future<bool> isRecording() => _recorder.isRecording();

  Stream<Amplitude> get amplitudeStream =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 200));

  Future<void> dispose() => _recorder.dispose();
}
