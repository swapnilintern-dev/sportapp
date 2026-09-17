import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport/app/app_scope.dart';
import 'package:sport/data/local/local_store.dart';
import 'package:sport/main.dart';

//==============================================================================
// Widget flow: Splash → Login → OTP → Home → product → cart → checkout gate.
// Runs against the in-memory store so nothing touches device storage.
//==============================================================================

void main() {
  late AppServices services;

  setUp(() {
    services = AppServices.demo(MemoryStore());
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532); // iPhone-class portrait
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SpocartApp(services: services));
  }

  Future<void> signIn(WidgetTester tester) async {
    // Splash plays for ~2.2 s, then routes to Login.
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pumpAndSettle();
    expect(find.text('Login with Mobile Number'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle(const Duration(milliseconds: 800));
    expect(find.text('Verify Your Mobile Number'), findsOneWidget);

    final String code = services.session.challenge!.demoCode!;
    await tester.enterText(find.byType(TextField).first, code);
    await tester.pumpAndSettle(const Duration(milliseconds: 900));
    expect(find.text('Popular Products'), findsOneWidget);
  }

  testWidgets('splash shows the brand and routes to login', (tester) async {
    await pumpApp(tester);
    expect(find.text('Your Sports Business Partner'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pumpAndSettle();
    expect(find.text('Login with Mobile Number'), findsOneWidget);
  });

  testWidgets('OTP login lands on Home with the catalogue', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(find.text('Kashmir Willow Cricket Bat'), findsWidgets);
    expect(services.session.isSignedIn, isTrue);
  });

  testWidgets('add to cart from Home updates the cart tab and gates checkout',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.text('Add to Cart').first);
    await tester.pumpAndSettle();
    expect(services.cart.lineCount, 1);
    expect(services.cart.quantityOf('ck-kashmir-willow-bat'), 10);

    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('My Cart (1)'), findsOneWidget);
    expect(find.text('Proceed to Checkout'), findsOneWidget);

    // The "added to cart" snackbar must auto-dismiss and not cover the CTA.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    // Unregistered buyers are asked for business details first.
    await tester.tap(find.text('Proceed to Checkout'));
    await tester.pumpAndSettle();
    expect(find.text('Complete Your Business Details'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('Delivery Address'), findsOneWidget);
  });

  testWidgets('categories tab lists every sport and opens a listing',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.text('Table Tennis'), findsOneWidget);
    expect(find.text('Gym & Fitness'), findsOneWidget);

    await tester.tap(find.text('Badminton'));
    await tester.pumpAndSettle();
    expect(find.text('Rackets'), findsOneWidget);
    expect(find.text('Badminton Racket'), findsOneWidget);
  });
}
