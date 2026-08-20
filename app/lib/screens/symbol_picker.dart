import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kylesvoice_core/kylesvoice_core.dart';

import '../log.dart';
import '../services/symbol_library.dart';

/// Picks a symbol from the bundled Mulberry set.
///
/// Opens showing results for whatever the card is already called, because a
/// parent adding a "drink" card almost always wants the drink symbol, and
/// making them type the word twice is friction for no gain.
class SymbolPicker extends StatefulWidget {
  /// Seeds the search box, normally the card's word.
  final String initialQuery;

  const SymbolPicker({super.key, this.initialQuery = ''});

  @override
  State<SymbolPicker> createState() => _SymbolPickerState();
}

/// Height of the horizontal category strip.
const double _categoryStripHeight = 44;

/// Below this much body height the category strip is dropped.
///
/// The search field occupies about 84 logical pixels including its padding.
/// Add the strip and a row of results still worth looking at, and the strip
/// only earns its place on a viewport this tall.
const double _minHeightForStrip = 200;

class _SymbolPickerState extends State<SymbolPicker> {
  late final TextEditingController _query;

  List<SymbolEntry> _results = const <SymbolEntry>[];
  String _category = '';

  @override
  void initState() {
    Log.enter('_SymbolPickerState.initState', 'query=${widget.initialQuery}');
    super.initState();

    _query = TextEditingController(text: widget.initialQuery);
    _refresh();

    Log.exit('_SymbolPickerState.initState', 'results=${_results.length}');
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _refresh() {
    final SymbolCatalog catalog = SymbolLibrary.catalog;
    final String text = _query.text.trim();

    if (_category.isNotEmpty && text.isEmpty) {
      _results = catalog.inCategory(_category);
      return;
    }

    _results = catalog.search(text, limit: 300);

    // A search that finds nothing at all is worth saying out loud rather than
    // showing an empty grid the parent has to interpret.
    if (_results.isEmpty && text.isNotEmpty) {
      Log.step('_SymbolPickerState._refresh', 'no matches for "$text"');
    }
  }

  void _onQueryChanged(String _) {
    setState(() {
      _category = '';
      _refresh();
    });
  }

  void _onCategorySelected(String? category) {
    Log.enter('_SymbolPickerState._onCategorySelected', 'category=$category');

    if (category == null) {
      Log.exit('_SymbolPickerState._onCategorySelected', 'ignored');
      return;
    }

    setState(() {
      _category = _category == category ? '' : category;
      _query.clear();
      _refresh();
    });

    Log.exit('_SymbolPickerState._onCategorySelected', 'category=$_category');
  }

  void _choose(SymbolEntry entry) {
    Log.enter('_SymbolPickerState._choose', 'symbol=${entry.file}');

    Navigator.of(context).pop(entry);

    Log.exit('_SymbolPickerState._choose');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1216),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B21),
        title: const Text('Choose a symbol'),
        actions: <Widget>[
          if (SymbolLibrary.isLoaded)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${SymbolLibrary.catalog.count} symbols',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: SymbolLibrary.isLoaded == false
          ? _buildUnavailable()
          : LayoutBuilder(builder: _buildBody),
    );
  }

  /// The picker proper, laid out against the height actually available.
  ///
  /// On a phone in landscape the keyboard takes most of the screen: roughly
  /// 100 logical pixels are left below the app bar, which is less than the
  /// search field and the category strip need together. Laying both out
  /// unconditionally overflowed the column by 29 pixels on a Pixel 6.
  ///
  /// The strip is the part that gives way. It is a browsing aid, and nobody is
  /// browsing categories while the keyboard is up — they are typing a word.
  /// Dismissing the keyboard brings it straight back.
  Widget _buildBody(BuildContext context, BoxConstraints constraints) {
    if (constraints.maxHeight <= 0) {
      Log.hot('_SymbolPickerState._buildBody', 'no height');
      return const SizedBox.shrink();
    }

    final bool roomForStrip = constraints.maxHeight >= _minHeightForStrip;

    return Column(
      children: <Widget>[
        _buildSearchField(),
        if (roomForStrip) _buildCategoryStrip(),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.image_not_supported_outlined,
              color: Colors.white38,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              SymbolLibrary.failure.isEmpty
                  ? 'The symbol set is not available.'
                  : SymbolLibrary.failure,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can still use a photograph or an emoji on this card.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _query,
        autofocus: true,
        onChanged: _onQueryChanged,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: InputDecoration(
          hintText: 'Search, e.g. drink',
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          suffixIcon: _query.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38),
                  onPressed: () {
                    _query.clear();
                    _onQueryChanged('');
                  },
                ),
          filled: true,
          fillColor: const Color(0x14FFFFFF),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildCategoryStrip() {
    final List<String> categories = SymbolLibrary.catalog.categories;

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: _categoryStripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (BuildContext context, int i) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          final String category = categories[i];

          return ChoiceChip(
            label: Text(category),
            selected: _category == category,
            onSelected: (_) => _onCategorySelected(category),
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'No symbols match that word.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'The set is strongest on objects and places. Some everyday '
                'words — including yes, no, stop and please — are not in it at '
                'all, so a photograph or an emoji may serve better.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _results.length,
      itemBuilder: (BuildContext context, int i) => _buildTile(_results[i]),
    );
  }

  Widget _buildTile(SymbolEntry entry) {
    return InkWell(
      onTap: () => _choose(entry),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          // A light plate behind every symbol: Mulberry artwork assumes a pale
          // background, and several symbols are mostly black line work that
          // would vanish on the dark theme.
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: <Widget>[
            Expanded(
              child: SvgPicture.asset(
                SymbolLibrary.assetFor(entry.file),
                fit: BoxFit.contain,
                placeholderBuilder: (BuildContext context) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entry.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black87, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
