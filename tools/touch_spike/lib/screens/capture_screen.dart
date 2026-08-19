import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../log.dart';
import '../models/touch_sample.dart';
import '../services/display_metrics.dart';
import '../services/session_recorder.dart';
import '../services/session_store.dart';
import '../widgets/contact_painter.dart';
import 'tts_screen.dart';

/// The capture surface.
///
/// A full-screen [Listener] rather than a [GestureDetector]: gesture
/// recognisers arbitrate and discard raw pointer data, and raw pointer data is
/// the entire product of this spike.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  /// Preset labels, so a capture run can be tagged on the device without typing.
  static const List<String> _labels = <String>[
    'slap',
    'point',
    'mixed',
    'calibration',
  ];

  /// How many recent touch-down points to keep in the visual trail.
  static const int _trailLength = 40;

  /// Assumed contact radius in logical pixels, used for drawing only when the
  /// device reports nothing usable.
  static const double _fallbackRadius = 48;

  late SessionRecorder _recorder;
  DisplayMetrics _metrics = DisplayMetrics.unknown;

  final Map<int, TouchSample> _liveContacts = <int, TouchSample>{};
  final List<TouchSample> _trail = <TouchSample>[];

  String _label = _labels.first;
  bool _verboseLogging = false;
  String _statusMessage = 'Ready. Touch anywhere to start capturing.';
  String _lastExportPath = '';

  /// True on screens too small for the tablet-sized overlays. Set during build
  /// from the actual constraints, and used to shrink type and padding.
  bool _compact = false;

  @override
  void initState() {
    Log.enter('_CaptureScreenState.initState');
    super.initState();

    _recorder = SessionRecorder(sessionId: _newSessionId(), label: _label);
    _loadDisplayMetrics();

    Log.exit(
      '_CaptureScreenState.initState',
      'sessionId=${_recorder.sessionId}',
    );
  }

  String _newSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  }

  Future<void> _loadDisplayMetrics() async {
    Log.enter('_CaptureScreenState._loadDisplayMetrics');

    final DisplayMetrics metrics = await DisplayMetrics.fetch();

    if (mounted == false) {
      Log.exit(
        '_CaptureScreenState._loadDisplayMetrics',
        'unmounted, discarding',
      );
      return;
    }

    setState(() {
      _metrics = metrics;
    });

    Log.exit(
      '_CaptureScreenState._loadDisplayMetrics',
      'usable=${metrics.isUsable}',
    );
  }

  /// Hot path. Deliberately minimal: record, update live state, repaint.
  void _onPointerEvent(PointerEvent? event) {
    if (event == null) {
      return;
    }

    final TouchSample? sample = _recorder.record(event);

    if (sample == null) {
      return;
    }

    setState(() {
      if (sample.phase == TouchPhase.up || sample.phase == TouchPhase.cancel) {
        _liveContacts.remove(sample.pointerId);
        return;
      }

      _liveContacts[sample.pointerId] = sample;

      if (sample.phase == TouchPhase.down) {
        _trail.add(sample);

        while (_trail.length > _trailLength) {
          _trail.removeAt(0);
        }
      }
    });
  }

  Future<void> _export() async {
    Log.enter(
      '_CaptureScreenState._export',
      'samples=${_recorder.sampleCount}',
    );

    final double ratio = MediaQuery.of(context).devicePixelRatio;

    final ExportResult result = await SessionStore.exportCsv(
      recorder: _recorder,
      metrics: _metrics,
      devicePixelRatio: ratio,
    );

    if (mounted == false) {
      Log.exit('_CaptureScreenState._export', 'unmounted');
      return;
    }

    setState(() {
      _statusMessage = result.success
          ? '${result.message}\n${result.path}'
          : result.message;
      _lastExportPath = result.path;
    });

    Log.exit(
      '_CaptureScreenState._export',
      'success=${result.success} path=${result.path}',
    );
  }

  /// Hands the most recent export to the system share sheet.
  ///
  /// Necessary because the export lands in the app's external files directory,
  /// which Android 11+ file managers cannot browse. Without this there is no
  /// practical way for a parent to get the capture off the tablet.
  Future<void> _shareLastExport() async {
    Log.enter('_CaptureScreenState._shareLastExport', 'path=$_lastExportPath');

    if (_lastExportPath.isEmpty) {
      Log.warn('_CaptureScreenState._shareLastExport', 'nothing exported yet');

      setState(() {
        _statusMessage = 'Export a CSV first, then share it.';
      });

      Log.exit('_CaptureScreenState._shareLastExport', 'aborted');
      return;
    }

    try {
      await Share.shareXFiles(
        <XFile>[XFile(_lastExportPath)],
        subject: 'Kyle\'s Voice touch capture',
        text: 'Touch geometry capture from the palm-mode spike.',
      );

      Log.exit('_CaptureScreenState._shareLastExport', 'share sheet dismissed');
    } catch (e, stack) {
      Log.error(
        '_CaptureScreenState._shareLastExport',
        'share failed',
        e,
        stack,
      );

      if (mounted == false) {
        return;
      }

      setState(() {
        _statusMessage = 'Share failed: $e';
      });

      Log.exit('_CaptureScreenState._shareLastExport', 'failed');
    }
  }

  void _reset() {
    Log.enter('_CaptureScreenState._reset');

    setState(() {
      _recorder = SessionRecorder(sessionId: _newSessionId(), label: _label);
      _liveContacts.clear();
      _trail.clear();
      _statusMessage = 'Session cleared. Touch anywhere to start capturing.';
    });

    Log.exit(
      '_CaptureScreenState._reset',
      'new sessionId=${_recorder.sessionId}',
    );
  }

  void _onLabelChanged(String? label) {
    Log.enter('_CaptureScreenState._onLabelChanged', 'label=$label');

    if (label == null) {
      Log.warn('_CaptureScreenState._onLabelChanged', 'null label ignored');
      Log.exit('_CaptureScreenState._onLabelChanged');
      return;
    }

    setState(() {
      _label = label;
      _recorder = SessionRecorder(sessionId: _newSessionId(), label: label);
      _liveContacts.clear();
      _trail.clear();
      _statusMessage = 'Started a new "$label" session.';
    });

    Log.exit(
      '_CaptureScreenState._onLabelChanged',
      'sessionId=${_recorder.sessionId}',
    );
  }

  /// Opens the speech-capability probe.
  ///
  /// Lives alongside touch capture so a single visit to the device answers both
  /// open hardware questions: can it measure a palm, and can it talk.
  Future<void> _openTtsCheck() async {
    Log.enter('_CaptureScreenState._openTtsCheck');

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const TtsScreen(),
      ),
    );

    Log.exit('_CaptureScreenState._openTtsCheck', 'returned to capture');
  }

  void _onVerboseChanged(bool? value) {
    Log.enter('_CaptureScreenState._onVerboseChanged', 'value=$value');

    if (value == null) {
      Log.warn('_CaptureScreenState._onVerboseChanged', 'null value ignored');
      Log.exit('_CaptureScreenState._onVerboseChanged');
      return;
    }

    setState(() {
      _verboseLogging = value;
      Log.verbose = value;
    });

    Log.exit('_CaptureScreenState._onVerboseChanged', 'verbose=$value');
  }

  @override
  Widget build(BuildContext context) {
    final SessionStats stats = _recorder.computeStats();

    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // The overlays were laid out for a tablet. On a phone in landscape
            // there is barely 350dp of height, so they must shrink and scroll
            // rather than collide with each other and hide the readouts.
            _compact =
                constraints.maxHeight < 560 || constraints.maxWidth < 900;

            final double panelWidth = _compact
                ? (constraints.maxWidth * 0.34).clamp(180.0, 300.0)
                : 330.0;

            // Leave room for the status bar along the bottom.
            final double panelMaxHeight = constraints.maxHeight - 130;

            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _onPointerEvent,
                    onPointerMove: _onPointerEvent,
                    onPointerUp: _onPointerEvent,
                    onPointerCancel: _onPointerEvent,
                    child: CustomPaint(
                      painter: ContactPainter(
                        live: _liveContacts.values.toList(growable: false),
                        trail: List<TouchSample>.unmodifiable(_trail),
                        fallbackRadius: _fallbackRadius,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: IgnorePointer(
                    child: _scrollable(
                      maxHeight: panelMaxHeight,
                      child: _buildStatsPanel(stats, panelWidth),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: _scrollable(
                    maxHeight: panelMaxHeight,
                    child: _buildControls(panelWidth),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: IgnorePointer(child: _buildStatusBar(stats)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Constrains a panel's height and lets it scroll, so a small screen shows
  /// all of the readout rather than clipping the bottom of it.
  Widget _scrollable({required double maxHeight, required Widget child}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight < 120 ? 120 : maxHeight),
      child: SingleChildScrollView(child: child),
    );
  }

  /// The live readout.
  ///
  /// This panel is wrapped in an [IgnorePointer] by its caller, because every
  /// touch must reach the capture surface underneath: a scrollable panel here
  /// would silently swallow the very events being measured. It therefore cannot
  /// scroll, so on a small screen it shows fewer rows instead of clipping them.
  /// The rows dropped in compact mode are the ones that do not change the
  /// verdict.
  Widget _buildStatsPanel(SessionStats stats, double width) {
    final Divider divider = Divider(
      color: Colors.white24,
      height: _compact ? 10 : 18,
    );

    return _panel(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'CAPTURE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: _compact ? 9 : 11,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: _compact ? 4 : 8),
          if (_compact == false)
            _row('Session', '${_recorder.sessionId}  (${_recorder.label})'),
          _row('Events', '${stats.totalEvents}'),
          _row('Downs / Ups', '${stats.downCount} / ${stats.upCount}'),
          if (_compact == false) _row('Moves', '${stats.moveCount}'),
          if (_compact == false) _row('Cancels', '${stats.cancelCount}'),
          _row('Max concurrent', '${stats.maxConcurrentPointers}'),
          divider,
          _row('radius min', stats.radiusMajorMin.toStringAsFixed(2)),
          _row('radius max', stats.radiusMajorMax.toStringAsFixed(2)),
          _row('radius mean', stats.radiusMajorMean.toStringAsFixed(2)),
          if (_compact == false)
            _row(
              'pressure',
              '${stats.pressureMin.toStringAsFixed(2)} - '
                  '${stats.pressureMax.toStringAsFixed(2)}',
            ),
          _row(
            'size',
            '${stats.sizeMin.toStringAsFixed(3)} - '
                '${stats.sizeMax.toStringAsFixed(3)}',
          ),
          divider,
          _row(
            'Device',
            _compact
                ? _metrics.deviceModel
                : '${_metrics.deviceManufacturer} ${_metrics.deviceModel}',
          ),
          _row(
            _compact ? 'dpi' : 'xdpi / ydpi',
            '${_metrics.xdpi.toStringAsFixed(1)} / ${_metrics.ydpi.toStringAsFixed(1)}',
          ),
          if (_compact == false)
            _row(
              'Screen px',
              '${_metrics.widthPixels} x ${_metrics.heightPixels}',
            ),
          _row(
            'Screen mm',
            '${_metrics.widthMillimetres.toStringAsFixed(0)} x '
                '${_metrics.heightMillimetres.toStringAsFixed(0)}',
          ),
          if (_compact == false)
            _row(
              'devicePixelRatio',
              MediaQuery.of(context).devicePixelRatio.toStringAsFixed(2),
            ),
        ],
      ),
    );
  }

  Widget _buildControls(double width) {
    return _panel(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'SESSION LABEL',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _label,
            isExpanded: true,
            dropdownColor: const Color(0xFF1C2228),
            style: const TextStyle(color: Colors.white, fontSize: 15),
            onChanged: _onLabelChanged,
            items: _labels
                .map(
                  (String l) =>
                      DropdownMenuItem<String>(value: l, child: Text(l)),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _export,
            icon: const Icon(Icons.save_alt),
            label: const Text('Export CSV'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _shareLastExport,
            icon: const Icon(Icons.ios_share),
            label: const Text('Share last export'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear session'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openTtsCheck,
            icon: const Icon(Icons.record_voice_over_outlined),
            label: const Text('Speech check'),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _verboseLogging,
            onChanged: _onVerboseChanged,
            title: const Text(
              'Verbose logcat',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: const Text(
              'Distorts timing. Off for real captures.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(SessionStats stats) {
    final Color verdictColour = _verdictColour(stats);

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            stats.verdict,
            style: TextStyle(
              color: verdictColour,
              fontSize: _compact ? 12 : 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: _compact ? 3 : 6),
          Text(
            _statusMessage,
            maxLines: _compact ? 2 : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white60,
              fontSize: _compact ? 10 : 12,
            ),
          ),
          if (stats.downToDownGapsMillis.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Gaps between downs (ms): ${_tail(stats.downToDownGapsMillis)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          if (stats.contactDurationsMillis.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Contact durations (ms): ${_tail(stats.contactDurationsMillis)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Color _verdictColour(SessionStats stats) {
    if (stats.totalEvents == 0) {
      return Colors.white54;
    }

    if (stats.anyRadiusReported == false) {
      return const Color(0xFFE57373);
    }

    if (stats.radiusIsConstant == true) {
      return const Color(0xFFFFB74D);
    }

    return const Color(0xFF81C784);
  }

  String _tail(List<int> values) {
    const int maxShown = 12;

    if (values.length <= maxShown) {
      return values.join(', ');
    }

    return values.sublist(values.length - maxShown).join(', ');
  }

  Widget _panel({required Widget child, double? width}) {
    return Container(
      width: width,
      padding: EdgeInsets.all(_compact ? 8 : 12),
      decoration: BoxDecoration(
        color: const Color(0xCC161B21),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _row(String label, String value) {
    final double fontSize = _compact ? 10 : 12;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: _compact ? 0.5 : 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _compact ? 96 : 130,
            child: Text(
              label,
              style: TextStyle(color: Colors.white54, fontSize: fontSize),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
