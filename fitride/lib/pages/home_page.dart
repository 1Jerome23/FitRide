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

//please work push
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class ActivityData {
  final String month;
  final double distance;

  ActivityData(this.month, this.distance);
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
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
    loadStravaUserId();

    // Fetch streak data
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _fetchStreakData(userId).then((streakData) {
        setState(() {
          _streakCount =
              streakData?['streak'] ?? 0; // Default to 0 if no streak exists
        });
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
                    "Glad to see you! Let’s make today’s ride a great one. Hop on and ride!",
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
                        "Your Activity Progress",
                        style: TextStyle(
                          fontFamily: 'Fredoka-SemiBold',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                      SizedBox(height: 15),
                      Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Color(0xFFFAF6F0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          spreadRadius: 2,
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _stravaUserId == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.link_off, color: Colors.red[400], size: 36),
                                SizedBox(height: 6),
                                Text(
                                  "No Strava account connected",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 15,
                                    fontFamily: "Inter",
                                  ),
                                ),
                              ],
                            ),
                          )
                        : FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('activities')
                                .where('user_id', isEqualTo: int.tryParse(_stravaUserId!))
                                .orderBy('start_date', descending: false)
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(
                                  child: SizedBox(
                                    height: 180,
                                    child: CircularProgressIndicator(
                                      color: Color(0xffFFA500),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                );
                              }
                              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return Center(
                                  child: SizedBox(
                                    height: 180,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.bar_chart_rounded,
                                          color: Colors.grey[400],
                                          size: 40,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          snapshot.hasError 
                                              ? "Error loading data" 
                                              : "No activity data available",
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

                              // Parse Firestore data into chart points
                              List<ActivityData> activityData = [];
                              for (var doc in snapshot.data!.docs) {
                                var data = doc.data() as Map<String, dynamic>;
                                double distance = double.tryParse(data['distance'].toString()) ?? 0.0;
                                Timestamp? timestamp = data['start_date'];
                                DateTime date = timestamp?.toDate() ?? DateTime.now();

                                // Format month for display
                                String monthLabel = DateFormat('MMM').format(date);
                                
                                activityData.add(
                                  ActivityData(
                                    monthLabel, // This will be displayed on the x-axis
                                    distance,
                                  ),
                                );
                              }

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 12, top: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Monthly Distance",
                                          style: TextStyle(
                                            fontFamily: 'Fredoka-SemiBold',
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Color(0xffFFA500), Color(0xffFF8C00)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Color(0xffFFA500).withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: Offset(0, 2),
                                              )
                                            ]
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.insights, size: 14, color: Colors.white),
                                              SizedBox(width: 4),
                                              Text(
                                                "Activity",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ).animate().shimmer(delay: 2000.ms, duration: 1800.ms),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    height: 200, // Compact height
                                    width: double.infinity,
                                    child: SfCartesianChart(
                                      margin: EdgeInsets.zero,
                                      plotAreaBorderWidth: 0,
                                      primaryXAxis: CategoryAxis(
                                        majorGridLines: MajorGridLines(width: 0),
                                        axisLine: AxisLine(width: 1, color: Colors.grey[200]),
                                        labelStyle: TextStyle(
                                          color: Colors.grey[700],
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        majorTickLines: MajorTickLines(size: 0),
                                        labelIntersectAction: AxisLabelIntersectAction.hide,
                                        interval: 1, // Ensure all months are shown
                                        labelRotation: 0, // Keep labels horizontal
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
                                        majorTickLines: MajorTickLines(size: 0),
                                      ),
                                      tooltipBehavior: TooltipBehavior(
                                        enable: true,
                                        color: Colors.grey[800],
                                        textStyle: TextStyle(color: Colors.white, fontSize: 12),
                                        duration: 1500,
                                        animationDuration: 150,
                                        elevation: 10,
                                        shadowColor: Colors.black.withOpacity(0.3),
                                      ),
                                      legend: Legend(isVisible: false),
                                      series: <ChartSeries>[
                                        // Area Series with gradient
                                        AreaSeries<ActivityData, String>(
                                          dataSource: activityData,
                                          xValueMapper: (ActivityData data, _) => data.month,
                                          yValueMapper: (ActivityData data, _) => data.distance,
                                          borderColor: Color(0xffFFA500),
                                          borderWidth: 0, // No border for area
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xffFFA500).withOpacity(0.5),
                                              Color(0xffFFA500).withOpacity(0.0),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          animationDuration: 1200,
                                        ),
                                        // Main line series - THICKER now
                                        SplineSeries<ActivityData, String>(
                                          dataSource: activityData,
                                          xValueMapper: (ActivityData data, _) => data.month,
                                          yValueMapper: (ActivityData data, _) => data.distance,
                                          width: 5, // Much thicker line
                                          color: Color(0xffFFA500),
                                          animationDuration: 1500,
                                          markerSettings: MarkerSettings(
                                            isVisible: true,
                                            height: 12,
                                            width: 12,
                                            shape: DataMarkerType.circle,
                                            borderWidth: 2,
                                            borderColor: Color(0xffFFA500),
                                            color: Colors.white,
                                          ),
                                          dataLabelSettings: DataLabelSettings(
                                            isVisible: true,
                                            color: Colors.white,
                                            borderColor: Color(0xffFFA500).withOpacity(0.5),
                                            borderWidth: 1,
                                            margin: EdgeInsets.all(4),
                                            textStyle: TextStyle(
                                              color: Colors.black87,
                                              fontFamily: 'Inter',
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            labelPosition: ChartDataLabelPosition.outside,
                                          ),
                                          enableTooltip: true,
                                        ),
                                      ],
                                    ),
                                  ).animate()
                                  .slideY(
                                    begin: 0.05,
                                    end: 0,
                                    duration: 600.ms,
                                    curve: Curves.easeOutQuad,
                                  ).then(delay: 300.ms)
                                  .shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.2)),
                                  
                                  // Small legend at the bottom
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              height: 3,
                                              width: 20,
                                              decoration: BoxDecoration(
                                                color: Color(0xffFFA500),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              "Distance (km)",
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 10,
                                                fontFamily: "Inter",
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          "Months",
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 10,
                                            fontFamily: "Inter",
                                          ),
                                        ),
                                      ],
                                    ),
                                  ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
                                ],
                              ).animate().fadeIn(duration: 400.ms);
                            },
                          ),
                  ),
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
