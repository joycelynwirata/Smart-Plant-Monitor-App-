import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_planter_app/login_page.dart';
import 'package:smart_planter_app/signup_page.dart';

void main() {
  testWidgets('Login validates required fields before authenticating', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.ensureVisible(find.text('Log In'));
    await tester.tap(find.text('Log In'));
    await tester.pump();
    expect(find.text('Email required'), findsOneWidget);
    expect(find.text('Password required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login opens signup and returns to login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpPage), findsOneWidget);
    await tester.ensureVisible(find.text('Already have an account? Log in'));
    await tester.tap(find.text('Already have an account? Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('Password reset requires an email', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.ensureVisible(find.text('Forgot Password?'));
    await tester.tap(find.text('Forgot Password?'));
    await tester.pump();
    expect(find.text('Enter your email first.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
