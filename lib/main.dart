import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'auth_gate.dart';

/// 🔥 Background handler (required)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Background message: ${message.notification?.title}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔥 Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    setupNotifications();
  }

  void setupNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    print("CURRENT UID: ${FirebaseAuth.instance.currentUser?.uid}");

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('Permission: ${settings.authorizationStatus}');

    String? token = await messaging.getToken(
      vapidKey: "BOgK5JT_3z5O7aXSrA_EyaT79SlBAYA9o782efKYrVG08-rNkVv4b6wgYIhPZ_Hgh5ENygsWpcjlswg_TKI76tc",
    );

    print("FCM TOKEN: $token");

 

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground notification received");

      if (message.notification != null) {
        print("Title: ${message.notification!.title}");
        print("Body: ${message.notification!.body}");
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification clicked!");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Planter',
      theme: ThemeData(useMaterial3: true),
      home: const AuthGate(),
    );
  }
}