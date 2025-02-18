import 'package:fitride/pages/UserDataModule.dart';
import 'package:fitride/pages/goal_tracking.dart';
import 'package:fitride/pages/profile.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitride/pages/recent_activity.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_register.dart';
import 'package:geolocator/geolocator.dart';
import 'recommendation.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  double? temperature;
  double? humidity;
  double? pm2_5;
  String airQualityStatus = "Loading...";
  String weatherImage = "assets/default_weather.png";
  String userName = '';
  String? bmi;
  double? weight;
  double? height;
  String? userId = FirebaseAuth.instance.currentUser?.uid;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Footer functionalities
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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();
    fetchWeatherData();
    _getUserName();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? fetchedUserName = prefs.getString('userName');
    if (fetchedUserName != null) {
      setState(() {
        userName = fetchedUserName;
      });
    }
  }

  // Logout function
  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  Future<void> fetchWeatherData() async {
    Position position;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        print("Location permission is denied permanently.");
        return;
      }

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permission is denied.");
        return;
      }
      position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print('Error fetching location: $e');
      return;
    }

    final latitude = position.latitude;
    final longitude = position.longitude;

    try {
      final weatherResponse = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true&hourly=relative_humidity_2m'));

      if (weatherResponse.statusCode == 200) {
        final data = json.decode(weatherResponse.body);
        final currentWeather = data['current_weather'];
        final hourly = data['hourly'];

        setState(() {
          temperature = (currentWeather['temperature'] as num).toDouble();
          humidity = (hourly['relative_humidity_2m'] != null &&
                  hourly['relative_humidity_2m'].isNotEmpty)
              ? (hourly['relative_humidity_2m'][0] as num).toDouble()
              : 0.0;

          weatherImage =
              _getWeatherImage(currentWeather['weathercode'].toString());
        });
      } else {
        print('Failed to fetch temperature and humidity.');
      }
    } catch (e) {
      print('Error fetching temperature and humidity: $e');
    }

    try {
      final airQualityResponse = await http.get(Uri.parse(
          'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$latitude&longitude=$longitude&hourly=pm2_5'));

      if (airQualityResponse.statusCode == 200) {
        final data = json.decode(airQualityResponse.body);
        final hourlyData = data['hourly'];

        setState(() {
          pm2_5 =
              (hourlyData['pm2_5'] != null && hourlyData['pm2_5'].isNotEmpty)
                  ? (hourlyData['pm2_5'][0] as num).toDouble()
                  : 0.0;

          airQualityStatus = _evaluateAirQuality(pm2_5);
        });
      } else {
        print('Failed to fetch air quality.');
      }
    } catch (e) {
      print('Error fetching air quality: $e');
    }
  }

  String _getWeatherImage(String? condition) {
    switch (condition) {
      case "0":
        return "assets/sunny.png";
      case "2":
        return "assets/cloudy.png";
      case "3":
        return "assets/overcast.png";
      case "61":
        return "assets/rainy.png";
      case "77":
        return "assets/stormy.png";
      default:
        return "assets/sunny.png";
    }
  }

  String _evaluateAirQuality(double? pm2_5) {
    if (pm2_5 == null) return "Unknown";
    if (pm2_5 <= 25) return "Good";
    if (pm2_5 <= 50) return "Moderate";
    return "Poor";
  }

<<<<<<< Updated upstream
=======
  Color _getAirQualityColor(String status) {
    switch (status) {
      case "Good":
        return Colors.green;
      case "Moderate":
        return Colors.orange;
      case "Poor":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _recordWeather() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Record the Weather",
            style: TextStyle(
              fontFamily: 'Fredoka-SemiBold',
              color: Color(0xffFFA500),
            ),
          ),
          content: Text(
            "Record the weather to get accurate information tailored for you!\nOnly record when you're going to cycle.",
            style: TextStyle(color: Colors.black, fontFamily: "Inter"),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Inter",
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (temperature != null && humidity != null && pm2_5 != null) {
                  String? userId = FirebaseAuth.instance.currentUser?.uid;

                  if (userId != null) {
                    Map<String, dynamic> weatherData = {
                      'temperature': temperature,
                      'humidity': humidity,
                      'pm2_5': pm2_5,
                      'airQualityStatus': airQualityStatus,
                      'timestamp': FieldValue.serverTimestamp(),
                      'userId': userId,
                    };

                    FirebaseFirestore.instance
                        .collection('weatherData')
                        .add(weatherData)
                        .then((value) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Weather recorded successfully!"),
                          backgroundColor: Color(0xffFFA500),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Failed to record weather: $error"),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("User is not logged in."),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Failed to fetch weather data."),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xffFFA500),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Record",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamily: "Inter",
                ),
              ),
            ),
          ],
        );
      },
    );
  }

