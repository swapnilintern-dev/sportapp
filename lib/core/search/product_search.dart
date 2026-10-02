import '../../data/models/catalog.dart';

//==============================================================================
// SPOCART — Product search
//------------------------------------------------------------------------------
// Buyers type the way they speak on the phone: "shuttle cock", "tt bat",
// "jursey", "foot ball". Plain substring matching finds none of those, so this
// matches on tokens, understands the trade's own vocabulary, forgives a typo,
// and ranks what it finds so the obvious answer comes first.
//
// It runs on the catalogue the app already holds, so there is no extra request
// and it works offline. Nothing here invents a product: it only decides which
// of the real ones match, and in what order.
//==============================================================================

/// Words buyers use for the same thing. Each key maps to extra terms that are
/// matched as if the buyer had typed them too.
const Map<String, List<String>> kSearchSynonyms = <String, List<String>>{
  'cock': <String>['shuttlecock', 'shuttle', 'badminton'],
  'shuttle': <String>['shuttlecock', 'badminton'],
  'shuttlecock': <String>['badminton'],
  'tt': <String>['table', 'tennis'],
  'bat': <String>['bats'],
  'ball': <String>['balls'],
  'jersey': <String>['kit', 'apparel', 'tshirt', 'shirt'],
  'kit': <String>['jersey', 'apparel'],
  'tshirt': <String>['jersey', 'apparel', 'shirt'],
  'shoes': <String>['footwear', 'spikes', 'studs'],
  'footwear': <String>['shoes'],
  'gloves': <String>['glove', 'batting'],
  'pads': <String>['pad', 'guard', 'guards'],
  'guard': <String>['pads', 'protection'],
  'net': <String>['nets', 'netting'],
  'rope': <String>['skipping', 'jump'],
  'dumbbell': <String>['dumbell', 'weights', 'gym'],
  'weights': <String>['dumbbell', 'gym'],
  'mat': <String>['mats', 'yoga', 'exercise'],
  'cone': <String>['cones', 'marker', 'markers'],
  'whistle': <String>['referee', 'umpire'],
  'football': <String>['soccer'],
  'soccer': <String>['football'],
  'cricket': <String>['cric'],
  'swimming': <String>['swim', 'pool'],
  'swim': <String>['swimming'],
  'hockey': <String>['stick'],
  'carrom': <String>['carom'],
  'volleyball': <String>['volley'],
  'basketball': <String>['basket'],
};

/// One product and why it matched, so the caller can sort or explain.
class SearchHit {
  const SearchHit(this.product, this.score, {this.corrected = false});

  final Product product;
  final int score;

  /// True when the match needed typo forgiveness rather than an exact token.
  final bool corrected;
}

/// Lowercase, strip punctuation, collapse spaces, split into words.
List<String> tokenize(String input) {
  final String cleaned = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return const <String>[];
  return cleaned.split(' ').where((String w) => w.isNotEmpty).toList();
}

/// Expands a token with the words the trade uses for the same thing.
Set<String> expand(String token) => <String>{token, ...?kSearchSynonyms[token]};

/// Levenshtein distance, capped: we only care whether it is within [maxEdits],
/// so the loop gives up as soon as it cannot be.
int editDistance(String a, String b, {int maxEdits = 2}) {
  if ((a.length - b.length).abs() > maxEdits) return maxEdits + 1;
  if (a == b) return 0;

  List<int> previous = List<int>.generate(b.length + 1, (int i) => i);
  for (int i = 1; i <= a.length; i++) {
    final List<int> current = List<int>.filled(b.length + 1, 0);
    current[0] = i;
    int best = current[0];
    for (int j = 1; j <= b.length; j++) {
      final int cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = <int>[
        current[j - 1] + 1,
        previous[j] + 1,
        previous[j - 1] + cost,
      ].reduce((int x, int y) => x < y ? x : y);
      if (current[j] < best) best = current[j];
    }
    if (best > maxEdits) return maxEdits + 1;
    previous = current;
  }
  return previous[b.length];
}

/// How much of a typo we forgive, by word length: short words must be right,
/// longer ones may be off by one or two letters.
int _allowedEdits(String token) {
  if (token.length <= 3) return 0;
  if (token.length <= 6) return 1;
  return 2;
}

/// Score awarded when a token only matched after forgiving a typo.
const int _correctedScore = 25;

/// Scores one token against one product. 0 means no match.
int _scoreToken(String token, Product product, {required bool allowTypos}) {
  final Set<String> wanted = expand(token);
  final String name = product.name.toLowerCase();
  final String brand = product.brand.toLowerCase();
  final String subcategory = product.subcategory.toLowerCase();
  final String category = product.categoryId.toLowerCase().replaceAll('-', ' ');
  final String description = product.description.toLowerCase();

  int best = 0;
  void keep(int score) => best = best > score ? best : score;

  for (final String term in wanted) {
    // The strongest signal wins outright; weaker fields cannot beat it.
    if (name == term) return 100;
    if (name.startsWith(term)) keep(70);
    if (RegExp('\\b${RegExp.escape(term)}').hasMatch(name)) {
      keep(60);
    } else if (name.contains(term)) {
      keep(45);
    }
    if (brand.contains(term)) keep(40);
    if (subcategory.contains(term)) keep(35);
    if (category.contains(term)) keep(30);
    if (description.contains(term)) keep(15);
  }
  if (best > 0 || !allowTypos) return best;

  // Nothing matched outright — allow a typo against the words that name the
  // product, never against the description, which is too noisy to be useful.
  final int allowed = _allowedEdits(token);
  if (allowed == 0) return 0;
  for (final String word in <String>[
    ...tokenize(product.name),
    ...tokenize(product.brand),
    ...tokenize(product.subcategory),
  ]) {
    if (editDistance(token, word, maxEdits: allowed) <= allowed) {
      return _correctedScore;
    }
  }
  return 0;
}

/// Ranked matches for [query] over [products].
///
/// Every word the buyer typed has to match something, so "cricket shoes" does
/// not return every cricket product. If that finds nothing, it runs again
/// forgiving typos and the hits are marked [SearchHit.corrected].
List<SearchHit> searchProducts(List<Product> products, String query) {
  final List<String> tokens = tokenize(query);
  if (tokens.isEmpty) return const <SearchHit>[];

  List<SearchHit> run({required bool allowTypos}) {
    final List<SearchHit> hits = <SearchHit>[];
    for (final Product product in products) {
      int total = 0;
      bool matchedAll = true;
      bool corrected = false;
      for (final String token in tokens) {
        final int score = _scoreToken(token, product, allowTypos: allowTypos);
        if (score == 0) {
          matchedAll = false;
          break;
        }
        if (score == _correctedScore) corrected = true;
        total += score;
      }
      if (matchedAll) {
        // Something a buyer can actually order ranks above something they cannot.
        hits.add(SearchHit(product, total + (product.inStock ? 5 : 0),
            corrected: corrected));
      }
    }
    hits.sort((SearchHit a, SearchHit b) {
      final int byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.product.name.compareTo(b.product.name);
    });
    return hits;
  }

  final List<SearchHit> exact = run(allowTypos: false);
  return exact.isNotEmpty ? exact : run(allowTypos: true);
}
