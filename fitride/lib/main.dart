import 'package:fitride/pages/goal_tracking.dart';
import 'package:fitride/pages/login_register.dart';
import 'package:fitride/pages/question.dart';
import 'package:flutter/material.dart';
import 'package:fitride/widget_tree.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_notifications_handler/firebase_notifications_handler.dart';
import 'package:fitride/pages/profile.dart';
import 'package:fitride/globals.dart';
import 'dart:developer';
import 'package:fitride/pages/question_after_exercise.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fitride/pages/welcome.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  setupNotificationChannel(); 
  runApp(const _MainApp());
}

void setupNotificationChannel() {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'default_notification_channel', 
    'Default Channel', 
    description: 'This is the default notification channel for the app.', 
    importance: Importance.high,
  );
 
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

class _MainApp extends StatelessWidget {
  static const id = '_MainApp';
  const _MainApp();

  @override
  Widget build(BuildContext context) {
    return FirebaseNotificationsHandler(
      localNotificationsConfiguration: LocalNotificationsConfiguration(
        androidConfig: AndroidNotificationsConfig(),
        iosConfig: IosNotificationsConfig(),
      ),
      shouldHandleNotification: (msg) => true,
      onOpenNotificationArrive: (info) {
        log(
          'Notification received while app is open with payload ${info.payload}',
          name: id,
        );
      },
      onTap: (info) {
        final payload = info.payload;
        final appState = info.appState;
        final firebaseMessage = info.firebaseMessage;

        log(
          'Notification tapped with $appState & payload $payload. Firebase message: $firebaseMessage',
          name: id,
        );

        if (payload != null && payload.containsKey('redirect_to')) {
          final redirectTo = payload['redirect_to'];
          log('Redirecting to: $redirectTo', name: id);

          if (redirectTo == 'question_after_exercise') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Globals.navigatorKey.currentContext != null) {
                log('Navigating to /question_after_exercise', name: id);
                Navigator.pushNamed(Globals.navigatorKey.currentContext!, '/question_after_exercise');
              } else {
                log('Navigation failed: No valid context available.', name: id);
              }
            });
          }
        } else {
          log('No valid redirect_to key in payload.', name: id);
        }
      },
      onFcmTokenInitialize: (token) {
        print('FCM Token Initialized: $token');
        Globals.fcmTokenNotifier.value = token;
      },
      onFcmTokenUpdate: (token) {
        print('FCM Token Updated: $token');
        Globals.fcmTokenNotifier.value = token;
      },
      child: MaterialApp(
        navigatorKey: Globals.navigatorKey,
        scaffoldMessengerKey: Globals.scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: Colors.black,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: Colors.black,
            secondary: Colors.black,
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.black,
            elevation: 5,
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.black,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.black),
              foregroundColor: MaterialStateProperty.all(Colors.white),
            ),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => WelcomePage(),
          '/questionnaire': (context) => QuestionPage(),
          '/homepage': (context) => WidgetTree(),
          '/recommendation': (context) => FoodQuestionnairePage(),
          '/goal_tracking': (context) => GoalTrackingPage(),
          '/profile': (context) => ProfilePage(),
          '/question_after_exercise': (context) => FoodQuestionnairePage(),
        },
      ),
    );
  }
}