>>>>>>> Stashed changes
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        title: const Text(
          "FitRide",
          style: GoogleFonts.roboto(
            color: Colors.orange,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          style: TextStyle(
            fontFamily: 'Fredoka-SemiBold',
            color: Color(0xffFFA500),
            fontSize: 22,
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
                height: 25,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 3,
                    blurRadius: 5,
                    offset: Offset(0, 3),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, Cyclist!",
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 28,
                    color: Colors.black,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (temperature != null)
                    Center(
                      child: Image.asset(weatherImage, height: 120),
                    ),
                  SizedBox(height: 12),
                  if (temperature != null)
                    Text(
                      "Temperature: ${temperature!.toStringAsFixed(1)}°C",
                      style: GoogleFonts.lato(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.w500),
                    ),
                  if (humidity != null)
                    Text(
                      "Humidity: ${humidity!.toStringAsFixed(1)}%",
                      style: GoogleFonts.lato(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.w500),
                    ),
                  Text(
                    "Air Quality: $airQualityStatus",
                    style: GoogleFonts.lato(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.w500),
                ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slide(begin: Offset(0, -0.1), end: Offset.zero),
                Text(
                  "Glad to see you! Let’s make today’s ride a great one. Hop on and ride!",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontFamily: "Inter",
                  ),
<<<<<<< Updated upstream
                ],
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Body Goals",
                    style: GoogleFonts.roboto(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                LoginPage()), // Replace with your settings page
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 3,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Edit Goals",
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.settings,
                            color: Colors.black,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildGoalCard("Goal 1", Colors.orange),
                  _buildGoalCard("Goal 2", Colors.blue),
                  _buildGoalCard("Goal 3", Colors.green),
                ],
              ),
            ),
            SizedBox(height: 16),
=======
                ).animate().fadeIn(duration: 600.ms, delay: 300.ms).slide(begin: Offset(0, -0.1), end: Offset.zero),
                SizedBox(height: 25),
