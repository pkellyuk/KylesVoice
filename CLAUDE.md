# Kyle's Voice — project conventions

These apply to this repository and override the global defaults where they
differ.

## Formatting

**Do not use Allman braces in this project.** Use each language's standard
style, enforced by its standard formatter:

- **Dart** — `dart format` (K&R). Run it before committing. Allman is not
  expressible in Dart: the formatter rewrites it unconditionally, so any Allman
  code would be reformatted on the next contributor's save.
- **Kotlin** — official Kotlin style (K&R). Allman is not merely unidiomatic
  here, it is a syntax error in places: a `{` on the line *after* a function
  call is parsed as a property access rather than a trailing lambda, which broke
  the `setMethodCallHandler` call in `MainActivity.kt` during initial
  development.

This is a deliberate, project-specific exception to the global Allman
preference, agreed because both toolchains actively fight it.

## Logging

Log on entry and exit of every function, and at intermediate logical steps,
including detail useful for debugging. Use the `Log` helper in each package
(`lib/log.dart` in Dart, `android.util.Log` in Kotlin), which routes to
`adb logcat`.

**Exception: the input hot path.** Pointer-event handlers run at input
frequency, and logging inside them distorts the touch latency and slap-bounce
timings this project measures. Hot-path logging goes through `Log.hot`, gated
behind a runtime `Log.verbose` flag that defaults to off. Everything else logs
unconditionally.

## Null handling and control flow

- Null-check every parameter on entry unless null is explicitly permitted.
- Guard clauses only: check the null/negative case and return early rather than
  nesting the happy path inside an `if`. Keep indentation shallow.

## Platform discipline

Android is the delivery target; iOS must remain *possible*. See
`docs/DESIGN.md` section 11.2. In short: no Android-only dependency without a
verified iOS equivalent, platform specifics behind interfaces, and the touch
resolver consumes a normalised contact-ellipse struct rather than raw
`MotionEvent` fields.

## Testing

The stack was chosen so that logic is testable headlessly on a development
machine with no device attached. Keep it that way:

- Core logic belongs in a pure Dart package with no Flutter dependency.
- Touch behaviour is tested with synthesised `PointerEvent`s carrying explicit
  `radiusMajor` / `radiusMinor` / `pressure`. See
  `tools/touch_spike/test/touch_spike_test.dart` for the pattern.
- `flutter analyze` must be clean and `flutter test` green before committing.

## Non-negotiables

No advertising, analytics, telemetry, tracking, accounts, in-app purchases, or
paid tiers. No proprietary symbol sets. The app must work fully offline.
