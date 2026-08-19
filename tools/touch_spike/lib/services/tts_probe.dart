import 'package:flutter_tts/flutter_tts.dart';

import '../log.dart';

/// A single voice offered by an installed TTS engine.
class ProbedVoice {
  final String name;
  final String locale;

  const ProbedVoice({required this.name, required this.locale});

  @override
  String toString() => '$name ($locale)';
}

/// What the device's speech synthesis can actually do.
class TtsCapabilities {
  final bool available;
  final List<String> engines;
  final String defaultEngine;
  final List<ProbedVoice> voices;
  final List<String> languages;
  final String failureReason;

  const TtsCapabilities({
    required this.available,
    required this.engines,
    required this.defaultEngine,
    required this.voices,
    required this.languages,
    required this.failureReason,
  });

  static const TtsCapabilities unknown = TtsCapabilities(
    available: false,
    engines: <String>[],
    defaultEngine: '',
    voices: <ProbedVoice>[],
    languages: <String>[],
    failureReason: 'Not probed yet.',
  );

  /// Voices matching a language prefix, e.g. 'en'.
  List<ProbedVoice> voicesForLanguagePrefix(String prefix) {
    if (prefix.isEmpty) {
      return voices;
    }

    return voices
        .where(
          (ProbedVoice v) =>
              v.locale.toLowerCase().startsWith(prefix.toLowerCase()),
        )
        .toList(growable: false);
  }

  /// Plain-language verdict for whoever is holding the device.
  String get verdict {
    if (available == false) {
      return 'PROBLEM: no usable speech synthesis found. $failureReason';
    }

    final int englishVoices = voicesForLanguagePrefix('en').length;

    if (englishVoices == 0) {
      return 'PROBLEM: a TTS engine exists but offers no English voices.';
    }

    if (englishVoices == 1) {
      return 'Marginal: exactly one English voice. No choice of voice for Kyle.';
    }

    return 'Usable: $englishVoices English voices across ${engines.length} engine(s).';
  }
}

/// Probes the device's text-to-speech capability.
///
/// This exists because the target device is an Amazon Fire tablet. Fire OS does
/// not ship Google's TTS engine, and it is not established how completely
/// Amazon's own engine is exposed through the standard Android TextToSpeech
/// API. If speech is unusable there, the entire app is unusable on Kyle's main
/// device, so this must be answered before anything is built on top of it.
class TtsProbe {
  /// Enumerates engines, voices and languages, and reports what it finds.
  ///
  /// Never throws: a failure is reported through [TtsCapabilities] so the probe
  /// screen can display the reason rather than crashing.
  static Future<TtsCapabilities> probe() async {
    Log.enter('TtsProbe.probe');

    final FlutterTts tts = FlutterTts();

    try {
      final List<String> engines = await _readEngines(tts);
      final String defaultEngine = await _readDefaultEngine(tts);
      final List<String> languages = await _readLanguages(tts);
      final List<ProbedVoice> voices = await _readVoices(tts);

      final bool available =
          engines.isNotEmpty || voices.isNotEmpty || languages.isNotEmpty;

      Log.step(
        'TtsProbe.probe',
        'engines=${engines.length} defaultEngine=$defaultEngine '
            'languages=${languages.length} voices=${voices.length}',
      );

      for (final String engine in engines) {
        Log.step('TtsProbe.probe', 'engine: $engine');
      }

      for (final ProbedVoice voice in voices) {
        Log.step('TtsProbe.probe', 'voice: $voice');
      }

      Log.exit('TtsProbe.probe', 'available=$available');

      return TtsCapabilities(
        available: available,
        engines: engines,
        defaultEngine: defaultEngine,
        voices: voices,
        languages: languages,
        failureReason: available
            ? ''
            : 'The platform returned no engines, voices or languages.',
      );
    } catch (e, stack) {
      Log.error('TtsProbe.probe', 'probe failed', e, stack);
      Log.exit('TtsProbe.probe', 'available=false');

      return TtsCapabilities(
        available: false,
        engines: const <String>[],
        defaultEngine: '',
        voices: const <ProbedVoice>[],
        languages: const <String>[],
        failureReason: '$e',
      );
    }
  }

