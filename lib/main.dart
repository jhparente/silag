import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:silag/firebase_options.dart';
import 'package:silag/main_screen.dart';
import 'pages/login.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';
import 'services/ban_check_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

      // Use ApiClient.navigatorKey — this is the SAME key ApiClient uses
      // internally to call pushNamedAndRemoveUntil('/login').
      // Using a separate key was the bug — the navigator was always null.
      navigatorKey: ApiClient.navigatorKey,

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
