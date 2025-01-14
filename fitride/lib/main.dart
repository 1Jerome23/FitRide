import 'package:flutter/material.dart';
import 'package:fitride/widget_tree.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';  

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
        primaryColor: Colors.black, // Set primary color to black
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Colors.black, // Set primary color to black
          secondary: Colors.black, // Set secondary color to black
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Colors.white, // Set text color to white
              displayColor: Colors.white, // Set text color to white
            ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black, // Set AppBar background color to black
          elevation: 5,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20), // Set title text color to white
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Colors.white, // Set selected item color to white
          unselectedItemColor: Colors.grey, // Set unselected item color to grey
          backgroundColor: Colors.black, // Set background color of BottomNavigationBar to black
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Colors.black), // Set button background color to black
            foregroundColor: MaterialStateProperty.all(Colors.white), // Set button text color to white
          ),
        ),
      ),
      home: const WidgetTree(),
    );
  }
}
