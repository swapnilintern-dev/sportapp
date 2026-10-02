import 'package:flutter_test/flutter_test.dart';
import 'package:sport/data/models/engagement.dart';
import 'package:sport/data/repositories/repositories.dart';
import 'package:sport/state/reviews_controller.dart';

//==============================================================================
// Reviews: the app must show what the server returned and never decide for
// itself who is allowed to write one.
//==============================================================================

ProductReview _review(String id, {int rating = 5, bool mine = false}) =>
    ProductReview(
      id: id,
      productId: 'bat-1',
      rating: rating,
      title: '',
      body: 'Body of $id',
      photos: const <String>[],
      createdAt: DateTime(2026, 10, 1),
      author: mine ? 'You' : 'ABC Sports',
      mine: mine,
    );

class _FakeReviewRepository implements ReviewRepository {
  _FakeReviewRepository({
    this.pages = const <ReviewPage>[],
    this.reviewable = const <ReviewableProduct>[],
    this.failSubmit,
  });

  List<ReviewPage> pages;
  List<ReviewableProduct> reviewable;
  AppException? failSubmit;

  int fetchCalls = 0;
  int submitCalls = 0;
  int? lastOffset;

  @override
  Future<ReviewPage> fetchReviews(String productId,
      {int offset = 0, int limit = 10}) async {
    lastOffset = offset;
    final ReviewPage page =
        fetchCalls < pages.length ? pages[fetchCalls] : ReviewPage.empty;
    fetchCalls++;
    return page;
  }

  @override
  Future<List<ReviewableProduct>> fetchReviewable() async => reviewable;

  @override
  Future<ProductReview> submit(
    String productId, {
    required int rating,
    required String title,
    required String body,
    List<String> photos = const <String>[],
  }) async {
    submitCalls++;
    if (failSubmit != null) throw failSubmit!;
    return _review('new', rating: rating, mine: true);
  }

  @override
  Future<void> remove(String reviewId) async {}
}

ReviewPage _page(List<ProductReview> reviews, {int? total, double average = 4}) =>
    ReviewPage(
      reviews: reviews,
      total: total ?? reviews.length,
      average: average,
      breakdown: const <int, int>{1: 0, 2: 0, 3: 0, 4: 1, 5: 1},
    );

