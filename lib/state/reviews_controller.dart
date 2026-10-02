import 'package:flutter/foundation.dart';

import '../data/models/engagement.dart';
import '../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Reviews controller
//------------------------------------------------------------------------------
// Holds one product's review page at a time (the product screen is the only
// place they are read) plus the list of products this buyer may still review.
// Writing a review refreshes both, so the product page and the "rate your
// order" prompt never disagree.
//==============================================================================

class ReviewsController extends ChangeNotifier {
  ReviewsController(this._repository);

  final ReviewRepository _repository;

  static const int pageSize = 10;

  String? _productId;
  ReviewPage _page = ReviewPage.empty;
  List<ReviewableProduct> _reviewable = const <ReviewableProduct>[];
  bool _loading = false;
  bool _loadingMore = false;
  bool _submitting = false;
  String? _error;

  ReviewPage get page => _page;
  List<ReviewableProduct> get reviewable => _reviewable;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get submitting => _submitting;
  String? get error => _error;

  /// True while more reviews remain on the server.
  bool get hasMore => _page.reviews.length < _page.total;

  /// This buyer's own review of the loaded product, if they wrote one.
  ProductReview? get mine {
    for (final ProductReview r in _page.reviews) {
      if (r.mine) return r;
    }
    return null;
  }

  /// Loads the first page for [productId]. Switching products starts clean so
  /// one product's reviews can never be shown under another.
  Future<void> load(String productId, {bool force = false}) async {
    if (_loading) return;
    if (_productId == productId && !force && _page.total > 0) return;
    _productId = productId;
    _page = ReviewPage.empty;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _page = await _repository.fetchReviews(productId, limit: pageSize);
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load reviews. Please try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    final String? productId = _productId;
    if (productId == null || _loadingMore || _loading || !hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final ReviewPage next = await _repository.fetchReviews(
        productId,
        offset: _page.reviews.length,
        limit: pageSize,
      );
      _page = ReviewPage(
        reviews: <ProductReview>[..._page.reviews, ...next.reviews],
        total: next.total,
        average: next.average,
        breakdown: next.breakdown,
      );
    } catch (_) {
      // Keep what is already on screen; the button can be tapped again.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadReviewable() async {
    try {
      _reviewable = await _repository.fetchReviewable();
    } catch (_) {
      _reviewable = const <ReviewableProduct>[];
    }
    notifyListeners();
  }

  /// True when this buyer may review [productId] — the server decides, this is
  /// only what it last told us.
  bool canReview(String productId) =>
      _reviewable.any((ReviewableProduct p) => p.productId == productId);

  /// Writes or replaces the buyer's review. Throws [AppException] with the
  /// server's message so the form can show exactly why it was refused.
  Future<void> submit(
    String productId, {
    required int rating,
    required String title,
    required String body,
    List<String> photos = const <String>[],
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      await _repository.submit(
        productId,
        rating: rating,
        title: title,
        body: body,
        photos: photos,
      );
      await load(productId, force: true);
      await loadReviewable();
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> remove(String reviewId) async {
    final String? productId = _productId;
    await _repository.remove(reviewId);
    if (productId != null) await load(productId, force: true);
    await loadReviewable();
  }

  void reset() {
    _productId = null;
    _page = ReviewPage.empty;
    _reviewable = const <ReviewableProduct>[];
    _error = null;
    notifyListeners();
  }
}
