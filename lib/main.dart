import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:silag/firebase_options.dart';
import 'package:silag/main_screen.dart';
import 'pages/login.dart';
import 'services/auth_service.dart';
import 'services/ban_check_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // =========================================================================
  // --- FIREBASE MESSAGING (COMMENTED OUT FOR CHROME/WEB TESTING) ---
  // =========================================================================
  // Uncomment this entire block when testing on a physical phone or emulator!

  /*
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  String? token = await messaging.getToken();
  print("🔥 FIREBASE DEVICE TOKEN: $token");
  */

  // =========================================================================

  // If the user already has a saved session (returning user), start ban-check
  // polling immediately so a user who was banned while offline is kicked out
  // as soon as they reopen the app.
  final existingToken = await AuthService().getToken();
  if (existingToken != null && existingToken.isNotEmpty) {
    BanCheckService().start();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SILAG',
      theme: ThemeData(fontFamily: 'Poppins'),

      navigatorKey: appNavigatorKey,

      // Named routes for app-wide navigation.
      routes: {
        '/login': (context) {
          final reason = ModalRoute.of(context)?.settings.arguments as String?;
          return Login(initialErrorMessage: reason);
        },
        '/home': (context) => const MainScreen(),
      },

      home: FutureBuilder<String?>(
        future: AuthService().getToken(),
        builder: (context, snapshot) {
          // While checking storage, show a loading spinner
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF101C45)),
              ),
            );
          }

          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.isNotEmpty) {
            return const MainScreen();
          }

          return const Login();
        },
      ),
    );
  }
}
