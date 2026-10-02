import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport/app/app_scope.dart';
import 'package:sport/core/network/api_client.dart';
import 'package:sport/core/widgets/inputs.dart';
import 'package:sport/data/local/local_store.dart';
import 'package:sport/features/catalog/widgets/product_video.dart';
import 'package:sport/main.dart';

//==============================================================================
// Home's Deals and New Launches shelves, the offer popup and the product video
// section, driven through the real HTTP repositories against a fake API — so
// what is asserted is what the app would do against the server.
//==============================================================================

Map<String, dynamic> _product(
  String id,
  String name, {
  double price = 500,
  String? videoUrl,
  int? stockLeft,
}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'brand': 'SPOCART',
      'categoryId': 'cricket',
      'subcategory': 'Bats',
      'unit': 'pc',
      'moq': 10,
      'description': 'Test product.',
      'images': <String>[],
      'sizes': <String>[],
      'features': <Map<String, String>>[],
      'rating': 4.5,
      'reviewCount': 0,
      'inStock': true,
      'popular': true,
      'customisable': false,
      'tiers': <Map<String, dynamic>>[
        {'minQty': 10, 'unitPrice': price},
      ],
      'videoUrl': ?videoUrl,
      if (videoUrl != null)
        'videoThumbnailUrl': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      'stockLeft': stockLeft,
    };

