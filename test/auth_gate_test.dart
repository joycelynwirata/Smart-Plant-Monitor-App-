import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_planter_app/auth_gate.dart';
import 'package:smart_planter_app/login_page.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'user-1';
}

void main() {
  testWidgets('Keeps the auth listener alive through login and logout', (
    tester,
  ) async {
    final auth = StreamController<User?>();
    addTearDown(auth.close);
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authChanges: auth.stream,
          signedInBuilder: (_, user) =>
              Scaffold(body: Text('Signed in: ${user.uid}')),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    auth.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    auth.add(_User());
    await tester.pumpAndSettle();
    expect(find.text('Signed in: user-1'), findsOneWidget);
    auth.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
