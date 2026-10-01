import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport/app/app_scope.dart';
import 'package:sport/core/widgets/buttons.dart';
import 'package:sport/data/local/local_store.dart';
import 'package:sport/data/models/catalog.dart';
import 'package:sport/data/sources/demo_catalog.dart';
import 'package:sport/features/catalog/image_viewer_screen.dart';
import 'package:sport/main.dart';

//==============================================================================
// Phase A widget flows: one help entry point, the "Size not selected" fix,
// remove + Undo, Continue Shopping, and the full-screen image viewer.
//==============================================================================

void main() {
  late AppServices services;

  final Product sized =
      kDemoProducts.firstWhere((Product p) => p.id == 'ck-kashmir-willow-bat');

  setUp(() {
    services = AppServices.demo(MemoryStore());
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SpocartApp(services: services));
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle(const Duration(milliseconds: 800));
    final String code = services.session.challenge!.demoCode!;
    await tester.enterText(find.byType(TextField).first, code);
    await tester.pumpAndSettle(const Duration(milliseconds: 900));
    expect(find.text('Best Sellers'), findsOneWidget);
  }

  Future<void> openCartTab(WidgetTester tester) async {
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
  }

  testWidgets('cart has exactly one help entry point', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    services.cart.add(sized, size: 'SH');
    await openCartTab(tester);

    expect(find.text('Need Help?'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('Need Help?'));
    await tester.pumpAndSettle();
    expect(find.text('Chat Now'), findsOneWidget);
  });

  testWidgets('a size-less line is flagged, blocks checkout and can be fixed',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    // A legacy line saved before sizes were enforced.
    services.cart.add(sized);
    await openCartTab(tester);

    expect(find.text('Size not selected'), findsOneWidget);

    await tester.tap(find.text('Proceed to Checkout'));
    await tester.pumpAndSettle();
    expect(find.text('Checkout'), findsNothing);
    expect(find.textContaining('needs a size'), findsOneWidget);

    await tester.tap(find.widgetWithText(GhostButton, 'Select size'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save size'));
    await tester.pumpAndSettle();

    expect(services.cart.lines.single.size, '6');
    expect(services.cart.missingSize, isEmpty);
    expect(find.text('Size not selected'), findsNothing);
  });

  testWidgets('removing a line offers Undo that restores it', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    services.cart.add(sized, size: 'SH', qty: 25);
    await openCartTab(tester);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(services.cart.isEmpty, isTrue);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(services.cart.lineCount, 1);
    expect(services.cart.lines.single.quantity, 25);
    expect(services.cart.lines.single.size, 'SH');
  });

  testWidgets('Continue Shopping leaves the cart for the catalogue',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    services.cart.add(sized, size: 'SH');
    await openCartTab(tester);

    await tester.scrollUntilVisible(find.text('Continue Shopping'), 200);
    await tester.tap(find.text('Continue Shopping'));
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsWidgets);
  });

  testWidgets('tapping a product photo opens the full-screen viewer',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester);

    await tester.tap(find.text(sized.name).first);
    await tester.pumpAndSettle();
    expect(find.text(sized.brand.toUpperCase()), findsOneWidget);

    await tester.tap(find.byType(PageView).first);
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerScreen), findsNothing);
  });
}
