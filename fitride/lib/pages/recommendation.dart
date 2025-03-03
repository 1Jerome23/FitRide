import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'goal_tracking.dart';
import 'login_register.dart';
import 'profile.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class RecommendationPage extends StatefulWidget {
  @override
  _RecommendationPageState createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  int _selectedIndex = 1;

  String? userId = FirebaseAuth.instance.currentUser?.uid;
  List<Map<String, dynamic>> recentData = [];
  List<Map<String, dynamic>> activityData = [];
  List<Map<String, dynamic>> weatherData = [];
  List<Map<String, dynamic>> nutritionData = [];

  String recommendation = "Loading...";
  String feedback = "";
  bool showAllLogs = false;

  // User goal data
  String goalType = "-";
  String currentLevel = "0";
  String daysPerWeek = "0";
  String targetDistance = "0";
  String targetWeight = "0";
  String targetDuration = "0";

  // User profile data
  int age = 0;
  String gender = "-";
  String healthCondition = "-";
  String respiratoryCondition = "No";
  String cardiovascularCondition = "No";
  String height = "0";
  String weight = "0";
  String bodyFat = "0";
  String basalMetabolicRate = "0";

  // Activity data
  String levelOfExertion = "0";
  String averageHeartrate = "0";
  String averageSpeed = "0";
  String caloriesBurned = "0";
  String distance = "0";
  String sessionDuration = "0";

  // Weather data
  String temperature = "0";
  String humidity = "0";
  String weatherCondition = "-";
  String airQuality = "Good"; // Air Quality Index category or value
  int airQualityIndex = 0; // Numerical AQI value

  // Nutrition data
  String foodIntake = "-";
  String foodType = "-";
  String caloriesConsumed = "0";

  // Training metrics
  int recommendedHeartRate = 0;
  int maxHeartRateCalculated = 0;
  int zone1HeartRate = 0;
  int zone2HeartRate = 0;
  int zone3HeartRate = 0;
  int zone4HeartRate = 0;
  int zone5HeartRate = 0;

  // Variables for comparison
  double latestWeight = 0.0;
  double previousWeight = 0.0;
  double latestBodyFat = 0.0;
  double previousBodyFat = 0.0;
  double latestDistance = 0.0;
  double previousDistance = 0.0;
  double latestCaloriesBurned = 0.0;
  double previousCaloriesBurned = 0.0;
  double latestAverageSpeed = 0.0;
  double previousAverageSpeed = 0.0;
  double latestAverageHeartrate = 0.0;
  double previousAverageHeartrate = 0.0;
  int latestAirQualityIndex = 0;
  int previousAirQualityIndex = 0;

  // Historical trend analysis
  Map<String, dynamic> trendAnalysis = {};
  bool isImprovingOverTime = false;
  bool isConsistent = false;
  int consecutiveImprovement = 0;
  int totalActivities = 0;
  double averageDistanceAllTime = 0.0;
  double averageSpeedAllTime = 0.0;
  double averageHeartrateAllTime = 0.0;
  double distanceVariability = 0.0; // Coefficient of variation
  double speedVariability = 0.0;
  double heartrateVariability = 0.0;
  double bestDistance = 0.0;
  double bestSpeed = 0.0;
  double lowestHeartRate = 0.0;
  DateTime bestPerformanceDate = DateTime.now();

  // Activity patterns with extended analysis
  DateTime lastActivityDate = DateTime.now();
  int daysSinceLastActivity = 0;
  int weeklyActivityCount = 0;
  double weeklyDistanceTotal = 0.0;
  List<int> activityGaps = []; // Days between activities
  bool hasRegularSchedule = false;
  String mostFrequentDay = "";
  List<double> distanceProgression = [];
  List<double> speedProgression = [];
  List<double> heartrateProgression = [];

  // Seasonal factors
  String seasonalAdvice = "";
  bool isIndoorSeason = false;

  // Recommendation categories
  List<String> trainingRecommendations = [];
  List<String> nutritionRecommendations = [];
  List<String> healthRecommendations = [];
  List<String> equipmentRecommendations = [];
  List<String> progressRecommendations = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (userId == null) return;

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
          goalType = goalsDoc['goalType'] ?? "-";
          if (goalType == 'Leisure') {
            daysPerWeek = goalsDoc['daysPerWeek']?.toString() ?? "0";
            sessionDuration = goalsDoc['sessionDuration']?.toString() ?? "0";
          } else if (goalType == 'High Intensity Cycling') {
            daysPerWeek = goalsDoc['daysPerWeek']?.toString() ?? "0";
            sessionDuration = goalsDoc['sessionDuration']?.toString() ?? "0";
            targetWeight = goalsDoc['targetWeight']?.toString() ?? "0";
          } else if (goalType == 'Endurance') {
            targetDistance = goalsDoc['targetDistance']?.toString() ?? "0";
            targetDuration = goalsDoc['targetDuration']?.toString() ?? "0";
          }
        });
      }

      // Fetch MORE activities data for historical analysis (increased limit from 10 to 30)
      QuerySnapshot activitiesQuery = await FirebaseFirestore.instance
          .collection('activities')
          .where('uid', isEqualTo: userId)
          .orderBy('start_date', descending: true)
          .limit(30) // Increased to get more historical data
          .get();

      if (activitiesQuery.docs.isNotEmpty) {
        List<Map<String, dynamic>> newActivityData = [];

        for (var doc in activitiesQuery.docs) {
          var data = doc.data() as Map<String, dynamic>;

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
            "uid": data['uid'],
          });
        }

        setState(() {
          activityData = newActivityData;
          totalActivities = activityData.length;

          // Calculate stats based on activity history
          if (activityData.isNotEmpty) {
            // Parse the start_date of the most recent activity
            if (activityData[0]['start_date'] != null) {
              lastActivityDate = activityData[0]['start_date'].toDate();
              daysSinceLastActivity = DateTime.now().difference(lastActivityDate).inDays;
            }

            // Count weekly activities and total distance
            weeklyActivityCount = 0;
            weeklyDistanceTotal = 0.0;
            DateTime oneWeekAgo = DateTime.now().subtract(Duration(days: 7));

            for (var activity in activityData) {
              if (activity['start_date'] != null) {
                DateTime activityDate = activity['start_date'].toDate();
                if (activityDate.isAfter(oneWeekAgo)) {
                  weeklyActivityCount++;
                  weeklyDistanceTotal += safeParseDouble(activity['distance']);
                }
              }
            }

            // Analyze historical trends
            _analyzeHistoricalTrends();
          }
        });
      } else {
        print("No documents found in activities for user $userId");
      }

      // Fetch user profile data
      QuerySnapshot userDataQuery = await FirebaseFirestore.instance
          .collection('userData')
          .where('uid', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (userDataQuery.docs.isNotEmpty) {
        DocumentSnapshot userDataDoc = userDataQuery.docs.first;
        var data = userDataDoc.data() as Map<String, dynamic>;

        setState(() {
          age = int.tryParse(data['age']?.toString() ?? '30') ?? 30;
          gender = data['gender'] ?? "-";
          healthCondition = data['healthCondition'] ?? "-";

          // Parse health conditions into specific types
          if (healthCondition.toLowerCase().contains('respiratory')) {
            respiratoryCondition = "Yes";
          }
          if (healthCondition.toLowerCase().contains('cardiovascular')) {
            cardiovascularCondition = "Yes";
          }

          height = data['height']?.toString() ?? "0";
          weight = data.containsKey('weight') ? data['weight']?.toString() ?? "0" : "0";
          bodyFat = data.containsKey('bodyFat') ? data['bodyFat']?.toString() ?? "0" : "0";
          basalMetabolicRate = data.containsKey('basalMetabolicRate')
              ? data['basalMetabolicRate']?.toString() ?? "0" : "0";

          // Calculate heart rate zones
          maxHeartRateCalculated = 220 - age;
          zone1HeartRate = (maxHeartRateCalculated * 0.6).round(); // 50-60% of max HR
          zone2HeartRate = (maxHeartRateCalculated * 0.7).round(); // 60-70% of max HR
          zone3HeartRate = (maxHeartRateCalculated * 0.8).round(); // 70-80% of max HR
          zone4HeartRate = (maxHeartRateCalculated * 0.9).round(); // 80-90% of max HR
          zone5HeartRate = (maxHeartRateCalculated * 0.95).round(); // 90-100% of max HR
          recommendedHeartRate = maxHeartRateCalculated;
        });
      }

      // Fetch after_exercise data - now with increased limit (20 instead of 10)
      if (goalType != "Leisure") {
        print("Attempting to fetch after_exercise data...");
        QuerySnapshot afterExerciseSnapshot = await FirebaseFirestore.instance
            .collection('after_exercise')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(20) // Increased for better historical analysis
            .get();

        print("Query completed. Document count: ${afterExerciseSnapshot.docs.length}");

        if (afterExerciseSnapshot.docs.isNotEmpty) {
          List<Map<String, dynamic>> newRecentData = [];

          for (var doc in afterExerciseSnapshot.docs) {
            var data = doc.data() as Map<String, dynamic>;

            newRecentData.add({
              "documentId": doc.id,
              "currentLevel": data['currentLevel'],
              "estimatedCalories": data['estimatedCalories'],
              "foodTaken": data['foodTaken'] ?? "-",
              "hydration": data['hydration'],
              "levelOfExertion": data['levelOfExertion'],
              "timestamp": data['timestamp'],
              "userId": data['userId'],
              "weight": data['weight'] ?? weight,
              "bodyFat": data['bodyFat'] ?? bodyFat,
              "sleepHours": data['sleepHours'] ?? "0",
              "recoveryScore": data['recoveryScore'] ?? "0",
            });
          }

          setState(() {
            recentData = newRecentData;
          });
          print("Recent data updated: ${recentData.length} entries");

          // Analyze body composition trends if we have enough data
          if (recentData.length >= 2) {
            _analyzeBodyCompositionTrends();
          }
        } else {
          print("No documents found in after_exercise for user $userId");
        }
      }

      // Fetch weather and air quality data
      try {
        QuerySnapshot weatherSnapshot = await FirebaseFirestore.instance
            .collection('weather')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(5) // Get more weather history
            .get();

        if (weatherSnapshot.docs.isNotEmpty) {
          List<Map<String, dynamic>> newWeatherData = [];

          for (var doc in weatherSnapshot.docs) {
            var data = doc.data() as Map<String, dynamic>;

            newWeatherData.add({
              "documentId": doc.id,
              "temperature": data['temperature'] ?? "0",
              "humidity": data['humidity'] ?? "0",
              "weatherCondition": data['weatherCondition'] ?? "-",
              "airQuality": data['airQuality'] ?? "Good",
              "airQualityIndex": data['airQualityIndex'] ?? 0,
              "timestamp": data['timestamp'],
            });
          }

          setState(() {
            weatherData = newWeatherData;
            if (weatherData.isNotEmpty) {
              temperature = weatherData[0]['temperature'].toString();
              humidity = weatherData[0]['humidity'].toString();
              weatherCondition = weatherData[0]['weatherCondition'];
              airQuality = weatherData[0]['airQuality'];
              airQualityIndex = weatherData[0]['airQualityIndex'] is int ?
              weatherData[0]['airQualityIndex'] :
              int.tryParse(weatherData[0]['airQualityIndex'].toString()) ?? 0;

              // Store for comparison if we have multiple weather entries
              latestAirQualityIndex = airQualityIndex;
              if (weatherData.length > 1) {
                previousAirQualityIndex = weatherData[1]['airQualityIndex'] is int ?
                weatherData[1]['airQualityIndex'] :
                int.tryParse(weatherData[1]['airQualityIndex'].toString()) ?? 0;
              }

              // Determine seasonal advice based on current weather
              _generateSeasonalAdvice();
            }
          });
        }
      } catch (e) {
        print("Weather data collection may not exist: $e");
      }

      // Fetch nutrition data - assuming a 'nutrition' collection exists
      try {
        QuerySnapshot nutritionSnapshot = await FirebaseFirestore.instance
            .collection('nutrition')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(7) // Get a week's worth of nutrition data
            .get();

        if (nutritionSnapshot.docs.isNotEmpty) {
          List<Map<String, dynamic>> newNutritionData = [];

          for (var doc in nutritionSnapshot.docs) {
            var data = doc.data() as Map<String, dynamic>;

            newNutritionData.add({
              "documentId": doc.id,
              "foodIntake": data['foodIntake'] ?? "-",
              "foodType": data['foodType'] ?? "-",
              "caloriesConsumed": data['caloriesConsumed'] ?? "0",
              "proteinIntake": data['proteinIntake'] ?? "0",
              "carbIntake": data['carbIntake'] ?? "0",
              "fatIntake": data['fatIntake'] ?? "0",
              "timestamp": data['timestamp'],
            });
          }

          setState(() {
            nutritionData = newNutritionData;
            if (nutritionData.isNotEmpty) {
              foodIntake = nutritionData[0]['foodIntake'];
              foodType = nutritionData[0]['foodType'];
              caloriesConsumed = nutritionData[0]['caloriesConsumed'].toString();
            }
          });
        }
      } catch (e) {
        print("Nutrition data collection may not exist: $e");
      }

      // Generate recommendations based on the fetched data
      _generateRecommendation();
    } catch (e) {
      setState(() {
        recommendation = "Error fetching data.";
      });
      print("Error fetching user data: $e");
    }
  }

  // New method to analyze historical trends across all activities
  void _analyzeHistoricalTrends() {
    if (activityData.length < 2) return;

    // Extract all values for analysis
    List<double> distances = [];
    List<double> speeds = [];
    List<double> heartRates = [];
    List<DateTime> dates = [];
    List<int> dayGaps = [];
    Map<String, int> dayFrequency = {};

    for (var activity in activityData) {
      double distance = safeParseDouble(activity['distance']);
      double speed = safeParseDouble(activity['average_speed']);
      double heartRate = safeParseDouble(activity['average_heartrate']);

      if (distance > 0) distances.add(distance);
      if (speed > 0) speeds.add(speed);
      if (heartRate > 0) heartRates.add(heartRate);

      if (activity['start_date'] != null) {
        DateTime date = activity['start_date'].toDate();
        dates.add(date);

        // Track day of week frequency
        String dayOfWeek = DateFormat('EEEE').format(date);
        dayFrequency[dayOfWeek] = (dayFrequency[dayOfWeek] ?? 0) + 1;
      }
    }

    // Sort dates and calculate gaps between activities
    if (dates.length >= 2) {
      dates.sort((a, b) => b.compareTo(a)); // Sort descending
      for (int i = 0; i < dates.length - 1; i++) {
        int gap = dates[i].difference(dates[i + 1]).inDays;
        if (gap > 0) dayGaps.add(gap);
      }
    }

    // Find most frequent day
    int maxFrequency = 0;
    dayFrequency.forEach((day, frequency) {
      if (frequency > maxFrequency) {
        maxFrequency = frequency;
        mostFrequentDay = day;
      }
    });

    // Check if schedule is regular (most activities on same day)
    hasRegularSchedule = maxFrequency > (activityData.length / 3);

    // Calculate statistical measures
    if (distances.isNotEmpty) {
      bestDistance = distances.reduce(math.max);
      averageDistanceAllTime = distances.reduce((a, b) => a + b) / distances.length;
      distanceVariability = _calculateCoeffOfVariation(distances);
      distanceProgression = distances.reversed.toList(); // Chronological order
    }

    if (speeds.isNotEmpty) {
      bestSpeed = speeds.reduce(math.max);
      averageSpeedAllTime = speeds.reduce((a, b) => a + b) / speeds.length;
      speedVariability = _calculateCoeffOfVariation(speeds);
      speedProgression = speeds.reversed.toList(); // Chronological order
    }

    if (heartRates.isNotEmpty) {
      lowestHeartRate = heartRates.reduce(math.min);
      averageHeartrateAllTime = heartRates.reduce((a, b) => a + b) / heartRates.length;
      heartrateVariability = _calculateCoeffOfVariation(heartRates);
      heartrateProgression = heartRates.reversed.toList(); // Chronological order
    }

    // Find best performance date (highest distance or speed)
    if (activityData.isNotEmpty) {
      int bestIndex = 0;
      double bestMetric = 0;

      for (int i = 0; i < activityData.length; i++) {
        double distance = safeParseDouble(activityData[i]['distance']);
        double speed = safeParseDouble(activityData[i]['average_speed']);
        double combined = distance * speed; // Simple combined metric

        if (combined > bestMetric) {
          bestMetric = combined;
          bestIndex = i;
        }
      }

      if (activityData[bestIndex]['start_date'] != null) {
        bestPerformanceDate = activityData[bestIndex]['start_date'].toDate();
      }
    }

    // Check for improvement trends
    isImprovingOverTime = _checkImprovementTrend();

    // Check consistency
    isConsistent = dayGaps.isNotEmpty &&
        _calculateCoeffOfVariation(dayGaps.map((g) => g.toDouble()).toList()) < 0.5;

    // Set the latest and previous values for basic comparison
    if (activityData.length >= 2) {
      var latestActivityData = activityData[0];
      var previousActivityData = activityData[1];

      latestDistance = safeParseDouble(latestActivityData['distance']);
      previousDistance = safeParseDouble(previousActivityData['distance']);

      latestCaloriesBurned = safeParseDouble(latestActivityData['calories_burned']);
      previousCaloriesBurned = safeParseDouble(previousActivityData['calories_burned']);

      latestAverageSpeed = safeParseDouble(latestActivityData['average_speed']);
      previousAverageSpeed = safeParseDouble(previousActivityData['average_speed']);

      latestAverageHeartrate = safeParseDouble(latestActivityData['average_heartrate']);
      previousAverageHeartrate = safeParseDouble(previousActivityData['average_heartrate']);

      // Update relevant activity metrics for recommendations
      averageHeartrate = latestActivityData['average_heartrate']?.toString() ?? "0";
      averageSpeed = latestActivityData['average_speed']?.toString() ?? "0";
      caloriesBurned = latestActivityData['calories_burned']?.toString() ?? "0";
      distance = latestActivityData['distance']?.toString() ?? "0";
      sessionDuration = latestActivityData['elapsed_time']?.toString() ?? "0";
    } else if (activityData.length == 1) {
      var latestActivityData = activityData[0];

      latestDistance = safeParseDouble(latestActivityData['distance']);
      latestCaloriesBurned = safeParseDouble(latestActivityData['calories_burned']);
      latestAverageSpeed = safeParseDouble(latestActivityData['average_speed']);
      latestAverageHeartrate = safeParseDouble(latestActivityData['average_heartrate']);

      // Update relevant activity metrics for recommendations
      averageHeartrate = latestActivityData['average_heartrate']?.toString() ?? "0";
      averageSpeed = latestActivityData['average_speed']?.toString() ?? "0";
      caloriesBurned = latestActivityData['calories_burned']?.toString() ?? "0";
      distance = latestActivityData['distance']?.toString() ?? "0";
      sessionDuration = latestActivityData['elapsed_time']?.toString() ?? "0";
    }
  }

  // Analyze body composition trends
  void _analyzeBodyCompositionTrends() {
    if (recentData.length < 2) return;

    // Extract weight and body fat data over time
    List<double> weights = [];
    List<double> bodyFats = [];

    for (var data in recentData) {
      double weight = safeParseDouble(data['weight']);
      double bodyFat = safeParseDouble(data['bodyFat']);

      if (weight > 0) weights.add(weight);
      if (bodyFat > 0) bodyFats.add(bodyFat);
    }

    // Update latest and previous values for comparison
    if (recentData.length >= 2) {
      var latestData = recentData[0];
      var previousData = recentData[1];

      latestWeight = safeParseDouble(latestData['weight']);
      previousWeight = safeParseDouble(previousData['weight']);

      latestBodyFat = safeParseDouble(latestData['bodyFat']);
      previousBodyFat = safeParseDouble(previousData['bodyFat']);

      // Update current values for recommendations
      levelOfExertion = latestData['levelOfExertion']?.toString() ?? "0";
    } else if (recentData.length == 1) {
      var latestData = recentData[0];

      latestWeight = safeParseDouble(latestData['weight']);
      latestBodyFat = safeParseDouble(latestData['bodyFat']);

      // Update current values for recommendations
      levelOfExertion = latestData['levelOfExertion']?.toString() ?? "0";
    }
  }

  // Generate seasonal advice based on current weather
  void _generateSeasonalAdvice() {
    double temp = safeParseDouble(temperature);

    // Check if it's indoor training season
    isIndoorSeason = temp < 5 || temp > 35 ||
        weatherCondition.toLowerCase().contains("rain") ||
        weatherCondition.toLowerCase().contains("snow") ||
        airQualityIndex > 150;

    if (isIndoorSeason) {
      if (temp < 5) {
        seasonalAdvice = "Cold weather season: Consider indoor training options or proper cold-weather gear.";
      } else if (temp > 35) {
        seasonalAdvice = "Hot weather season: Early morning rides or indoor training recommended to avoid heat stress.";
      } else if (weatherCondition.toLowerCase().contains("rain") ||
          weatherCondition.toLowerCase().contains("snow")) {
        seasonalAdvice = "Inclement weather: Indoor training recommended. If riding outdoors, use appropriate gear.";
      } else if (airQualityIndex > 150) {
        seasonalAdvice = "Poor air quality season: Consider indoor training to protect respiratory health.";
      }
    } else {
      seasonalAdvice = "Current weather conditions are favorable for outdoor cycling.";
    }
  }

  // Calculate coefficient of variation (statistical measure of relative variability)
  double _calculateCoeffOfVariation(List<double> values) {
    if (values.isEmpty || values.length < 2) return 0.0;

    double mean = values.reduce((a, b) => a + b) / values.length;
    num sumSquaredDiff = values.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b);
    double stdDev = math.sqrt(sumSquaredDiff / (values.length - 1));

    return mean > 0 ? stdDev / mean : 0.0;
  }

  // Check if there's a consistent improvement trend
  bool _checkImprovementTrend() {
    if (distanceProgression.length < 3) return false;

    // Count consecutive improvements
    consecutiveImprovement = 0;
    for (int i = 1; i < distanceProgression.length; i++) {
      if (distanceProgression[i] > distanceProgression[i-1]) {
        consecutiveImprovement++;
      } else {
        break; // Reset on any decline
      }
    }

    return consecutiveImprovement >= 2; // At least 3 consecutive improvements
  }

  void _generateRecommendation() {
    print("Starting recommendation generation");
    print("Goal type: $goalType");
    print("Recent data count: ${recentData.length}");
    print("Activity data count: ${activityData.length}");

    if (activityData.isEmpty) {
      setState(() {
        recommendation = "No activity data available.";
        feedback = "Please sync your Strava data or record some activities to generate recommendations.";
      });
      return;
    }

    // Clear previous recommendations
    trainingRecommendations = [];
    nutritionRecommendations = [];
    healthRecommendations = [];
    equipmentRecommendations = [];
    progressRecommendations = [];

    // Generate recommendations based on goal type
    switch (goalType) {
      case "Leisure":
        _generateLeisureRecommendations();
        break;
      case "High Intensity Cycling":
        _generateWeightManagementRecommendations();
        break;
      case "Endurance":
        _generateCyclingEnduranceRecommendations();
        break;
      default:
        setState(() {
          recommendation = "No goal type selected.";
          feedback = "Please set a goal in the app.";
        });
    }

    // Add historical trend analysis to progress recommendations
    _addHistoricalTrendRecommendations();
  }

  // Add recommendations based on historical trends
  void _addHistoricalTrendRecommendations() {
    // Only provide trend recommendations if we have enough data
    if (activityData.length < 3) return;

    // General consistency recommendations
    if (!isConsistent && activityData.length >= 5) {
      progressRecommendations.add("Your cycling schedule shows some inconsistency. Try establishing a regular weekly routine for better results.");

      if (hasRegularSchedule) {
        progressRecommendations.add("You tend to ride most frequently on $mostFrequentDay. Consider adding 1-2 more days to your weekly schedule.");
      }
    }

    // Distance progress
    if (distanceProgression.length >= 3) {
      if (isImprovingOverTime) {
        progressRecommendations.add("Great progress! You've shown consistent improvement over your last ${consecutiveImprovement + 1} rides.");
      } else if (distanceVariability > 0.3) {
        progressRecommendations.add("Your ride distances vary significantly (±${(distanceVariability * 100).toStringAsFixed(0)}%). Consider a more structured training plan.");
      }
    }

    // Speed progress
    if (speedProgression.length >= 3) {
      double recentAverage = 0;
      double earlierAverage = 0;

      // Compare recent vs earlier speeds
      if (speedProgression.length >= 6) {
        int midpoint = speedProgression.length ~/ 2;
        recentAverage = speedProgression.sublist(0, midpoint).reduce((a, b) => a + b) / midpoint;
        earlierAverage = speedProgression.sublist(midpoint).reduce((a, b) => a + b) / (speedProgression.length - midpoint);

        double percentChange = ((recentAverage - earlierAverage) / earlierAverage) * 100;

        if (percentChange > 5) {
          progressRecommendations.add("Your average speed has improved by ${percentChange.toStringAsFixed(1)}% compared to your earlier rides. Excellent progress!");
        } else if (percentChange < -5) {
          progressRecommendations.add("Your average speed has decreased by ${(-percentChange).toStringAsFixed(1)}% compared to your earlier rides. Focus on technique and interval training.");
        }
      }
    }

    // Heart rate progress
    if (heartrateProgression.length >= 3) {
      double recentAverage = 0;
      double earlierAverage = 0;

      // Compare recent vs earlier heart rates
      if (heartrateProgression.length >= 6) {
        int midpoint = heartrateProgression.length ~/ 2;
        recentAverage = heartrateProgression.sublist(0, midpoint).reduce((a, b) => a + b) / midpoint;
        earlierAverage = heartrateProgression.sublist(midpoint).reduce((a, b) => a + b) / (heartrateProgression.length - midpoint);

        double percentChange = ((recentAverage - earlierAverage) / earlierAverage) * 100;

        if (percentChange < -3 && goalType != "High Intensity Cycling") {
          progressRecommendations.add("Your average heart rate has decreased by ${(-percentChange).toStringAsFixed(1)}% while maintaining performance. This indicates improved cardiovascular efficiency!");
        }
      }
    }

    // Best performance insight
    if (bestDistance > 0 && bestSpeed > 0) {
      String formattedDate = DateFormat('MMM d, y').format(bestPerformanceDate);
      progressRecommendations.add("Your best overall performance was on $formattedDate. Analyze what made that ride successful and try to replicate those conditions.");
    }

    // Weekly volume insights
    if (weeklyDistanceTotal > 0 && activityData.length >= 3) {
      double targetWeeklyDistance = 0;

      if (goalType == "Leisure") {
        targetWeeklyDistance = safeParseDouble(daysPerWeek) * 15; // 15km per leisure ride
      } else if (goalType == "High Intensity Cycling") {
        targetWeeklyDistance = safeParseDouble(daysPerWeek) * 20; // 20km per high intensity ride
      } else if (goalType == "Endurance") {
        targetWeeklyDistance = safeParseDouble(targetDistance) * 1.5; // 1.5x target distance for training
      }

      if (targetWeeklyDistance > 0) {
        double percentOfTarget = (weeklyDistanceTotal / targetWeeklyDistance) * 100;

        if (percentOfTarget < 70) {
          progressRecommendations.add("You're currently at ${percentOfTarget.toStringAsFixed(0)}% of your ideal weekly distance. Try adding ${(targetWeeklyDistance - weeklyDistanceTotal).toStringAsFixed(0)} km to your weekly total.");
        } else if (percentOfTarget > 120) {
          progressRecommendations.add("You're exceeding your weekly distance target by ${(percentOfTarget - 100).toStringAsFixed(0)}%. Consider focusing on quality over quantity to prevent overtraining.");
        }
      }
    }

    // Add seasonal advice if applicable
    if (seasonalAdvice.isNotEmpty) {
      progressRecommendations.add(seasonalAdvice);
    }
  }

  void _generateLeisureRecommendations() {
    // Define heart rate zones for leisure cycling
    double maxHeartRate = 220 - age.toDouble();
    double targetHeartRateUpper = maxHeartRate * 0.7; // 70% of max HR for leisure
    double targetHeartRateLower = maxHeartRate * 0.5; // 50% of max HR for leisure

    // Get latest activity metrics
    double latestHeartRate = safeParseDouble(averageHeartrate);
    double latestExertion = safeParseDouble(levelOfExertion);
    double targetDaysPerWeek = safeParseDouble(daysPerWeek);

    // Primary recommendation based on heart rate zones
    if (latestHeartRate > targetHeartRateUpper && latestHeartRate > 0) {
      setState(() {
        recommendation = "⚠️ Warning";
        feedback = "Heart rate too high for leisure cycling. Aim for ${targetHeartRateLower.toInt()}-${targetHeartRateUpper.toInt()} bpm for recovery and enjoyment.";
      });
    } else if (latestHeartRate >= targetHeartRateLower &&
        latestHeartRate <= targetHeartRateUpper &&
        latestExertion <= 5 &&
        latestHeartRate > 0) {
      setState(() {
        recommendation = "✅ Good";
        feedback = "Perfect leisure zone! Your heart rate and effort level are ideal for enjoyable, recreational cycling.";
      });
    } else if (latestHeartRate < targetHeartRateLower && latestHeartRate > 0) {
      setState(() {
        recommendation = "ℹ️ Info";
        feedback = "Heart rate is on the lower side. Consider slightly increasing intensity for better cardiovascular benefits.";
      });
    } else {
      setState(() {
        recommendation = "ℹ️ Info";
        feedback = "Use a heart rate monitor for more personalized recommendations.";
      });
    }

    // Historical data insights for leisure cycling
    if (averageHeartrateAllTime > 0 && activityData.length > 3) {
      if (averageHeartrateAllTime > targetHeartRateUpper) {
        trainingRecommendations.add("Your historical average heart rate (${averageHeartrateAllTime.toInt()} bpm) is above the leisure zone. Focus on more relaxed rides.");
      }

      // Consistency recommendations based on historical data
      if (activityGaps.isNotEmpty) {
        double avgGap = activityGaps.reduce((a, b) => a + b) / activityGaps.length;
        if (avgGap > 7) {
          trainingRecommendations.add("You tend to have ${avgGap.toStringAsFixed(0)} days between rides. For leisure benefits, try riding more regularly.");
        }
      }
    }

    // Training recommendations
    if (weeklyActivityCount < targetDaysPerWeek && targetDaysPerWeek > 0) {
      trainingRecommendations.add("Try adding ${(targetDaysPerWeek - weeklyActivityCount).toInt()} more rides to meet your weekly goal.");
    }

    if (daysSinceLastActivity > 3) {
      trainingRecommendations.add("It's been ${daysSinceLastActivity} days since your last ride. Consider a short, easy ride soon.");
    }

    trainingRecommendations.add("Aim for 30-60 min rides at conversational pace.");

    if (safeParseDouble(distance) > 20) {
      trainingRecommendations.add("Try shorter routes focused on enjoyment rather than distance.");
    }

    // Weather and air quality recommendations
    if (weatherData.isNotEmpty) {
      double currentTemp = safeParseDouble(temperature);

      if (currentTemp > 30) {
        trainingRecommendations.add("High temp: Ride in early morning or evening.");
        nutritionRecommendations.add("Increase fluid intake in this heat.");
      } else if (currentTemp < 10) {
        trainingRecommendations.add("Cold temp: Extend warm-up to 10-15 minutes.");
        equipmentRecommendations.add("Dress in layers with gloves for cold weather.");
      }

      // Air quality recommendations
      if (airQualityIndex > 0) {
        if (airQualityIndex <= 50) {
          healthRecommendations.add("AQI: ${airQualityIndex} - Good air quality for riding.");
        } else if (airQualityIndex <= 100) {
          healthRecommendations.add("AQI: ${airQualityIndex} - Moderate. Most can ride without issues.");
        } else if (airQualityIndex <= 150) {
          healthRecommendations.add("AQI: ${airQualityIndex} - Unhealthy for sensitive groups. Consider indoor cycling.");
          if (respiratoryCondition == "Yes") {
            healthRecommendations.add("With respiratory condition, avoid outdoor cycling when AQI > 100.");
          }
        } else if (airQualityIndex <= 200) {
          healthRecommendations.add("AQI: ${airQualityIndex} - Unhealthy. Consider indoor cycling or wear a mask.");
        } else {
          healthRecommendations.add("AQI: ${airQualityIndex} - Very unhealthy. Indoor cycling recommended.");
        }
      }

      if (weatherCondition.toLowerCase().contains("rain")) {
        equipmentRecommendations.add("Rain expected. Use fenders and lights.");
      }
    }

    // Health condition recommendations
    if (respiratoryCondition == "Yes") {
      healthRecommendations.add("Monitor breathing with 'talk test' during rides.");
      healthRecommendations.add("Check air quality before rides (aim for AQI < 100).");
    }

    if (cardiovascularCondition == "Yes") {
      healthRecommendations.add("Stay in ${targetHeartRateLower.toInt()}-${targetHeartRateUpper.toInt()} bpm zone.");
      healthRecommendations.add("Be cautious on high AQI days due to cardiovascular stress.");
    }

    // Nutrition recommendations
    nutritionRecommendations.add("Water is sufficient for rides under 1 hour.");
    nutritionRecommendations.add("Light snack 30-60 min before riding for energy.");

    // Health recommendations
    healthRecommendations.add("Stretch after rides for flexibility.");

    // Equipment recommendations
    equipmentRecommendations.add("Ensure proper bike fit and saddle height.");
    equipmentRecommendations.add("Consider padded shorts for longer rides.");
  }

  void _generateWeightManagementRecommendations() {
    // Weight management through high intensity cycling needs specific guidelines
    double targetWeightValue = safeParseDouble(targetWeight);
    double currentWeightValue = safeParseDouble(weight);
    double bmr = safeParseDouble(basalMetabolicRate);
    double bodyFatPercentage = safeParseDouble(bodyFat);
    double totalCaloriesBurned = safeParseDouble(caloriesBurned);

    // Calculate heart rate zones for weight management
    double maxHeartRate = 220 - age.toDouble();
    double fatBurningZoneLower = maxHeartRate * 0.7; // 70% of max HR
    double fatBurningZoneUpper = maxHeartRate * 0.85; // 85% of max HR

    // Get latest values
    double latestHeartRate = safeParseDouble(averageHeartrate);

    // Primary feedback based on weight/body fat trends
    if (latestWeight < previousWeight && latestBodyFat < previousBodyFat &&
        latestWeight > 0 && previousWeight > 0 && latestBodyFat > 0 && previousBodyFat > 0) {
      setState(() {
        recommendation = "✅ Great Progress";
        feedback = "You're losing both weight and body fat! Your high-intensity cycling is working effectively.";
      });
    } else if (latestWeight < previousWeight && latestBodyFat >= previousBodyFat &&
        latestWeight > 0 && previousWeight > 0 && latestBodyFat > 0 && previousBodyFat > 0) {
      setState(() {
        recommendation = "⚠️ Mixed Results";
        feedback = "Losing weight but not body fat. Add interval training and hill climbs to your routine.";
      });
    } else if (latestWeight > previousWeight && latestBodyFat < previousBodyFat &&
        latestWeight > 0 && previousWeight > 0 && latestBodyFat > 0 && previousBodyFat > 0) {
      setState(() {
        recommendation = "✅ Gaining Muscle";
        feedback = "Gaining weight while reducing body fat suggests muscle building. Great work!";
      });
    } else if (latestWeight == previousWeight && latestBodyFat < previousBodyFat &&
        latestWeight > 0 && previousWeight > 0 && latestBodyFat > 0 && previousBodyFat > 0) {
      setState(() {
        recommendation = "✅ Body Recomposition";
        feedback = "Stable weight with reduced body fat means you're building muscle. Keep it up!";
      });
    } else if (latestWeight >= previousWeight && latestBodyFat >= previousBodyFat &&
        latestWeight > 0 && previousWeight > 0 && latestBodyFat > 0 && previousBodyFat > 0) {
      setState(() {
        recommendation = "⚠️ Needs Adjustment";
        feedback = "Adjust your training and nutrition strategy to kickstart fat loss.";
      });
    } else if (latestWeight > 0 && currentWeightValue > targetWeightValue) {
      setState(() {
        recommendation = "ℹ️ In Progress";
        feedback = "You're ${(currentWeightValue - targetWeightValue).toStringAsFixed(1)} kg from your target. Let's refine your strategy.";
      });
    } else {
      setState(() {
        recommendation = "ℹ️ Building Baseline";
        feedback = "Track metrics consistently for personalized recommendations.";
      });
    }

    // Historical heart rate analysis
    if (heartrateProgression.length >= 3) {
      double avgHistoricalHR = heartrateProgression.reduce((a, b) => a + b) / heartrateProgression.length;

      if (avgHistoricalHR < fatBurningZoneLower) {
        trainingRecommendations.add("Your historical average heart rate (${avgHistoricalHR.toInt()} bpm) is below optimal fat-burning zone. Increase intensity in future workouts.");
      } else if (avgHistoricalHR > fatBurningZoneUpper) {
        trainingRecommendations.add("Your historical heart rates average ${avgHistoricalHR.toInt()} bpm, which is quite high. Mix in some Zone 2 (${zone2HeartRate} bpm) training for recovery.");
      }
    }

    // Heart rate recommendations for current workout
    if (latestHeartRate > 0) {
      if (latestHeartRate < fatBurningZoneLower) {
        trainingRecommendations.add("Increase intensity to ${fatBurningZoneLower.toInt()}-${fatBurningZoneUpper.toInt()} bpm for optimal fat burning.");
      } else if (latestHeartRate > fatBurningZoneUpper) {
        trainingRecommendations.add("Try intervals between high intensity and recovery periods.");
      } else {
        trainingRecommendations.add("Perfect fat-burning zone! Maintain this intensity.");
      }
    }

    // Training structure based on historical data
    int totalHighIntensitySessions = 0;
    List<int> lastFiveHeartRates = [];

    // Count high intensity sessions from historical data
    for (int i = 0; i < math.min(activityData.length, 10); i++) {
      double hr = safeParseDouble(activityData[i]['average_heartrate']);
      if (hr > fatBurningZoneLower) totalHighIntensitySessions++;

      if (i < 5 && hr > 0) lastFiveHeartRates.add(hr.toInt());
    }

    if (totalHighIntensitySessions < 3 && activityData.length >= 5) {
      trainingRecommendations.add("Of your last ${math.min(activityData.length, 10)} rides, only $totalHighIntensitySessions were at high intensity. Aim for at least 3 per week for weight management.");
    }

    if (lastFiveHeartRates.length >= 3) {
      String hrTrend = lastFiveHeartRates.join(" → ");
      trainingRecommendations.add("Your recent heart rate trend (bpm): $hrTrend. Aim for consistent intensity in the fat-burning zone.");
    }

    // Standard training recommendations
    trainingRecommendations.add("Aim for 3-5 sessions/week with 4-6 intervals (2-3 min high intensity, 2-3 min recovery).");

    if (weeklyActivityCount < 3) {
      trainingRecommendations.add("Increase to at least 3 sessions per week for weight management.");
    }

    // Calorie recommendations with historical context
    if (bmr > 0 && activityData.length >= 3) {
      // Calculate average calories burned per session
      List<double> allCalories = [];
      for (var activity in activityData) {
        double cals = safeParseDouble(activity['calories_burned']);
        if (cals > 0) allCalories.add(cals);
      }

      if (allCalories.isNotEmpty) {
        double avgCaloriesPerSession = allCalories.reduce((a, b) => a + b) / allCalories.length;
        double weeklyCalorieBurn = avgCaloriesPerSession * weeklyActivityCount;
        double dailyDeficitFromExercise = weeklyCalorieBurn / 7.0;

        if (dailyDeficitFromExercise < 250) {
          trainingRecommendations.add("Your average workout burns ${avgCaloriesPerSession.toInt()} kcal. Aim for 400-500 kcal daily deficit through longer/intense rides.");
        } else if (dailyDeficitFromExercise > 1000) {
          trainingRecommendations.add("You're burning an average of ${avgCaloriesPerSession.toInt()} kcal per workout, creating a ${dailyDeficitFromExercise.toInt()} kcal daily deficit. Ensure proper fueling.");
        }
      }
    }

    // Weather and air quality
    if (weatherData.isNotEmpty) {
      double currentTemp = safeParseDouble(temperature);

      if (currentTemp > 30) {
        trainingRecommendations.add("Hot weather: Exercise early morning for better fat burning efficiency.");
        nutritionRecommendations.add("Drink 750ml-1L fluid/hour with electrolytes in hot weather.");
      }

      // Air quality for weight management
      if (airQualityIndex > 0) {
        if (airQualityIndex <= 50) {
          healthRecommendations.add("AQI: ${airQualityIndex} - Ideal for high-intensity training.");
        } else if (airQualityIndex <= 100) {
          healthRecommendations.add("AQI: ${airQualityIndex} - Monitor breathing during intervals.");
        } else if (airQualityIndex <= 150) {
          healthRecommendations.add("AQI: ${airQualityIndex} - Consider moderate-intensity instead of intervals.");
          if (respiratoryCondition == "Yes") {
            healthRecommendations.add("With respiratory condition, train indoors when AQI > 100.");
          }
        } else {
          healthRecommendations.add("AQI: ${airQualityIndex} - Switch to indoor cycling for today.");
        }
      }
    }

    // Health condition recommendations
    if (respiratoryCondition == "Yes") {
      healthRecommendations.add("Use shorter intervals (30s-1min) with longer recovery periods.");
    }

    if (cardiovascularCondition == "Yes") {
      healthRecommendations.add("Focus on moderate intensity (60-70% max HR) for longer durations.");
    }

    // Nutrition recommendations
    nutritionRecommendations.add("Try fasted morning rides (30-45 min) at moderate intensity.");
    nutritionRecommendations.add("Stay well-hydrated for metabolism and recovery.");
    nutritionRecommendations.add("Time carbs around workouts - more on training days, less on rest days.");

    // Health recommendations
    healthRecommendations.add("Include 2 rest days weekly to prevent hormonal imbalances.");
    healthRecommendations.add("Aim for 7-9 hours sleep to regulate hunger hormones.");

    // Equipment recommendations
    equipmentRecommendations.add("Ensure proper bike fit to prevent injury during hard efforts.");
    equipmentRecommendations.add("Use a heart rate monitor for optimal fat-burning zone training.");
  }

  void _generateCyclingEnduranceRecommendations() {
    // Basic data
    double targetDistanceValue = safeParseDouble(targetDistance);
    double currentDistanceValue = safeParseDouble(distance);
    double targetDurationValue = safeParseDouble(targetDuration);
    double currentDurationValue = safeParseDouble(sessionDuration) / 60; // Convert to minutes

    // Heart rate zones
    double maxHeartRate = 220 - age.toDouble();
    double enduranceZoneLower = maxHeartRate * 0.65; // 65% of max HR
    double enduranceZoneUpper = maxHeartRate * 0.75; // 75% of max HR
    double thresholdZoneLower = maxHeartRate * 0.76; // 76% of max HR
    double thresholdZoneUpper = maxHeartRate * 0.90; // 90% of max HR

    // Latest HR
    double latestHeartRate = safeParseDouble(averageHeartrate);

    // Primary feedback based on recent activities
    if (latestDistance > previousDistance && latestDistance > 0 && previousDistance > 0) {
      setState(() {
        recommendation = "✅ Distance Improving";
        feedback = "Great progress! Your distance increased from ${previousDistance.toStringAsFixed(1)} km to ${latestDistance.toStringAsFixed(1)} km.";
      });
    } else if (latestAverageSpeed > previousAverageSpeed && latestAverageSpeed > 0 && previousAverageSpeed > 0) {
      setState(() {
        recommendation = "✅ Speed Improving";
        feedback = "Your speed increased while maintaining distance. Cycling efficiency is improving!";
      });
    } else if (latestAverageHeartrate < previousAverageHeartrate &&
        latestDistance >= previousDistance &&
        latestAverageHeartrate > 0 && previousAverageHeartrate > 0) {
      setState(() {
        recommendation = "✅ Efficiency Improving";
        feedback = "Lower heart rate at same/higher distance shows improved cardiovascular efficiency!";
      });
    } else if (latestDistance < previousDistance && latestDistance > 0 && previousDistance > 0) {
      setState(() {
        recommendation = "⚠️ Distance Decreasing";
        feedback = "Recent ride was shorter than previous. Focus on recovery before next endurance effort.";
      });
    } else if (latestAverageSpeed < previousAverageSpeed && latestAverageSpeed > 0 && previousAverageSpeed > 0) {
      setState(() {
        recommendation = "⚠️ Speed Decreasing";
        feedback = "Average speed dropped. Work on consistent pacing during long rides.";
      });
    } else if (latestDistance > 0 && currentDistanceValue < targetDistanceValue) {
      setState(() {
        recommendation = "ℹ️ Building Endurance";
        feedback = "Currently at ${currentDistanceValue.toStringAsFixed(1)} km toward ${targetDistanceValue.toStringAsFixed(1)} km goal.";
      });
    } else {
      setState(() {
        recommendation = "ℹ️ Establishing Baseline";
        feedback = "Track rides consistently for personalized endurance recommendations.";
      });
    }

    // Historical distance progression analysis
    if (distanceProgression.length >= 5) {
      // Calculate the long-term trend
      double oldestAvg = 0;
      double newestAvg = 0;

      int midpoint = distanceProgression.length ~/ 2;
      if (midpoint > 1) {
        oldestAvg = distanceProgression.sublist(midpoint).reduce((a, b) => a + b) / (distanceProgression.length - midpoint);
        newestAvg = distanceProgression.sublist(0, midpoint).reduce((a, b) => a + b) / midpoint;

        double improvementPercent = ((newestAvg - oldestAvg) / oldestAvg) * 100;

        if (improvementPercent > 10) {
          trainingRecommendations.add("Your endurance has improved ${improvementPercent.toStringAsFixed(0)}% compared to your earlier rides. Excellent progression!");
        } else if (improvementPercent < -10) {
          trainingRecommendations.add("Your recent distances are ${(-improvementPercent).toStringAsFixed(0)}% shorter than your earlier rides. Consider adjusting your training load.");
        } else {
          trainingRecommendations.add("Your distance progression is stable. To continue improving, try gradually increasing your longest ride each week.");
        }
      }

      // Find longest ride ever
      double longestRide = distanceProgression.reduce(math.max);
      if (longestRide > 0 && targetDistanceValue > 0) {
        double percentOfTarget = (longestRide / targetDistanceValue) * 100;
        trainingRecommendations.add("Your longest ride to date (${longestRide.toStringAsFixed(1)} km) is ${percentOfTarget.toStringAsFixed(0)}% of your target distance.");
      }
    }

    // Heart rate zone analysis from historical data
    if (heartrateProgression.length >= 3) {
      int enduranceZoneCount = 0;
      int aboveThresholdCount = 0;

      for (double hr in heartrateProgression) {
        if (hr >= enduranceZoneLower && hr <= enduranceZoneUpper) {
          enduranceZoneCount++;
        } else if (hr > thresholdZoneUpper) {
          aboveThresholdCount++;
        }
      }

      double endurancePercent = (enduranceZoneCount / heartrateProgression.length) * 100;
      double thresholdPercent = (aboveThresholdCount / heartrateProgression.length) * 100;

      if (endurancePercent < 60 && thresholdPercent > 30) {
        trainingRecommendations.add("${thresholdPercent.toStringAsFixed(0)}% of your rides are above threshold zone. For endurance, focus more on Zone 2 (${enduranceZoneLower.toInt()}-${enduranceZoneUpper.toInt()} bpm).");
      }
    }

    // Current heart rate recommendations
    if (latestHeartRate > 0) {
      if (latestHeartRate > thresholdZoneUpper) {
        trainingRecommendations.add("Heart rate too high for endurance. Stay within ${enduranceZoneLower.toInt()}-${enduranceZoneUpper.toInt()} bpm range.");
      } else if (latestHeartRate < enduranceZoneLower) {
        trainingRecommendations.add("Increase intensity to ${enduranceZoneLower.toInt()}-${enduranceZoneUpper.toInt()} bpm for aerobic development.");
      } else if (latestHeartRate >= enduranceZoneLower && latestHeartRate <= enduranceZoneUpper) {
        trainingRecommendations.add("Perfect endurance zone! Great for building aerobic capacity.");
      } else {
        trainingRecommendations.add("You're in threshold zone - good for tempo sessions but not longer rides.");
      }
    }

    // Training structure
    trainingRecommendations.add("Follow 80/20 rule: 80% low intensity, 20% higher intensity rides.");

    // Distance progression
    if (currentDistanceValue > 0 && targetDistanceValue > 0 && currentDistanceValue < targetDistanceValue) {
      double percentComplete = (currentDistanceValue / targetDistanceValue) * 100;
      double weeklyIncrease = targetDistanceValue * 0.1;

      trainingRecommendations.add("You're ${percentComplete.toStringAsFixed(0)}% to goal. Increase long ride by ~${weeklyIncrease.toStringAsFixed(1)} km/week.");
    }

    if (weeklyActivityCount < 3) {
      trainingRecommendations.add("Aim for 3-4 rides/week: one long, 2-3 shorter recovery rides.");
    }

    // Specific training strategies
    trainingRecommendations.add("Include one 'tempo' ride weekly at ${thresholdZoneLower.toInt()}-${thresholdZoneUpper.toInt()} bpm.");

    // Weather and air quality
    if (weatherData.isNotEmpty) {
      double currentTemp = safeParseDouble(temperature);

      if (currentTemp > 30) {
        trainingRecommendations.add("Hot weather: Lower heart rate target by 5-10% and hydrate more.");
        nutritionRecommendations.add("In heat, increase electrolyte intake to prevent cramping.");
      }

      // Air quality for endurance
      if (airQualityIndex > 0) {
        if (airQualityIndex <= 50) {
          healthRecommendations.add("AQI: ${airQualityIndex} - Excellent for long endurance rides.");
        } else if (airQualityIndex <= 100) {
          healthRecommendations.add("AQI: ${airQualityIndex} - Suitable for training. Shorten very long rides if uncomfortable.");
        } else if (airQualityIndex <= 150) {
          healthRecommendations.add("AQI: ${airQualityIndex} - Consider shorter rides or indoor training.");

          if (targetDistanceValue > 80) {
            trainingRecommendations.add("With AQI > 100, do shorter rides or train indoors.");
          }
        } else {
          healthRecommendations.add("AQI: ${airQualityIndex} - Switch to indoor training today.");
        }

        // Air quality improvement/deterioration
        if (previousAirQualityIndex > 0 && latestAirQualityIndex < previousAirQualityIndex && latestAirQualityIndex < 100) {
          healthRecommendations.add("Air quality improved - good day for a longer session.");
        } else if (previousAirQualityIndex > 0 && latestAirQualityIndex > previousAirQualityIndex && latestAirQualityIndex > 100) {
          healthRecommendations.add("Air quality worsened - adjust training plan accordingly.");
        }
      }
    }

    // Health condition recommendations
    if (respiratoryCondition == "Yes") {
      healthRecommendations.add("With respiratory condition, build endurance gradually (max 10%/week).");
      healthRecommendations.add("Only ride outdoors when AQI < 100, preferably < 50.");
    }

    if (cardiovascularCondition == "Yes") {
      healthRecommendations.add("Focus on Zone 2 (${enduranceZoneLower.toInt()}-${enduranceZoneUpper.toInt()} bpm) for cardiovascular efficiency.");
      healthRecommendations.add("Be extra cautious when AQI > 100 with your condition.");
    }

    // Nutrition recommendations
    nutritionRecommendations.add("Rides < 90 mins: water only. Longer rides: 30-60g carbs/hour.");
    nutritionRecommendations.add("Practice nutrition strategy during training for events.");
    nutritionRecommendations.add("Start fueling early - within first 30 minutes of long rides.");

    if (currentDurationValue > 120) {
      nutritionRecommendations.add("For ${currentDurationValue.toStringAsFixed(0)}-minute rides: ${(currentDurationValue * 0.5).toStringAsFixed(0)}g carbs + electrolytes.");
    }

    // Health recommendations
    healthRecommendations.add("Balance training stress with recovery between sessions.");
    healthRecommendations.add("Post-ride: 3:1 carb:protein ratio within 30 minutes.");

    if (daysSinceLastActivity < 1 && weeklyActivityCount > 5) {
      healthRecommendations.add("Add dedicated recovery days to prevent overtraining.");
    }

    // Equipment recommendations
    equipmentRecommendations.add("Bike fit is crucial for endurance - small discomforts become major on long rides.");
    equipmentRecommendations.add("Quality padded shorts and chamois cream for rides > 2 hours.");

    if (airQualityIndex > 100) {
      equipmentRecommendations.add("Consider pollution mask if outdoor training is necessary in poor air quality.");
    }
  }

  double safeParseDouble(dynamic value) {
    if (value == null || value == "-") return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recommendations Title
            Text(
              "Personalized Recommendations",
              style: GoogleFonts.roboto(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 6),
            Text(
              "Based on your ${goalType.toLowerCase()} cycling goals",
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 16),

            // Primary Recommendation Container
            Container(
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
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation,
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _getRecommendationColor(recommendation),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    feedback,
                    style: GoogleFonts.lato(fontSize: 16, color: Colors.black),
                  ),

                  // Activity history summary
                  if (activityData.length >= 3) ...[
                    SizedBox(height: 16),
                    Divider(),
                    SizedBox(height: 8),
                    Text(
                      "Based on ${activityData.length} activities over ${_calculateActivitySpan()} days",
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 24),

            // Recommendation Categories Carousel
            _buildRecommendationCarousel(),

            SizedBox(height: 24),

            // Recent Activity Logs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent Activity Log",
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                if (activityData.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showAllLogs = !showAllLogs;
                      });
                    },
                    child: Text(
                      showAllLogs ? "Hide" : "View All",
                      style: GoogleFonts.lato(fontSize: 16, color: Colors.orange),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            if (activityData.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: showAllLogs ? activityData.length : 1,
                itemBuilder: (context, index) {
                  var data = activityData[index];
                  // Format the start date
                  String formattedDate = "N/A";
                  if (data['start_date'] != null) {
                    DateTime startDate = data['start_date'].toDate();
                    formattedDate = DateFormat('MMM d, y • h:mm a').format(startDate);
                  }

                  // Convert elapsed time to hours:minutes format
                  String duration = "N/A";
                  int elapsedSeconds = 0;
                  if (data['elapsed_time'] != null) {
                    elapsedSeconds = int.tryParse(data['elapsed_time'].toString()) ?? 0;
                    int hours = elapsedSeconds ~/ 3600;
                    int minutes = (elapsedSeconds % 3600) ~/ 60;
                    duration = hours > 0
                        ? "${hours}h ${minutes}m"
                        : "${minutes}m";
                  }

                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Activity name and date
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name'] ?? "Cycling Activity",
                                    style: GoogleFonts.roboto(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: GoogleFonts.lato(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                data['type'] ?? "Ride",
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Activity metrics in grid
                        Row(
                          children: [
                            _buildActivityMetric(
                              "Distance",
                              "${safeParseDouble(data['distance']).toStringAsFixed(1)} km",
                              Icons.straighten_outlined,
                            ),
                            _buildActivityMetric(
                              "Duration",
                              duration,
                              Icons.timer_outlined,
                            ),
                            _buildActivityMetric(
                              "Avg Speed",
                              "${safeParseDouble(data['average_speed']).toStringAsFixed(1)} km/h",
                              Icons.speed_outlined,
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            _buildActivityMetric(
                              "Heart Rate",
                              "${safeParseDouble(data['average_heartrate']).toInt()} bpm",
                              Icons.favorite_border_outlined,
                            ),
                            _buildActivityMetric(
                              "Calories",
                              "${safeParseDouble(data['calories_burned']).toInt()} kcal",
                              Icons.local_fire_department_outlined,
                            ),
                            _buildActivityMetric(
                              "Air Quality",
                              airQualityIndex > 0 ? "AQI: ${airQualityIndex}" : "N/A",
                              Icons.air_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (activityData.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600]),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "No activity data found. Connect your Strava account or log your rides manually to get personalized recommendations.",
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
      ),
    );
  }

  // Calculate how many days the activity data spans
  String _calculateActivitySpan() {
    if (activityData.length < 2) return "0";

    DateTime oldest = DateTime.now();
    DateTime newest = DateTime.now().subtract(Duration(days: 365));

    for (var activity in activityData) {
      if (activity['start_date'] != null) {
        DateTime date = activity['start_date'].toDate();
        if (date.isBefore(oldest)) oldest = date;
        if (date.isAfter(newest)) newest = date;
      }
    }

    int days = newest.difference(oldest).inDays;
    return days.toString();
  }

  // Create an active page indicator for the carousel
  Widget _buildRecommendationCarousel() {
    // Create list of recommendation categories with their data
    List<Map<String, dynamic>> recommendationCategories = [];

    if (trainingRecommendations.isNotEmpty) {
      recommendationCategories.add({
        "title": "Training Tips",
        "icon": Icons.directions_bike_outlined,
        "color": Colors.blue[700]!,
        "recommendations": trainingRecommendations,
      });
    }

    if (nutritionRecommendations.isNotEmpty) {
      recommendationCategories.add({
        "title": "Nutrition & Hydration",
        "icon": Icons.restaurant_outlined,
        "color": Colors.green[700]!,
        "recommendations": nutritionRecommendations,
      });
    }

    if (healthRecommendations.isNotEmpty) {
      recommendationCategories.add({
        "title": "Health & Recovery",
        "icon": Icons.favorite_outline,
        "color": Colors.purple[700]!,
        "recommendations": healthRecommendations,
      });
    }

    if (equipmentRecommendations.isNotEmpty) {
      recommendationCategories.add({
        "title": "Equipment & Gear",
        "icon": Icons.handyman_outlined,
        "color": Colors.orange[700]!,
        "recommendations": equipmentRecommendations,
      });
    }

    // Add Progress Insights category if available
    if (progressRecommendations.isNotEmpty) {
      recommendationCategories.add({
        "title": "Progress Insights",
        "icon": Icons.insights_outlined,
        "color": Colors.teal[700]!,
        "recommendations": progressRecommendations,
      });
    }

    // If no recommendations are available
    if (recommendationCategories.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600]),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Track more cycling activities to receive personalized recommendations.",
                style: GoogleFonts.lato(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Current page value
    int currentPage = 0;

    // Create a PageController for the carousel
    PageController pageController = PageController(
      initialPage: 0,
      viewportFraction: 0.9, // Slightly increase view fraction to reduce clipping
    );

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          children: [
            Container(
              height: 280, // Fixed height for carousel
              child: PageView.builder(
                controller: pageController,
                itemCount: recommendationCategories.length,
                itemBuilder: (context, index) {
                  var category = recommendationCategories[index];
                  return _buildRecommendationCard(
                    category["title"],
                    category["icon"],
                    category["color"],
                    category["recommendations"],
                  );
                },
                onPageChanged: (index) {
                  setState(() {
                    currentPage = index;
                  });
                },
              ),
            ),
            SizedBox(height: 12),
            // Page indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                recommendationCategories.length,
                    (index) => Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentPage == index ? recommendationCategories[index]["color"] : Colors.grey[300],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Build improved recommendation card with scrollable content
  Widget _buildRecommendationCard(String title, IconData icon, Color color, List<String> recommendations) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title - fixed height
          Container(
            padding: EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: color.withOpacity(0.2),
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),

          // Recommendation content - scrollable section
          Expanded(
            child: ListView.builder(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: 10),
              itemCount: recommendations.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recommendations[index],
                          style: GoogleFonts.lato(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Scroll indicator
          Container(
            alignment: Alignment.center,
            padding: EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                SizedBox(width: 2),
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRecommendationColor(String recommendation) {
    if (recommendation.contains("✅") || recommendation.contains("Good") || recommendation.contains("Improving") || recommendation.contains("Progress")) {
      return Colors.green[700]!;
    } else if (recommendation.contains("⚠️") || recommendation.contains("Warning") || recommendation.contains("Needs") || recommendation.contains("Decreasing")) {
      return Colors.orange[700]!;
    } else if (recommendation.contains("❌") || recommendation.contains("Bad")) {
      return Colors.red[700]!;
    } else if (recommendation.contains("ℹ️") || recommendation.contains("Info") || recommendation.contains("Building") || recommendation.contains("In Progress")) {
      return Colors.blue[700]!;
    } else {
      return Colors.black;
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

  void _logout() {
    FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }
}