/// Platform-free core logic for Kyle's Voice.
///
/// This package has no Flutter dependency by design. The hardest and most
/// safety-critical logic in the app — deciding which card a contact activates —
/// lives here so it can be tested exhaustively and headlessly, with no device
/// attached and no emulator running.
library;

export 'src/geometry/contact_ellipse.dart';
export 'src/geometry/ellipse_overlap.dart';
export 'src/geometry/primitives.dart';
export 'src/grid/grid_geometry.dart';
export 'src/touch/composite_contact.dart';
export 'src/touch/contact_coalescer.dart';
export 'src/touch/resolver_config.dart';
export 'src/touch/touch_resolver.dart';
