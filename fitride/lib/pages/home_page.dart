import 'package:fitride/pages/goal_tracking.dart';
import 'package:fitride/pages/profile.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_register.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'recommendation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class ActivityData {
  final String month;
  final double distance;

  ActivityData(this.month, this.distance);
}

class SessionData {
  final String day;
  final int count;

  SessionData(this.day, this.count);
}

class ActivitySessionData {
  final String session;
  final double value;

  ActivitySessionData(this.session, this.value);
}

class MetricData {
  final String date;
  final double value;

  MetricData(this.date, this.value);
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String _userGoal = 'Unknown'; // Default value
  PageController _pageController = PageController();
  int _currentPage = 0;
  List<Map<String, dynamic>> activityData = [];
  bool _isLoadingGraphs = true;
  int? _streakCount;
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
  String? _stravaUserId;

  double safeParseDouble(dynamic value) {
    if (value == null || value == "-") return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
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

    // Sequentially load data
    _loadUserData();
  }

  // Sequentially load data to ensure dependencies are respected
  Future<void> _loadUserData() async {
    // First load streak data
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _fetchStreakData(userId).then((streakData) {
        setState(() {
          _streakCount = streakData?['streak'] ?? 0;
        });
      });
    }

    // Then load Strava ID
    await loadStravaUserId();

