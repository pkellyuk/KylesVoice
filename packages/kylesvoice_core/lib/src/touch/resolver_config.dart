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
  ///
  /// Superseded in practice by contact coalescing, which is a better model of
  /// what the hardware reports. Retained because point mode on a device with a
  /// well-behaved single-touch driver still benefits from it, and because
  /// switch-driven activation has no use for coalescing at all.
  final bool multiTouchLockout;

  /// Contacts landing within this many milliseconds of each other are treated
  /// as one composite act rather than as separate activations.
  ///
  /// Measurement drove the default: a single slap produced six contacts spread
  /// over 16 ms. Fifty milliseconds gives comfortable margin without being long
  /// enough to merge two deliberate taps.
  final int coalesceWindowMillis;

  /// At or above this many simultaneous contacts, a composite is considered a
  /// palm rather than a deliberate point.
  ///
  /// Concurrent contact count proved the most reliable palm indicator in the
  /// capture data: six contacts inside 16 ms for a slap, against one for
  /// deliberate tapping. It is far more dependable than any single contact's
  /// radius, which varied ninefold within one slap.
  final int palmContactCountThreshold;

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
    this.coalesceWindowMillis = 50,
    this.palmContactCountThreshold = 3,
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
    int? coalesceWindowMillis,
    int? palmContactCountThreshold,
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
      coalesceWindowMillis: coalesceWindowMillis ?? this.coalesceWindowMillis,
      palmContactCountThreshold:
          palmContactCountThreshold ?? this.palmContactCountThreshold,
    );
  }
}
