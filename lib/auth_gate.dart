import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.authChanges, this.signedInBuilder});

  final Stream<User?>? authChanges;
  final Widget Function(BuildContext, User)? signedInBuilder;

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: authChanges ?? FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Scaffold(
          body: Center(
            child: Text(
              'Unable to check your session. Please restart the app.',
            ),
          ),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = snapshot.data;
      if (user != null) {
        return signedInBuilder?.call(context, user) ??
            HomePage(key: ValueKey(user.uid));
      }
      return const LoginPage();
    },
  );
}
