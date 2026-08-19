import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

/// One cell, occupied or empty.
///
/// An empty cell renders as a faint outline rather than as nothing. That is
/// deliberate: vocabulary grows by filling empty cells, and a gap that is
/// visible now is a gap that will hold the same position when it is filled. The
/// board must never collapse or reflow.
class CardTile extends StatelessWidget {
  final BoardCard? card;
  final bool isFlashing;
  final bool showOutline;

  /// Absolute path of the board's media directory, used to resolve the relative
  /// file name a card stores. Null when storage is unavailable, in which case
  /// cards fall back to their symbol.
  final String? mediaDirectory;

  const CardTile({
    super.key,
    required this.card,
    required this.isFlashing,
    this.showOutline = false,
    this.mediaDirectory,
  });

  @override
  Widget build(BuildContext context) {
    final BoardCard? resolved = card;

    if (resolved == null) {
      return _buildEmpty();
    }

    return _buildCard(resolved);
  }

  Widget _buildEmpty() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: showOutline
              ? const Color(0x33FFFFFF)
              : const Color(0x14FFFFFF),
        ),
      ),
    );
  }

  Widget _buildCard(BoardCard resolved) {
    return AnimatedContainer(
      // Short and plain. Feedback must be immediate and unambiguous; flourishes
      // add latency and distract.
      duration: const Duration(milliseconds: 90),
      decoration: BoxDecoration(
        color: isFlashing
            ? Color.lerp(Color(resolved.colourArgb), Colors.white, 0.45)
            : Color(resolved.colourArgb),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFlashing ? Colors.white : const Color(0x22000000),
          width: isFlashing ? 4 : 2,
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double labelSize = (constraints.maxHeight * 0.12).clamp(
            11.0,
            30.0,
          );

          return Padding(
            padding: EdgeInsets.all(constraints.maxHeight * 0.06),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(child: _buildArtwork(resolved)),
                SizedBox(height: constraints.maxHeight * 0.03),
                // Shown even for a non-reading user: incidental exposure to
                // print alongside the image is standard practice and costs
                // nothing.
                Text(
                  resolved.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: labelSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: const <Shadow>[
                      Shadow(color: Color(0x66000000), blurRadius: 3),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Draws the photograph, the symbol, or both, according to the card's mode.
  ///
  /// The blend mode supports a deliberate clinical progression: a card can begin
  /// as a photograph of the child's own cup and shift over weeks toward the
  /// abstract symbol for "drink", so the concept generalises beyond that one
  /// object — without the card ever changing position or label.
  Widget _buildArtwork(BoardCard resolved) {
    final Widget symbol = _buildSymbol(resolved);
    final Widget? photo = _buildPhoto(resolved);

    if (photo == null) {
      return symbol;
    }

    if (resolved.effectiveImageMode == ImageMode.both) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Expanded(child: photo),
          const SizedBox(width: 6),
          Expanded(child: symbol),
        ],
      );
    }

    return Stack(
      fit: StackFit.passthrough,
      alignment: Alignment.center,
      children: <Widget>[
        Opacity(opacity: resolved.photoOpacity, child: photo),
        Opacity(opacity: resolved.symbolOpacity, child: symbol),
      ],
    );
  }

  Widget _buildSymbol(BoardCard resolved) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        resolved.glyph.isEmpty ? ' ' : resolved.glyph,
        style: const TextStyle(fontSize: 96),
      ),
    );
  }

  /// Returns null when there is no photograph or it cannot be located.
  ///
  /// A missing file falls back to the symbol rather than showing a broken
  /// image: a card that still says the right word is far better than one that
  /// looks broken to a child who cannot ask why.
  Widget? _buildPhoto(BoardCard resolved) {
    if (resolved.hasPhoto == false) {
      return null;
    }

    final String? directory = mediaDirectory;

    if (directory == null) {
      return null;
    }

    final File file = File(
      '$directory${Platform.pathSeparator}${resolved.photoFile.trim()}',
    );

    if (file.existsSync() == false) {
      return null;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return _buildSymbol(resolved);
        },
      ),
    );
  }
}
