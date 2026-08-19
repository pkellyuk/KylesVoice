import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

import '../log.dart';
import '../services/photo_service.dart';
import '../services/symbol_library.dart';
import 'symbol_picker.dart';

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

  /// Where photographs are filed. Null when storage is unavailable.
  final MediaStore? media;

  /// Absolute path of the media directory, for previewing.
  final String? mediaDirectory;

  const CardEditor({
    super.key,
    required this.address,
    this.existing,
    this.media,
    this.mediaDirectory,
  });

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

  final PhotoService _photos = PhotoService();

  late TextEditingController _label;
  late TextEditingController _speech;
  late TextEditingController _glyph;
  late int _colour;
  late String _photoFile;
  late String _symbolFile;
  late ImageMode _imageMode;
  late double _blend;

  bool _busy = false;
  String _photoStatus = '';

  @override
  void initState() {
    Log.enter('_CardEditorState.initState', 'address=${widget.address}');
    super.initState();

    final BoardCard? existing = widget.existing;

    _label = TextEditingController(text: existing?.label ?? '');
    _speech = TextEditingController(text: existing?.speech ?? '');
    _glyph = TextEditingController(text: existing?.glyph ?? _glyphs.first);
    _colour = existing?.colourArgb ?? _palette.first;
    _photoFile = existing?.photoFile ?? '';
    _symbolFile = existing?.symbolFile ?? '';
    _imageMode = existing?.imageMode ?? ImageMode.photo;
    _blend = existing?.blend ?? 0;

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
      symbolFile: _symbolFile,
      colourArgb: _colour,
      photoFile: _photoFile,
      imageMode: _imageMode,
      blend: _blend,
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

  Future<void> _attachPhoto({required bool fromCamera}) async {
    Log.enter('_CardEditorState._attachPhoto', 'fromCamera=$fromCamera');

    if (_busy) {
      Log.exit('_CardEditorState._attachPhoto', 'already busy');
      return;
    }

    setState(() {
      _busy = true;
      _photoStatus = '';
    });

    final PhotoResult result = fromCamera
        ? await _photos.capture(widget.media)
        : await _photos.choose(widget.media);

    if (mounted == false) {
      Log.exit('_CardEditorState._attachPhoto', 'unmounted');
      return;
    }

    setState(() {
      _busy = false;

      if (result.succeeded) {
        _photoFile = result.fileName;

        // A photograph is almost always what a parent wants to see the moment
        // they attach one, whatever the mode was set to before.
        if (_imageMode == ImageMode.symbol) {
          _imageMode = ImageMode.photo;
        }

        _photoStatus = 'Photograph attached.';
        return;
      }

      if (result.cancelled) {
        _photoStatus = '';
        return;
      }

      _photoStatus = result.failure;
    });

    Log.exit('_CardEditorState._attachPhoto', 'file=$_photoFile');
  }

  void _removePhoto() {
    Log.enter('_CardEditorState._removePhoto', 'file=$_photoFile');

    setState(() {
      // The file itself is left on disk. Undo has to be able to bring the card
      // back with its picture intact, and orphans are pruned separately.
      _photoFile = '';
      _imageMode = ImageMode.symbol;
      _photoStatus = 'Photograph removed from this card.';
    });

    Log.exit('_CardEditorState._removePhoto');
  }

  Future<void> _chooseSymbol() async {
    Log.enter('_CardEditorState._chooseSymbol');

    final SymbolEntry? chosen = await Navigator.of(context).push<SymbolEntry>(
      MaterialPageRoute<SymbolEntry>(
        // Seed the search with the card's word: a parent adding "drink"
        // almost always wants the drink symbol, and typing it twice is
        // friction for no gain.
        builder: (BuildContext context) =>
            SymbolPicker(initialQuery: _label.text.trim()),
      ),
    );

    if (chosen == null) {
      Log.exit('_CardEditorState._chooseSymbol', 'cancelled');
      return;
    }

    if (mounted == false) {
      Log.exit('_CardEditorState._chooseSymbol', 'unmounted');
      return;
    }

    setState(() {
      _symbolFile = chosen.file;

      // Choosing a symbol for a card that has a photograph almost always means
      // the parent wants to see the symbol, or to fade toward it.
      if (_photoFile.isNotEmpty && _imageMode == ImageMode.photo) {
        _imageMode = ImageMode.blend;
      }
    });

    Log.exit('_CardEditorState._chooseSymbol', 'symbol=${chosen.file}');
  }

  void _clearSymbol() {
    Log.enter('_CardEditorState._clearSymbol', 'was=$_symbolFile');

    setState(() {
      _symbolFile = '';
    });

    Log.exit('_CardEditorState._clearSymbol');
  }

  void _onImageModeChanged(ImageMode? mode) {
    Log.enter('_CardEditorState._onImageModeChanged', 'mode=$mode');

    if (mode == null) {
      Log.warn('_CardEditorState._onImageModeChanged', 'null mode ignored');
      Log.exit('_CardEditorState._onImageModeChanged');
      return;
    }

    setState(() {
      _imageMode = mode;
    });

    Log.exit('_CardEditorState._onImageModeChanged', 'mode=${mode.name}');
  }

  /// Resolves the photograph for preview, or null if there is not one to show.
  File? get _photoFileHandle {
    if (_photoFile.trim().isEmpty) {
      return null;
    }

    final String? directory = widget.mediaDirectory;

    if (directory == null) {
      return null;
    }

    final File file = File(
      '$directory${Platform.pathSeparator}${_photoFile.trim()}',
    );

    if (file.existsSync() == false) {
      return null;
    }

    return file;
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
          _sectionLabel('PHOTOGRAPH'),
          const SizedBox(height: 6),
          const Text(
            "A photograph of the real thing — their own cup, their own "
            'school, their own people — is usually more motivating than a '
            'stock symbol for a first board.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 10),
          _buildPhotoControls(),
          if (_photoStatus.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _photoStatus,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          if (_photoFile.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _buildImageModeControls(),
          ],
          const SizedBox(height: 20),
          _sectionLabel('SYMBOL'),
          const SizedBox(height: 8),
          _buildSymbolControls(),
          const SizedBox(height: 16),
          _field(
            controller: _glyph,
            label: 'Emoji instead',
            hint: '\u{1F964}',
            helper:
                'Used when no symbol is chosen. The symbol set has no picture '
                'for some everyday words, so an emoji is sometimes the better '
                'answer.',
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
            Flexible(child: _buildPreviewArtwork()),
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

  Widget _buildSymbolControls() {
    final SymbolEntry? chosen = SymbolLibrary.catalog.byFile(_symbolFile);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (_symbolFile.isNotEmpty)
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(6),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              // Mulberry artwork assumes a pale background; several symbols are
              // mostly black line work that would vanish on the dark theme.
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SvgPicture.asset(
              SymbolLibrary.assetFor(_symbolFile),
              fit: BoxFit.contain,
              placeholderBuilder: (BuildContext context) =>
                  const SizedBox.shrink(),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _chooseSymbol,
                    icon: const Icon(Icons.emoji_symbols_outlined),
                    label: Text(
                      _symbolFile.isEmpty ? 'Choose a symbol' : 'Change symbol',
                    ),
                  ),
                  if (_symbolFile.isNotEmpty)
                    TextButton.icon(
                      onPressed: _clearSymbol,
                      icon: const Icon(Icons.close),
                      label: const Text('Remove symbol'),
                    ),
                ],
              ),
              if (chosen != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  '${chosen.name}  \u00b7  ${chosen.category}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoControls() {
    if (widget.media == null) {
      return const Text(
        'Photographs are unavailable because storage could not be opened.',
        style: TextStyle(color: Color(0xFFE57373), fontSize: 12),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        FilledButton.icon(
          onPressed: _busy ? null : () => _attachPhoto(fromCamera: true),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Take a photo'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _attachPhoto(fromCamera: false),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose a photo'),
        ),
        if (_photoFile.isNotEmpty)
          TextButton.icon(
            onPressed: _busy ? null : _removePhoto,
            icon: const Icon(Icons.hide_image_outlined),
            label: const Text('Remove photo'),
          ),
        if (_busy)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  /// Controls for combining the photograph with the symbol.
  ///
  /// The blend slider exists to support a deliberate progression: begin on a
  /// photograph of the child's own cup, and move gradually toward the abstract
  /// symbol so the concept generalises beyond that one object. The card never
  /// changes position or label while this happens.
  Widget _buildImageModeControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionLabel('PHOTO AND SYMBOL'),
        const SizedBox(height: 8),
        SegmentedButton<ImageMode>(
          segments: const <ButtonSegment<ImageMode>>[
            ButtonSegment<ImageMode>(
              value: ImageMode.photo,
              label: Text('Photo'),
            ),
            ButtonSegment<ImageMode>(
              value: ImageMode.symbol,
              label: Text('Symbol'),
            ),
            ButtonSegment<ImageMode>(
              value: ImageMode.both,
              label: Text('Both'),
            ),
            ButtonSegment<ImageMode>(
              value: ImageMode.blend,
              label: Text('Fade'),
            ),
          ],
          selected: <ImageMode>{_imageMode},
          onSelectionChanged: (Set<ImageMode> selection) =>
              _onImageModeChanged(selection.firstOrNull),
        ),
        if (_imageMode == ImageMode.blend) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Text(
                'Photo',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: _blend.clamp(0.0, 1.0),
                  onChanged: (double v) => setState(() => _blend = v),
                ),
              ),
              const Text(
                'Symbol',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const Text(
            'Move this a little at a time, over weeks. The card keeps its '
            'position and its word throughout.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ],
    );
  }

  /// The preview's artwork, mirroring exactly how the card will be drawn on
  /// the board so a parent can judge the result before saving.
  Widget _buildPreviewArtwork() {
    final Widget glyph = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        _glyph.text.isEmpty ? ' ' : _glyph.text,
        style: const TextStyle(fontSize: 72),
      ),
    );

    final Widget symbol = _symbolFile.isEmpty
        ? glyph
        : Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SvgPicture.asset(
              SymbolLibrary.assetFor(_symbolFile),
              fit: BoxFit.contain,
              placeholderBuilder: (BuildContext context) => glyph,
            ),
          );

    final File? photo = _photoFileHandle;

    if (photo == null) {
      return symbol;
    }

    final Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        photo,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            symbol,
      ),
    );

    if (_imageMode == ImageMode.both) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Expanded(child: image),
          const SizedBox(width: 6),
          Expanded(child: symbol),
        ],
      );
    }

    final double blend = _blend.clamp(0.0, 1.0);
    final double photoOpacity = switch (_imageMode) {
      ImageMode.photo => 1.0,
      ImageMode.symbol => 0.0,
      ImageMode.both => 1.0,
      ImageMode.blend => 1 - blend,
    };
    final double symbolOpacity = switch (_imageMode) {
      ImageMode.photo => 0.0,
      ImageMode.symbol => 1.0,
      ImageMode.both => 1.0,
      ImageMode.blend => blend,
    };

    return Stack(
      fit: StackFit.passthrough,
      alignment: Alignment.center,
      children: <Widget>[
        Opacity(opacity: photoOpacity, child: image),
        Opacity(opacity: symbolOpacity, child: symbol),
      ],
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
