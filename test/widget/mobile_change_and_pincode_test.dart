import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport/app/app_scope.dart';
import 'package:sport/core/widgets/buttons.dart';
import 'package:sport/core/widgets/inputs.dart';
import 'package:sport/data/local/local_store.dart';
import 'package:sport/data/models/account.dart';
import 'package:sport/main.dart';

//==============================================================================
// A7: the registered number can only change through an OTP on the new number.
// A10: a complete PIN code fills the city and state, without ever overwriting
// what the buyer typed.
//==============================================================================

void main() {
  late AppServices services;

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
    await tester.enterText(
        find.byType(TextField).first, services.session.challenge!.demoCode!);
    await tester.pumpAndSettle(const Duration(milliseconds: 900));
    expect(find.text('Popular Products'), findsOneWidget);
  }

  Future<void> openAccountItem(WidgetTester tester, String label) async {
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(label), 200);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('A7 · change mobile number', () {
    testWidgets('the number only changes after the OTP is verified',
        (tester) async {
      await pumpApp(tester);
      await signIn(tester);
      await openAccountItem(tester, 'Change Mobile Number');

      expect(find.text('+91 9876543210'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '9123456780');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Send OTP'));
      await tester.pumpAndSettle(const Duration(milliseconds: 900));

      // A code was requested for the NEW number, and nothing has changed yet.
      expect(find.text('Enter the OTP sent to +91 9123456780'), findsOneWidget);
      expect(services.session.session!.mobile, '9876543210');

      final String code = services.session.mobileChangeChallenge!.demoCode!;
      await tester.enterText(find.byType(TextField).first, code);
      await tester.pumpAndSettle(const Duration(milliseconds: 900));

      expect(services.session.session!.mobile, '9123456780');
      expect(find.textContaining('Your number is now +91 9123456780'),
          findsOneWidget);
    });

    testWidgets('a wrong code changes nothing', (tester) async {
      await pumpApp(tester);
      await signIn(tester);
      await openAccountItem(tester, 'Change Mobile Number');

      await tester.enterText(find.byType(TextFormField).first, '9123456780');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Send OTP'));
      await tester.pumpAndSettle(const Duration(milliseconds: 900));

      await tester.enterText(find.byType(TextField).first, '000000');
      await tester.pumpAndSettle(const Duration(milliseconds: 900));

      expect(services.session.session!.mobile, '9876543210');
      expect(find.textContaining('Incorrect OTP'), findsOneWidget);
    });

    testWidgets('the current number is refused', (tester) async {
      await pumpApp(tester);
      await signIn(tester);
      await openAccountItem(tester, 'Change Mobile Number');

      await tester.enterText(find.byType(TextFormField).first, '9876543210');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Send OTP'));
      await tester.pumpAndSettle(const Duration(milliseconds: 900));

      expect(find.textContaining('already your registered number'), findsOneWidget);
      expect(services.session.mobileChangeChallenge, isNull);
    });

    testWidgets('Business Details shows the number read-only with Change',
        (tester) async {
      await pumpApp(tester);
      await signIn(tester);
      await openAccountItem(tester, 'Business Details');

      expect(find.text('Your verified sign-in number.'), findsOneWidget);
      await tester.tap(find.widgetWithText(GhostButton, 'Change'));
      await tester.pumpAndSettle();
      expect(find.text('Change Mobile Number'), findsWidgets);
    });
  });

  group('A10 · PIN code autofill', () {
    // AppTextField draws its label with RichText beside the field, so match the
    // field through the AppTextField that carries that label.
    Finder fieldLabelled(String label) => find.descendant(
          of: find.byWidgetPredicate(
              (Widget w) => w is AppTextField && w.label == label),
          matching: find.byType(TextFormField),
        );

    Finder pinField() => fieldLabelled('PIN Code');
    Finder cityField() => fieldLabelled('City');
    String textOf(WidgetTester tester, Finder f) =>
        tester.widget<TextFormField>(f).controller!.text;

    Future<void> openAddressForm(WidgetTester tester) async {
      await openAccountItem(tester, 'Addresses');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Add New Address').first);
      await tester.pumpAndSettle();
      // The city / PIN row is below the fold and the list only builds what is on
      // screen, so scroll the form down to it first.
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(pinField(), findsOneWidget);
      expect(cityField(), findsOneWidget);
    }

    testWidgets('a known PIN fills the city and state', (tester) async {
      await pumpApp(tester);
      await signIn(tester);
      await openAddressForm(tester);

      await tester.enterText(pinField(), '411001');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Pune City, Maharashtra'), findsOneWidget);
      expect(textOf(tester, cityField()), 'Pune City');
    });

    testWidgets('a city the buyer typed is never overwritten', (tester) async {
      await pumpApp(tester);
      await signIn(tester);
      await openAddressForm(tester);

      await tester.enterText(cityField(), 'Pimpri');
      await tester.enterText(pinField(), '411001');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(textOf(tester, cityField()), 'Pimpri');
      // The lookup still reports what it found, so the buyer can decide.
      expect(find.text('Pune City, Maharashtra'), findsOneWidget);
    });

    testWidgets('a PIN the lookup cannot resolve is reported, not fatal',
        (tester) async {
      await pumpApp(tester);
      await signIn(tester);
      await openAddressForm(tester);

      await tester.enterText(pinField(), '999999');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.textContaining('Please type your city and state'),
          findsOneWidget);
      expect(textOf(tester, cityField()), isEmpty);
    });

    testWidgets('the last PIN typed wins', (tester) async {
      await pumpApp(tester);
      await signIn(tester);
      await openAddressForm(tester);

      await tester.enterText(pinField(), '411001');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(pinField(), '400001');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Mumbai, Maharashtra'), findsOneWidget);
      expect(textOf(tester, cityField()), 'Mumbai');
    });

    testWidgets('an incomplete PIN triggers nothing', (tester) async {
      await pumpApp(tester);
      await signIn(tester);
      await openAddressForm(tester);

      await tester.enterText(pinField(), '4110');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.textContaining('Looking up'), findsNothing);
      expect(textOf(tester, cityField()), isEmpty);
    });
  });

  test('UserSession.copyWith can move the mobile and keeps the rest', () {
    final UserSession s = UserSession(
      mobile: '9876543210',
      signedInAt: DateTime.utc(2026, 9, 17),
      creditLimit: 100000,
    );
    final UserSession moved = s.copyWith(mobile: '9123456780');
    expect(moved.mobile, '9123456780');
    expect(moved.creditLimit, 100000);
    expect(moved.signedInAt, s.signedInAt);
  });
}
