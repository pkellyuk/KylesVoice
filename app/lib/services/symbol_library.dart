import 'package:flutter/services.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

import '../log.dart';

/// Loads the bundled symbol set from assets.
///
/// The catalogue itself is platform-free and lives in the core package; this is
/// only the part that needs Flutter to read an asset. Kept as a singleton
/// because the index is a few hundred kilobytes and reparsing it every time the
/// picker opens would be visible on a low-end tablet.
class SymbolLibrary {
  static const String indexAsset = 'assets/symbols/index.json';
  static const String svgDirectory = 'assets/symbols/svg';

  static SymbolCatalog _catalog = SymbolCatalog.empty;
  static bool _loaded = false;
  static String _failure = '';

  static SymbolCatalog get catalog => _catalog;

  static bool get isLoaded => _loaded && _catalog.isEmpty == false;

  static String get failure => _failure;

  /// Asset path for a symbol file name.
  static String assetFor(String? fileName) {
    if (fileName == null) {
      return '';
    }

    if (fileName.trim().isEmpty) {
      return '';
    }

    return '$svgDirectory/${fileName.trim()}';
  }

  /// Loads the index once. Safe to call repeatedly.
  ///
  /// Never throws. If the set fails to load the picker says so and cards fall
  /// back to emoji, rather than the board becoming unusable.
  static Future<void> load() async {
    Log.enter('SymbolLibrary.load');

    if (_loaded) {
      Log.exit(
        'SymbolLibrary.load',
        'already loaded, ${_catalog.count} symbols',
      );
      return;
    }

    try {
      final String json = await rootBundle.loadString(indexAsset);
      _catalog = SymbolCatalog.parse(json);
      _loaded = true;

      if (_catalog.isEmpty) {
        _failure = 'The symbol index was readable but contained no symbols.';
        Log.warn('SymbolLibrary.load', _failure);
      } else {
        _failure = '';
      }

      Log.exit(
        'SymbolLibrary.load',
        '${_catalog.count} symbols, ${_catalog.categories.length} categories',
      );
    } catch (e, stack) {
      _loaded = true;
      _catalog = SymbolCatalog.empty;
      _failure = 'The symbol set could not be loaded: $e';

      Log.error('SymbolLibrary.load', 'index unavailable', e, stack);
      Log.exit('SymbolLibrary.load', 'empty');
    }
  }

  /// Test seam: resets the cached catalogue.
  static void resetForTest() {
    _catalog = SymbolCatalog.empty;
    _loaded = false;
    _failure = '';
  }
}
