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
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:fitride/pages/update_metrics.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  
  // Initialize timezone data
  tz_data.initializeTimeZones();
  
  setupNotificationChannel();
  await scheduleWeeklyMetricsUpdate();
  
  runApp(const _MainApp());
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

void setupNotificationChannel() {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'default_notification_channel', 
    'Default Channel', 
    description: 'This is the default notification channel for the app.', 
    importance: Importance.high,
  );
  
  const AndroidNotificationChannel metricsChannel = AndroidNotificationChannel(
    'metrics_update_channel', 
    'Metrics Update Channel', 
    description: 'This channel is used for weekly metrics update reminders.', 
    importance: Importance.high,
  );
 
  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
      
  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(metricsChannel);
      
  // Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  
  flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      log('Local notification tapped: ${response.payload}', name: '_MainApp');
      if (response.payload == 'update_metrics') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Globals.navigatorKey.currentContext != null) {
            Navigator.pushNamed(Globals.navigatorKey.currentContext!, '/update_metrics');
          }
        });
      }
    },
  );
}

Future<void> scheduleWeeklyMetricsUpdate() async {
  try {
    // Request notification permissions for Android
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
            
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
    
    // Check if we already scheduled the notification
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isScheduled = prefs.getBool('metrics_notification_scheduled') ?? false;
    
    if (!isScheduled) {
      // Cancel any existing notifications with this ID
      await flutterLocalNotificationsPlugin.cancel(0);
      
      // Schedule the notification for one week from now
      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 7,
        10, // 10 AM
      );
      
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'metrics_update_channel',
        'Metrics Update Channel',
        channelDescription: 'This channel is used for weekly metrics update reminders.',
        importance: Importance.high,
        priority: Priority.high,
      );
      
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );
      
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'Time to Update Your Metrics',
        'Please update your weight, body fat, and metabolic rate for better tracking.',
        scheduledDate,
        platformChannelSpecifics,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'update_metrics',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      // Mark as scheduled
      await prefs.setBool('metrics_notification_scheduled', true);
      
      log('Weekly metrics update notification scheduled for $scheduledDate', name: '_MainApp');
    }
  } catch (e) {
    log('Error scheduling notification: $e', name: '_MainApp');
  }
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
          } else if (redirectTo == 'update_metrics') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Globals.navigatorKey.currentContext != null) {
                log('Navigating to /update_metrics', name: id);
                Navigator.pushNamed(Globals.navigatorKey.currentContext!, '/update_metrics');
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
          '/update_metrics': (context) => UpdateMetricsPage(), // New route
        },
      ),
    );
  }
}