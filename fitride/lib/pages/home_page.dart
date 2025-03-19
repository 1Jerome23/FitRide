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
import 'package:lottie/lottie.dart';
import 'dart:math' as math;

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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String _userGoal = 'Unknown'; // Default value
  PageController _pageController = PageController();
  int _currentPage = 0;
  List<Map<String, dynamic>> activityData = [];
  bool _isLoadingGraphs = true;
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
  bool showAllLogs = false;
  bool _isMealHistoryExpanded = false;
  bool _showAllMeals = false;
  int _currentMealCardIndex = 0;
  final PageController _mealPageController = PageController();
  List<Map<String, dynamic>> bodyMetricsData = [];
  bool _showAllMetrics = false;

  int? _streakCount;
  DateTime? _lastStreakUpdate;
  int? _lastCompletedWeek;
  bool _isStreakLoading = true;
  bool _streakAnimationPlaying = false;
  late AnimationController _streakAnimationController;
  final List<String> _streakMilestoneMessages = [
    "Keep it up! Your fitness journey is just beginning.",
    "Fantastic consistency! You're building strong habits.",
    "Impressive dedication! You're now in elite territory.",
    "Legendary status! Your commitment is truly inspiring.",
  ];

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

    _streakAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    // Sequentially load data
    _loadUserData();
    _fetchFoodDiaryData();
    _fetchBodyMetricsData(); 
  }

  // Sequentially load data to ensure dependencies are respected
  Future<void> _loadUserData() async {
  // First load streak data
  String? userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId != null) {
    await _fetchStreakData(userId);
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
    _streakAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchBodyMetricsData() async {
  if (userId == null) return;

  try {
    QuerySnapshot metricsSnapshot = await FirebaseFirestore.instance
        .collection('userData')
        .where('uid', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    if (metricsSnapshot.docs.isNotEmpty) {
      List<Map<String, dynamic>> newMetricsData = [];

      for (var doc in metricsSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // Only add entries that have at least one metric
        if (data.containsKey('weight') || 
            data.containsKey('bodyFat') || 
            data.containsKey('basalMetabolicRate')) {
          
          newMetricsData.add({
            "documentId": doc.id,
            "weight": data['weight'] ?? "-",
            "bodyFat": data['bodyFat'] ?? "-",
            "basalMetabolicRate": data['basalMetabolicRate'] ?? "-",
            "timestamp": data['timestamp'],
          });
        }
      }

      setState(() {
        bodyMetricsData = newMetricsData;
      });
      
      print("Fetched ${bodyMetricsData.length} body metrics entries");
    }
  } catch (e) {
    print("Error fetching body metrics data: $e");
  }
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

  Future<void> _fetchStreakData(String userId) async {
  setState(() {
    _isStreakLoading = true;
  });
  
  try {
    print('Fetching streak data for user: $userId');
    
    // 1. First get the goal document to determine goal creation date
    QuerySnapshot goalsSnapshot = await FirebaseFirestore.instance
        .collection('goals')
        .where('uid', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    
    if (goalsSnapshot.docs.isEmpty) {
      print('No goals found for user');
      setState(() {
        _streakCount = 0;
        _isStreakLoading = false;
      });
      return;
    }
    
    DocumentSnapshot goalDoc = goalsSnapshot.docs.first;
    String goalId = goalDoc.id;
    Map<String, dynamic> goalData = goalDoc.data() as Map<String, dynamic>;
    
    // Get goal creation date
    Timestamp goalCreationTimestamp = goalData['timestamp'] as Timestamp;
    DateTime goalCreationDate = goalCreationTimestamp.toDate();
    print('Goal creation date: $goalCreationDate');
    
    // 2. Calculate the CURRENT week number based on days since goal creation
    DateTime now = DateTime.now();
    int daysSinceCreation = now.difference(goalCreationDate).inDays;
    int currentWeekNumber = (daysSinceCreation ~/ 7) + 1;
    print('Current week number: $currentWeekNumber');
    
    // 3. Get the streak document to see what's stored
    DocumentSnapshot<Map<String, dynamic>> streakSnapshot = await FirebaseFirestore
        .instance
        .collection('Streak')
        .doc(userId)
        .get();
    
    Map<String, dynamic>? streakData;
    int? storedStreakCount;
    int? lastCompletedWeek;
    
    if (streakSnapshot.exists) {
      streakData = streakSnapshot.data()!;
      storedStreakCount = streakData['streak'] ?? 0;
      lastCompletedWeek = streakData['lastCompletedWeek'] ?? 0;
      print('Stored streak: $storedStreakCount, Last completed week: $lastCompletedWeek');
    } else {
      print('No streak document exists yet');
      storedStreakCount = 0;
      lastCompletedWeek = 0;
    }
    
    // 4. Explicitly get the CURRENT week's progress
    QuerySnapshot currentWeekSnapshot = await FirebaseFirestore.instance
        .collection('weekly_progress')
        .where('uid', isEqualTo: userId)
        .where('goalId', isEqualTo: goalId)
        .where('weekNumber', isEqualTo: currentWeekNumber)
        .limit(1)
        .get();
    
    bool currentWeekCompleted = false;
    Map<String, dynamic>? currentWeekData;
    
    if (currentWeekSnapshot.docs.isNotEmpty) {
      currentWeekData = currentWeekSnapshot.docs.first.data() as Map<String, dynamic>;
      print('Current week data found: $currentWeekData');
      
      // Calculate current week completion
      double daysProgress = 0.0;
      double daysTarget = 7.0;
      
      if (currentWeekData.containsKey('dayProgress')) {
        daysProgress = (currentWeekData['dayProgress'] as num).toDouble();
      } else if (currentWeekData.containsKey('uniqueDays')) {
        List<dynamic> uniqueDays = currentWeekData['uniqueDays'] ?? [];
        daysProgress = uniqueDays.length.toDouble();
      }
      
      if (currentWeekData.containsKey('targetDaysPerWeek')) {
        daysTarget = (currentWeekData['targetDaysPerWeek'] as num).toDouble();
      } else if (goalData.containsKey('daysPerWeek')) {
        daysTarget = (goalData['daysPerWeek'] as num).toDouble();
      }
      
      // Calculate completion percentage
      double completionPercentage = daysTarget > 0 ? (daysProgress / daysTarget) : 0.0;
      currentWeekCompleted = completionPercentage >= 1.0;
      
      print('Current week progress: $daysProgress/$daysTarget (${(completionPercentage * 100).toStringAsFixed(1)}%)');
      print('Current week is completed: $currentWeekCompleted');
    } else {
      print('No data found for current week $currentWeekNumber');
    }
    
    // 5. Get the PREVIOUS week's progress
    QuerySnapshot previousWeekSnapshot = await FirebaseFirestore.instance
        .collection('weekly_progress')
        .where('uid', isEqualTo: userId)
        .where('goalId', isEqualTo: goalId)
        .where('weekNumber', isEqualTo: currentWeekNumber - 1)
        .limit(1)
        .get();
    
    bool previousWeekCompleted = false;
    
    if (previousWeekSnapshot.docs.isNotEmpty) {
      Map<String, dynamic> previousWeekData = previousWeekSnapshot.docs.first.data() as Map<String, dynamic>;
      print('Previous week data found');
      
      // Calculate previous week completion
      double daysProgress = 0.0;
      double daysTarget = 7.0;
      
      if (previousWeekData.containsKey('dayProgress')) {
        daysProgress = (previousWeekData['dayProgress'] as num).toDouble();
      } else if (previousWeekData.containsKey('uniqueDays')) {
        List<dynamic> uniqueDays = previousWeekData['uniqueDays'] ?? [];
        daysProgress = uniqueDays.length.toDouble();
      }
      
      if (previousWeekData.containsKey('targetDaysPerWeek')) {
        daysTarget = (previousWeekData['targetDaysPerWeek'] as num).toDouble();
      } else if (goalData.containsKey('daysPerWeek')) {
        daysTarget = (goalData['daysPerWeek'] as num).toDouble();
      }
      
      // Calculate completion percentage
      double completionPercentage = daysTarget > 0 ? (daysProgress / daysTarget) : 0.0;
      previousWeekCompleted = completionPercentage >= 1.0;
      
      print('Previous week completed: $previousWeekCompleted');
    } else {
      print('No data found for previous week ${currentWeekNumber - 1}');
    }
    
    // 6. Determine new streak value based on completion status
    int newStreakCount = storedStreakCount ?? 0;
    int? newLastCompletedWeek = lastCompletedWeek;
    bool shouldPlayAnimation = false;
    
    // CASE 1: Current week is complete and hasn't been counted yet
    if (currentWeekCompleted && lastCompletedWeek != currentWeekNumber) {
      newStreakCount = (storedStreakCount ?? 0) + 1;
      newLastCompletedWeek = currentWeekNumber;
      shouldPlayAnimation = true;
      print('INCREMENTING STREAK: Current week complete and not yet counted');
    }
    // CASE 2: Current week is incomplete, but previous week was complete and hasn't been counted
    else if (!currentWeekCompleted && previousWeekCompleted && lastCompletedWeek != currentWeekNumber - 1) {
      newStreakCount = (storedStreakCount ?? 0) + 1;
      newLastCompletedWeek = currentWeekNumber - 1;
      shouldPlayAnimation = true;
      print('INCREMENTING STREAK: Previous week complete and not yet counted');
    }
    // CASE 3: Streak broken (missed a week)
    else if (currentWeekNumber > (lastCompletedWeek ?? 0) + 1 && 
             !previousWeekCompleted && 
             !currentWeekCompleted) {
      newStreakCount = 0; // Reset streak
      print('RESETTING STREAK: Missed a week, streak broken');
    }
    // CASE 4: First time user with completed current week
    else if (lastCompletedWeek == 0 && currentWeekCompleted) {
      newStreakCount = 1;
      newLastCompletedWeek = currentWeekNumber;
      shouldPlayAnimation = true;
      print('NEW STREAK: First-time user with completed current week');
    }
    
    print('Final streak calculation: $storedStreakCount -> $newStreakCount');
    
    // 7. Update streak in Firestore if needed
    if (newStreakCount != storedStreakCount || newLastCompletedWeek != lastCompletedWeek) {
      if (streakSnapshot.exists) {
        await FirebaseFirestore.instance
            .collection('Streak')
            .doc(userId)
            .update({
              'streak': newStreakCount,
              'lastCompletedWeek': newLastCompletedWeek,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
        print('Updated streak document: streak=$newStreakCount, lastCompletedWeek=$newLastCompletedWeek');
      } else {
        await FirebaseFirestore.instance
            .collection('Streak')
            .doc(userId)
            .set({
              'streak': newStreakCount,
              'lastCompletedWeek': newLastCompletedWeek,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
        print('Created new streak document: streak=$newStreakCount, lastCompletedWeek=$newLastCompletedWeek');
      }
    }
    
    // 8. Update UI state
    setState(() {
      _streakCount = newStreakCount;
      _lastCompletedWeek = newLastCompletedWeek;
      
      if (shouldPlayAnimation) {
        _streakAnimationPlaying = true;
        _streakAnimationController.forward(from: 0.0);
      }
    });
    
  } catch (e) {
    print('Error fetching or updating streak data: $e');
    setState(() {
      _streakCount = 0;
    });
  } finally {
    setState(() {
      _isStreakLoading = false;
    });
  }
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

  Future<Map<String, dynamic>> _fetchCurrentWeekProgress() async {
  String? userId = FirebaseAuth.instance.currentUser?.uid;
  Map<String, dynamic> result = {
    'progress': 0.0,
    'daysCompleted': 0,
    'daysTarget': 7,
    'isCompleted': false,
    'weekNumber': 0,
  };
  
  if (userId == null) return result;
  
  try {
    // Get the most recent goal
    QuerySnapshot goalsSnapshot = await FirebaseFirestore.instance
        .collection('goals')
        .where('uid', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    
    if (goalsSnapshot.docs.isEmpty) return result;
    
    DocumentSnapshot goalDoc = goalsSnapshot.docs.first;
    String goalId = goalDoc.id;
    Map<String, dynamic> goalData = goalDoc.data() as Map<String, dynamic>;
    
    // Calculate the current week number
    Timestamp goalCreationTimestamp = goalData['timestamp'] as Timestamp;
    DateTime goalCreationDate = goalCreationTimestamp.toDate();
    DateTime now = DateTime.now();
    int daysSinceCreation = now.difference(goalCreationDate).inDays;
    int currentWeekNumber = (daysSinceCreation ~/ 7) + 1;
    
    // Get the current week's progress
    QuerySnapshot weeklyProgressSnapshot = await FirebaseFirestore.instance
        .collection('weekly_progress')
        .where('uid', isEqualTo: userId)
        .where('goalId', isEqualTo: goalId)
        .where('weekNumber', isEqualTo: currentWeekNumber)
        .limit(1)
        .get();
    
    if (weeklyProgressSnapshot.docs.isEmpty) {
      result['weekNumber'] = currentWeekNumber;
      return result;
    }
    
    Map<String, dynamic> weekData = weeklyProgressSnapshot.docs.first.data() as Map<String, dynamic>;
    
    // Parse the days progress
    double daysProgress = 0.0;
    if (weekData.containsKey('dayProgress')) {
      daysProgress = (weekData['dayProgress'] as num).toDouble();
    } else if (weekData.containsKey('uniqueDays')) {
      List<dynamic> uniqueDays = weekData['uniqueDays'] ?? [];
      daysProgress = uniqueDays.length.toDouble();
    }
    
    // Parse the days target
    double daysTarget = 7.0;
    if (weekData.containsKey('targetDaysPerWeek')) {
      daysTarget = (weekData['targetDaysPerWeek'] as num).toDouble();
    } else if (goalData.containsKey('daysPerWeek')) {
      daysTarget = (goalData['daysPerWeek'] as num).toDouble();
    }
    
    // Calculate progress percentage
    double progress = daysTarget > 0 ? (daysProgress / daysTarget).clamp(0.0, 1.0) : 0.0;
    bool isCompleted = progress >= 1.0;
    
    return {
      'progress': progress,
      'daysCompleted': daysProgress.toInt(),
      'daysTarget': daysTarget.toInt(),
      'isCompleted': isCompleted,
      'weekNumber': currentWeekNumber,
      'weekData': weekData,
    };
  } catch (e) {
    print('Error fetching current week progress: $e');
    return result;
  }
}

  String _getProgressMotivationalText(double progress) {
    if (progress >= 1.0) {
      return "Amazing! You've completed this week's goal. Keep the streak alive!";
    } else if (progress >= 0.75) {
      return "Almost there! Just a few more cycling days to reach your goal.";
    } else if (progress >= 0.5) {
      return "You're making great progress. Keep pushing!";
    } else if (progress > 0) {
      return "Good start! Keep up the consistency to build your streak.";
    } else {
      return "Time to hit the road! Start cycling to build your streak.";
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

 Widget _buildEnhancedStreakWidget() {
  // Determine streak level (for UI purposes)
  int streakLevel = 0;
  if (_streakCount != null) {
    if (_streakCount! >= 12) streakLevel = 3;
    else if (_streakCount! >= 8) streakLevel = 2;
    else if (_streakCount! >= 4) streakLevel = 1;
  }
  
  String streakMessage = _streakCount == 0 || _streakCount == null
      ? "Start your streak by completing your weekly cycling goal!"
      : _streakMilestoneMessages[streakLevel];
  
  Color primaryColor = Color(0xffFFA500); // Orange primary color
  
  return Card(
    elevation: 8,
    shadowColor: primaryColor.withOpacity(0.4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xffFFA500), // Orange background
            Color(0xffFF8C00), // Darker orange
          ],
        ),
      ),
      child: _isStreakLoading 
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background gradient
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2), 
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      
                      // Always show the GIF background if streak count > 0
                      if (_streakCount != null && _streakCount! > 0)
                        Positioned.fill(
                          child: Image.asset(
                            'assets/flame_background.gif',
                            fit: BoxFit.cover,
                          ),
                        ),
                      
                      // Streak counter & animation
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 15),
                          // Streak counter with black circle
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: Duration(milliseconds: 1000),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: _streakAnimationPlaying 
                                    ? 1 + math.sin(value * math.pi) * 0.3
                                    : 1,
                                child: child,
                              );
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black, // Black circle background
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.6),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  "${_streakCount ?? 0}",
                                  style: TextStyle(
                                    fontFamily: 'Fredoka-Bold',
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: primaryColor.withOpacity(0.8),
                                        offset: Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Streak message
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        _streakCount == 0 || _streakCount == null
                            ? Icons.emoji_events_outlined
                            : Icons.emoji_events,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          streakMessage,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Weekly progress indicator
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0, 
                    right: 16.0, 
                    bottom: 16.0,
                  ),
                  child: _buildStreakWeekProgress(),
                ),
              ],
            ),
    ),
  );
}

  Widget _buildStreakWeekProgress() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchCurrentWeekProgress(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 40,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xffFFA500)),
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return SizedBox(height: 40);
        }
        
        Map<String, dynamic> progressData = snapshot.data!;
        double progress = progressData['progress'] ?? 0.0;
        int daysCompleted = progressData['daysCompleted'] ?? 0;
        int daysTarget = progressData['daysTarget'] ?? 7;
        
        // Create a more engaging progress indicator
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "This Week's Progress",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  "$daysCompleted/$daysTarget days",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xffFFA500),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            // Custom progress bar
            Stack(
              children: [
                // Background
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                
                // Filled portion
                 AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  height: 12,
                  width: MediaQuery.of(context).size.width * 0.8 * progress,
                  decoration: BoxDecoration(
                    color: Colors.black, // Black filled portion instead of gradient
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                
                // Day markers
                ...List.generate(daysTarget, (index) {
                  double markerPosition = MediaQuery.of(context).size.width * 0.8 * (index + 1) / daysTarget;
                  return Positioned(
                    left: markerPosition - 2,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: index < daysCompleted 
                            ? Colors.white.withOpacity(0.8)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ],
            ),
            
            // Motivational text based on progress
            SizedBox(height: 8),
            Text(
              _getProgressMotivationalText(progress),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBodyMetricsHistory() {
  if (bodyMetricsData.isEmpty) {
    return Container(
      padding: EdgeInsets.all(20),
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
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.grey[500], size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "No body metrics data found. Update your profile to track your progress.",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.07),
          blurRadius: 20,
          spreadRadius: 5,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Latest metrics always visible
        if (bodyMetricsData.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: _buildBodyMetricsCard(
              bodyMetricsData[0], 
              _formatMetricsDate(bodyMetricsData[0]['timestamp']), 
              true
            ),
          ),
        
        // Past metrics (conditionally visible)
        if (_showAllMetrics && bodyMetricsData.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Column(
              children: [
                for (int i = 1; i < bodyMetricsData.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: _buildBodyMetricsCard(
                      bodyMetricsData[i], 
                      _formatMetricsDate(bodyMetricsData[i]['timestamp']), 
                      false
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

String _formatMetricsDate(dynamic timestamp) {
  if (timestamp == null) return "Unknown";
  
  DateTime date;
  try {
    date = timestamp.toDate();
  } catch (e) {
    print("Error parsing date: $e");
    return "Unknown";
  }
  
  DateTime now = DateTime.now();
  DateTime yesterday = DateTime(now.year, now.month, now.day - 1);
  
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return "Today";
  } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
    return "Yesterday";
  } else {
    return DateFormat('EEEE, MMM d').format(date);
  }
}

Widget _buildBodyMetricsCard(Map<String, dynamic> metricsData, String dateLabel, bool isLatest) {
  // Get metrics values
  String weightValue = metricsData['weight'].toString();
  String bodyFatValue = metricsData['bodyFat'].toString();
  String bmrValue = metricsData['basalMetabolicRate'].toString();
  
  // Check if metrics exist
  bool hasWeight = weightValue != "-";
  bool hasBodyFat = bodyFatValue != "-";
  bool hasBMR = bmrValue != "-";
  bool hasMetrics = hasWeight || hasBodyFat || hasBMR;
  
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: isLatest 
              ? Colors.blue.withOpacity(0.2) 
              : Colors.grey.withOpacity(0.15),
          blurRadius: 15,
          spreadRadius: 1,
          offset: Offset(0, 5),
        ),
      ],
      border: Border.all(
        color: isLatest 
            ? Colors.blue.withOpacity(0.3) 
            : Colors.grey.withOpacity(0.1),
        width: 1.5,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          // Date header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isLatest 
                    ? [Colors.blue[400]!, Colors.blue[600]!]
                    : [Colors.grey[600]!, Colors.grey[700]!],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isLatest ? Icons.today_rounded : Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                ),
              ],
            ),
          ),
          
          // No metrics message
          if (!hasMetrics)
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded, 
                    size: 20, 
                    color: Colors.grey[400]
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "No body metrics recorded for this day",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Metrics
          if (hasMetrics)
            Container(
              color: Colors.grey[50],
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (hasWeight)
                    _buildMetricItem(
                      "Weight",
                      weightValue,
                      "kg",
                      Icons.monitor_weight_rounded,
                      Colors.green[600]!,
                    ),
                  if (hasBodyFat)
                    _buildMetricItem(
                      "Body Fat",
                      bodyFatValue,
                      "%",
                      Icons.pie_chart_rounded,
                      Colors.orange[600]!,
                    ),
                  if (hasBMR)
                    _buildMetricItem(
                      "BMR",
                      bmrValue,
                      "kcal",
                      Icons.local_fire_department_rounded,
                      Colors.red[600]!,
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _buildMetricItem(String label, String value, String unit, IconData icon, Color color) {
  return Expanded(
    child: Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 4),
        Text(
          "$value $unit",
          style: TextStyle(
            fontFamily: 'Fredoka-SemiBold',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildActivityLogHeader() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Icon(
            Icons.directions_bike_rounded,
            size: 22,
            color: Color(0xffFFA500),
          ),
          SizedBox(width: 8),
          Text(
            "Recent Activities",
            style: TextStyle(
              fontFamily: 'Fredoka-SemiBold',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
      if (activityData.isNotEmpty)
        GestureDetector(
          onTap: () {
            setState(() {
              showAllLogs = !showAllLogs;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xffFFA500).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Color(0xffFFA500).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  showAllLogs
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 16,
                  color: Color(0xffFFA500),
                ),
                SizedBox(width: 4),
                Text(
                  showAllLogs ? "Hide" : "View All",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xffFFA500),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

Widget _buildActivityLogs() {
  if (activityData.isEmpty) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.grey[500], size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "No activity data found. Connect your Strava account or log your rides manually to get personalized recommendations.",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  return ListView.builder(
    shrinkWrap: true,
    physics: NeverScrollableScrollPhysics(),
    itemCount: showAllLogs ? activityData.length : 1,
    itemBuilder: (context, index) {
      var data = activityData[index];

      String formattedDate = "N/A";
      if (data['start_date'] != null) {
        DateTime startDate = data['start_date'].toDate();
        formattedDate = DateFormat('MMM d, y • h:mm a').format(startDate);
      }

      String duration = "N/A";
      int elapsedSeconds = 0;
      if (data['elapsed_time'] != null) {
        elapsedSeconds = int.tryParse(data['elapsed_time'].toString()) ?? 0;
        int hours = elapsedSeconds ~/ 3600;
        int minutes = (elapsedSeconds % 3600) ~/ 60;
        duration = hours > 0 ? "${hours}h ${minutes}m" : "${minutes}m";
      }

      return Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.12),
              spreadRadius: 0,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Color(0xffFFA500),
                  width: 4,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.directions_bike_rounded,
                          color: Color(0xffFFA500),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['name'] ?? "Cycling Activity",
                              style: TextStyle(
                                fontFamily: 'Fredoka-SemiBold',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          data['type'] ?? "Ride",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Metrics grid
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildActivityMetric(
                              "Distance",
                              "${safeParseDouble(data['distance']).toStringAsFixed(1)} km",
                              Icons.straighten_rounded,
                              Colors.blue[700]!,
                            ),
                            _buildActivityMetric(
                              "Duration",
                              duration,
                              Icons.timer_rounded,
                              Colors.purple[700]!,
                            ),
                            _buildActivityMetric(
                              "Avg Speed",
                              "${safeParseDouble(data['average_speed']).toStringAsFixed(1)} km/h",
                              Icons.speed_rounded,
                              Colors.green[700]!,
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            _buildActivityMetric(
                              "Heart Rate",
                              "${safeParseDouble(data['average_heartrate']).toInt()} bpm",
                              Icons.favorite_rounded,
                              Colors.red[700]!,
                            ),
                            _buildActivityMetric(
                              "Calories",
                              "${safeParseDouble(data['calories_burned']).toInt()} kcal",
                              Icons.local_fire_department_rounded,
                              Colors.orange[700]!,
                            ),
                            Expanded(child: SizedBox()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildActivityMetric(
    String label, String value, IconData icon, Color color) {
  return Expanded(
    child: Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

List<Map<String, dynamic>> nutritionData = [];

Future<void> _fetchFoodDiaryData() async {
  if (userId == null) return;

  try {
    // Get current date at midnight
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Get date from 7 days ago at midnight
    final oneWeekAgo = today.subtract(Duration(days: 7));
    
    print("Fetching meals from ${oneWeekAgo.toString()} to ${today.toString()}");

    QuerySnapshot foodEntrySnapshot = await FirebaseFirestore.instance
        .collection('food_entries')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(oneWeekAgo))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59)))
        .orderBy('date', descending: true)
        .limit(8) // Increased limit slightly
        .get();

    print("Found ${foodEntrySnapshot.docs.length} food entries");

    if (foodEntrySnapshot.docs.isNotEmpty) {
      List<Map<String, dynamic>> newNutritionData = [];

      for (var doc in foodEntrySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        
        // Get the date from the document
        DateTime entryDate;
        try {
          entryDate = data['date'].toDate();
          print("Food entry date: ${entryDate.toString()}");
        } catch (e) {
          print("Error parsing date: $e");
          continue; // Skip entries with invalid dates
        }

        newNutritionData.add({
          "documentId": doc.id,
          "breakfast": data['breakfast'] ?? "-",
          "lunch": data['lunch'] ?? "-",
          "dinner": data['dinner'] ?? "-",
          "breakfast_calories": data['breakfast_calories'] ?? 0,
          "lunch_calories": data['lunch_calories'] ?? 0,
          "dinner_calories": data['dinner_calories'] ?? 0,
          "breakfast_carbs": data['breakfast_carbs'] ?? 0,
          "lunch_carbs": data['lunch_carbs'] ?? 0,
          "dinner_carbs": data['dinner_carbs'] ?? 0,
          "total_carbs": data['total_carbs'] ?? 0,
          "breakfast_fat": data['breakfast_fat'] ?? 0,
          "lunch_fat": data['lunch_fat'] ?? 0,
          "dinner_fat": data['dinner_fat'] ?? 0,
          "total_fat": data['total_fat'] ?? 0,
          "breakfast_protein": data['breakfast_protein'] ?? 0,
          "lunch_protein": data['lunch_protein'] ?? 0,
          "dinner_protein": data['dinner_protein'] ?? 0,
          "total_protein": data['total_protein'] ?? 0,
          "total_calories": data['total_calories'] ?? 0,
          "date": data['date'],
          "timestamp": data['timestamp'],
        });
      }

      // Sort by date (newest first)
      newNutritionData.sort((a, b) {
        DateTime dateA = a['date'].toDate();
        DateTime dateB = b['date'].toDate();
        return dateB.compareTo(dateA);
      });

      setState(() {
        nutritionData = newNutritionData;
      });
      
      print("Processed ${nutritionData.length} food entries");
    } else {
      print("No food entries found for the last 7 days");
    }
  } catch (e) {
    print("Error fetching food diary data: $e");
  }
}

Widget _buildMealsHistory() {
  if (nutritionData.isEmpty) {
    return Container(
      padding: EdgeInsets.all(20),
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
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.grey[500], size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "No meal data found. Add your meals to track your nutrition alongside your cycling activities.",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.07),
          blurRadius: 20,
          spreadRadius: 5,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Today's meals always visible
        if (nutritionData.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: _buildEnhancedMealCard(
              nutritionData[0], 
              _formatMealDate(nutritionData[0]['date']), 
              true
            ),
          ),
        
        // Past days (conditionally visible)
        if (_showAllMeals && nutritionData.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Column(
              children: [
                for (int i = 1; i < nutritionData.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: _buildEnhancedMealCard(
                      nutritionData[i], 
                      _formatMealDate(nutritionData[i]['date']), 
                      false
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget _buildEnhancedMealCard(Map<String, dynamic> dayData, String dayLabel, bool isToday) {
  bool hasBreakfast = dayData['breakfast'] != "-";
  bool hasLunch = dayData['lunch'] != "-";
  bool hasDinner = dayData['dinner'] != "-";
  bool hasMeals = hasBreakfast || hasLunch || hasDinner;
  
  final totalCalories = double.tryParse(dayData['total_calories'].toString()) ?? 0;
  final totalProtein = double.tryParse(dayData['total_protein'].toString()) ?? 0;
  final totalCarbs = double.tryParse(dayData['total_carbs'].toString()) ?? 0;
  final totalFat = double.tryParse(dayData['total_fat'].toString()) ?? 0;
  
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: isToday 
              ? Color(0xffFFA500).withOpacity(0.2) 
              : Colors.grey.withOpacity(0.15),
          blurRadius: 15,
          spreadRadius: 1,
          offset: Offset(0, 5),
        ),
      ],
      border: Border.all(
        color: isToday 
            ? Color(0xffFFA500).withOpacity(0.3) 
            : Colors.grey.withOpacity(0.1),
        width: 1.5,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          // Day header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isToday 
                    ? [Color(0xffFFA500), Color(0xffFF8C00)]
                    : [Colors.grey[600]!, Colors.grey[700]!],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isToday ? Icons.today_rounded : Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        "${totalCalories.toStringAsFixed(0)} kcal",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Macros summary
          if (hasMeals) 
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isToday 
                  ? Color(0xffFFA500).withOpacity(0.05) 
                  : Colors.grey[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroCircle("P", totalProtein, Colors.purple[700]!),
                  _buildMacroCircle("C", totalCarbs, Colors.green[600]!),
                  _buildMacroCircle("F", totalFat, Colors.blue[600]!),
                ],
              ),
            ),
          
          // No meals message
          if (!hasMeals)
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Row(
                children: [
                  Icon(
                    Icons.no_meals_rounded, 
                    size: 20, 
                    color: Colors.grey[400]
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "No meals recorded for this day",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Meals
          if (hasMeals)
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  if (hasBreakfast)
                    _buildMealItem(
                      mealType: "Breakfast",
                      mealDesc: dayData['breakfast'],
                      calories: "${double.tryParse(dayData['breakfast_calories'].toString()) ?? 0}",
                      protein: "${double.tryParse(dayData['breakfast_protein'].toString()) ?? 0}",
                      carbs: "${double.tryParse(dayData['breakfast_carbs'].toString()) ?? 0}",
                      fat: "${double.tryParse(dayData['breakfast_fat'].toString()) ?? 0}",
                      color: Color(0xffFFA500),
                      icon: Icons.wb_sunny_outlined,
                    ),
                  if (hasLunch)
                    _buildMealItem(
                      mealType: "Lunch",
                      mealDesc: dayData['lunch'],
                      calories: "${double.tryParse(dayData['lunch_calories'].toString()) ?? 0}",
                      protein: "${double.tryParse(dayData['lunch_protein'].toString()) ?? 0}",
                      carbs: "${double.tryParse(dayData['lunch_carbs'].toString()) ?? 0}",
                      fat: "${double.tryParse(dayData['lunch_fat'].toString()) ?? 0}",
                      color: Color(0xffFF7E00),
                      icon: Icons.restaurant_outlined,
                    ),
                  if (hasDinner)
                    _buildMealItem(
                      mealType: "Dinner",
                      mealDesc: dayData['dinner'],
                      calories: "${double.tryParse(dayData['dinner_calories'].toString()) ?? 0}",
                      protein: "${double.tryParse(dayData['dinner_protein'].toString()) ?? 0}",
                      carbs: "${double.tryParse(dayData['dinner_carbs'].toString()) ?? 0}",
                      fat: "${double.tryParse(dayData['dinner_fat'].toString()) ?? 0}",
                      color: Color(0xffFF5900),
                      icon: Icons.nightlight_outlined,
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _buildMealItem({
  required String mealType,
  required String mealDesc,
  required String calories,
  required String protein,
  required String carbs,
  required String fat,
  required Color color,
  required IconData icon,
}) {
  Color bgColor;
  if (mealType == "Breakfast") {
    bgColor = Color(0xFFFFF8E1).withOpacity(0.9); 
  } else if (mealType == "Lunch") {
    bgColor = Color(0xFFFFF3E0).withOpacity(0.9); 
  } else {
    bgColor = Color(0xFFE8EAF6).withOpacity(0.9); 
  }

  return Container(
    margin: EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal header
          Row(
            children: [
              // Icon container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,
                      Color.lerp(color, Colors.black, 0.2)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              SizedBox(width: 12),
              
              // Meal details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mealType,
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                    Text(
                      mealDesc,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Calories container
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: color.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  "$calories kcal",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          
          // Macros detail
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 4, bottom: 8),
            child: Row(
              children: [
                _buildMacroDetail("Pro", protein, Colors.purple[700]!),
                SizedBox(width: 8),
                _buildMacroDetail("Carb", carbs, Colors.green[600]!),
                SizedBox(width: 8),
                _buildMacroDetail("Fat", fat, Colors.blue[600]!),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildMacroDetail(String letter, String value, Color color) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.6),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Row(
      children: [
        Text(
          letter,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(width: 2),
        Text(
          "${value}g",
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

Widget _buildMacroCircle(String letter, double value, Color color) {
  return Column(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.1),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: letter,
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SizedBox(height: 4),
      Text(
        "${value.toStringAsFixed(0)}g",
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
    ],
  );
}

// Use this helper method for date formatting
String _formatMealDate(dynamic timestamp) {
  if (timestamp == null) return "Unknown";
  
  DateTime date;
  try {
    date = timestamp.toDate();
  } catch (e) {
    print("Error parsing date: $e");
    return "Unknown";
  }
  
  DateTime now = DateTime.now();
  DateTime yesterday = DateTime(now.year, now.month, now.day - 1);
  
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return "Today";
  } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
    return "Yesterday";
  } else {
    return DateFormat('EEEE, MMM d').format(date);
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
                    "Weekly Streak",
                    style: TextStyle(
                      fontFamily: 'Fredoka-SemiBold',
                      fontSize: 22,
                      color: Colors.black,
                    ),
                  ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                  SizedBox(height: 15),
                  _buildEnhancedStreakWidget()
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 700.ms)
                      .slideY(begin: 0.1, end: 0),

                      SizedBox(height: 30),

                  // Activity Log Header Section
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, double value, child) {
                      return Transform.translate(
                        offset: Offset(-30 * (1 - value), 0),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildActivityLogHeader(),
                  ),

                  SizedBox(height: 12),

                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (context, double value, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildActivityLogs(),
                  ),

                  SizedBox(height: 10),

                  // Meals History Section
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, double value, child) {
                      return Transform.translate(
                        offset: Offset(-30 * (1 - value), 0),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5, bottom: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Title section
                          Row(
                            children: [
                              Icon(
                                Icons.restaurant_rounded,
                                size: 22,
                                color: Color(0xffFFA500),
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Your Nutrition",
                                style: TextStyle(
                                  fontFamily: 'Fredoka-SemiBold',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          
                          // Show All Week button
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showAllMeals = !_showAllMeals;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Color(0xffFFA500).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Color(0xffFFA500).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _showAllMeals
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: Color(0xffFFA500),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    _showAllMeals ? "Hide" : "Show All Week",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xffFFA500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, double value, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildMealsHistory(),
                  ),

                  SizedBox(height: 25),

                  // Body Metrics History Section Header
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, double value, child) {
                      return Transform.translate(
                        offset: Offset(-30 * (1 - value), 0),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5, bottom: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Title section
                          Row(
                            children: [
                              Icon(
                                Icons.fitness_center_rounded,
                                size: 22,
                                color: Colors.blue[600],
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Body Metrics",
                                style: TextStyle(
                                  fontFamily: 'Fredoka-SemiBold',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          
                          // Show All Metrics button
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showAllMetrics = !_showAllMetrics;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue[500]!.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue[500]!.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _showAllMetrics
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: Colors.blue[600],
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    _showAllMetrics ? "Hide" : "Show History",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 8),

                  // Body Metrics History Content
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, double value, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildBodyMetricsHistory(),
                  ),

                  SizedBox(height: 40),

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