>>>>>>> Stashed changes

            // Added section for User Data
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "User Data",
                    style: GoogleFonts.roboto(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                // Weather Section
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xffFFA500).withOpacity(0.9),
                        Color(0xffFFA500).withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                FitRidePage()), // Replace with your User page
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 3,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Today's Weather",
                          style: TextStyle(
                            fontFamily: 'Fredoka-SemiBold',
                            fontSize: 22,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 2),
                                blurRadius: 4,
                                color: Colors.black.withOpacity(0.3),
                              ),
                            ],
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Edit Data",
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                        ),
                        SizedBox(height: 24),
                        if (temperature != null)
                          Image.asset(
                            weatherImage,
                            height: 120,
                          ).animate().scale(delay: 400.ms, duration: 800.ms, curve: Curves.elasticOut),
                        SizedBox(height: 20),
                        if (temperature != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${temperature!.toStringAsFixed(1)}",
                                style: TextStyle(
                                  fontFamily: 'Fredoka-SemiBold',
                                  fontSize: 50,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 4),
                                      blurRadius: 8,
                                      color: Colors.black.withOpacity(0.3),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "°C",
                                style: TextStyle(
                                  fontFamily: 'Fredoka-SemiBold',
                                  fontSize: 24,
                                  color: Colors.white.withOpacity(0.8),
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 2),
                                      blurRadius: 4,
                                      color: Colors.black.withOpacity(0.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ).animate().fadeIn(duration: 800.ms, delay: 500.ms),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (humidity != null)
                              _weatherInfoItem(
                                Icons.water_drop_outlined,
                                "${humidity!.toStringAsFixed(1)}%",
                                "Humidity",
                                Colors.blue,
                              ),
                            SizedBox(width: 30),
                            _weatherInfoItem(
                              Icons.air,
                              airQualityStatus,
                              "Air Quality",
                              _getAirQualityColor(airQualityStatus),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.settings,
                            color: Colors.black,
                            size: 20,
                          ),
                        ],
                      ),
                          ],
                        ).animate().fadeIn(duration: 800.ms, delay: 600.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('User Questionnaires')
                    .doc(userId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return Text("Error fetching data");
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return Text("No data available");
                  }
                ).animate()
                  .fadeIn(duration: 600.ms, delay: 400.ms)
                  .slideY(begin: 0.1, end: 0)
                  .shimmer(delay: 1000.ms, duration: 1800.ms),
                
                SizedBox(height: 30),

                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  double weight =
                      double.tryParse(data['weight'].toString()) ?? 0.0;
                  double height =
                      double.tryParse(data['height'].toString()) ?? 0.0;

                  // Calculate BMI
                  double bmi = (weight /
                      ((height / 100) *
                          (height / 100))); // Convert height to meters

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDataCard(
                          "BMI", bmi.toStringAsFixed(1), Colors.orange),
                      _buildDataCard(
                          "Weight", weight.toStringAsFixed(1), Colors.blue),
                      _buildDataCard(
                          "Height", height.toStringAsFixed(1), Colors.green),
                
                Text(
                  "Your Data",
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 22,
                    color: Colors.black,
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                SizedBox(height: 15),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: 16),

            // Added section for Recent Activity
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Activity",
                    style: GoogleFonts.roboto(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Navigate to the Recent Activity page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                RecentActivityPage()), // Replace with your Recent Activity page
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 3,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('User Questionnaires')
                        .doc(userId)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: Color(0xffFFA500),
                          ),
                        ],
                      ),
                      child: Row(
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            "Error fetching data",
                            style: TextStyle(color: Colors.red, fontFamily: "Inter"),
                          ),
                        );
                      }

                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 40,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "No data available",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                  fontFamily: "Inter",
                                ),
                              ),
                              SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => FitRidePage()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xffFFA500),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  "Add Your Data",
                                  style: TextStyle(color: Colors.white, fontFamily: "Inter"),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      var data = snapshot.data!.data() as Map<String, dynamic>;
                      double weight =
                          double.tryParse(data['weight'].toString()) ?? 0.0;
                      double height =
                          double.tryParse(data['height'].toString()) ?? 0.0;

                      
                      double bmi = (weight /
                          ((height / 100) *
                              (height / 100))); 

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(
                            "See All",
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          _buildStatCard(
                            "BMI",
                            bmi.toStringAsFixed(1),
                            "assets/bmi_icon.png", 
                            _getBmiColor(bmi),
                            _getBmiCategory(bmi),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.black,
                            size: 20,
                          _buildStatCard(
                            "Weight",
                            "${weight.toStringAsFixed(1)} kg",
                            "assets/weight_icon.png", 
                            Color(0xFF2E86C1),
                            null,
                          ),
                          _buildStatCard(
                            "Height",
                            "${height.toStringAsFixed(1)} cm",
                            "assets/height_icon.png", 
                            Color(0xFF16A085),
                            null,
                          ),
                        ],
                      ).animate().fadeIn(duration: 800.ms, delay: 700.ms);
                    },
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 700.ms).slideY(begin: 0.1, end: 0),

                SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Recent Activity",
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 22,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 3,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => RecentActivityPage()),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xffFFA500).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              "View All",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xffFFA500),
                                fontFamily: "Inter",
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Color(0xffFFA500),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    "No recent activity",
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                ).animate().fadeIn(duration: 600.ms, delay: 800.ms),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    physics: NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: 1, // Placeholder for one item, adjust when there's real data
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.grey[200],
                    ),
                    itemBuilder: (context, index) {
                      // Placeholder for activity items
                      return _buildActivityItem(
                        "No recent activity",
                        "Record your first ride to see it here!",
                        "00:00",
                        Icons.directions_bike_outlined,
                      );
                    },
                  ),
                ),
              ),
                ).animate().fadeIn(duration: 600.ms, delay: 900.ms).slideY(begin: 0.1, end: 0),
                SizedBox(height: 20),
              ],
            ),
            SizedBox(height: 16),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          child: BottomNavigationBar(
            backgroundColor: Colors.grey[900],
            currentIndex: _selectedIndex,
            selectedItemColor: Color(0xffFFA500),
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              fontFamily: "Inter",
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 12,
              fontFamily: "Inter",
            ),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            onTap: _onItemTapped,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.insights_rounded),
                label: 'Insights',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.track_changes_rounded),
                label: 'Goals',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ],
      ),
        ),
      )
    );
  }

  Widget _buildGoalCard(String title, Color color) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 3,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
  Widget _weatherInfoItem(IconData icon, String value, String label, Color color) {
  return Column(
    children: [
      Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              offset: Offset(0, 2),
              blurRadius: 4,
              color: Colors.black.withOpacity(0.2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
      child: Center(
        child: Text(
          title,
          style: GoogleFonts.lato(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
      SizedBox(height: 8),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          shadows: [
            Shadow(
              offset: Offset(0, 2),
              blurRadius: 4,
              color: Colors.black.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
      Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: Colors.white.withOpacity(0.8),
          shadows: [
            Shadow(
              offset: Offset(0, 1),
              blurRadius: 2,
              color: Colors.black.withOpacity(0.2),
            ),
          ],
        ),
      ),
    ],
  );
}

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }

  String? _getBmiCategory(double bmi) {
    if (bmi < 18.5) return "Underweight";
    if (bmi < 25) return "Normal";
    if (bmi < 30) return "Overweight";
    return "Obese";
  }

  Widget _buildDataCard(String title, String value, Color color) {
  Widget _buildStatCard(String title, String value, String iconAsset, Color iconColor, String? subtitle) {
    return Container(
      padding: EdgeInsets.all(10),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 3,
            blurRadius: 5,
            offset: Offset(0, 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              iconAsset,
              width: 24,
              height: 24,
              color: iconColor,
            ),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.lato(fontSize: 14, color: Colors.white),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Fredoka-SemiBold',
              fontSize: 20,
              color: Colors.black,
            ),
            Text(
              value,
              style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: "Inter",
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: iconColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Inter",
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, String time, IconData icon) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Color(0xffFFA500).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Color(0xffFFA500),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Colors.black87,
          fontFamily: "Inter",
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
          fontFamily: "Inter",
        ),
      ),
      trailing: Text(
        time,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[500],
          fontWeight: FontWeight.w500,
          fontFamily: "Inter",
        ),
      ),
    );
  }
}

