import 'package:flutter/services.dart';

import '../log.dart';

/// Physical display characteristics, needed to convert reported contact radii
/// into millimetres.
///
/// Flutter's `devicePixelRatio` on Android is derived from the *bucketed*
/// density (densityDpi / 160), not the panel's true physical DPI, so it is not
/// sufficient on its own for a physical-size calibration. This class reaches
/// through to `DisplayMetrics.xdpi` / `ydpi` for the real figures.
class DisplayMetrics {
  final double xdpi;
  final double ydpi;
  final double densityDpi;
  final double density;
  final int widthPixels;
  final int heightPixels;
  final String deviceModel;
  final String deviceManufacturer;
  final int androidSdkInt;

  const DisplayMetrics({
    required this.xdpi,
    required this.ydpi,
    required this.densityDpi,
    required this.density,
    required this.widthPixels,
    required this.heightPixels,
    required this.deviceModel,
    required this.deviceManufacturer,
    required this.androidSdkInt,
  });

  /// A safe placeholder used when the platform channel is unavailable, for
  /// example when running in a widget test or on an unsupported platform.
  static const DisplayMetrics unknown = DisplayMetrics(
    xdpi: 0,
    ydpi: 0,
    densityDpi: 0,
    density: 0,
    widthPixels: 0,
    heightPixels: 0,
    deviceModel: 'unknown',
    deviceManufacturer: 'unknown',
    androidSdkInt: 0,
  );

  bool get isUsable => xdpi > 0 && ydpi > 0;

  /// Physical screen width in millimetres, or 0 if unknown.
  double get widthMillimetres {
    if (isUsable == false) {
      return 0;
    }

    return widthPixels / xdpi * 25.4;
  }

  /// Physical screen height in millimetres, or 0 if unknown.
  double get heightMillimetres {
    if (isUsable == false) {
      return 0;
    }

    return heightPixels / ydpi * 25.4;
  }

  static const MethodChannel _channel = MethodChannel(
    'dev.kylesvoice.touch_spike/display',
  );

  /// Fetches display metrics from the host platform.
  ///
  /// Never throws: returns [unknown] if the channel is missing or errors, so a
  /// capture session is still possible (millimetre columns will simply be
  /// empty) rather than the app failing to start.
  static Future<DisplayMetrics> fetch() async {
    Log.enter('DisplayMetrics.fetch');

    try {
      final Map<Object?, Object?>? raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('getDisplayMetrics');

      if (raw == null) {
        Log.warn(
          'DisplayMetrics.fetch',
          'channel returned null, using unknown',
        );
        Log.exit('DisplayMetrics.fetch', 'result=unknown');
        return unknown;
      }

      final DisplayMetrics metrics = DisplayMetrics(
        xdpi: _toDouble(raw['xdpi']),
        ydpi: _toDouble(raw['ydpi']),
        densityDpi: _toDouble(raw['densityDpi']),
        density: _toDouble(raw['density']),
        widthPixels: _toInt(raw['widthPixels']),
        heightPixels: _toInt(raw['heightPixels']),
        deviceModel: _toString(raw['model']),
        deviceManufacturer: _toString(raw['manufacturer']),
        androidSdkInt: _toInt(raw['sdkInt']),
      );

      Log.step(
        'DisplayMetrics.fetch',
        'device=${metrics.deviceManufacturer} ${metrics.deviceModel} '
            'sdk=${metrics.androidSdkInt} xdpi=${metrics.xdpi} ydpi=${metrics.ydpi} '
            'densityDpi=${metrics.densityDpi} '
            'pixels=${metrics.widthPixels}x${metrics.heightPixels}',
      );

      Log.exit('DisplayMetrics.fetch', 'usable=${metrics.isUsable}');
      return metrics;
    } on MissingPluginException catch (e) {
      Log.warn('DisplayMetrics.fetch', 'platform channel unavailable: $e');
      Log.exit('DisplayMetrics.fetch', 'result=unknown');
      return unknown;
    } catch (e, stack) {
      Log.error('DisplayMetrics.fetch', 'unexpected failure', e, stack);
      Log.exit('DisplayMetrics.fetch', 'result=unknown');
      return unknown;
    }
  }

  static double _toDouble(Object? value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return 0;
  }

  static int _toInt(Object? value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  static String _toString(Object? value) {
    if (value == null) {
      return 'unknown';
    }

    return value.toString();
  }
}
