import 'package:image_picker/image_picker.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

import '../log.dart';

/// The outcome of trying to attach a photograph to a card.
class PhotoResult {
  /// Stored file name, relative to the media directory. Empty if nothing was
  /// captured.
  final String fileName;

  /// Human-readable reason, empty on success or plain cancellation.
  final String failure;

  /// True when the parent backed out rather than anything going wrong.
  final bool cancelled;

  const PhotoResult({
    required this.fileName,
    this.failure = '',
    this.cancelled = false,
  });

  bool get succeeded => fileName.isNotEmpty;

  static const PhotoResult cancelledResult = PhotoResult(
    fileName: '',
    cancelled: true,
  );
}

/// Captures photographs and files them in the board's media store.
///
/// Personal photographs matter more than stock symbols for a first system: the
/// child's own cup, their own school, their own people. This is the shortest
/// path from "I want that on a card" to a card with it on.
///
/// Uses the system camera app rather than an embedded camera, so the app needs
/// no CAMERA permission and a parent never has to answer a permission prompt.
class PhotoService {
  final ImagePicker _picker = ImagePicker();

  /// Takes a photograph with the device camera and stores it.
  Future<PhotoResult> capture(MediaStore? store) async {
    Log.enter('PhotoService.capture');

    final PhotoResult result = await _pick(store, ImageSource.camera);

    Log.exit('PhotoService.capture', 'file=${result.fileName}');
    return result;
  }

  /// Chooses an existing photograph from the device gallery and stores it.
  Future<PhotoResult> choose(MediaStore? store) async {
    Log.enter('PhotoService.choose');

    final PhotoResult result = await _pick(store, ImageSource.gallery);

    Log.exit('PhotoService.choose', 'file=${result.fileName}');
    return result;
  }

  /// Never throws. A camera that misbehaves must not cost the parent the rest
  /// of the card they were editing.
  Future<PhotoResult> _pick(MediaStore? store, ImageSource source) async {
    if (store == null) {
      Log.warn('PhotoService._pick', 'no media store available');
      return const PhotoResult(
        fileName: '',
        failure: 'Photographs cannot be saved: storage is unavailable.',
      );
    }

    try {
      // Downscale at capture time. A full-resolution phone photograph is
      // several megabytes; this keeps a whole board small enough to email while
      // staying sharp on an 8-inch tablet.
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: MediaStore.maxEdgePixels.toDouble(),
        maxHeight: MediaStore.maxEdgePixels.toDouble(),
        imageQuality: 85,
      );

      if (picked == null) {
        Log.step('PhotoService._pick', 'cancelled by the user');
        return PhotoResult.cancelledResult;
      }

      Log.step('PhotoService._pick', 'picked ${picked.path}');

      final String fileName = await store.importFile(picked.path);

      if (fileName.isEmpty) {
        Log.warn('PhotoService._pick', 'import produced no file');
        return const PhotoResult(
          fileName: '',
          failure: 'The photograph could not be saved.',
        );
      }

      Log.step('PhotoService._pick', 'stored as $fileName');
      return PhotoResult(fileName: fileName);
    } catch (e, stack) {
      Log.error('PhotoService._pick', 'capture failed', e, stack);
      return PhotoResult(
        fileName: '',
        failure: 'Could not get a photograph: $e',
      );
    }
  }
}