  /// Speaks [phrase], optionally forcing a specific voice.
  ///
  /// Returns an empty string on success, or a human-readable failure reason.
  static Future<String> speak({
    required String? phrase,
    ProbedVoice? voice,
    double rate = 0.5,
    double pitch = 1.0,
  }) async {
    Log.enter('TtsProbe.speak', 'voice=$voice rate=$rate pitch=$pitch');

    if (phrase == null) {
      Log.warn('TtsProbe.speak', 'null phrase');
      Log.exit('TtsProbe.speak', 'aborted');
      return 'Nothing to say.';
    }

    if (phrase.trim().isEmpty) {
      Log.warn('TtsProbe.speak', 'blank phrase');
      Log.exit('TtsProbe.speak', 'aborted');
      return 'Nothing to say.';
    }

    final FlutterTts tts = FlutterTts();

    try {
      if (voice != null) {
        Log.step(
          'TtsProbe.speak',
          'selecting voice ${voice.name} / ${voice.locale}',
        );
        await tts.setVoice(<String, String>{
          'name': voice.name,
          'locale': voice.locale,
        });
      }

      await tts.setSpeechRate(rate);
      await tts.setPitch(pitch);

      Log.step('TtsProbe.speak', 'speaking "${phrase.trim()}"');
      await tts.speak(phrase.trim());

      Log.exit('TtsProbe.speak', 'dispatched');
      return '';
    } catch (e, stack) {
      Log.error('TtsProbe.speak', 'speak failed', e, stack);
      Log.exit('TtsProbe.speak', 'failed');
      return '$e';
    }
  }

  static Future<List<String>> _readEngines(FlutterTts tts) async {
    Log.enter('TtsProbe._readEngines');

    try {
      final dynamic raw = await tts.getEngines;
      final List<String> engines = _toStringList(raw);

      Log.exit('TtsProbe._readEngines', 'count=${engines.length}');
      return engines;
    } catch (e) {
      Log.warn('TtsProbe._readEngines', 'unavailable: $e');
      Log.exit('TtsProbe._readEngines', 'count=0');
      return <String>[];
    }
  }

  static Future<String> _readDefaultEngine(FlutterTts tts) async {
    Log.enter('TtsProbe._readDefaultEngine');

    try {
      final dynamic raw = await tts.getDefaultEngine;

      if (raw == null) {
        Log.exit('TtsProbe._readDefaultEngine', 'none');
        return '';
      }

      Log.exit('TtsProbe._readDefaultEngine', 'engine=$raw');
      return raw.toString();
    } catch (e) {
      Log.warn('TtsProbe._readDefaultEngine', 'unavailable: $e');
      Log.exit('TtsProbe._readDefaultEngine', 'none');
      return '';
    }
  }

  static Future<List<String>> _readLanguages(FlutterTts tts) async {
    Log.enter('TtsProbe._readLanguages');

    try {
      final dynamic raw = await tts.getLanguages;
      final List<String> languages = _toStringList(raw);
      languages.sort();

      Log.exit('TtsProbe._readLanguages', 'count=${languages.length}');
      return languages;
    } catch (e) {
      Log.warn('TtsProbe._readLanguages', 'unavailable: $e');
      Log.exit('TtsProbe._readLanguages', 'count=0');
      return <String>[];
    }
  }

  static Future<List<ProbedVoice>> _readVoices(FlutterTts tts) async {
    Log.enter('TtsProbe._readVoices');

    try {
      final dynamic raw = await tts.getVoices;

      if (raw is! List) {
        Log.warn(
          'TtsProbe._readVoices',
          'unexpected shape: ${raw.runtimeType}',
        );
        Log.exit('TtsProbe._readVoices', 'count=0');
        return <ProbedVoice>[];
      }

      final List<ProbedVoice> voices = <ProbedVoice>[];

      for (final dynamic entry in raw) {
        if (entry is! Map) {
          continue;
        }

        final String name = entry['name']?.toString() ?? '';

        if (name.isEmpty) {
          continue;
        }

        voices.add(
          ProbedVoice(name: name, locale: entry['locale']?.toString() ?? ''),
        );
      }

      voices.sort((ProbedVoice a, ProbedVoice b) {
        final int byLocale = a.locale.compareTo(b.locale);

        if (byLocale != 0) {
          return byLocale;
        }

        return a.name.compareTo(b.name);
      });

      Log.exit('TtsProbe._readVoices', 'count=${voices.length}');
      return voices;
    } catch (e) {
      Log.warn('TtsProbe._readVoices', 'unavailable: $e');
      Log.exit('TtsProbe._readVoices', 'count=0');
      return <ProbedVoice>[];
    }
  }

  static List<String> _toStringList(dynamic raw) {
    if (raw is! List) {
      return <String>[];
    }

    return raw
        .where((dynamic e) => e != null)
        .map((dynamic e) => e.toString())
        .where((String s) => s.isNotEmpty)
        .toList();
  }
}
