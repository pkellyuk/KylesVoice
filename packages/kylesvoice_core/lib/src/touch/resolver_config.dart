/// How a contact is mapped to a cell.
enum TouchMode {
  /// Hit-test the reported centre point only.
  point,

  /// Resolve by contact area: activate the cell the patch mostly covers.
  palm,

  /// Choose per touch from the reported contact size.
  auto,
}

/// What to do when two cells are covered near-equally.
enum AmbiguityPolicy {
  /// Activate the larger overlap anyway. Biased toward always giving the child
  /// a voice, at the cost of occasionally saying the wrong word.
  nearest,

  /// Activate nothing. Safer, but silence in response to a deliberate reach can
  /// itself be distressing.
  ignore,
}

/// Tunable parameters for touch resolution.
///
/// Every default here is provisional until real capture data exists. They are
/// deliberately gathered in one place so they can be set per user profile, and
/// so a device calibration can be applied without touching the resolver.
class ResolverConfig {
  final TouchMode mode;
  final AmbiguityPolicy ambiguityPolicy;

  /// Two cells are ambiguous when the runner-up's overlap is within this
  /// fraction of the winner's.
  final double ambiguityThreshold;

  /// A contact must cover at least this fraction of a cell's area, or this
  /// fraction of its own area, before it counts as landing there at all. Stops a
  /// grazing edge contact activating a card.
  final double minimumOverlapFraction;

  /// Milliseconds after an activation during which nothing else may activate.
  /// Suppresses the repeat contacts a slap produces as the hand settles.
  final int lockoutMillis;

  /// Milliseconds a contact must be held before it arms. Zero disables dwell.
  final int dwellMillis;

  /// Radius in logical pixels assumed when the platform reports no usable
  /// contact size.
  final double fallbackRadius;

  /// Multiplier converting the platform's reported contact size into logical
  /// pixels. Derived per device from captured data, because many Android touch
  /// drivers report in device-specific units rather than pixels.
  final double calibrationScale;

  /// Above this reported radius, [TouchMode.auto] treats a contact as a palm.
  final double autoPalmRadiusThreshold;

  /// Whether additional pointers landing while one is already down are ignored.
  /// A palm slap routinely registers several within milliseconds.
  final bool multiTouchLockout;

  const ResolverConfig({
    this.mode = TouchMode.palm,
    this.ambiguityPolicy = AmbiguityPolicy.nearest,
    this.ambiguityThreshold = 0.15,
    this.minimumOverlapFraction = 0.05,
    this.lockoutMillis = 800,
    this.dwellMillis = 0,
    this.fallbackRadius = 48,
    this.calibrationScale = 1.0,
    this.autoPalmRadiusThreshold = 30,
    this.multiTouchLockout = true,
  });

  /// Kyle's provisional starting configuration. See DESIGN.md section 12.
  static const ResolverConfig kyle = ResolverConfig(
    mode: TouchMode.palm,
    ambiguityPolicy: AmbiguityPolicy.nearest,
    ambiguityThreshold: 0.15,
    lockoutMillis: 800,
    dwellMillis: 0,
  );

  ResolverConfig copyWith({
    TouchMode? mode,
    AmbiguityPolicy? ambiguityPolicy,
    double? ambiguityThreshold,
    double? minimumOverlapFraction,
    int? lockoutMillis,
    int? dwellMillis,
    double? fallbackRadius,
    double? calibrationScale,
    double? autoPalmRadiusThreshold,
    bool? multiTouchLockout,
  }) {
    return ResolverConfig(
      mode: mode ?? this.mode,
      ambiguityPolicy: ambiguityPolicy ?? this.ambiguityPolicy,
      ambiguityThreshold: ambiguityThreshold ?? this.ambiguityThreshold,
      minimumOverlapFraction:
          minimumOverlapFraction ?? this.minimumOverlapFraction,
      lockoutMillis: lockoutMillis ?? this.lockoutMillis,
      dwellMillis: dwellMillis ?? this.dwellMillis,
      fallbackRadius: fallbackRadius ?? this.fallbackRadius,
      calibrationScale: calibrationScale ?? this.calibrationScale,
      autoPalmRadiusThreshold:
          autoPalmRadiusThreshold ?? this.autoPalmRadiusThreshold,
      multiTouchLockout: multiTouchLockout ?? this.multiTouchLockout,
    );
  }
}
