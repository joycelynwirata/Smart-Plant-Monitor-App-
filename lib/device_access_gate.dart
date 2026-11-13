import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_page.dart';

/// Registration creates an account; protected device membership grants access.
class DeviceAccessGate extends StatelessWidget {
  const DeviceAccessGate({
    super.key,
    required this.user,
    this.approvals,
    this.approvedBuilder,
    this.signOut,
  });

  final User user;
  final Stream<bool>? approvals;
  final WidgetBuilder? approvedBuilder;
  final Future<void> Function()? signOut;

  Stream<bool> _watchApproval() {
    if (user.isAnonymous) return Stream.value(false);
    return FirebaseDatabase.instance
        .ref('deviceAccess/plant1/operators/${user.uid}')
        .onValue
        .map((event) => event.snapshot.value == true);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: approvals ?? _watchApproval(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!user.isAnonymous && !snapshot.hasError && snapshot.data == true) {
        return approvedBuilder?.call(context) ??
            HomePage(key: ValueKey(user.uid));
      }
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7F6),
        appBar: AppBar(title: const Text('Smart Planter')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, color: Colors.green, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.hasError
                        ? 'Unable to check device access'
                        : 'Device access pending',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your account can sign in. The project owner must approve it before you can view the planter or start watering. Send your account UID to the owner to request access.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (user.email != null) Text(user.email!),
                  const SizedBox(height: 8),
                  SelectableText(
                    'Account UID: ${user.uid}',
                    textAlign: TextAlign.center,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy account UID'),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: user.uid)),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      try {
                        await (signOut?.call() ??
                            FirebaseAuth.instance.signOut());
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Unable to sign out. Please try again.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
