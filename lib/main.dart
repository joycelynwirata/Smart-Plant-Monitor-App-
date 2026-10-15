import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'auth_gate.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

bool get _supportsMessaging =>
    kIsWeb ||
    {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (_supportsMessaging) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;

  @override
  void initState() {
    super.initState();
    if (!_supportsMessaging) return;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) unawaited(_setupNotifications(user));
    });
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) unawaited(_saveToken(user, token));
      },
      onError: (Object error) =>
          debugPrint('Notification token refresh failed.'),
    );
  }

  Future<void> _saveToken(User user, String token) async {
    if (!mounted || FirebaseAuth.instance.currentUser?.uid != user.uid) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notificationTokens')
          .doc(token)
          .set({'token': token, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (error) {
      debugPrint('Unable to register notification token.');
    }
  }

  Future<void> _setupNotifications(User user) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (!mounted ||
          settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      final token = await messaging.getToken(
        vapidKey: kIsWeb
            ? 'BOgK5JT_3z5O7aXSrA_EyaT79SlBAYA9o782efKYrVG08-rNkVv4b6wgYIhPZ_Hgh5ENygsWpcjlswg_TKI76tc'
            : null,
      );
      if (token != null) await _saveToken(user, token);
    } catch (error) {
      debugPrint('Notifications unavailable on this device.');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _tokenSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Smart Planter',
    theme: ThemeData(useMaterial3: true),
    home: const AuthGate(),
  );
}
