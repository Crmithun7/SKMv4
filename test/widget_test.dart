// Basic smoke tests for the app's startup flow.
//
// The previous version of this file was still the default `flutter create`
// counter-app test (`find.text('0')`, tapping a '+' icon) even though this
// app has no counter anywhere — it didn't test anything real and would fail
// immediately if run.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skmcam/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the login screen when no employee session is stored', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('login form validates empty fields before calling the backend', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // The "Sign In" button is a custom InkWell, not an ElevatedButton —
    // tap its label directly.
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your login code'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
}
