import 'package:fitride/pages/goal_tracking.dart';
import 'package:fitride/pages/home_page.dart';
import 'package:fitride/pages/login_register.dart';
import 'package:fitride/pages/question.dart';
import 'package:fitride/pages/question_after_exercise.dart';
import 'package:flutter/material.dart';
import 'package:fitride/widget_tree.dart'; // Assuming this imports your main app UI structure
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';  
import 'package:fitride/pages/recommendation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        '/': (context) => HomePage(),
        '/questionnaire': (context) => QuestionPage(),
        '/homepage': (context) => WidgetTree(),
        '/recommendation': (context) => RecommendationPage(), 
        '/goal_tracking': (context) => GoalTrackingPage(),
      },
    );
  }
}
