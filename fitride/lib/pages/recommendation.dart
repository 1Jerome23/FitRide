import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'goal_tracking.dart';
import 'login_register.dart';
import 'profile.dart';
import 'dart:async';

class RecommendationPage extends StatefulWidget {
  @override
  _RecommendationPageState createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  int _selectedIndex = 1;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String userId = FirebaseAuth.instance.currentUser!.uid;
  Map<String, dynamic> userData = {};
  List<Map<String, dynamic>> activities = [];
  Map<String, dynamic> weatherData = {};
  double? temperature;
  double? humidity;
  double? pm2_5;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchActivities();
    _fetchWeatherData();
  }

  Future<void> _fetchUserData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      print("User is not logged in.");
      return;
    }

    print("Fetching data for user ID: $userId");

    try {
      DocumentSnapshot userSnapshot = await _firestore.collection('User Questionnaires').doc(userId).get();
      if (userSnapshot.exists) {
        if (mounted) {
          setState(() {
            userData = userSnapshot.data() as Map<String, dynamic>;
          });
        }
        print("User Data: $userData");
      } else {
        print("User data not found");
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<void> _fetchActivities() async {
    try {
      QuerySnapshot activitySnapshot = await _firestore
          .collection('activities')
          .where('user_id', isEqualTo: userId)
          .get();
      
      print("Activities snapshot: ${activitySnapshot.docs.length} documents found");

      if (activitySnapshot.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            activities = activitySnapshot.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList();
          });
        }
      } else {
        print("No activities found");
      }
    } catch (e) {
      print("Error fetching activities: $e");
    }
  }

  Future<void> _fetchWeatherData() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      print("User is not logged in.");
      return;
    }

    try {
      QuerySnapshot weatherSnapshot = await _firestore
          .collection('weatherData')
          .where('userId', isEqualTo: userId)
          .get();

      if (weatherSnapshot.docs.isNotEmpty) {
        DocumentSnapshot doc = weatherSnapshot.docs.first;

        if (doc.exists && doc.data() != null) {
          var data = doc.data() as Map<String, dynamic>;

          print("Fetched Weather Data: $data");

          if (mounted) {
            setState(() {
              temperature = double.tryParse(data['temperature'].toString()) ?? 0.0;
              humidity = double.tryParse(data['humidity'].toString()) ?? 0.0;
              pm2_5 = double.tryParse(data['pm2_5'].toString()) ?? 0.0;
            });
          }

          print("Weather Data Set: Temperature: $temperature, Humidity: $humidity, PM2.5: $pm2_5");
        } else {
          print("Weather data not found for user $userId.");
        }
      } else {
        print("No documents found for user $userId.");
      }
    } catch (e) {
      print("Error fetching weather data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    String recommendations = _generateRecommendations();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).primaryColor,
        title: Row(
          children: [
            Text(
              "FitRide",
              style: GoogleFonts.roboto(
                color: Colors.orange,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
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
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Section
            Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Your Cycling Recommendations",
                style: GoogleFonts.roboto(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

            Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200], 
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  recommendations.isEmpty
                      ? "No recommendations available."
                      : recommendations,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
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
            label: 'Goals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

String _generateRecommendations() {
  int age = userData['age'] ?? 20;
  double weight = userData['weight'] ?? 70.0;
  String fitnessLevel = userData['activityLevel'] ?? 'beginner';
  String recommendation = "";

  if (age <= 50 && fitnessLevel == 'beginner') {
    recommendation += "As a young beginner, focus on building stamina with low-intensity rides.\n";
    recommendation += "Start with shorter cycling sessions and gradually increase the duration.\n";
    recommendation += "Prioritize rest and recovery, and maintain a balanced diet to support your training.\n";
  } else if (age <= 18 && weight > 60 && fitnessLevel == 'beginner') {
    recommendation += "As a young beginner with a higher weight, focus on moderate cycling to build endurance.\n";
    recommendation += "Take it easy and avoid overexertion, as it may lead to injuries.\n";
    recommendation += "Ensure proper hydration and nutrition to fuel your training.\n";
  } else if (age >= 25 && age <= 35 && fitnessLevel == 'intermediate') {
    recommendation += "As an intermediate cyclist, increase the intensity of your rides.\n";
    recommendation += "Incorporate interval training and hill climbs to improve strength and endurance.\n";
    recommendation += "Balance cycling with strength training to support muscle development.\n";
  } else if (age >= 25 && weight > 80 && fitnessLevel == 'advanced') {
    recommendation += "As an advanced cyclist with a higher weight, focus on strength and endurance workouts.\n";
    recommendation += "Incorporate longer rides with varied terrain and resistance training.\n";
    recommendation += "Make sure to get proper nutrition and sufficient recovery to handle intense training.\n";
  } else if (age > 35 && (fitnessLevel == 'advanced' || fitnessLevel == 'intermediate')) {
    recommendation += "As an experienced cyclist, mix endurance rides with strength training.\n";
    recommendation += "Consider recovery-focused workouts and pay attention to your body's needs.\n";
    recommendation += "Cycling with intervals and resistance will improve your overall fitness.\n";
  } else {
    recommendation += "You don't have at least 3 cycling activities recorded.\n";
    recommendation += "Start cycling now to get your own personalized recommendation.\n";
  }

  return recommendation;
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

  void _logout() {
    FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }
}
