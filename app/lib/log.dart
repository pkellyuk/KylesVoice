import 'dart:developer' as developer;

/// Central logging, surfacing in `adb logcat` under the `flutter` tag so a
/// session on a real device can be diagnosed from a host machine.
///
/// Pointer-level logging is gated behind [verbose] and defaults to off, because
/// logging at input frequency distorts the touch timings the resolver depends
/// on. Everything else logs unconditionally.
class Log {
  static bool verbose = false;

  static const String _name = 'kylesvoice';

  static void enter(String function, [String detail = '']) {
    if (function.isEmpty) {
      return;
    }

    _emit('ENTER $function${detail.isEmpty ? '' : ' | $detail'}');
  }

  static void exit(String function, [String detail = '']) {
    if (function.isEmpty) {
      return;
    }

    _emit('EXIT  $function${detail.isEmpty ? '' : ' | $detail'}');
  }

  static void step(String function, String detail) {
    if (function.isEmpty) {
      return;
    }

    _emit('STEP  $function${detail.isEmpty ? '' : ' | $detail'}');
  }

  static void warn(String function, String detail) {
    if (function.isEmpty) {
      return;
    }

    _emit('WARN  $function${detail.isEmpty ? '' : ' | $detail'}');
  }

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

    // Also emitted through the release-visible path, with the cause, since
    // developer.log above produces nothing in a release build.
    _emit('ERROR $function | $detail${cause == null ? '' : ' | $cause'}');
  }

  /// Per-pointer-event logging. Suppressed unless [verbose].
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
    // print(), not developer.log(). dart:developer's log() is a no-op in
    // release builds, and release is what runs on Kyle's tablet, so every
    // entry/exit line would be invisible in exactly the build that matters.
    // print() reaches logcat under the "flutter" tag in both debug and release.
    //
    // Nothing here leaves the device: this is a local diagnostic channel, not
    // telemetry, and the app collects nothing.
    // ignore: avoid_print
    print('$_name: $message');
  }
}
