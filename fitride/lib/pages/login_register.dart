import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitride/auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? errorMessage = '';
  bool isLogin = true;

  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();

  @override
  void dispose() {
    _controllerEmail.dispose();
    _controllerPassword.dispose();
    super.dispose();
  }

  Future<void> signInWithEmailAndPassword() async {
    try {
      await Auth().signInWithEmailAndPassword(
        email: _controllerEmail.text,
        password: _controllerPassword.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }

  Future<void> createUserWithEmailAndPassword() async {
    try {
      await Auth().createUserWithEmailAndPassword(
        email: _controllerEmail.text,
        password: _controllerPassword.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }
  Widget _submitButton() {
  return ElevatedButton(
    onPressed: isLogin ? signInWithEmailAndPassword : createUserWithEmailAndPassword,
    child: Text(isLogin ? 'Login' : 'Register'),
    style: ElevatedButton.styleFrom(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 30),
    ),
  );
}

Widget _loginOrRegisterButton() {
  return TextButton(
    onPressed: () {
      setState(() {
        isLogin = !isLogin;
      });
    },
    child: Text(isLogin ? 'Register instead' : 'Login instead'),
  );
}
  Widget _entryField(String title, TextEditingController controller, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: title,
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _errorMessage() {
    return errorMessage == null || errorMessage!.isEmpty
        ? const SizedBox.shrink()
        : Text('Hmm? $errorMessage', style: TextStyle(color: Colors.red));
  }

 Widget _socialButton(String text, Color color, IconData icon, VoidCallback onPressed) {
  return ElevatedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, color: Colors.white),  
    label: Text(
      text,
      style: TextStyle(color: Colors.white),  
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
    ),
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: SingleChildScrollView( 
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(top: 30.0),
              child: Text(
                'Welcome to',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 5.0),
              child: Text(
                'FitRide',
                style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 15),
            Container(
              width: 350,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
              ),
              child: _entryField('Email', _controllerEmail),
            ),
            SizedBox(height: 15),
            Container(
              width: 350,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
              ),
              child: _entryField('Password', _controllerPassword, isPassword: true),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: Text('Forgot Password?', style: TextStyle(color: Colors.blue)),
              ),
            ),
            _errorMessage(),
            SizedBox(height: 10),
            Container(
              width: 300,
              child: _submitButton(),
            ),
            SizedBox(height: 5),
            Container(
              width: 300,
              child: _loginOrRegisterButton(),
            ),
            SizedBox(width: 350, child: _socialButton('Connect with Facebook', Colors.blueAccent, Icons.facebook, () {})),
            SizedBox(height: 10),
            SizedBox(width: 350, child: _socialButton('Connect with Google', Colors.red, FontAwesomeIcons.google, () {})),
            Image.asset(
              'assets/bicycle_home.png',
              height: 100,
            ),
          ],
        ),
      ),
    ),
  );
}

}


//login register UI