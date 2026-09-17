import 'package:flutter/foundation.dart';

import '../data/models/catalog.dart';
import '../data/models/order.dart';
import '../data/repositories/repositories.dart';
import 'catalog_controller.dart';

//==============================================================================
// SPOCART — Cart & wishlist controllers
//------------------------------------------------------------------------------
// The cart stores (product, size, quantity) lines. Prices are always resolved
// through the catalogue so a slab change updates every total automatically.
//==============================================================================

class CartController extends ChangeNotifier {
  CartController(this._storage, this._catalog);

  static const double gstRate = 0.18;

  final CartStorage _storage;
  final CatalogController _catalog;

  List<CartLine> _lines = <CartLine>[];
  bool _loaded = false;

  List<CartLine> get lines => List<CartLine>.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;
  bool get loaded => _loaded;
  int get lineCount => _lines.length;
  int get totalUnits => _lines.fold(0, (sum, l) => sum + l.quantity);

  Future<void> load() async {
    if (_loaded) return;
    try {
      _lines = List<CartLine>.of(await _storage.load());
    } catch (_) {
      _lines = <CartLine>[];
    }
    _loaded = true;
    notifyListeners();
  }

  int quantityOf(String productId, {String? size}) {
    int total = 0;
    for (final CartLine l in _lines) {
      if (l.productId == productId && (size == null || l.size == size)) {
        total += l.quantity;
      }
    }
    return total;
  }

  CartLine? lineFor(String productId, {String? size}) {
    for (final CartLine l in _lines) {
      if (l.productId == productId && l.size == size) return l;
    }
    return null;
  }

  /// Adds [product]; a fresh line starts at the MOQ, an existing one grows by
  /// [qty]. Returns the resulting quantity on that line.
  int add(Product product, {int? qty, String? size}) {
    final CartLine? existing = lineFor(product.id, size: size);
    if (existing == null) {
      final int start = (qty ?? product.moq).clamp(1, 99999);
      _lines.add(CartLine(productId: product.id, quantity: start, size: size));
      _persist();
      return start;
    }
    final int next = existing.quantity + (qty ?? 1);
    _replace(existing, existing.copyWith(quantity: next));
    _persist();
    return next;
  }

  void setQuantity(CartLine line, int qty) {
    if (qty <= 0) {
      _lines.removeWhere((l) => l.key == line.key);
    } else {
      final CartLine? existing = lineFor(line.productId, size: line.size);
      if (existing == null) return;
      _replace(existing, existing.copyWith(quantity: qty));
    }
    _persist();
  }

  void remove(CartLine line) {
    _lines.removeWhere((l) => l.key == line.key);
    _persist();
  }

  void clear() {
    _lines.clear();
    _persist();
  }

  void _replace(CartLine oldLine, CartLine newLine) {
    final int i = _lines.indexWhere((l) => l.key == oldLine.key);
    if (i >= 0) _lines[i] = newLine;
  }

  void _persist() {
    notifyListeners();
    _storage.save(_lines);
  }

  //----------------------------------------------------------------------------
  // Money
  //----------------------------------------------------------------------------
  Product? productOf(CartLine line) => _catalog.productById(line.productId);

  double unitPrice(CartLine line) =>
      productOf(line)?.priceForQuantity(line.quantity) ?? 0;

  double lineTotal(CartLine line) => unitPrice(line) * line.quantity;

  double get subtotal => _lines.fold(0, (sum, l) => sum + lineTotal(l));
  double get gst => subtotal * gstRate;
  double get total => subtotal + gst;

  /// Lines whose quantity is below the product's MOQ (blocks checkout).
  List<CartLine> get belowMoq => _lines
      .where((l) => (productOf(l)?.moq ?? 1) > l.quantity)
      .toList(growable: false);

  /// Lines whose product no longer exists in the catalogue.
  List<CartLine> get orphaned =>
      _lines.where((l) => productOf(l) == null).toList(growable: false);

  /// Frozen copies of every line for an order snapshot.
  List<OrderLine> toOrderLines() {
    final List<OrderLine> out = <OrderLine>[];
    for (final CartLine l in _lines) {
      final Product? p = productOf(l);
      if (p == null) continue;
      out.add(OrderLine(
        productId: p.id,
        name: p.name,
        image: p.primaryImage,
        unit: p.unit,
        quantity: l.quantity,
        unitPrice: p.priceForQuantity(l.quantity),
        size: l.size,
      ));
    }
    return out;
  }
}

class WishlistController extends ChangeNotifier {
  WishlistController(this._storage);

  final CartStorage _storage;

  List<String> _ids = <String>[];
  bool _loaded = false;

  List<String> get ids => List<String>.unmodifiable(_ids);
  bool get isEmpty => _ids.isEmpty;
  int get count => _ids.length;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      _ids = List<String>.of(await _storage.loadWishlist());
    } catch (_) {
      _ids = <String>[];
    }
    _loaded = true;
    notifyListeners();
  }

  bool contains(String productId) => _ids.contains(productId);

  /// Returns true when the product is now saved, false when removed.
  bool toggle(String productId) {
    final bool saved;
    if (_ids.contains(productId)) {
      _ids.remove(productId);
      saved = false;
    } else {
      _ids.insert(0, productId);
      saved = true;
    }
    _persist();
    return saved;
  }

  void remove(String productId) {
    _ids.remove(productId);
    _persist();
  }

  void clear() {
    _ids.clear();
    _persist();
  }

  void _persist() {
    notifyListeners();
    _storage.saveWishlist(_ids);
  }
}
