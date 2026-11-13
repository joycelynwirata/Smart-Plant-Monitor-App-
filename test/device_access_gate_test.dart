import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_planter_app/device_access_gate.dart';

class _User extends Fake implements User {
  _User({this.anonymous = false});
  final bool anonymous;
  @override
  String get uid => 'professor-uid';
  @override
  String? get email => 'professor@example.invalid';
  @override
  bool get isAnonymous => anonymous;
}

void main() {
  testWidgets(
    'Registration waits for approval; granting and revoking updates access',
    (tester) async {
      final approvals = StreamController<bool>();
      var signedOut = false;
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceAccessGate(
            user: _User(),
            approvals: approvals.stream,
            approvedBuilder: (_) =>
                const Scaffold(body: Text('Device dashboard')),
            signOut: () async {
              signedOut = true;
            },
          ),
        ),
      );
      approvals.add(false);
      await tester.pumpAndSettle();
      expect(find.text('Device access pending'), findsOneWidget);
      expect(find.text('Account UID: professor-uid'), findsOneWidget);
      expect(find.text('Device dashboard'), findsNothing);
      approvals.add(true);
      await tester.pumpAndSettle();
      expect(find.text('Device dashboard'), findsOneWidget);
      approvals.add(false);
      await tester.pumpAndSettle();
      expect(find.text('Device access pending'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(signedOut, isTrue);
      await tester.pumpWidget(const SizedBox());
      approvals.close();
      await tester.pump();
    },
  );
  testWidgets(
    'Anonymous identities cannot enter the app even if marked approved',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceAccessGate(
            user: _User(anonymous: true),
            approvals: Stream.value(true),
            approvedBuilder: (_) =>
                const Scaffold(body: Text('Device dashboard')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Device access pending'), findsOneWidget);
      expect(find.text('Device dashboard'), findsNothing);
    },
  );
}
