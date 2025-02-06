import 'package:fitride/pages/health_summary.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'goal_tracking.dart';
import 'login_register.dart';
import 'recommendation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:fitride/pages/change_password.dart';
import 'strava_webview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fitride/pages/edit_goal.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 3;
  bool _isLoading = true;
  String name = "Loading...";
  String email = "Loading...";
  String? _imagePath;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadImagePath(); 
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      try {
        DocumentSnapshot athleteDoc = await FirebaseFirestore.instance
            .collection('athletes')
            .doc(currentUser.uid)
            .get();

        if (athleteDoc.exists) {
          setState(() {
            name = athleteDoc['athlete_name'] ?? 'Your Name';
          });
        } else {
          setState(() {
            name = 'Your Name';
          });
        }
      } catch (e) {
        print('Error fetching athlete data: $e');
        setState(() {
          name = 'Your Name';
        });
      }

      setState(() {
        email = currentUser.email ?? 'your.email@example.com';
      });

      prefs.setString('email', email);
    } else {
      setState(() {
        name = 'Your Name';
        email = 'your.email@example.com';
      });
    }
  }

  Future<void> _loadImagePath() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _imagePath = prefs.getString('profileImagePath'); 
    });
  }

  Future<void> _saveImagePath(String path) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileImagePath', path);
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
      await _saveImagePath(pickedFile.path);
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
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RecommendationPage()),
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

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
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
      double averageHeartRate = (activity['average_heartrate'] ?? 0); 
      double caloriesBurned = (activity['calories'] ?? 0);  

      final activityRef = FirebaseFirestore.instance.collection('activities').doc();
      batch.set(activityRef, {
        'user_id': userId,
        'name': activity['name'] ?? 'Unnamed Activity',
        'distance': distanceInKm, 
        'start_date': activity['start_date'] ?? '',
        'type': activity['type'] ?? '',
        'average_speed': averageSpeedInKmh,
        'average_heartrate': averageHeartRate,
        'calories_burned': caloriesBurned,  
      });
    }

    await batch.commit();
    print('Activities data saved to Firestore.');
  } catch (e) {
    print('Error saving activities data to Firestore: $e');
  }
}

Future<void> _subscribeToStravaWebhook() async {
  final String clientId = "146485";
  final String clientSecret = "6e8f87ec4856b0793c009aaf3dc17ff9a941f50f";
  final String callbackUrl = 'https://fitride.trycloudflare.com/webhook'; 
  final String verifyToken = '510a9fdca8569583355fc3c158c3cb0a2583f6c1';

  try {
    print('Creating webhook subscription...');
    print('Request Body: ${{
      'client_id': clientId,
      'client_secret': clientSecret,
      'callback_url': callbackUrl,
      'verify_token': verifyToken,
    }}');

    final response = await http.post(
      Uri.parse('https://www.strava.com/api/v3/push_subscriptions'),
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'callback_url': callbackUrl,
        'verify_token': verifyToken,
      },
    );

    print('Response Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 201) {
      print('Webhook subscription created successfully: ${response.body}');
    } else {
      print('Error creating webhook subscription: ${response.body}');
    }
  } catch (e) {
    print('Error during webhook subscription: $e');
  }
}

Future<void> _exchangeAuthorizationCodeForTokens(String code) async {
  final String clientId = "146485";
  final String clientSecret = "6e8f87ec4856b0793c009aaf3dc17ff9a941f50f"; 

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
      final Map data = json.decode(response.body);
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
        await _subscribeToStravaWebhook();
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
    final String clientId = "146485";
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
            child: Image.asset(
              'assets/logobike.png',
              height: 40,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _imagePath == null
                      ? null
                      : FileImage(File(_imagePath!)),
                  child: _imagePath == null
                      ? Icon(Icons.person, size: 50, color: Colors.grey[700])
                      : null,
                ),
              ),
              SizedBox(height: 10),
              Text(
                name,
                style: GoogleFonts.lato(fontSize: 18, color: Colors.black),
              ),
              Text(
                email,
                style: GoogleFonts.lato(fontSize: 16, color: Colors.black),
              ),
              SizedBox(height: 30),
              _buildProfileButton("Authorize Strava", Icons.arrow_forward, () async {
                _authorizeStrava();
              }),
              _buildProfileButton("Edit Your Goal", Icons.arrow_forward, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChangeGoalPage()),
                );
              }),
              _buildProfileButton("Change Password", Icons.arrow_forward, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChangePasswordPage()),
                );
              }),
              _buildProfileButton("Health Summary", Icons.arrow_forward, () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HealthSummary()),
                );             
              }),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _logout,
                child: Text("Log Out"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: GoogleFonts.lato(fontSize: 18, color: Colors.black),
                ),
              ),
            ],
          ),
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

  Widget _buildProfileButton(String text, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          padding: EdgeInsets.symmetric(vertical: 15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black),
            SizedBox(width: 10),
            Text(
              text,
              style: GoogleFonts.lato(fontSize: 16, color: Colors.black, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }


}
