import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around flutter_tts with Russian voice defaults and
/// cooldown-aware speak(). Keeps the rest of the app from carrying TTS state.
class TtsService {
  TtsService() {
    _init();
  }

  final FlutterTts _tts = FlutterTts();
  DateTime _lastSpoke = DateTime.fromMillisecondsSinceEpoch(0);
  bool _ready = false;

  Future<void> _init() async {
    try {
      await _tts.setLanguage('ru-RU');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _ready = true;
    } catch (_) {
      // Some devices have no TTS engine — fail silently.
    }
  }

  /// Speak with an optional cooldown. If [cooldown] has not yet elapsed
  /// since the last spoken phrase, the call is ignored.
  Future<void> speak(
    String phrase, {
    Duration cooldown = Duration.zero,
    bool interrupt = false,
  }) async {
    if (!_ready) return;
    final now = DateTime.now();
    if (!interrupt && now.difference(_lastSpoke) < cooldown) return;
    _lastSpoke = now;
    if (interrupt) {
      await _tts.stop();
    }
    await _tts.speak(phrase);
  }

  Future<void> stop() async => _tts.stop();
  Future<void> dispose() async => _tts.stop();
}
