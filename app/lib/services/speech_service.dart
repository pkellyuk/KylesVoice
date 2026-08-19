import 'package:flutter_tts/flutter_tts.dart';

import '../log.dart';

/// Speaks card text through whichever engine the device has installed.
///
/// Uses the standard platform speech API and no Google SDK. The primary target
/// is an Amazon Fire tablet, where Play Services may be absent or may be removed
/// by a Fire OS update, so the app must work with whatever engine is present.
///
/// A new utterance always interrupts the previous one rather than queueing
/// behind it. Queued speech would mean a child pressing a second card hears the
/// first card finish first, which teaches that the device is not listening.
class SpeechService {
  final FlutterTts _tts = FlutterTts();

  bool _ready = false;
  String _lastFailure = '';

  bool get isReady => _ready;

  String get lastFailure => _lastFailure;

  /// Prepares the engine. Safe to call more than once.
  Future<void> initialise() async {
    Log.enter('SpeechService.initialise');

    if (_ready) {
      Log.exit('SpeechService.initialise', 'already ready');
      return;
    }

    try {
      await _tts.setLanguage('en-GB');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      // Interrupt rather than queue: see the class docs.
      await _tts.awaitSpeakCompletion(false);

      _ready = true;
      _lastFailure = '';

      Log.exit('SpeechService.initialise', 'ready');
    } catch (e, stack) {
      _lastFailure = '$e';
      Log.error('SpeechService.initialise', 'engine setup failed', e, stack);
      Log.exit('SpeechService.initialise', 'not ready');
    }
  }

  /// Speaks [phrase]. Never throws: a failure to speak must not take the board
  /// down, because the board is the child's only means of communicating.
  Future<void> speak(String? phrase) async {
    Log.enter('SpeechService.speak', 'phrase=$phrase');

    if (phrase == null) {
      Log.warn('SpeechService.speak', 'null phrase ignored');
      Log.exit('SpeechService.speak', 'aborted');
      return;
    }

    if (phrase.trim().isEmpty) {
      Log.warn('SpeechService.speak', 'blank phrase ignored');
      Log.exit('SpeechService.speak', 'aborted');
      return;
    }

    try {
      await _tts.stop();
      await _tts.speak(phrase.trim());

      _lastFailure = '';
      Log.exit('SpeechService.speak', 'dispatched');
    } catch (e, stack) {
      _lastFailure = '$e';
      Log.error('SpeechService.speak', 'speak failed', e, stack);
      Log.exit('SpeechService.speak', 'failed');
    }
  }

  Future<void> stop() async {
    Log.enter('SpeechService.stop');

    try {
      await _tts.stop();
      Log.exit('SpeechService.stop', 'stopped');
    } catch (e, stack) {
      Log.error('SpeechService.stop', 'stop failed', e, stack);
      Log.exit('SpeechService.stop', 'failed');
    }
  }
}
