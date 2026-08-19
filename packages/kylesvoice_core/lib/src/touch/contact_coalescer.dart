import '../geometry/contact_ellipse.dart';
import 'composite_contact.dart';

/// Gathers contacts that land together into a single [CompositeContact].
///
/// A hand landing on the glass produces several pointers within a few
/// milliseconds. Measurement showed six contacts spread over 16 ms for a single
/// slap. Treating those as six separate activations would fire six words; taking
/// only the first would aim at whichever fingertip happened to register first.
/// Coalescing them into one composite is the only model that matches what the
/// hardware actually reports.
///
/// Deliberately free of timers. Emission is driven by incoming events, or by an
/// explicit [flush] the host calls when its own timer expires. That keeps the
/// class a pure function of its inputs and exhaustively testable, which matters
/// for something on the path between a child and their voice.
class ContactCoalescer {
  /// Contacts arriving within this many milliseconds of the cluster's first
  /// contact join that cluster.
  final int windowMillis;

  final List<ClusteredContact> _pending = <ClusteredContact>[];
  int? _clusterStartMillis;

  ContactCoalescer({this.windowMillis = 50});

  bool get hasPending => _pending.isNotEmpty;

  int get pendingCount => _pending.length;

  /// When the currently accumulating cluster began, or null if none.
  int? get pendingSinceMillis => _clusterStartMillis;

  /// The timestamp at which the pending cluster is ready to emit, or null.
  ///
  /// The host uses this to schedule its flush, so a single slow finger cannot
  /// hold an utterance back indefinitely.
  int? get readyAtMillis {
    final int? start = _clusterStartMillis;

    if (start == null) {
      return null;
    }

    return start + windowMillis;
  }

  /// Offers a contact to the coalescer.
  ///
  /// Returns a completed composite when this contact fell outside the current
  /// window and therefore closed the previous cluster; otherwise null, meaning
  /// the contact joined the cluster still being assembled.
  CompositeContact? add({
    required ContactEllipse? contact,
    required int pointerId,
    required int timestampMillis,
  }) {
    if (contact == null) {
      return null;
    }

    final int? start = _clusterStartMillis;

    if (start == null) {
      _startCluster(
        contact: contact,
        pointerId: pointerId,
        timestampMillis: timestampMillis,
      );
      return null;
    }

    if (timestampMillis - start <= windowMillis) {
      _pending.add(
        ClusteredContact(
          ellipse: contact,
          pointerId: pointerId,
          timestampMillis: timestampMillis,
        ),
      );
      return null;
    }

    // This contact belongs to a new act. Close the previous one and open the
    // next in the same step, so no contact is ever dropped.
    final CompositeContact completed = CompositeContact(
      contacts: List<ClusteredContact>.unmodifiable(_pending),
    );

    _pending.clear();
    _startCluster(
      contact: contact,
      pointerId: pointerId,
      timestampMillis: timestampMillis,
    );

    return completed;
  }

  /// Emits the pending cluster if its window has elapsed by [timestampMillis].
  ///
  /// Returns null when nothing is pending or the window is still open.
  CompositeContact? flushIfReady(int timestampMillis) {
    final int? ready = readyAtMillis;

    if (ready == null) {
      return null;
    }

    if (timestampMillis < ready) {
      return null;
    }

    return flush();
  }

  /// Emits the pending cluster immediately, regardless of its window.
  ///
  /// Returns null when nothing is pending.
  CompositeContact? flush() {
    if (_pending.isEmpty) {
      _clusterStartMillis = null;
      return null;
    }

    final CompositeContact completed = CompositeContact(
      contacts: List<ClusteredContact>.unmodifiable(_pending),
    );

    _pending.clear();
    _clusterStartMillis = null;

    return completed;
  }

  /// Discards anything pending without emitting it.
  void reset() {
    _pending.clear();
    _clusterStartMillis = null;
  }

  void _startCluster({
    required ContactEllipse contact,
    required int pointerId,
    required int timestampMillis,
  }) {
    _clusterStartMillis = timestampMillis;
    _pending.add(
      ClusteredContact(
        ellipse: contact,
        pointerId: pointerId,
        timestampMillis: timestampMillis,
      ),
    );
  }
}
