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

  const CardTile({
    super.key,
    required this.card,
    required this.isFlashing,
    this.showOutline = false,
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
                // Scale the artwork to whatever room is left after the label,
                // rather than assuming a fixed proportion. Cell sizes vary
                // enormously between an 8-inch tablet and a phone, and a card
                // that overflows is a card whose picture is cut off.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      resolved.glyph,
                      style: const TextStyle(fontSize: 96),
                    ),
                  ),
                ),
                SizedBox(height: constraints.maxHeight * 0.03),
                // Shown even though he cannot read: incidental exposure to print
                // alongside the image is standard practice and costs nothing.
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
}
