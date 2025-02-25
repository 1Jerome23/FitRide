import 'package:fitride/pages/goal_tracking.dart';
import 'package:fitride/pages/profile.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitride/pages/recent_activity.dart';
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
    _loadRecentActivities();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  Future<void> _loadStravaUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _stravaUserId = prefs.getString('stravaUserId');
    });
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
    // Ensure location services are enabled
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("Location services are disabled.");
      return;
    }

    // Check & request permission
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
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

    // Get current position using geo.geolocation
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
          weatherImage = _getWeatherImage(currentWeather['weathercode'].toString());
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
      final pmValue = airQualityPM25.isNotEmpty ? (airQualityPM25[0] as num).toDouble() : 0.0;

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


  List<Map<String, dynamic>> _recentActivities = [];
  bool _loadingActivities = false;

  Future<void> _loadRecentActivities() async {
    setState(() {
      _loadingActivities = true;
    });
    
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final athleteQuerySnapshot = await FirebaseFirestore.instance
            .collection('athletes')
            .where('app_id', isEqualTo: uid)
            .limit(1)
            .get();
        
        if (athleteQuerySnapshot.docs.isNotEmpty) {
          final athleteDoc = athleteQuerySnapshot.docs.first;
          final athleteId = athleteDoc.id;
          
          final userIdNumber = int.tryParse(athleteId);
          
          if (userIdNumber != null) {
            final activitiesSnapshot = await FirebaseFirestore.instance
                .collection('activities')
                .where('user_id', isEqualTo: userIdNumber)
                .limit(10)
                .get();
            
            List<Map<String, dynamic>> activities = [];
            for (var doc in activitiesSnapshot.docs) {
              activities.add(doc.data() as Map<String, dynamic>);
            }
            
            activities.sort((a, b) {
              var aDate = a['start_date'];
              var bDate = b['start_date'];
              if (aDate == null || bDate == null) return 0;
              if (aDate is Timestamp && bDate is Timestamp) {
                return bDate.compareTo(aDate); 
              }
              return bDate.toString().compareTo(aDate.toString());
            });
            
            if (activities.length > 3) {
              activities = activities.sublist(0, 3);
            }
            
            setState(() {
              _recentActivities = activities;
              _loadingActivities = false;
            });
          } else {
            setState(() {
              _loadingActivities = false;
            });
          }
        } else {
          setState(() {
            _loadingActivities = false;
          });
        }
      } catch (e) {
        print('Error loading recent activities: $e');
        setState(() {
          _loadingActivities = false;
        });
      }
    } else {
      setState(() {
        _loadingActivities = false;
      });
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
                ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slide(begin: Offset(0, -0.1), end: Offset.zero),
                Text(
                  "Glad to see you! Let’s make today’s ride a great one. Hop on and ride!",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontFamily: "Inter",
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 300.ms).slide(begin: Offset(0, -0.1), end: Offset.zero),
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
                          ],
                        ).animate().fadeIn(duration: 800.ms, delay: 600.ms),
                      ],
                    ),
                  ),
                ).animate()
                  .fadeIn(duration: 600.ms, delay: 400.ms)
                  .slideY(begin: 0.1, end: 0)
                  .shimmer(delay: 1000.ms, duration: 1800.ms),
                
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
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          spreadRadius: 4,
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('activities')
                          .where('user_id', isEqualTo: int.parse(_stravaUserId.toString()))
                          .orderBy('start_date', descending: false)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Color(0xffFFA500),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          print("Firestore Error: ${snapshot.error}");
                          return Center(
                            child: Text(
                              "Error fetching data",
                              style: TextStyle(color: Colors.red, fontFamily: "Inter"),
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          print("No activities found for user: $_stravaUserId");
                          return Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  size: 50,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "No activity data available",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 18,
                                    fontFamily: "Inter",
                                  ),
                                ),
                              ],
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

                          activityData.add(
                            ActivityData(
                              DateFormat('MMM').format(date),
                              distance,
                            ),
                          );
                        }

                        return SizedBox(
                          width: double.infinity,
                          height: 300, // Increased height for better visibility
                          child: SfCartesianChart(
                            primaryXAxis: CategoryAxis(
                              title: AxisTitle(
                                text: 'Month',
                                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              labelStyle: TextStyle(fontSize: 14),
                            ),
                            primaryYAxis: NumericAxis(
                              title: AxisTitle(
                                text: 'Distance (km)',
                                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              labelFormat: '{value} km',
                              labelStyle: TextStyle(fontSize: 14),
                            ),
                            title: ChartTitle(
                              text: 'Monthly Distance Traveled',
                              textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            legend: Legend(
                              isVisible: true,
                              position: LegendPosition.bottom,
                              textStyle: TextStyle(fontSize: 14),
                            ),
                            tooltipBehavior: TooltipBehavior(enable: true),
                            series: [
                              LineSeries<ActivityData, String>(
                                name: 'Distance',
                                dataSource: activityData,
                                xValueMapper: (ActivityData data, _) => data.month,
                                yValueMapper: (ActivityData data, _) => data.distance,
                                dataLabelSettings: DataLabelSettings(isVisible: true, textStyle: TextStyle(fontSize: 14)),
                                markerSettings: MarkerSettings(isVisible: true, height: 8, width: 8),
                                width: 4, // Thicker line for better visibility
                                color: Color(0xffFFA500),
                              ),
                            ],
                          ),
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
                  child: _loadingActivities
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                              color: Color(0xffFFA500),
                            ),
                          ),
                        )
                      : _recentActivities.isEmpty
                          ? ListView.builder(
                              physics: NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: 1,
                              itemBuilder: (context, index) {
                                return _buildActivityItem(
                                  "No recent activity",
                                  "Record your first ride to see it here!",
                                  "00:00",
                                  Icons.directions_bike_outlined,
                                );
                              },
                            )
                          : ListView.separated(
                              physics: NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: _recentActivities.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: Colors.grey[200],
                              ),
                              itemBuilder: (context, index) {
                                final activity = _recentActivities[index];
                              
                                final name = activity['name'] ?? 'Cycling Activity';
                                final type = activity['type'] ?? 'Ride';
                                
                                String distanceStr = '0 km';
                                if (activity['distance'] != null) {
                                  try {
                                    final distance = double.tryParse(activity['distance'].toString()) ?? 0.0;
                                    
                                    distanceStr = '${distance.toStringAsFixed(1)} km';
                                  } catch (e) {
                                    print('Error parsing distance: $e');
                                    distanceStr = '0 km';
                                  }
                                }
                                
                                return _buildActivityItem(
                                  name,
                                  type,
                                  distanceStr,
                                  Icons.directions_bike_outlined,
                                );
                              },
                            ),
                ),
                SizedBox(height: 20),
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
      )
    );
  }

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
