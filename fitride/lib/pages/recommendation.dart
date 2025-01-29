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

  String generateOverallRecommendation() {
    if (activities.length < 2) {
      return "You need at least two recorded cycling activities to receive personalized recommendations.";
    }
    return "${getHeartRateRecommendation()}\n${getHydrationRecommendation()}\n${getSleepRecommendation()}\n${getEnergyRecommendation()}\n${getWeatherRecommendation(weatherData)}\n${getAQIRecommendation(weatherData)}";
  }

  String getHeartRateRecommendation() {
    int age = userData['age'] ?? 20;
    int heartRate = userData['heartRate'] ?? 140;
    int maxHeartRate = 220 - age;
    double targetHeartRateMin = maxHeartRate * 0.5;
    double targetHeartRateMax = maxHeartRate * 0.7;

    String fitnessLevel = userData['currentFitnessLevel'] ?? 'Intermediate'; 

    if (fitnessLevel == 'Beginner') {
      targetHeartRateMin = maxHeartRate * 0.5;
      targetHeartRateMax = maxHeartRate * 0.6;
    } else if (fitnessLevel == 'Advanced') {
      targetHeartRateMin = maxHeartRate * 0.7;
      targetHeartRateMax = maxHeartRate * 0.85;
    }

    if (heartRate >= targetHeartRateMin && heartRate <= targetHeartRateMax) {
      return "You're in the right heart rate zone. Keep cycling at this intensity.";
    } else if (heartRate < targetHeartRateMin) {
      return "Increase intensity to reach your optimal heart rate zone.";
    } else {
      return "Reduce intensity to avoid overexertion.";
    }
  }

  String getHydrationRecommendation() {
    int hydrationLevel = userData['hydrationLevel'] ?? 5;
    int temperature = userData['weatherTemperature'] ?? 25;
    int humidity = userData['humidity'] ?? 50;

    if (hydrationLevel < 5) {
      return "Increase water intake. Drink at least 500 ml per hour of cycling.";
    }

    if (temperature > 30 || humidity > 60) {
      return "Hot and humid conditions! Make sure to hydrate frequently.";
    }

    return "You're hydrated! Keep it up.";
  }

  String getSleepRecommendation() {
    int sleepHours = userData['sleepHours'] ?? 7;
    String goal = userData['goals'] ?? 'Endurance'; 

    if (sleepHours < 7) {
      return goal == 'Muscle Building' ? "Increase your sleep for muscle recovery." : "You need more rest to perform well in your next ride.";
    }

    return "Great sleep! You're ready for your workout.";
  }

  String getEnergyRecommendation() {
    int energyLevel = userData['energyLevel'] ?? 8;
    String fitnessLevel = userData['currentFitnessLevel'] ?? 'Intermediate';

    if (energyLevel < 5) {
      return "You're low on energy. Consider reducing intensity or cycling duration.";
    }

    return fitnessLevel == 'Advanced'
        ? "You're energized! Push yourself harder for a more intense session."
        : "You're energized! A good ride is ahead.";
  }

  String getWeatherRecommendation(Map<String, dynamic> weatherData) {
    int temperature = weatherData['temperature'] ?? 25;
    int humidity = weatherData['humidity'] ?? 50;
    int precipitation = weatherData['precipitation'] ?? 0;

    if (precipitation > 50) {
      return "It's raining heavily. Consider indoor cycling.";
    } else if (temperature > 30) {
      return "It's quite hot today. Stay hydrated and consider a shorter session.";
    } else if (temperature < 15) {
      return "Chilly weather. Dress warmly!";
    }

    return "Ideal cycling weather. Enjoy your ride!";
  }

  String getAQIRecommendation(Map<String, dynamic> weatherData) {
    int airQualityIndex = weatherData['airQualityIndex'] ?? 50;
    String respiratoryHealth = weatherData['respiratoryHealth'] ?? 'Good';

    if (airQualityIndex > 100 || respiratoryHealth != 'Good') {
      return "The air quality is poor. Consider indoor cycling.";
    }

    return "Air quality is good. Enjoy outdoor cycling!";
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

    String recommendations = generateOverallRecommendation();

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Recommendations for Today:",
                style: GoogleFonts.roboto(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                recommendations,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                ),
              ),
            ],
          ),
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
}