void main() {
  late Map<String, dynamic Function()> routes;

  setUp(() {
    routes = <String, dynamic Function()>{
      '/api/v1/auth/otp/send': () =>
          {'mobile': '9876543210', 'expiresAt': '2099-01-01T00:00:00Z', 'devCode': '123456'},
      '/api/v1/auth/otp/verify': () => {
            'token': 'jwt-test',
            'user': {
              'mobile': '9876543210',
              'signedInAt': '2026-10-02T10:00:00Z',
              'profile': null,
              'creditLimit': 100000,
            },
          },
      '/api/v1/auth/me': () => {
            'mobile': '9876543210',
            'signedInAt': '2026-10-02T10:00:00Z',
            'profile': null,
            'creditLimit': 100000,
          },
      '/api/v1/catalog/categories': () => [
            {
              'id': 'cricket', 'name': 'Cricket', 'icon': 'sports_cricket',
              'subcategories': ['Bats'], 'imageUrl': null,
            }
          ],
      '/api/v1/catalog/products': () => [
            _product('bat-1', 'Willow Bat',
                videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
                stockLeft: 7),
            _product('ball-1', 'Leather Ball'),
          ],
      '/api/v1/catalog/best-sellers': () => {'productIds': <String>['bat-1', 'ball-1']},
      '/api/v1/catalog/deals': () => <Map<String, dynamic>>[],
      '/api/v1/catalog/new-launches': () => <Map<String, dynamic>>[],
      '/api/v1/promotions/active': () => {'promotion': null},
      '/api/v1/notifications': () => {'items': <Map<String, dynamic>>[], 'unread': 0},
      '/api/v1/orders': () => <Map<String, dynamic>>[],
      '/api/v1/reviews/pending': () => <Map<String, dynamic>>[],
      '/api/v1/rewards': () => {'active': false, 'settings': <String, dynamic>{}},
      '/api/v1/rewards/ledger': () => {'entries': <Map<String, dynamic>>[], 'total': 0, 'balance': 0},
      '/api/v1/catalog/products/bat-1/reviews': () => {
            'reviews': <Map<String, dynamic>>[],
            'total': 0, 'average': 0,
            'breakdown': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
          },
      '/api/v1/catalog/products/ball-1/reviews': () => {
            'reviews': <Map<String, dynamic>>[],
            'total': 0, 'average': 0,
            'breakdown': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
          },
    };
  });

  AppServices build() {
    final MockClient client = MockClient((http.Request req) async {
      final dynamic Function()? handler = routes[req.url.path];
      if (handler == null) {
        return http.Response(
            jsonEncode({'ok': false, 'message': 'Route not found: ${req.url.path}'}), 404);
      }
      return http.Response(jsonEncode({'ok': true, 'data': handler()}), 200,
          headers: {'content-type': 'application/json'});
    });
    return AppServices.http(MemoryStore(),
        client: ApiClient(client: client, baseUrl: 'http://api.test/api/v1'));
  }

  /// Home's own list — every tab in the IndexedStack keeps a scrollable alive,
  /// so the one to drive has to be named.
  Future<void> scrollHome(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  /// The product page builds its slivers lazily, so anything below the fold
  /// has to be scrolled to before it exists to find.
  Future<void> scrollProductPage(WidgetTester tester, Finder target) async {
    for (int i = 0; i < 8 && target.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
  }

  Future<AppServices> pumpSignedIn(WidgetTester tester) async {
    final AppServices services = build();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SpocartApp(services: services));
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pumpAndSettle(const Duration(milliseconds: 900));
    return services;
  }

  testWidgets('empty shelves are hidden, not shown empty', (tester) async {
    await pumpSignedIn(tester);
    expect(find.text('Best Sellers'), findsOneWidget);
    expect(find.text('Deals'), findsNothing);
    expect(find.text('New Launches'), findsNothing);
  });

  testWidgets('a recorded drop and a tracked stock both show honestly',
      (tester) async {
    routes['/api/v1/catalog/deals'] = () => [
          {
            ..._product('bat-1', 'Willow Bat', price: 1500),
            'currentPrice': 1500,
            'previousPrice': 1800,
            'stockLeft': null,
          },
          {
            ..._product('ball-1', 'Leather Ball', price: 400),
            'currentPrice': 400,
            'previousPrice': null,
            'stockLeft': 6,
          },
        ];
    await pumpSignedIn(tester);

    await scrollHome(tester, find.text('Deals'));

    // The drop shows its percent and the old price struck through.
    expect(find.text('17% off'), findsOneWidget);
    expect(find.text('₹1,800'), findsOneWidget);
    // The low-stock product claims a count but never a saving.
    expect(find.text('Only 6 left'), findsOneWidget);
    expect(find.textContaining('% off'), findsOneWidget);
  });

  testWidgets('New Launches appears when the server sends any', (tester) async {
    routes['/api/v1/catalog/new-launches'] =
        () => [_product('new-1', 'Brand New Bat')];
    await pumpSignedIn(tester);

    await scrollHome(tester, find.text('New Launches'));
    expect(find.text('Brand New Bat'), findsWidgets);
  });

  testWidgets('the offer popup waits, then obeys "don\'t show again today"',
      (tester) async {
    routes['/api/v1/promotions/active'] = () => {
          'promotion': {
            'id': 'promo-1',
            'title': 'Diwali Bulk Sale',
            'body': 'Extra 10% off above 100 units.',
            'imageUrl': null,
            'linkType': 'none',
            'linkTarget': null,
            'endsAt': '2099-12-31T00:00:00Z',
          }
        };
    final AppServices services = await pumpSignedIn(tester);

    // It must not be on screen the instant Home opens.
    expect(find.text('Diwali Bulk Sale'), findsNothing);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Diwali Bulk Sale'), findsOneWidget);

    await tester.tap(find.text("Don't show this again today"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Diwali Bulk Sale'), findsNothing);

    // A later launch on the same device and day stays quiet.
    services.promotions.reset();
    expect(await services.promotions.takePending(), isNull);
  });

  testWidgets('reviews read from the server, and writing is offered only when '
      'the server says the buyer may', (tester) async {
    routes['/api/v1/catalog/products/bat-1/reviews'] = () => {
          'reviews': [
            {
              'id': 'r1', 'productId': 'bat-1', 'rating': 5, 'title': 'Held up all season',
              'body': 'Our academy has used these for six months.',
              'photos': <String>[], 'createdAt': '2026-10-01T10:00:00Z',
              'author': 'ABC Sports', 'verifiedBuyer': true, 'mine': false,
            }
          ],
          'total': 1, 'average': 5.0,
          'breakdown': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 1},
        };
    await pumpSignedIn(tester);
    await tester.tap(find.text('Willow Bat').first);
    await tester.pumpAndSettle();

    await scrollProductPage(tester, find.text('Ratings & Reviews'));
    expect(find.text('Ratings & Reviews'), findsOneWidget);
    expect(find.text('Held up all season'), findsOneWidget);
    expect(find.text('Verified buyer'), findsOneWidget);
    // Nothing in /reviews/pending, so this buyer is not offered the form.
    expect(find.text('Write a review'), findsNothing);
  });

  testWidgets('a buyer the server lists as eligible is offered the form',
      (tester) async {
    routes['/api/v1/reviews/pending'] = () => [
          {'productId': 'bat-1', 'name': 'Willow Bat', 'image': ''}
        ];
    await pumpSignedIn(tester);
    await tester.tap(find.text('Willow Bat').first);
    await tester.pumpAndSettle();

    await scrollProductPage(tester, find.text('Write a review'));
    expect(find.text('Write a review'), findsOneWidget);
    await tester.tap(find.text('Write a review'));
    await tester.pumpAndSettle();
    expect(find.text('Tap to rate'), findsOneWidget);
    expect(find.text('Post Review'), findsOneWidget);
  });

  testWidgets('search offers voice and scanning, and forgives a typo',
      (tester) async {
    await pumpSignedIn(tester);
    // Home's search bar is read-only and opens the search screen.
    await tester.tap(find.byType(AppSearchBar).first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Search by voice'), findsOneWidget);
    expect(find.byTooltip('Scan a barcode'), findsOneWidget);

    // "Wilow" is one letter off "Willow": the product still comes back, and
    // the screen says it is the closest match rather than an exact one.
    await tester.enterText(find.byType(TextField).first, 'wilow');
    await tester.pumpAndSettle();
    expect(find.text('Willow Bat'), findsOneWidget);
    expect(find.textContaining('showing the closest products'), findsOneWidget);

    // An exact query says nothing of the sort.
    await tester.enterText(find.byType(TextField).first, 'willow');
    await tester.pumpAndSettle();
    expect(find.textContaining('showing the closest products'), findsNothing);
  });

  testWidgets('Rewards stays hidden until the business switches it on',
      (tester) async {
    await pumpSignedIn(tester);
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Rewards'), findsNothing);
  });

  testWidgets('Rewards appears, and shows only what the server set',
      (tester) async {
    routes['/api/v1/rewards'] = () => {
          'active': true,
          'settings': {'earnsOnCheckIn': true, 'earnsOnPurchase': true},
          'balance': 240,
          'creditsWorth': 60,
          'purchasedTotal': 117528,
          'streak': 3,
          'checkedInToday': true,
          'nextTier': {
            'name': 'Gold', 'giftLabel': 'Free kit bag',
            'threshold': 300000, 'remaining': 182472, 'progress': 0.39,
          },
          'tiers': [
            {
              'id': 't1', 'name': 'Silver', 'description': '',
              'giftLabel': 'Branded cap', 'threshold': 50000,
              'reached': true, 'status': 'delivered',
            }
          ],
        };
    routes['/api/v1/rewards/ledger'] = () => {
          'entries': [
            {
              'id': 1, 'delta': 240, 'reason': 'orderEarned',
              'note': 'Earned on order SC-2026-0004', 'at': '2026-10-01T00:00:00Z',
            }
          ],
          'total': 1, 'balance': 240,
        };
    await pumpSignedIn(tester);
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    // ensureVisible scrolls whichever list actually holds it — the Account
    // tab's, not Home's, which is also alive inside the IndexedStack.
    await tester.ensureVisible(find.text('Rewards'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();

    expect(find.text('240'), findsOneWidget);
    expect(find.text('3 day streak'), findsOneWidget);
    // Already checked in today, so no button to claim again.
    expect(find.text('Check In'), findsNothing);
    expect(find.text('Next gift: Free kit bag'), findsOneWidget);
    expect(find.text('Branded cap'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('Earned on an order'), findsOneWidget);
  });

  testWidgets('the video section shows only for a product that has one',
      (tester) async {
    await pumpSignedIn(tester);

    await tester.tap(find.text('Willow Bat').first);
    await tester.pumpAndSettle();
    expect(find.byType(ProductVideoSection), findsOneWidget);
    // The section is built with the rest of the page, so no scrolling is
    // needed to know it is there.
    expect(find.text('Product Video'), findsOneWidget);
    expect(find.text('Only 7 left in stock'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leather Ball').first);
    await tester.pumpAndSettle();
    expect(find.text('Product Video'), findsNothing);
  });
}
