import 'package:flutter/material.dart';

import '../models/canvas_item.dart';

/// Owns the collection of overlay items in the content panel plus the current
/// selection. Extends [ChangeNotifier] so the panel + inspector rebuild when
/// items change, while individual item drags update in place for smoothness.
class CanvasController extends ChangeNotifier {
  final List<CanvasItem> _items = [];
  List<CanvasItem> get items => List.unmodifiable(_items);

  String? _selectedId;
  String? get selectedId => _selectedId;
  CanvasItem? get selected {
    for (final item in _items) {
      if (item.id == _selectedId) return item;
    }
    return null;
  }

  int _seq = 0;
  String _nextId() => 'item_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  void add(CanvasItemType type, {String? text, String? assetPath}) {
    final item = CanvasItem(
      id: _nextId(),
      type: type,
      center: const Offset(0.5, 0.5),
      size: const Size(0.55, 0.28),
      text: text ?? _defaultTextFor(type),
      assetPath: assetPath,
    );
    _items.add(item);
    _selectedId = item.id;
    notifyListeners();
  }

  String _defaultTextFor(CanvasItemType type) => switch (type) {
        CanvasItemType.text => 'Double tap to edit',
        CanvasItemType.emoji => '😍',
        CanvasItemType.watermark => '@yourbrand',
        _ => type.label,
      };

  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  /// Applies a mutation to an item and notifies once. During a drag we skip the
  /// full notify (see [updateSilently]) to keep things at 60fps and only notify
  /// on release.
  void update(String id, void Function(CanvasItem) mutate,
      {bool notify = true}) {
    final item = _byId(id);
    if (item == null || item.locked) return;
    mutate(item);
    if (notify) notifyListeners();
  }

  void bringToFront(String id) {
    final item = _byId(id);
    if (item == null) return;
    _items
      ..remove(item)
      ..add(item);
    notifyListeners();
  }

  void sendToBack(String id) {
    final item = _byId(id);
    if (item == null) return;
    _items
      ..remove(item)
      ..insert(0, item);
    notifyListeners();
  }

  void toggleLock(String id) {
    final item = _byId(id);
    if (item == null) return;
    item.locked = !item.locked;
    notifyListeners();
  }

  void duplicate(String id) {
    final item = _byId(id);
    if (item == null) return;
    final clone = item.copyWith(
      id: _nextId(),
      center: item.center + const Offset(0.04, 0.04),
    );
    _items.add(clone);
    _selectedId = clone.id;
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    if (_selectedId == id) _selectedId = null;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _selectedId = null;
    notifyListeners();
  }

  CanvasItem? _byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }
}
