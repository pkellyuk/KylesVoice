import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../log.dart';
import '../models/touch_sample.dart';
import 'display_metrics.dart';
import 'session_recorder.dart';

/// The outcome of writing a session to disk.
class ExportResult {
  final bool success;
  final String path;
  final int rowsWritten;
  final String message;

  const ExportResult({
    required this.success,
    required this.path,
    required this.rowsWritten,
    required this.message,
  });
}

/// Writes capture sessions to CSV on external app storage.
///
/// The target directory is the app's own external files directory, which is
/// readable over `adb pull` without root and without any runtime storage
/// permission. That matters: it means capture data can be retrieved from the
/// tablet by a developer over USB, or shared out by a parent via the share
/// sheet, with no permission prompts to navigate.
class SessionStore {
  /// Writes [recorder]'s samples to a timestamped CSV file.
  ///
  /// Never throws: failures are reported through [ExportResult] so the capture
  /// UI can show them without losing the in-memory session.
  static Future<ExportResult> exportCsv({
    required SessionRecorder? recorder,
    required DisplayMetrics? metrics,
    required double devicePixelRatio,
  }) async {
    Log.enter('SessionStore.exportCsv');

    if (recorder == null) {
      Log.warn('SessionStore.exportCsv', 'null recorder');
      Log.exit('SessionStore.exportCsv', 'success=false');
      return const ExportResult(
        success: false,
        path: '',
        rowsWritten: 0,
        message: 'No session to export.',
      );
    }

    if (recorder.sampleCount == 0) {
      Log.warn('SessionStore.exportCsv', 'nothing captured');
      Log.exit('SessionStore.exportCsv', 'success=false');
      return const ExportResult(
        success: false,
        path: '',
        rowsWritten: 0,
        message: 'Nothing captured yet.',
      );
    }

    final DisplayMetrics resolved = metrics ?? DisplayMetrics.unknown;

    try {
      final Directory? directory = await _resolveDirectory();

      if (directory == null) {
        Log.error('SessionStore.exportCsv', 'no writable directory available');
        Log.exit('SessionStore.exportCsv', 'success=false');
        return const ExportResult(
          success: false,
          path: '',
          rowsWritten: 0,
          message: 'No writable storage directory found.',
        );
      }

      final String fileName = _fileNameFor(recorder);
      final File file = File(
        '${directory.path}${Platform.pathSeparator}$fileName',
      );

      Log.step('SessionStore.exportCsv', 'writing to ${file.path}');

      final StringBuffer buffer = StringBuffer();
      buffer.writeln(_metadataComment(recorder: recorder, metrics: resolved));
      buffer.writeln(TouchSample.csvHeader);

      for (final TouchSample sample in recorder.samples) {
        buffer.writeln(
          sample.toCsvRow(
            sessionId: recorder.sessionId,
            sessionLabel: recorder.label,
            devicePixelRatio: devicePixelRatio,
            xdpi: resolved.xdpi,
            ydpi: resolved.ydpi,
          ),
        );
      }

      await file.writeAsString(buffer.toString(), flush: true);

      Log.step('SessionStore.exportCsv', 'wrote ${recorder.sampleCount} rows');
      Log.exit('SessionStore.exportCsv', 'success=true path=${file.path}');

      return ExportResult(
        success: true,
        path: file.path,
        rowsWritten: recorder.sampleCount,
        message: 'Saved ${recorder.sampleCount} rows.',
      );
    } catch (e, stack) {
      Log.error('SessionStore.exportCsv', 'write failed', e, stack);
      Log.exit('SessionStore.exportCsv', 'success=false');
      return ExportResult(
        success: false,
        path: '',
        rowsWritten: 0,
        message: 'Export failed: $e',
      );
    }
  }

  /// Lists previously exported CSV files, newest first.
  static Future<List<File>> listExports() async {
    Log.enter('SessionStore.listExports');

    try {
      final Directory? directory = await _resolveDirectory();

      if (directory == null) {
        Log.exit('SessionStore.listExports', 'count=0 (no directory)');
        return <File>[];
      }

      final List<File> files = directory
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.toLowerCase().endsWith('.csv'))
          .toList();

      files.sort((File a, File b) => b.path.compareTo(a.path));

      Log.exit('SessionStore.listExports', 'count=${files.length}');
      return files;
    } catch (e, stack) {
      Log.error('SessionStore.listExports', 'listing failed', e, stack);
      Log.exit('SessionStore.listExports', 'count=0');
      return <File>[];
    }
  }

  static Future<Directory?> _resolveDirectory() async {
    if (Platform.isAndroid) {
      final Directory? external = await getExternalStorageDirectory();

      if (external != null) {
        if (external.existsSync() == false) {
          external.createSync(recursive: true);
        }

        return external;
      }

      Log.warn(
        'SessionStore._resolveDirectory',
        'external storage null, falling back',
      );
    }

    return getApplicationDocumentsDirectory();
  }

  static String _fileNameFor(SessionRecorder recorder) {
    final DateTime t = recorder.startedAt;
    final String stamp =
        '${t.year.toString().padLeft(4, '0')}'
        '${t.month.toString().padLeft(2, '0')}'
        '${t.day.toString().padLeft(2, '0')}_'
        '${t.hour.toString().padLeft(2, '0')}'
        '${t.minute.toString().padLeft(2, '0')}'
        '${t.second.toString().padLeft(2, '0')}';

    final String safeLabel = recorder.label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (safeLabel.isEmpty) {
      return 'touch_${stamp}_unlabelled.csv';
    }

    return 'touch_${stamp}_$safeLabel.csv';
  }

  static String _metadataComment({
    required SessionRecorder recorder,
    required DisplayMetrics metrics,
  }) {
    final SessionStats stats = recorder.computeStats();

    return '# touch_spike session=${recorder.sessionId} label="${recorder.label}" '
        'started=${recorder.startedAt.toIso8601String()} '
        'device="${metrics.deviceManufacturer} ${metrics.deviceModel}" '
        'sdk=${metrics.androidSdkInt} '
        'xdpi=${metrics.xdpi} ydpi=${metrics.ydpi} '
        'densityDpi=${metrics.densityDpi} density=${metrics.density} '
        'screenPx=${metrics.widthPixels}x${metrics.heightPixels} '
        'screenMm=${metrics.widthMillimetres.toStringAsFixed(1)}x'
        '${metrics.heightMillimetres.toStringAsFixed(1)} '
        'events=${stats.totalEvents} downs=${stats.downCount} '
        'maxConcurrentPointers=${stats.maxConcurrentPointers} '
        'anyRadiusReported=${stats.anyRadiusReported} '
        'radiusConstant=${stats.radiusIsConstant}';
  }
}