void main() {
  group('ReviewsController', () {
    test('loads a product\'s first page', () async {
      final ReviewsController c = ReviewsController(
        _FakeReviewRepository(pages: <ReviewPage>[
          _page(<ProductReview>[_review('a'), _review('b')], average: 4.5),
        ]),
      );
      await c.load('bat-1');
      expect(c.page.total, 2);
      expect(c.page.average, 4.5);
      expect(c.loading, isFalse);
      expect(c.error, isNull);
    });

    test('switching products never shows the previous product\'s reviews',
        () async {
      final _FakeReviewRepository repo = _FakeReviewRepository(pages: <ReviewPage>[
        _page(<ProductReview>[_review('a')]),
        ReviewPage.empty,
      ]);
      final ReviewsController c = ReviewsController(repo);
      await c.load('bat-1');
      expect(c.page.total, 1);

      await c.load('ball-1');
      expect(c.page.total, 0, reason: 'the new product has none');
      expect(c.page.reviews, isEmpty);
    });

    test('paging appends and asks from where it left off', () async {
      final _FakeReviewRepository repo = _FakeReviewRepository(pages: <ReviewPage>[
        _page(<ProductReview>[_review('a'), _review('b')], total: 4),
        _page(<ProductReview>[_review('c'), _review('d')], total: 4),
      ]);
      final ReviewsController c = ReviewsController(repo);
      await c.load('bat-1');
      expect(c.hasMore, isTrue);

      await c.loadMore();
      expect(repo.lastOffset, 2);
      expect(c.page.reviews.length, 4);
      expect(c.hasMore, isFalse);
    });

    test('a failure is reported without losing the screen', () async {
      final ReviewsController c = ReviewsController(_ThrowingRepository());
      await c.load('bat-1');
      expect(c.error, isNotNull);
      expect(c.page.isEmpty, isTrue);
      expect(c.loading, isFalse);
    });

    test('eligibility comes from the server, not from the app', () async {
      final ReviewsController c = ReviewsController(_FakeReviewRepository(
        reviewable: const <ReviewableProduct>[
          ReviewableProduct(productId: 'bat-1', name: 'Bat', image: ''),
        ],
      ));
      expect(c.canReview('bat-1'), isFalse, reason: 'nothing asked for yet');

      await c.loadReviewable();
      expect(c.canReview('bat-1'), isTrue);
      expect(c.canReview('ball-1'), isFalse);
    });

    test('the buyer\'s own review is identified for editing', () async {
      final ReviewsController c = ReviewsController(
        _FakeReviewRepository(pages: <ReviewPage>[
          _page(<ProductReview>[_review('a'), _review('b', mine: true)]),
        ]),
      );
      await c.load('bat-1');
      expect(c.mine?.id, 'b');
    });

    test('a refused review keeps the server\'s wording', () async {
      final ReviewsController c = ReviewsController(_FakeReviewRepository(
        failSubmit: const AppException(
            'You can review a product once your order for it has been delivered.'),
      ));
      await expectLater(
        c.submit('bat-1', rating: 5, title: '', body: 'Great bat'),
        throwsA(isA<AppException>().having((AppException e) => e.message, 'message',
            contains('has been delivered'))),
      );
      expect(c.submitting, isFalse, reason: 'the form must become usable again');
    });

    test('a saved review reloads the page and the eligibility list', () async {
      final _FakeReviewRepository repo = _FakeReviewRepository(pages: <ReviewPage>[
        ReviewPage.empty,
        _page(<ProductReview>[_review('new', mine: true)]),
      ]);
      final ReviewsController c = ReviewsController(repo);
      await c.load('bat-1');
      await c.submit('bat-1', rating: 5, title: '', body: 'Great bat');
      expect(repo.submitCalls, 1);
      expect(c.page.total, 1);
      expect(c.mine, isNotNull);
    });
  });

  group('ReviewPage parsing', () {
    test('reads the summary and breakdown the server sends', () {
      final ReviewPage page = ReviewPage.fromJson(<String, dynamic>{
        'reviews': <Map<String, dynamic>>[
          {
            'id': 'r1', 'productId': 'bat-1', 'rating': 5, 'title': 'Solid',
            'body': 'Held up all season.', 'photos': <String>[],
            'createdAt': '2026-10-01T10:00:00Z', 'author': 'ABC Sports',
            'verifiedBuyer': true, 'mine': false,
          }
        ],
        'total': 7,
        'average': 4.3,
        'breakdown': {'1': 0, '2': 1, '3': 0, '4': 2, '5': 4},
      });
      expect(page.total, 7);
      expect(page.average, 4.3);
      expect(page.breakdown[5], 4);
      expect(page.reviews.single.verifiedBuyer, isTrue);
      expect(page.reviews.single.mine, isFalse);
    });

    test('an empty page is empty, not broken', () {
      final ReviewPage page = ReviewPage.fromJson(<String, dynamic>{
        'reviews': <dynamic>[], 'total': 0, 'average': 0, 'breakdown': <String, dynamic>{},
      });
      expect(page.isEmpty, isTrue);
      expect(page.breakdown.length, 5);
      expect(page.breakdown.values.every((int v) => v == 0), isTrue);
    });
  });
}

class _ThrowingRepository implements ReviewRepository {
  @override
  Future<ReviewPage> fetchReviews(String productId, {int offset = 0, int limit = 10}) async {
    throw const AppException('Could not load reviews.');
  }

  @override
  Future<List<ReviewableProduct>> fetchReviewable() async => const <ReviewableProduct>[];

  @override
  Future<ProductReview> submit(String productId,
      {required int rating,
      required String title,
      required String body,
      List<String> photos = const <String>[]}) async {
    throw const AppException('nope');
  }

  @override
  Future<void> remove(String reviewId) async {}
}
