import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitride/pages/home_page.dart';
import 'package:fitride/pages/login_register.dart';
import 'package:flutter/material.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasData) {
            return HomePage();
          } else if (snapshot.hasError) {
            return Center(child: Text('Something went wrong!'));
          } else {
            return LoginPage();
          }
        },
      ),
    );
  }
}