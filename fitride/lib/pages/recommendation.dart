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
  String _athleteName = '';
  List<dynamic> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStravaData();
  }

  Future<void> _fetchStravaData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        DocumentSnapshot userTokenDoc = await FirebaseFirestore.instance
            .collection('user_tokens')
            .doc(userId)
            .get();

        if (userTokenDoc.exists) {
          final String accessToken = userTokenDoc['access_token'];
          print("Access Token: $accessToken");

          final athleteResponse = await http.get(
            Uri.parse('https://www.strava.com/api/v3/athlete'),
            headers: {
              'Authorization': 'Bearer $accessToken',
            },
          );

          if (athleteResponse.statusCode == 200) {
            final Map<String, dynamic> athleteData = json.decode(athleteResponse.body);
            print("Athlete Data: $athleteData"); // Debugging: Check if athlete data is fetched successfully
            setState(() {
              _athleteName = athleteData['firstname'] ?? 'No name available';
            });
          } else {
            print('Error fetching athlete data: ${athleteResponse.body}');
          }

          // Fetch activities data
          final activitiesResponse = await http.get(
            Uri.parse('https://www.strava.com/api/v3/athlete/activities'),
            headers: {
              'Authorization': 'Bearer $accessToken',
            },
          );

          if (activitiesResponse.statusCode == 200) {
            final List<dynamic> activitiesData = json.decode(activitiesResponse.body);
            print("Activities Data: $activitiesData"); // Debugging: Check if activities data is fetched successfully
            setState(() {
              _activities = activitiesData;
              _isLoading = false;
            });
          } else {
            print('Error fetching activities: ${activitiesResponse.body}');
          }
        } else {
          print('No user token found in Firestore.');
        }
      } catch (e) {
        print('Error fetching Strava data: $e');
      }
    }
  }

  Widget _buildDataDisplay() {
  if (_isLoading) {
    return Center(child: CircularProgressIndicator());
  }

  if (_athleteName.isEmpty && _activities.isEmpty) {
    return Center(child: Text('No data available.'));
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Display Athlete's Name
      Text(
        'Hello, $_athleteName!',
        style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 20),

      // Display Recent Activities
      Text(
        'Recent Activities:',
        style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 10),
      
      // If no activities, show a message
      _activities.isEmpty
          ? Text("No activities found.")
          : Column(
              children: _activities.map((activity) {
                final activityName = activity['name'] ?? 'Unnamed Activity';
                final distance = activity['distance'] / 1000; // Convert from meters to kilometers
                final date = DateTime.parse(activity['start_date']).toLocal(); // Format the start date

                return Card(
                  margin: EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    title: Text(activityName),
                    subtitle: Text(
                      'Distance: ${distance.toStringAsFixed(2)} km\nDate: ${date.toLocal()}',
                    ),
                    trailing: Icon(Icons.directions_bike),
                  ),
                );
              }).toList(),
            ),
    ],
  );
}

void _authorizeStrava() {
  final String clientId = "145840"; 
  final String redirectUri = 'https://amend-adjustable-generators-marcus.trycloudflare.com/callback'; 
  final String responseType = "code";
  final String approvalPrompt = "force";
  final String scope = "read";

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

          // Log to check if code exists in the URL
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

    // Log the response to check for errors or success
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

  // Handle logout
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
                : _buildDataDisplay(), // Show data or loading indicator
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
