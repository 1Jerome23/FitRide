import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'goal_tracking.dart';
import 'login_register.dart';
import 'profile.dart';

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
    try {
      DocumentSnapshot userSnapshot = await _firestore.collection('User Questionnaires').doc(userId).get();
      if (userSnapshot.exists) {
        setState(() {
          userData = userSnapshot.data() as Map<String, dynamic>;
        });
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
        setState(() {
          activities = activitySnapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
        });
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

        setState(() {
          temperature = (data['temperature'] as num).toDouble();
          humidity = (data['humidity'] as num).toDouble();
          pm2_5 = (data['pm2_5'] as num).toDouble();
        });

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
    if (userData.isEmpty) {
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
        ),
        body: Center(child: CircularProgressIndicator()),  
      );
    }
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
}
