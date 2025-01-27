import 'package:fitride/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitride/auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart'; 
import 'question.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? errorMessage = '';
  bool isLogin = true;
  late SharedPreferences _prefs;

  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn(); 
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
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

    await _onLoginSuccess();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  } on FirebaseAuthException catch (e) {
    setState(() {
      errorMessage = e.message;
    });
  }
}

Future<void> _onLoginSuccess() async {
  _prefs = await SharedPreferences.getInstance();
  
  await _prefs.setBool('isFirstLogin', true);
  
  bool isFirstLogin = _prefs.getBool('isFirstLogin') ?? true;

  if (isFirstLogin) {
    await _prefs.setBool('isFirstLogin', false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFirstLoginDialog();
    });
  }
}


  void _showFirstLoginDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Welcome!",
            style: TextStyle(color: Colors.black),
          ),
          content: Text(
            "We noticed this is your first time using the application. We'd like to collect some data for you\nto enhance the personalization of the application.",
            style: TextStyle(color: Colors.black),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                "OK",
                style: TextStyle(color: Colors.black),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => QuestionPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }

Future<void> signInWithGoogle() async {
  try {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      setState(() {
        errorMessage = 'Google Sign-In was canceled.';
      });
      return;
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await _auth.signInWithCredential(credential);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  } catch (e) {
    setState(() {
      errorMessage = 'Google Sign-In failed: $e';
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
      child: RichText(
        text: TextSpan(
          text: isLogin ? "Don't have an account? " : "Already have an account? ",
          style: TextStyle(color: Colors.white),
          children: [
            TextSpan(
              text: isLogin ? 'Register instead' : 'Login instead',
              style: TextStyle(color: Colors.yellow[700], fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryField(String title, TextEditingController controller, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: title,
        labelStyle: TextStyle(color: Colors.black),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(color: Colors.black),
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
      onPressed: signInWithGoogle,  
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color.fromARGB(255, 56, 56, 56), Color(0xFF383838)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.only(top: 30.0),
                  child: Text(
                    'Welcome to',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  child: Image.asset(
                    'assets/fitride_logo.png',
                    width: 350.0,
                    height: 150.0,
                  ),
                ),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _entryField('Email', _controllerEmail),
                ),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
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
                  width: double.infinity,
                  child: _submitButton(),
                ),
                SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  child: _loginOrRegisterButton(),
                ),
                SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  child: _socialButton('Connect with Google', Colors.red, FontAwesomeIcons.google, () {}),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