// BMI Categories Extension
extension BMICategory on double {
  String get category {
    if (this < 18.5) return 'Underweight';
    if (this < 25.0) return 'Normal';
    if (this < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color get categoryColor {
    if (this < 18.5) return Colors.blue;
    if (this < 25.0) return Colors.green;
    if (this < 30.0) return Colors.orange;
    return Colors.red;
  }
}

// Weather Status Extension
extension WeatherStatus on double {
  String get description {
    if (this < 10) return 'Cold';
    if (this < 20) return 'Cool';
    if (this < 30) return 'Pleasant';
    return 'Hot';
  }

  Color get temperatureColor {
    if (this < 10) return Colors.blue;
    if (this < 20) return Colors.green;
    if (this < 30) return Color(0xffFFA500);
    return Colors.red;
  }
}

// Air Quality Extension
extension AirQualityDescription on String {
  Color get qualityColor {
    switch (this.toLowerCase()) {
      case 'good':
        return Colors.green;
      case 'moderate':
        return Color(0xffFFA500);
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get qualityIcon {
    switch (this.toLowerCase()) {
      case 'good':
        return Icons.sentiment_very_satisfied;
      case 'moderate':
        return Icons.sentiment_satisfied;
      case 'poor':
        return Icons.sentiment_dissatisfied;
      default:
        return Icons.help_outline;
    }
  }
}