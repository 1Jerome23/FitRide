import 'package:fitride/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitride/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'question.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  final bool startWithSignup;

  const LoginPage({Key? key, this.startWithSignup = false}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLogin = true;

  @override
  void initState() {
    super.initState();
    isLogin = !widget.startWithSignup;
  }

  String? errorMessage = '';
  bool _isPasswordVisible = false;
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

    // Save FCM token after successful sign-in
    await _onLoginSuccess();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  } on FirebaseAuthException catch (e) {
    setState(() {
      errorMessage = 'Invalid email or password.';
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
Future _getFCMToken() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print("User notification permissions: ${settings.authorizationStatus}");
    String? token = await messaging.getToken();
    if (token != null) {
      print("FCM Token: $token");
      await _saveTokenToFirestore(token);
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        print("New FCM Token: $newToken");
        await _saveTokenToFirestore(newToken);
      });
    } else {
      print("Failed to retrieve FCM token.");
    }
  } catch (e) {
    print("Error getting FCM token: $e");
  }
}

    Future _saveTokenToFirestore(String token) async {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docRef = FirebaseFirestore.instance
            .collection('user_device_tokens')
            .doc(user.uid);

            final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        // Document exists, check if token is already in the array
        List<dynamic> existingTokens = docSnapshot.data()?['tokens'] ?? [];
        
        if (!existingTokens.contains(token)) {
          // Token doesn't exist, add it to the array
          await docRef.update({
            'tokens': FieldValue.arrayUnion([token])
          });
          print("Token added to existing user document");
        } else {
          print("Token already exists in user document");
        }
      } else {
        // Document doesn't exist, create it with the token in an array
        await docRef.set({
          'tokens': [token],
          'lastUpdated': FieldValue.serverTimestamp()
        });
        print("Created new user device tokens document");
      }
      }
    }

  Future<void> _onLoginSuccess() async {
    _prefs = await SharedPreferences.getInstance();
    await _prefs.setBool('isFirstLogin', true);
    bool isFirstLogin = _prefs.getBool('isFirstLogin') ?? true;
    await _getFCMToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print("New FCM Token: $newToken");
      await _saveTokenToFirestore(newToken);
    });
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
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Hi There!",
            style: TextStyle(
              color: Color(0xffFFA500),
              fontFamily: "Fredoka-SemiBold",
            ),
          ),
          content: Text(
            "We noticed this is your first time using the application. We'd like to collect some data for you\nto enhance the personalization of the application.",
            style: TextStyle(
              color: Colors.black,
              fontFamily: "Inter",
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                "OK",
                style: TextStyle(color: Colors.black, fontFamily: "Inter"),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
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
    final GoogleSignIn googleSignIn = GoogleSignIn();
    await googleSignIn.signOut(); // ✅ Ensure fresh login prompt
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

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

    UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    User? user = userCredential.user;

    if (user != null) {

      await _getFCMToken();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool hasCompletedQuestionnaire = prefs.getBool('${user.uid}_completed_questionnaire') ?? false;

      print("🔍 Has Completed Questionnaire: $hasCompletedQuestionnaire");

      if (!hasCompletedQuestionnaire) {
        print("➡️ Redirecting to Questionnaire...");

        // ✅ Immediately mark questionnaire as completed
        await prefs.setBool('${user.uid}_completed_questionnaire', true);
        print("✅ Set questionnaire as completed IMMEDIATELY");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => QuestionPage()),
        );
      } else {
        print("🏠 Redirecting to HomePage...");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      }
    }
  } catch (e) {
    setState(() {
      errorMessage = 'Google Sign-In failed: $e';
    });
    print("❌ Google Sign-In Error: $e");
  }
}


void completeQuestionnaire() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId == null) {
    print("❌ Error: No authenticated user.");
    return;
  }

  print("🔹 Attempting to save questionnaire completion for user: $userId");

  // ✅ Save flag
  await prefs.setBool('${userId}_completed_questionnaire', true);

  // ✅ Force reload before checking the value
  await Future.delayed(Duration(milliseconds: 300));
  await prefs.reload(); // Ensures value is persisted

  // ✅ Read and print saved value
  bool savedValue = prefs.getBool('${userId}_completed_questionnaire') ?? false;
  print("✅ Questionnaire completed flag saved: $savedValue");

  // ✅ Add another delay to ensure SharedPreferences is fully written
  await Future.delayed(Duration(milliseconds: 300));

  // Redirect to HomePage after completing the questionnaire
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => HomePage()),
  );
}
  void toggleAuthMode() {
    setState(() {
      isLogin = !isLogin;
      errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SafeArea(
      child: Scaffold(
        backgroundColor: Color(0xff222021),
        body: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image(
                  image: AssetImage("assets/logo-white.png"),
                  height: size.height * 0.2,
                ),
                Text(
                  isLogin ? "Welcome Back," : "Get on Board!",
                  style: TextStyle(
                    fontFamily: "Fredoka-SemiBold",
                    fontSize: 31,
                    color: Color(0xfffdaa48),
                  ),
                ),
                Text(
                  isLogin
                      ? "Ready to track your rides and improve your health? Log in and continue your journey!"
                      : "Start your cycling journey today! Set goals, track progress, and get personalized insights to stay healthy and motivated!",
                  style: TextStyle(
                    fontFamily: "Inter",
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                Form(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _controllerEmail,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.person_outline_outlined, color: Colors.white),
                            labelText: "Email",
                            labelStyle: TextStyle(color: Colors.white),
                            floatingLabelStyle: TextStyle(color: Colors.white),
                            hintText: "Email",
                            hintStyle: TextStyle(color: Colors.white70),
                            filled: true, 
                            fillColor: Color(0xff777B7E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10.0),
                        TextFormField(
                          controller: _controllerPassword,
                          obscureText: !_isPasswordVisible,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.lock_outline, color: Colors.white),
                            labelText: "Password",
                            labelStyle: TextStyle(color: Colors.white), 
                            floatingLabelStyle: TextStyle(color: Colors.white), 
                            hintText: "Password",
                            hintStyle: TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Color(0xff777B7E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                              icon: Icon(_isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off, color: Colors.white),
                            ),
                          ),
                        ),
                        if (errorMessage?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 50.0),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLogin
                                ? signInWithEmailAndPassword
                                : createUserWithEmailAndPassword,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 15.0),
                              backgroundColor: Color(0xfffdaa48),
                            ),
                            child: Text(
                              isLogin ? "LOGIN" : "SIGNUP",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        Row(
                          children: [
                            Expanded(
                                child: Divider(thickness: 1, color: Colors.white)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0),
                              child: Text(
                                "OR",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Expanded(
                                child: Divider(thickness: 1, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 20.0),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: signInWithGoogle,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 15.0),
                              side: BorderSide(color: Color(0xfffdaa48)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset("assets/googleicon.png", height: 24.0),
                                const SizedBox(width: 10.0),
                                Text(
                                  isLogin
                                      ? "Continue with Google"
                                      : "Continue with Google",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xfffdaa48),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        Center(
                          child: TextButton(
                            onPressed: toggleAuthMode,
                            child: Text(
                              isLogin
                                  ? "Don't have an account? Signup"
                                  : "Already have an account? Login",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}