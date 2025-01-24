import 'package:fitride/pages/profile.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart';
import 'goal_tracking.dart';
import 'login_register.dart';
import 'strava_webview.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class RecommendationPage extends StatefulWidget {
  @override
  _RecommendationPageState createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  int _selectedIndex = 1;

  void _authorizeStrava() {
    final String clientId = "145840"; 
    final String redirectUri = "com.example.fitride"; 
    final String responseType = "code";
    final String approvalPrompt = "auto";
    final String scope = "activity:write,read";

    final String authorizationUrl = Uri.parse("https://www.strava.com/oauth/mobile/authorize")
        .replace(queryParameters: {
          "client_id": clientId,
          "redirect_uri": redirectUri,
          "response_type": responseType,
          "approval_prompt": approvalPrompt,
          "scope": scope,
        }).toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StravaWebView(
          initialUrl: authorizationUrl,
          onRedirect: (url) {
            final Uri parsedUrl = Uri.parse(url);
            final authCode = parsedUrl.queryParameters['code'];

            if (authCode != null) {
              print('Authorization Code: $authCode');
              _exchangeAuthorizationCodeForTokens(authCode); 
            } else {
              print('Authorization failed: No code found in redirect URL.');
            }
          },
        ),
      ),
    );
  }

  Future<void> _exchangeAuthorizationCodeForTokens(String code) async {
    final String clientId = "145840"; 
    final String clientSecret = "63ef4f6d5aa9f156ba84279c51569261cb37e905"; 

    try {
      final response = await http.post(
        Uri.parse('https://www.strava.com/oauth/token'),
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String accessToken = data['access_token'];
        final String refreshToken = data['refresh_token'];

        final userId = FirebaseAuth.instance.currentUser?.uid;

        if (userId != null) {
          await FirebaseFirestore.instance.collection('user_tokens').doc(userId).set({
            'access_token': accessToken,
            'refresh_token': refreshToken,
          });

          print('Tokens saved in Firestore');
        } else {
          print('User is not authenticated.');
        }
      } else {
        print('Error exchanging authorization code: ${response.body}');
      }
    } catch (e) {
      print('Error during token exchange: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => GoalTrackingPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ProfilePage()),
        );
        break;
    }
  }

  // Handle logout
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          "FitRide",
          style: GoogleFonts.roboto(
            color: Colors.orange,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: _logout,
              child: Image.asset(
                'assets/logobike.png',
                height: 40,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Recommendation content goes here",
              style: GoogleFonts.lato(fontSize: 18, color: Colors.black),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authorizeStrava,
              child: Text('Authorize Strava'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: GoogleFonts.lato(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.data_usage),
            label: 'Goal/Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
