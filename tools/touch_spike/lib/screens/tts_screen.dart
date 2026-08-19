import 'package:flutter/material.dart';

import '../log.dart';
import '../services/tts_probe.dart';

/// Reports what speech synthesis the device actually offers, and lets each
/// voice be auditioned.
///
/// Paired with the touch capture so that one visit to the device answers both
/// open hardware questions: can it measure a palm, and can it talk.
class TtsScreen extends StatefulWidget {
  const TtsScreen({super.key});

  @override
  State<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends State<TtsScreen> {
  /// Phrases drawn from what a first AAC board would actually say, so the
  /// audition reflects real use rather than a generic test sentence.
  static const List<String> _testPhrases = <String>[
    'I want a drink',
    'more please',
    'all done',
    'I need the toilet',
    'help me',
    'yes',
    'no',
  ];

  TtsCapabilities _capabilities = TtsCapabilities.unknown;
  ProbedVoice? _selectedVoice;
  bool _englishOnly = true;
  bool _probing = true;
  double _rate = 0.5;
  double _pitch = 1.0;
  String _status = 'Probing speech engines...';

  @override
  void initState() {
    Log.enter('_TtsScreenState.initState');
    super.initState();

    _runProbe();

    Log.exit('_TtsScreenState.initState');
  }

  Future<void> _runProbe() async {
    Log.enter('_TtsScreenState._runProbe');

    setState(() {
      _probing = true;
      _status = 'Probing speech engines...';
    });

    final TtsCapabilities capabilities = await TtsProbe.probe();

    if (mounted == false) {
      Log.exit('_TtsScreenState._runProbe', 'unmounted, discarding');
      return;
    }

    final List<ProbedVoice> shortlist = capabilities.voicesForLanguagePrefix(
      'en',
    );

    setState(() {
      _capabilities = capabilities;
      _probing = false;
      _selectedVoice = shortlist.isNotEmpty
          ? shortlist.first
          : (capabilities.voices.isNotEmpty ? capabilities.voices.first : null);
      _status = capabilities.available
          ? 'Found ${capabilities.voices.length} voices.'
          : capabilities.failureReason;
    });

    Log.exit(
      '_TtsScreenState._runProbe',
      'available=${capabilities.available}',
    );
  }

  Future<void> _speak(String? phrase) async {
    Log.enter('_TtsScreenState._speak', 'phrase=$phrase');

    if (phrase == null) {
      Log.warn('_TtsScreenState._speak', 'null phrase ignored');
      Log.exit('_TtsScreenState._speak', 'aborted');
      return;
    }

    final String failure = await TtsProbe.speak(
      phrase: phrase,
      voice: _selectedVoice,
      rate: _rate,
      pitch: _pitch,
    );

    if (mounted == false) {
      Log.exit('_TtsScreenState._speak', 'unmounted');
      return;
    }

    setState(() {
      _status = failure.isEmpty ? 'Spoke: "$phrase"' : 'Failed: $failure';
    });

    Log.exit(
      '_TtsScreenState._speak',
      'failure=${failure.isEmpty ? "none" : failure}',
    );
  }

  void _onVoiceChanged(ProbedVoice? voice) {
    Log.enter('_TtsScreenState._onVoiceChanged', 'voice=$voice');

    if (voice == null) {
      Log.warn('_TtsScreenState._onVoiceChanged', 'null voice ignored');
      Log.exit('_TtsScreenState._onVoiceChanged');
      return;
    }

    setState(() {
      _selectedVoice = voice;
      _status = 'Selected ${voice.name}.';
    });

    Log.exit('_TtsScreenState._onVoiceChanged');
  }

  List<ProbedVoice> get _visibleVoices {
    if (_englishOnly == false) {
      return _capabilities.voices;
    }

    final List<ProbedVoice> english = _capabilities.voicesForLanguagePrefix(
      'en',
    );

    if (english.isEmpty) {
      return _capabilities.voices;
    }

    return english;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      appBar: AppBar(
        title: const Text('Speech check'),
        backgroundColor: const Color(0xFF161B21),
        actions: <Widget>[
          IconButton(
            onPressed: _probing ? null : _runProbe,
            icon: const Icon(Icons.refresh),
            tooltip: 'Probe again',
          ),
        ],
      ),
      body: _probing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _verdictBanner(),
                  const SizedBox(height: 16),
                  _enginesPanel(),
                  const SizedBox(height: 16),
                  _voicePanel(),
                  const SizedBox(height: 16),
                  _phrasePanel(),
                  const SizedBox(height: 16),
                  Text(
                    _status,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _verdictBanner() {
    final bool problem = _capabilities.verdict.startsWith('PROBLEM');
    final bool marginal = _capabilities.verdict.startsWith('Marginal');

    final Color colour = problem
        ? const Color(0xFFE57373)
        : (marginal ? const Color(0xFFFFB74D) : const Color(0xFF81C784));

    return _panel(
      child: Text(
        _capabilities.verdict,
        style: TextStyle(
          color: colour,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _enginesPanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _heading('ENGINES'),
          const SizedBox(height: 8),
          if (_capabilities.engines.isEmpty)
            const Text(
              'No engines reported.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          for (final String engine in _capabilities.engines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                engine == _capabilities.defaultEngine
                    ? '$engine   (default)'
                    : engine,
                style: TextStyle(
                  color: engine == _capabilities.defaultEngine
                      ? const Color(0xFF4FC3F7)
                      : Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '${_capabilities.languages.length} languages, '
            '${_capabilities.voices.length} voices total, '
            '${_capabilities.voicesForLanguagePrefix('en').length} English.',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _voicePanel() {
    final List<ProbedVoice> voices = _visibleVoices;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _heading('VOICE'),
          const SizedBox(height: 8),
          if (voices.isEmpty)
            const Text(
              'No voices to choose from.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          if (voices.isNotEmpty)
            DropdownButton<ProbedVoice>(
              value: voices.contains(_selectedVoice)
                  ? _selectedVoice
                  : voices.first,
              isExpanded: true,
              dropdownColor: const Color(0xFF1C2228),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: _onVoiceChanged,
              items: voices
                  .map(
                    (ProbedVoice v) => DropdownMenuItem<ProbedVoice>(
                      value: v,
                      child: Text('${v.name}  —  ${v.locale}'),
                    ),
                  )
                  .toList(growable: false),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _englishOnly,
            onChanged: (bool v) => setState(() => _englishOnly = v),
            title: const Text(
              'English voices only',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          _slider(
            label: 'Rate',
            value: _rate,
            min: 0.1,
            max: 1.0,
            onChanged: (double v) => setState(() => _rate = v),
          ),
          _slider(
            label: 'Pitch',
            value: _pitch,
            min: 0.5,
            max: 2.0,
            onChanged: (double v) => setState(() => _pitch = v),
          ),
          const SizedBox(height: 4),
          const Text(
            'Higher pitch is the usual workaround for the absence of genuine '
            'child voices. Judge whether it sounds like a child or merely like '
            'a distorted adult.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _phrasePanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _heading('AUDITION'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _testPhrases
                .map(
                  (String phrase) => FilledButton(
                    onPressed: () => _speak(phrase),
                    child: Text(phrase),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(2),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _heading(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 11,
        letterSpacing: 2,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC161B21),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}
