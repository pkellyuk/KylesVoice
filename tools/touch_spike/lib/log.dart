import 'dart:developer' as developer;

/// Central logging for the touch spike.
///
/// Every log line is emitted through `dart:developer`, which surfaces in
/// `adb logcat` under the `flutter` tag, so a session can be diagnosed from a
/// host machine without attaching a debugger.
///
/// NOTE ON THE HOT PATH: this spike exists to measure touch timing (slap
/// bounce intervals, activation latency). Logging inside the pointer handler
/// at input frequency would distort exactly those measurements. Pointer-level
/// logging is therefore gated behind [verbose], which defaults to off and is
/// toggleable from the capture screen. All non-hot-path functions log entry and
/// exit unconditionally.
class Log {
  /// Enables per-pointer-event logging. Off by default: see class docs.
  static bool verbose = false;

  static const String _name = 'touch_spike';

  /// Logs entry to a function.
  static void enter(String function, [String detail = '']) {
    if (function.isEmpty) {
      return;
    }

    _emit('ENTER $function${detail.isEmpty ? '' : ' | $detail'}');
  }

  /// Logs exit from a function.
  static void exit(String function, [String detail = '']) {
    if (function.isEmpty) {
      return;
    }

    _emit('EXIT  $function${detail.isEmpty ? '' : ' | $detail'}');
  }

  /// Logs an intermediate logical step.
  static void step(String function, String detail) {
    if (function.isEmpty) {
      return;
    }

    _emit('STEP  $function${detail.isEmpty ? '' : ' | $detail'}');
  }

  /// Logs a warning. Always emitted regardless of [verbose].
  static void warn(String function, String detail) {
    if (function.isEmpty) {
      return;
    }

    _emit('WARN  $function${detail.isEmpty ? '' : ' | $detail'}');
  }

  /// Logs an error, with optional exception and stack trace.
  static void error(
    String function,
    String detail, [
    Object? cause,
    StackTrace? stack,
  ]) {
    if (function.isEmpty) {
      return;
    }

    developer.log(
      'ERROR $function | $detail',
      name: _name,
      error: cause,
      stackTrace: stack,
      level: 1000,
    );
  }

  /// Logs a hot-path (per pointer event) message. Suppressed unless [verbose].
  static void hot(String function, String detail) {
    if (verbose == false) {
      return;
    }

    if (function.isEmpty) {
      return;
    }

    _emit('HOT   $function${detail.isEmpty ? '' : ' | $detail'}');
  }

  static void _emit(String message) {
    developer.log(message, name: _name);
  }
}
