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
import 'package:fitride/pages/food_questionnaire.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';


// Global notification plugin instance for scheduled notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  
  // Initialize timezone for scheduled notifications
  tz.initializeTimeZones();
  
  // Setup notification channels and initialize plugins
  await setupNotifications();
  
  runApp(const _MainApp());
}

  Future<void> setupNotifications() async {
    // Setup channel for Firebase notifications
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'default_notification_channel', 
      'Default Channel', 
      description: 'This is the default notification channel for the app.', 
      importance: Importance.high,
    );
  
    // Create food reminder channel
    const AndroidNotificationChannel foodChannel = AndroidNotificationChannel(
      'food_reminder_channel', 
      'Food Reminders', 
      description: 'Daily reminders to complete food questionnaire.', 
      importance: Importance.high,
    );

    // Initialize notification settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      log('Local notification tapped with payload: ${response.payload}');
      
      if (response.payload != null) {
        try {
          final Map<String, dynamic> payload = Map<String, dynamic>.from(
            (response.payload!.startsWith('{')) 
                ? json.decode(response.payload!) 
                : {'redirect_to': response.payload}
          );
          
          if (payload.containsKey('redirect_to') && payload['redirect_to'] == 'food_questionnaire') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Globals.navigatorKey.currentContext != null) {
                Navigator.pushNamed(Globals.navigatorKey.currentContext!, '/food_questionnaire');
              }
            });
          }
        } catch (e) {
          log('Error parsing notification payload: $e');
        }
      }
    },
  );

  // Create notification channels
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
      
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(foodChannel);
      
  log('Notification setup complete');
}

// Schedule a daily notification for food questionnaire
Future<void> scheduleDailyFoodReminder() async {
  // Cancel any existing food reminders first
  await flutterLocalNotificationsPlugin.cancel(1001);
  
  // Set notification time (e.g., 7:00 PM)
  final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
  tz.TZDateTime scheduledDate = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    19, // 7 PM
    0,  // 0 minutes
  );
  
  // If scheduled time is in the past, set for next day
  if (scheduledDate.isBefore(now)) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }
  
  await flutterLocalNotificationsPlugin.zonedSchedule(
    1001, // Unique ID for food reminders
    'Food Diary Reminder',
    'Time to log what you ate today!',
    scheduledDate,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'food_reminder_channel',
        'Food Reminders',
        channelDescription: 'Daily reminders to complete food questionnaire.',
        importance: Importance.high,
        priority: Priority.high,
        color: Colors.black,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time, // Makes it daily
    payload: '{"redirect_to":"food_questionnaire"}',
  );
  
  log('Daily food reminder scheduled for $scheduledDate');
}

class _MainApp extends StatelessWidget {
  static const id = '_MainApp';
  const _MainApp();

  @override
  Widget build(BuildContext context) {
    // Enable daily food reminders on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduleDailyFoodReminder();
    });
    
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
          } else if (redirectTo == 'food_questionnaire') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Globals.navigatorKey.currentContext != null) {
                log('Navigating to /food_questionnaire', name: id);
                Navigator.pushNamed(Globals.navigatorKey.currentContext!, '/food_questionnaire');
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
          '/recommendation': (context) => PostExercise(),
          '/goal_tracking': (context) => GoalTrackingPage(),
          '/profile': (context) => ProfilePage(),
          '/question_after_exercise': (context) => PostExercise(),
          '/food_questionnaire': (context) => FoodQuestionnairePage(), // New route
        },
      ),
    );
  }
}