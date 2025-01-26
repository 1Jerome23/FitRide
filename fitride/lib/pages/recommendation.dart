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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchStravaData(String accessToken) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        final athleteResponse = await http.get(
          Uri.parse('https://www.strava.com/api/v3/athlete'),
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (athleteResponse.statusCode == 200) {
          final Map<String, dynamic> athleteData = json.decode(athleteResponse.body);
          print("Athlete Data: $athleteData");

          await _saveAthleteDataToFirestore(userId, athleteData);
        } else {
          print('Error fetching athlete data: ${athleteResponse.body}');
        }

        final activitiesResponse = await http.get(
          Uri.parse('https://www.strava.com/api/v3/athlete/activities'),
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (activitiesResponse.statusCode == 200) {
          final List<dynamic> activitiesData = json.decode(activitiesResponse.body);
          print("Activities Data: $activitiesData");

          await _saveActivitiesDataToFirestore(userId, activitiesData);
        } else {
          print('Error fetching activities: ${activitiesResponse.body}');
        }
      } catch (e) {
        print('Error fetching Strava data: $e');
      } finally {
        setState(() {
          _isLoading = false;  
        });
      }
    }
  }

  Future<void> _saveAthleteDataToFirestore(String userId, Map<String, dynamic> athleteData) async {
    try {
      await FirebaseFirestore.instance.collection('athletes').doc(userId).set({
        'athlete_name': '${athleteData['firstname']} ${athleteData['lastname']}',
        'sex': athleteData['sex'] ?? '',
        'country': athleteData['country'] ?? '',
        'city': athleteData['city'] ?? '',
        'weight': athleteData['weight'] ?? '',
        'bio': athleteData['bio'] ?? '',
        'created_at': athleteData['created_at'] ?? '',
        'updated_at': athleteData['updated_at'] ?? '',
      });
      print('Athlete data saved to Firestore.');
    } catch (e) {
      print('Error saving athlete data to Firestore: $e');
    }
  }
Future<void> _saveActivitiesDataToFirestore(String userId, List<dynamic> activitiesData) async {
  try {
    final batch = FirebaseFirestore.instance.batch();

    for (var activity in activitiesData) {

      double distanceInKm = (activity['distance'] ?? 0) / 1000; 

      double averageSpeedInKmh = (activity['average_speed'] ?? 0) * 3.6;

      final activityRef = FirebaseFirestore.instance.collection('activities').doc();
      batch.set(activityRef, {
        'user_id': userId,
        'name': activity['name'] ?? 'Unnamed Activity',
        'distance': distanceInKm, 
        'start_date': activity['start_date'] ?? '',
        'type': activity['type'] ?? '',
        'average_speed': averageSpeedInKmh, 
      });
    }

    await batch.commit();
    print('Activities data saved to Firestore.');
  } catch (e) {
    print('Error saving activities data to Firestore: $e');
  }
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

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

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

          await _fetchStravaData(accessToken);
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

void _authorizeStrava() {
  final String clientId = "145840";
  final String redirectUri = 'https://fitride.trycloudflare.com/callback';
  final String responseType = "code";
  final String approvalPrompt = "force";
  final String scope = "activity:read_all";
  final String login = "true";  

  final String authorizationUrl = Uri.parse("https://www.strava.com/oauth/authorize")
      .replace(queryParameters: {
    "client_id": clientId,
    "redirect_uri": redirectUri,
    "response_type": responseType,
    "approval_prompt": approvalPrompt,
    "scope": scope,
    "login": login,  
  }).toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StravaWebView(
          initialUrl: authorizationUrl,
          onRedirect: (url) {
            final Uri parsedUrl = Uri.parse(url);
            final authCode = parsedUrl.queryParameters['code'];

            print('Authorization Code: $authCode');

            if (authCode != null && authCode.isNotEmpty) {
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

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading
                ? CircularProgressIndicator()
                : SizedBox.shrink(),
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
            icon: Icon(Icons.track_changes),
            label: 'Goals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