    // Then load goal and finally activity data
    await fetchUserGoal();
    await fetchActivityData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> fetchUserGoal() async {
    if (userId != null) {
      try {
        // Fetch the most recent document from goals collection
        QuerySnapshot goalsQuery = await FirebaseFirestore.instance
            .collection('goals')
            .where('uid', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (goalsQuery.docs.isNotEmpty) {
          DocumentSnapshot goalsDoc = goalsQuery.docs.first;
          setState(() {
            _userGoal = goalsDoc['goalType'] ?? "Unknown";
          });
          print("User goal fetched: $_userGoal");
        } else {
          print("No goal documents found for user $userId");
        }
      } catch (e) {
        print('Error fetching user goal: $e');
      }
    }
  }

  Future<void> fetchActivityData() async {
    setState(() {
      _isLoadingGraphs = true;
    });

    String? stravaUserId = _stravaUserId;
    if (stravaUserId == null) {
      setState(() {
        _isLoadingGraphs = false;
      });
      print("No Strava ID available, skipping activity fetch");
      return;
    }

    try {
      int? parsedStravaId = int.tryParse(stravaUserId);
      if (parsedStravaId == null) {
        setState(() {
          _isLoadingGraphs = false;
        });
        print("Invalid Strava ID format: $stravaUserId");
        return;
      }

      // Query for recent activities WITHOUT filtering by goal
      // This ensures we get data even if the 'goal' field is missing
      QuerySnapshot activitiesQuery = await FirebaseFirestore.instance
          .collection('activities')
          .where('user_id', isEqualTo: parsedStravaId)
          .orderBy('start_date', descending: true)
          .limit(10) // Get more than needed to allow filtering
          .get();

      print(
          "Activity query complete. Found ${activitiesQuery.docs.length} activities.");

      if (activitiesQuery.docs.isNotEmpty) {
        List<Map<String, dynamic>> newActivityData = [];

        // Process all activities
        for (var doc in activitiesQuery.docs) {
          var data = doc.data() as Map<String, dynamic>;

          // Add all activities to the data array
          newActivityData.add({
            "documentId": doc.id,
            "average_heartrate": data['average_heartrate'],
            "max_heartrate": data['max_heartrate'] ?? "0",
            "average_speed": data['average_speed'],
            "max_speed": data['max_speed'] ?? "0",
            "calories_burned": data['calories_burned'],
            "distance": data['distance'],
            "elapsed_time": data['elapsed_time'],
            "elevation_gain": data['elevation_gain'] ?? "0",
            "name": data['name'],
            "start_date": data['start_date'],
            "type": data['type'],
            "user_id": data['user_id'],
            "goal": data['goal'], // Include goal field if it exists
          });
        }

        setState(() {
          activityData = newActivityData;
          _isLoadingGraphs = false;
        });

        print(
            "Activity data loaded successfully: ${activityData.length} activities");
      } else {
        print("No activity data found for user with Strava ID $parsedStravaId");
        setState(() {
          _isLoadingGraphs = false;
        });
      }
    } catch (e) {
      print('Error fetching activity data: $e');
      setState(() {
        _isLoadingGraphs = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchStreakData(String userId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('Streak')
          .doc(userId)
          .get();

      if (snapshot.exists) {
        return snapshot.data()!;
      }
    } catch (e) {
      print('Error fetching streak data: $e');
    }
    return {'streak': 0};
  }

  Future<void> loadStravaUserId() async {
    try {
      FirebaseAuth auth = FirebaseAuth.instance;
      User? user = auth.currentUser;

      if (user == null) {
        print("No authenticated user found.");
        return;
      }

      print("Fetching Strava User ID from athletes for UID: ${user.uid}");

      QuerySnapshot athleteSnapshot = await FirebaseFirestore.instance
          .collection('athletes')
          .where("app_id", isEqualTo: user.uid)
          .limit(1)
          .get();

      if (athleteSnapshot.docs.isEmpty) {
        print("No athlete document found for UID: ${user.uid}");
        return;
      }

      String stravaUserIdString = athleteSnapshot.docs.first.id;
      print("Retrieved Strava User ID (String): $stravaUserIdString");

      setState(() {
        _stravaUserId = stravaUserIdString;
      });

      int? stravaUserId = int.tryParse(stravaUserIdString);
      if (stravaUserId == null) {
        print("Error: Unable to convert Strava User ID to an integer.");
        return;
      }

      print("Converted Strava User ID (Integer): $stravaUserId");
    } catch (e) {
      print("Error fetching Strava User ID: $e");
    }
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
    geo.Position? position;

    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services are disabled.");
        return;
      }

      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.deniedForever) {
        debugPrint("Location permission is denied permanently.");
        return;
      }
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          debugPrint("Location permission is denied.");
          return;
        }
      }

      position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high);
    } catch (e) {
      debugPrint('Error fetching location: $e');
      return;
    }

    final latitude = position.latitude;
    final longitude = position.longitude;

    try {
      // Fetch weather data
      final weatherResponse = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true&hourly=relative_humidity_2m'));

      if (weatherResponse.statusCode == 200) {
        final data = json.decode(weatherResponse.body);
        final currentWeather = data['current_weather'];
        final hourly = data['hourly'];

        if (currentWeather == null || hourly == null) {
          debugPrint("Weather API response is missing expected data.");
          return;
        }

        final weatherTemp = currentWeather['temperature'];
        final weatherHumidity = hourly['relative_humidity_2m'] != null &&
                hourly['relative_humidity_2m'].isNotEmpty
            ? (hourly['relative_humidity_2m'][0] as num).toDouble()
            : 0.0;

        if (mounted) {
          setState(() {
            temperature = (weatherTemp as num).toDouble();
            humidity = weatherHumidity;
            weatherImage =
                _getWeatherImage(currentWeather['weathercode'].toString());
          });
        }
      } else {
        debugPrint('Failed to fetch temperature and humidity.');
      }
    } catch (e) {
      debugPrint('Error fetching temperature and humidity: $e');
    }

    try {
      // Fetch air quality data
      final airQualityResponse = await http.get(Uri.parse(
          'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$latitude&longitude=$longitude&hourly=pm2_5'));

      if (airQualityResponse.statusCode == 200) {
        final data = json.decode(airQualityResponse.body);
        final hourlyData = data['hourly'];

        if (hourlyData == null || !hourlyData.containsKey('pm2_5')) {
          debugPrint("Air Quality API response is missing expected data.");
          return;
        }

        final airQualityPM25 = List<dynamic>.from(hourlyData['pm2_5']);
        final pmValue = airQualityPM25.isNotEmpty
            ? (airQualityPM25[0] as num).toDouble()
            : 0.0;

        if (mounted) {
          setState(() {
            pm2_5 = pmValue;
            airQualityStatus = _evaluateAirQuality(pm2_5);
          });
        }
      } else {
        debugPrint('Failed to fetch air quality.');
      }
    } catch (e) {
      debugPrint('Error fetching air quality: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.grey[900],
          elevation: 0,
          title: const Text(
            "FitRide",
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
                  height: 25,
                ),
              ),
            ),
          ],
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
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
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 200.ms)
                      .slide(begin: Offset(0, -0.1), end: Offset.zero),
                  Text(
                    "Glad to see you! Let's make today's ride a great one. Hop on and ride!",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontFamily: "Inter",
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 300.ms)
                      .slide(begin: Offset(0, -0.1), end: Offset.zero),
                  SizedBox(height: 25),

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
                          ),
                          SizedBox(height: 24),
                          if (temperature != null)
                            Image.asset(
                              weatherImage,
                              height: 120,
                            ).animate().scale(
                                delay: 400.ms,
                                duration: 800.ms,
                                curve: Curves.elasticOut),
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
                            ],
                          ).animate().fadeIn(duration: 800.ms, delay: 600.ms),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 400.ms)
                      .slideY(begin: 0.1, end: 0)
                      .shimmer(delay: 1000.ms, duration: 1800.ms),
                  SizedBox(height: 30),
                  Text(
                    "Your Streak",
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
                    ),
                    child: _streakCount != null
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_fire_department,
                                  color: Colors.orange, size: 30),
                              SizedBox(width: 10),
                              Text(
                                _streakCount == 0
                                    ? "No active streak yet"
                                    : "Current Streak: $_streakCount weeks",
                                style: TextStyle(
                                  fontFamily: 'Fredoka-SemiBold',
                                  fontSize: 18,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: CircularProgressIndicator(
                              color: Color(0xffFFA500),
                            ),
                          ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 700.ms)
                      .slideY(begin: 0.1, end: 0),

                  SizedBox(height: 30),
                  Text(
                    "Your Goal Progress",
                    style: TextStyle(
                      fontFamily: 'Fredoka-SemiBold',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                  SizedBox(height: 15),
                  _buildGoalBasedGraphs()
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 700.ms)
                      .slideY(begin: 0.1, end: 0),
                ],
              ),
            ),
          ),
        ),
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
          ),
        ));
  }

  // Create a carousel widget for multiple graphs
  Widget _buildGoalBasedGraphs() {
    // If loading, show a loading indicator
    if (_isLoadingGraphs) {
      return _buildLoadingGraph();
    }

    // If the user goal is unknown or if Strava is not connected, show a message
    if (_userGoal == 'Unknown' || _stravaUserId == null) {
      return Container(
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
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _stravaUserId == null ? Icons.link_off : Icons.help_outline,
                color: Colors.red[400],
                size: 36,
              ),
              SizedBox(height: 12),
              Text(
                _stravaUserId == null
                    ? "No Strava account connected"
                    : "Goal information not available",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                  fontFamily: "Inter",
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If no activity data is available
    if (activityData.isEmpty) {
      return Container(
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
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_chart_outlined_rounded,
                color: Colors.grey[400],
                size: 36,
              ),
              SizedBox(height: 12),
              Text(
                "No activity data available for your goals",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                  fontFamily: "Inter",
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build the appropriate graphs based on the user's goal
    List<Widget> goalGraphs = [];

    switch (_userGoal) {
      case 'Leisure':
        goalGraphs.add(_buildSessionsPerWeekGraph());
        break;
      case 'Endurance':
        goalGraphs.add(_buildDistancePerSessionGraph());
        goalGraphs.add(_buildDurationPerSessionGraph());
        break;
      case 'High Intensity Cycling':
        goalGraphs.add(_buildWeightOverTimeGraph());
        goalGraphs.add(_buildBodyFatOverTimeGraph());
        break;
      default:
        goalGraphs.add(
          Center(
            child: Text(
              "No specific graphs for this goal type",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
                fontFamily: "Inter",
              ),
            ),
          ),
        );
    }

    // If there's only one graph, return it directly
    if (goalGraphs.length == 1) {
      return goalGraphs.first;
    }

    // Otherwise, create a carousel with page indicator
    return Column(
      children: [
        Container(
          height: 250, // Adjust height as needed
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: goalGraphs,
          ),
        ),
        SizedBox(height: 10),
        // Page indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            goalGraphs.length,
            (index) => Container(
              margin: EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? Color(0xffFFA500)
                    : Colors.grey[300],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionsPerWeekGraph() {
    // Map to store session count per day
    Map<String, int> sessionsPerDay = {
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };

    // Process activity data to count sessions per day
    for (var activity in activityData) {
      if (activity['start_date'] != null) {
        Timestamp timestamp = activity['start_date'];
        DateTime date = timestamp.toDate();

        // Get day of week
        String dayOfWeek = DateFormat('E').format(date);
        sessionsPerDay[dayOfWeek] = (sessionsPerDay[dayOfWeek] ?? 0) + 1;
      }
    }

    List<SessionData> chartData = sessionsPerDay.entries
        .map((entry) => SessionData(entry.key, entry.value))
        .toList();

    return _buildGraphContainer(
      title: "Weekly Sessions",
      subtitle: "Leisure activities",
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(
          majorGridLines: MajorGridLines(width: 0),
          axisLine: AxisLine(width: 1, color: Colors.grey[200]),
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        primaryYAxis: NumericAxis(
          majorGridLines: MajorGridLines(
            width: 0.5,
            color: Colors.grey[200],
            dashArray: <double>[3, 3],
          ),
          axisLine: AxisLine(width: 0),
          labelFormat: '{value}',
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontFamily: 'Inter',
            fontSize: 10,
          ),
        ),
        tooltipBehavior: TooltipBehavior(
          enable: true,
          color: Colors.grey[800],
          textStyle: TextStyle(color: Colors.white, fontSize: 12),
        ),
        series: <ChartSeries>[
          ColumnSeries<SessionData, String>(
            dataSource: chartData,
            xValueMapper: (SessionData data, _) => data.day,
            yValueMapper: (SessionData data, _) => data.count,
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            color: Color(0xffFFA500),
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(
                color: Colors.black87,
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

// First graph for 'Endurance' goal - Distance per session
  Widget _buildDistancePerSessionGraph() {
    List<ActivitySessionData> chartData = [];
    int sessionCount = 1;

    // Process activity data to extract distance per session
    for (var activity in activityData.reversed) {
      // Use reversed to show oldest to newest
      double distance = safeParseDouble(activity['distance']);
      print('Pakyu: $distance');
      // Convert to kilometers and round to 1 decimal place
      print("Round distances: $distance");

      chartData.add(ActivitySessionData("S$sessionCount", distance));
      sessionCount++;
    }

    return _buildGraphContainer(
      title: "Recent Distances",
      subtitle: "Last ${chartData.length} endurance sessions",
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(
          majorGridLines: MajorGridLines(width: 0),
          axisLine: AxisLine(width: 1, color: Colors.grey[200]),
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        primaryYAxis: NumericAxis(
          majorGridLines: MajorGridLines(
            width: 0.5,
            color: Colors.grey[200],
            dashArray: <double>[3, 3],
          ),
          axisLine: AxisLine(width: 0),
          labelFormat: '{value} km',
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontFamily: 'Inter',
            fontSize: 10,
          ),
        ),
        tooltipBehavior: TooltipBehavior(
          enable: true,
          color: Colors.grey[800],
          textStyle: TextStyle(color: Colors.white, fontSize: 12),
        ),
        series: <ChartSeries>[
          LineSeries<ActivitySessionData, String>(
            dataSource: chartData,
            xValueMapper: (ActivitySessionData data, _) => data.session,
            yValueMapper: (ActivitySessionData data, _) => data.value,
            color: Color(0xffFFA500),
            width: 3,
            markerSettings: MarkerSettings(
              isVisible: true,
              shape: DataMarkerType.circle,
              color: Color(0xffFFA500),
              borderColor: Colors.white,
              borderWidth: 2,
              height: 10,
              width: 10,
            ),
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(
                color: Colors.black87,
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

// Second graph for 'Endurance' goal - Duration per session
  Widget _buildDurationPerSessionGraph() {
    List<ActivitySessionData> chartData = [];
    int sessionCount = 1;

    // Process activity data to extract duration per session
    for (var activity in activityData.reversed) {
      // Use reversed to show oldest to newest
      // Assuming duration is stored in seconds
      double duration = safeParseDouble(activity['elapsed_time']);
      // Convert to minutes
      duration = (duration / 60).roundToDouble();

      chartData.add(ActivitySessionData("S$sessionCount", duration));
      sessionCount++;
    }

    return _buildGraphContainer(
      title: "Recent Durations",
      subtitle: "Last ${chartData.length} endurance sessions",
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(
          majorGridLines: MajorGridLines(width: 0),
          axisLine: AxisLine(width: 1, color: Colors.grey[200]),
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        primaryYAxis: NumericAxis(
          majorGridLines: MajorGridLines(
            width: 0.5,
            color: Colors.grey[200],
            dashArray: <double>[3, 3],
          ),
          axisLine: AxisLine(width: 0),
          labelFormat: '{value} min',
          labelStyle: TextStyle(
            color: Colors.grey[700],
            fontFamily: 'Inter',
            fontSize: 10,
          ),
        ),
        tooltipBehavior: TooltipBehavior(
          enable: true,
          color: Colors.grey[800],
          textStyle: TextStyle(color: Colors.white, fontSize: 12),
        ),
        series: <ChartSeries>[
          LineSeries<ActivitySessionData, String>(
            dataSource: chartData,
            xValueMapper: (ActivitySessionData data, _) => data.session,
            yValueMapper: (ActivitySessionData data, _) => data.value,
            color: Color(0xff4CAF50), // Different color from distance graph
            width: 3,
            markerSettings: MarkerSettings(
              isVisible: true,
              shape: DataMarkerType.circle,
              color: Color(0xff4CAF50),
              borderColor: Colors.white,
              borderWidth: 2,
              height: 10,
              width: 10,
            ),
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(
                color: Colors.black87,
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

// First graph for 'High Intensity Cycling' goal - Weight over time
  Widget _buildWeightOverTimeGraph() {
  return FutureBuilder<QuerySnapshot>(
    future: FirebaseFirestore.instance
        .collection('userData')
        .where('uid', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(5) // Last 5 weight entries
        .get(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildLoadingGraph();
      }

      if (snapshot.hasError ||
          !snapshot.hasData ||
          snapshot.data!.docs.isEmpty) {
        return _buildEmptyGraph("No weight tracking data available");
      }

      List<MetricData> chartData = [];

      for (var doc in snapshot.data!.docs.reversed) {
        // Use reversed to show oldest to newest
        var data = doc.data() as Map<String, dynamic>;
        double weight = safeParseDouble(data['weight']);
        
        // Get the exact timestamp for the x-axis
        Timestamp timestamp = data['timestamp'];
        DateTime date = timestamp.toDate();

        // Format date to show exact measurement time
        String dateLabel = DateFormat('MM/dd HH:mm').format(date);

        chartData.add(MetricData(dateLabel, weight));
      }

      return _buildGraphContainer(
        title: "Weight Tracking",
        subtitle: "High Intensity goal",
        child: SfCartesianChart(
          margin: EdgeInsets.fromLTRB(10, 10, 10, 10),
          primaryXAxis: CategoryAxis(
            majorGridLines: MajorGridLines(width: 0),
            axisLine: AxisLine(width: 1, color: Colors.grey[200]),
            labelStyle: TextStyle(
              color: Colors.grey[700],
              fontFamily: 'Inter',
              fontSize: 10, // Smaller font for detailed timestamps
              fontWeight: FontWeight.w500,
            ),
            labelRotation: 15, // Angle the labels to avoid overlap
            labelAlignment: LabelAlignment.end,
            maximumLabels: 5, // Limit number of labels to avoid crowding
          ),
          primaryYAxis: NumericAxis(
            majorGridLines: MajorGridLines(
              width: 0.5,
              color: Colors.grey[200],
              dashArray: <double>[3, 3],
            ),
            axisLine: AxisLine(width: 0),
            labelFormat: '{value} kg',
            labelStyle: TextStyle(
              color: Colors.grey[700],
              fontFamily: 'Inter',
              fontSize: 10,
            ),
          ),
          tooltipBehavior: TooltipBehavior(
            enable: true,
            color: Colors.grey[800],
            textStyle: TextStyle(color: Colors.white, fontSize: 12),
            format: 'Weight: point.y kg\nTime: point.x', // Custom tooltip
          ),
          series: <ChartSeries>[
            SplineSeries<MetricData, String>(
              dataSource: chartData,
              xValueMapper: (MetricData data, _) => data.date,
              yValueMapper: (MetricData data, _) => data.value,
              color: Color(0xff2196F3), // Blue for weight
              width: 3,
              markerSettings: MarkerSettings(
                isVisible: true,
                shape: DataMarkerType.circle,
                color: Color(0xff2196F3),
                borderColor: Colors.white,
                borderWidth: 2,
                height: 10,
                width: 10,
              ),
              dataLabelSettings: DataLabelSettings(
                isVisible: true,
                textStyle: TextStyle(
                  color: Colors.black87,
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                labelAlignment: ChartDataLabelAlignment.top,
              ),
            ),
          ],
        ),
      );
    },
  );
}

// Second graph for 'High Intensity Cycling' goal - Body fat percentage over time
Widget _buildBodyFatOverTimeGraph() {
  return FutureBuilder<QuerySnapshot>(
    future: FirebaseFirestore.instance
        .collection('userData')
        .where('uid', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(5) // Last 5 entries
        .get(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildLoadingGraph();
      }

      if (snapshot.hasError ||
          !snapshot.hasData ||
          snapshot.data!.docs.isEmpty) {
        return _buildEmptyGraph("No body fat tracking data available");
      }

      List<MetricData> chartData = [];

      for (var doc in snapshot.data!.docs.reversed) {
        // Use reversed to show oldest to newest
        var data = doc.data() as Map<String, dynamic>;
        double bodyFat = safeParseDouble(data['bodyFat']);
        
        // Get the exact timestamp for the x-axis
        Timestamp timestamp = data['timestamp'];
        DateTime date = timestamp.toDate();

        // Format date to show exact measurement time
        String dateLabel = DateFormat('MM/dd HH:mm').format(date);

        chartData.add(MetricData(dateLabel, bodyFat));
      }

      return _buildGraphContainer(
        title: "Body Fat Percentage",
        subtitle: "High Intensity goal",
        child: SfCartesianChart(
          margin: EdgeInsets.fromLTRB(10, 10, 10, 10),
          primaryXAxis: CategoryAxis(
            majorGridLines: MajorGridLines(width: 0),
            axisLine: AxisLine(width: 1, color: Colors.grey[200]),
            labelStyle: TextStyle(
              color: Colors.grey[700],
              fontFamily: 'Inter',
              fontSize: 10, // Smaller font for detailed timestamps
              fontWeight: FontWeight.w500,
            ),
            labelRotation: 15, // Angle the labels to avoid overlap
            labelAlignment: LabelAlignment.end,
            maximumLabels: 5, // Limit number of labels to avoid crowding
          ),
          primaryYAxis: NumericAxis(
            majorGridLines: MajorGridLines(
              width: 0.5,
              color: Colors.grey[200],
              dashArray: <double>[3, 3],
            ),
            axisLine: AxisLine(width: 0),
            labelFormat: '{value}%',
            labelStyle: TextStyle(
              color: Colors.grey[700],
              fontFamily: 'Inter',
              fontSize: 10,
            ),
          ),
          tooltipBehavior: TooltipBehavior(
            enable: true,
            color: Colors.grey[800],
            textStyle: TextStyle(color: Colors.white, fontSize: 12),
            format: 'Body Fat: point.y%\nTime: point.x', // Custom tooltip
          ),
          series: <ChartSeries>[
            SplineSeries<MetricData, String>(
              dataSource: chartData,
              xValueMapper: (MetricData data, _) => data.date,
              yValueMapper: (MetricData data, _) => data.value,
              color: Color(0xffE91E63), // Pink for body fat
              width: 3,
              markerSettings: MarkerSettings(
                isVisible: true,
                shape: DataMarkerType.circle,
                color: Color(0xffE91E63),
                borderColor: Colors.white,
                borderWidth: 2,
                height: 10,
                width: 10,
              ),
              dataLabelSettings: DataLabelSettings(
                isVisible: true,
                textStyle: TextStyle(
                  color: Colors.black87,
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                labelAlignment: ChartDataLabelAlignment.top,
              ),
            ),
          ],
        ),
      );
    },
  );
}

// Helper methods for common UI elements
  Widget _buildLoadingGraph() {
    return Container(
      height: 250,
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
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xffFFA500),
        ),
      ),
    );
  }

  Widget _buildEmptyGraph(String message) {
    return Container(
      height: 250,
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
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              color: Colors.grey[400],
              size: 40,
            ),
            SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
                fontFamily: "Inter",
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphContainer({
  required String title,
  required String subtitle,
  required Widget child
}) {
  return Container(
    height: 250,
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
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Fredoka-SemiBold',
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10, // Reduced from 12 to 10
                  color: Colors.grey[700],
                  fontFamily: "Inter",
                  overflow: TextOverflow.ellipsis, // Added overflow handling
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Expanded(child: child),
      ],
    ),
  );
}

  Widget _weatherInfoItem(
      IconData icon, String value, String label, Color color) {
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
