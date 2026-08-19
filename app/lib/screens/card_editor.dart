import 'package:flutter/material.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

import '../log.dart';

/// What the card editor was asked to do.
enum CardEditAction { save, delete, cancel }

class CardEditResult {
  final CardEditAction action;
  final BoardCard? card;

  const CardEditResult({required this.action, this.card});
}

/// Edits one card.
///
/// The spoken phrase is a separate field from the label throughout, because they
/// genuinely differ: a card reading "toilet" should usually say "I need the
/// toilet". Collapsing them would force a choice between a readable board and
/// natural speech.
class CardEditor extends StatefulWidget {
  final CellAddress address;
  final BoardCard? existing;

  const CardEditor({super.key, required this.address, this.existing});

  @override
  State<CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<CardEditor> {
  /// A small palette rather than a full colour picker. Fewer, clearly distinct
  /// choices are easier for a tired parent at 9pm, and keep boards legible.
  static const List<int> _palette = <int>[
    0xFF4FA3D1,
    0xFFD96C6C,
    0xFF6BA368,
    0xFFC08A3E,
    0xFF9B7EC4,
    0xFF4FB3A8,
    0xFFD98CB3,
    0xFF7A8794,
  ];

  /// Stand-ins until photo capture and the symbol library exist.
  static const List<String> _glyphs = <String>[
    '\u{1F964}',
    '\u{1F34E}',
    '\u{2795}',
    '\u{270B}',
    '\u{1F6BD}',
    '\u{1F198}',
    '\u{2705}',
    '\u{274C}',
    '\u{1F3B5}',
    '\u{1F4FA}',
    '\u{1F697}',
    '\u{1F3E0}',
    '\u{1F634}',
    '\u{1F60A}',
    '\u{1F622}',
    '\u{1F915}',
  ];

  late TextEditingController _label;
  late TextEditingController _speech;
  late TextEditingController _glyph;
  late int _colour;

  @override
  void initState() {
    Log.enter('_CardEditorState.initState', 'address=${widget.address}');
    super.initState();

    final BoardCard? existing = widget.existing;

    _label = TextEditingController(text: existing?.label ?? '');
    _speech = TextEditingController(text: existing?.speech ?? '');
    _glyph = TextEditingController(text: existing?.glyph ?? _glyphs.first);
    _colour = existing?.colourArgb ?? _palette.first;

    Log.exit('_CardEditorState.initState', 'editing=${existing != null}');
  }

  @override
  void dispose() {
    _label.dispose();
    _speech.dispose();
    _glyph.dispose();
    super.dispose();
  }

  void _save() {
    Log.enter('_CardEditorState._save');

    final String label = _label.text.trim();
    final String speech = _speech.text.trim();

    if (label.isEmpty && speech.isEmpty) {
      Log.warn('_CardEditorState._save', 'refused: nothing to say');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Give the card a word or a phrase before saving.'),
        ),
      );

      Log.exit('_CardEditorState._save', 'refused');
      return;
    }

    final BoardCard card = BoardCard(
      address: widget.address,
      label: label,
      speech: speech,
      glyph: _glyph.text.trim(),
      colourArgb: _colour,
    );

    Navigator.of(context)
        .pop(CardEditResult(action: CardEditAction.save, card: card));

    Log.exit('_CardEditorState._save', 'saved "${card.label}"');
  }

  Future<void> _delete() async {
    Log.enter('_CardEditorState._delete');

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2228),
        title: const Text(
          'Remove this card?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'The cell stays empty and keeps its place, so the card can be put '
          'back in the same position later.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      Log.exit('_CardEditorState._delete', 'cancelled');
      return;
    }

    if (mounted == false) {
      Log.exit('_CardEditorState._delete', 'unmounted');
      return;
    }

    Navigator.of(context)
        .pop(const CardEditResult(action: CardEditAction.delete));

    Log.exit('_CardEditorState._delete', 'deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1216),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B21),
        title: Text(
          widget.existing == null
              ? 'New card (row ${widget.address.row + 1}, '
                    'column ${widget.address.col + 1})'
              : 'Edit "${widget.existing!.label}"',
        ),
        actions: <Widget>[
          if (widget.existing != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove card',
            ),
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.check),
            tooltip: 'Save',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _preview(),
          const SizedBox(height: 20),
          _field(
            controller: _label,
            label: 'Word on the card',
            hint: 'drink',
            helper:
                'Shown on the card. Kept short so it fits and stays readable.',
          ),
          const SizedBox(height: 16),
          _field(
            controller: _speech,
            label: 'What it says out loud',
            hint: 'I want a drink',
            helper:
                'Leave blank to speak the word above. A card reading "toilet" '
                'usually wants to say "I need the toilet".',
          ),
          const SizedBox(height: 20),
          _sectionLabel('PICTURE'),
          const SizedBox(height: 8),
          _field(
            controller: _glyph,
            label: 'Symbol',
            hint: '\u{1F964}',
            helper:
                'Photographs and a symbol library are coming; for now, '
                'pick one below or type any emoji.',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _glyphs
                .map(
                  (String glyph) => InkWell(
                    onTap: () => setState(() => _glyph.text = glyph),
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _glyph.text == glyph
                              ? Colors.white
                              : Colors.white24,
                          width: _glyph.text == glyph ? 2 : 1,
                        ),
                      ),
                      child: Text(glyph, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 20),
          _sectionLabel('COLOUR'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _palette
                .map(
                  (int colour) => InkWell(
                    onTap: () => setState(() => _colour = colour),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Color(colour),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _colour == colour
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _preview() {
    return Center(
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          color: Color(_colour),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x22000000), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _glyph.text.isEmpty ? ' ' : _glyph.text,
                  style: const TextStyle(fontSize: 72),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _label.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: <Shadow>[
                  Shadow(color: Color(0x66000000), blurRadius: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 11,
        letterSpacing: 2,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String helper,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white24),
        helperStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0x14FFFFFF),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
