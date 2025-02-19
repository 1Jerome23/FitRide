import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_notifications_handler/firebase_notifications_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'mi_scale.dart'; 
import 'package:fitride/widget_tree.dart';
import 'package:fitride/pages/login_register.dart';
import 'package:fitride/pages/question.dart';
import 'package:fitride/pages/recommendation.dart';
import 'package:fitride/pages/profile.dart';
import 'package:fitride/pages/goal_tracking.dart';
import 'package:fitride/pages/question_after_exercise.dart';
import 'package:fitride/globals.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  setupNotificationChannel();

  await requestPermissions();

  final MiScaleService miScaleService = MiScaleService();

  await _initializeMiScaleService(miScaleService);

  runApp(const _MainApp());
}

Future<bool> requestPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
    Permission.location,
  ].request();

  // Check if all permissions were granted
  bool allGranted = statuses.values.every((status) => status.isGranted);
  return allGranted;
}

Future<void> checkPermissions() async {
  bool granted = await requestPermissions();
  if (!granted) {
    throw Exception('Bluetooth or Location permission not granted.');
  }
}

Future<void> _initializeMiScaleService(MiScaleService miScaleService) async {
  try {
    print("Scanning for Mi Scale devices...");
    List<String> deviceIds = await miScaleService.scanForDevices();

    if (deviceIds.isEmpty) {
      print("No Mi Scale devices found. Retrying in 5 seconds...");
      await Future.delayed(Duration(seconds: 5));
      deviceIds = await miScaleService.scanForDevices();
    }

    if (deviceIds.isNotEmpty) {
      String selectedDeviceId = deviceIds.first;
      print("Connecting to device: $selectedDeviceId");

      bool isConnected = await miScaleService.connectToScale(selectedDeviceId);
      if (!isConnected) {
        throw Exception("Failed to connect to the Mi Scale device.");
      }

      final weightData = await miScaleService.getWeightData(selectedDeviceId);
      final bodyWater = weightData['bodyWater'];
      final bodyMass = weightData['bodyMass'];
      print("Weight: ${weightData['weight']}, Body Water: $bodyWater, Body Mass: $bodyMass");

    } else {
      print("No Mi Scale devices found after retry.");
    }
  } catch (e) {
    print("MiScaleService Error: $e");
  }
}

// Set up the notification channel
void setupNotificationChannel() {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'default_notification_channel', // ID
    'Default Channel', // Name
    description: 'This is the default notification channel for the app.', // Description
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
        print(
          'Notification received while app is open with payload ${info.payload}',
        );
      },
      onTap: (info) {
        final payload = info.payload;
        final appState = info.appState;
        final firebaseMessage = info.firebaseMessage;
        print(
          'Notification tapped with $appState & payload $payload. Firebase message: $firebaseMessage',
        );
        if (payload != null && payload.containsKey('redirect_to')) {
          final redirectTo = payload['redirect_to'];
          print('Redirecting to: $redirectTo');
          if (redirectTo == 'question_after_exercise') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Globals.navigatorKey.currentContext != null) {
                print('Navigating to /question_after_exercise');
                Navigator.pushNamed(Globals.navigatorKey.currentContext!, '/question_after_exercise');
              } else {
                print('Navigation failed: No valid context available.');
              }
            });
          }
        } else {
          print('No valid redirect_to key in payload.');
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
          '/': (context) => LoginPage(),
          '/questionnaire': (context) => QuestionPage(),
          '/homepage': (context) => WidgetTree(),
          '/recommendation': (context) => RecommendationPage(),
          '/goal_tracking': (context) => GoalTrackingPage(),
          '/profile': (context) => ProfilePage(),
          '/question_after_exercise': (context) => PostExercise(),
        },
      ),
    );
  }
}