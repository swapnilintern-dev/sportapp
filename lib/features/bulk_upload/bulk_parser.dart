import '../../data/models/catalog.dart';
import '../../state/catalog_controller.dart';

//==============================================================================
// SPOCART — Bulk CSV parsing
//------------------------------------------------------------------------------
// Accepts "product, quantity, size" rows (header optional, quoted fields
// supported) and matches each product cell against the catalogue by id, then
// exact name, then a contains match. Rows that don't match are kept so the
// buyer can send them for a quote.
//==============================================================================

const String kBulkCsvTemplate = 'product,quantity,size\n'
    'Kashmir Willow Cricket Bat,50,SH\n'
    'ck-ss-ball,120,\n'
    'Football (Size 5),40,5';

class BulkRow {
  const BulkRow({
    required this.input,
    required this.quantity,
    this.product,
    this.size,
  });

  /// What the buyer wrote in the product column.
  final String input;
  final int quantity;
  final Product? product;
  final String? size;
}

List<BulkRow> parseBulkCsv(String text, CatalogController catalog) {
  final List<BulkRow> rows = <BulkRow>[];
  final List<String> lines = text.split(RegExp(r'\r?\n'));

  for (int i = 0; i < lines.length; i++) {
    final String raw = lines[i].trim();
    if (raw.isEmpty) continue;
    final List<String> cells = _splitCsvLine(raw);
    if (cells.isEmpty) continue;

    final String productCell = cells[0].trim();
    final String qtyCell = cells.length > 1 ? cells[1].trim() : '';
    final String sizeCell = cells.length > 2 ? cells[2].trim() : '';

    // Skip a header row.
    if (i == 0 &&
        productCell.toLowerCase().contains('product') &&
        int.tryParse(qtyCell) == null) {
      continue;
    }
    if (productCell.isEmpty) continue;

    final int quantity = int.tryParse(qtyCell) ?? 0;
    final Product? product = matchProduct(productCell, catalog);
    rows.add(BulkRow(
      input: productCell,
      quantity: quantity <= 0 ? (product?.moq ?? 1) : quantity,
      product: product,
      size: sizeCell.isEmpty ? null : _matchSize(product, sizeCell),
    ));
  }
  return rows;
}

Product? matchProduct(String input, CatalogController catalog) {
  final String q = input.trim().toLowerCase();
  if (q.isEmpty) return null;
  final Product? byId = catalog.productById(input.trim());
  if (byId != null) return byId;
  for (final Product p in catalog.products) {
    if (p.name.toLowerCase() == q) return p;
  }
  for (final Product p in catalog.products) {
    if (p.name.toLowerCase().contains(q) || q.contains(p.name.toLowerCase())) {
      return p;
    }
  }
  return null;
}

String? _matchSize(Product? product, String size) {
  if (product == null) return size;
  for (final String s in product.sizes) {
    if (s.toLowerCase() == size.toLowerCase()) return s;
  }
  return size;
}

List<String> _splitCsvLine(String line) {
  final List<String> out = <String>[];
  final StringBuffer current = StringBuffer();
  bool inQuotes = false;
  for (int i = 0; i < line.length; i++) {
    final String c = line[i];
    if (c == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        current.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if ((c == ',' || c == ';' || c == '\t') && !inQuotes) {
      out.add(current.toString());
      current.clear();
    } else {
      current.write(c);
    }
  }
  out.add(current.toString());
  return out;
}
