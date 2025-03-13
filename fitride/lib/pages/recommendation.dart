import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'home_page.dart';
import 'goal_tracking.dart';
import 'login_register.dart';
import 'profile.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class PieEfficiencyData {
  final String sessionLabel;
  final double efficiency;
  final bool isBest;
  
  PieEfficiencyData(this.sessionLabel, this.efficiency, this.isBest);
}

class PaceCaloriesData {
  final DateTime date;
  final double pace;      // in minutes per kilometer
  final double calories;  // calories burned
  final String activityName;

  PaceCaloriesData(this.date, this.pace, this.calories, this.activityName);
}

class WeightCalorieData {
  final DateTime date;
  final double weight;
  final double netCalories;

  WeightCalorieData(this.date, this.weight, this.netCalories);
}
class BaselineComparisonData {
  final String metric;
  final double baselineValue;
  final double currentValue;
  final double changePercent;

  BaselineComparisonData(
      this.metric, this.baselineValue, this.currentValue, this.changePercent);
}

class ActivityData {
  final String month;
  final double distance;

  ActivityData(this.month, this.distance);
}

class MetricData {
  final String date;
  final double value;

  MetricData(this.date, this.value);
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

class RecommendationPage extends StatefulWidget {
  @override
  _RecommendationPageState createState() => _RecommendationPageState();
}
class TemperatureActivityData {
  final double temperature;
  final double speed;      // km/h
  final double distance;   // km
  final double duration;   // minutes
  final DateTime date;

  TemperatureActivityData(
      this.temperature, this.speed, this.distance, this.duration, this.date);
}
class ErrorBoundary extends StatelessWidget {
  final Widget child;

  const ErrorBoundary({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext context) {
        try {
          // Attempt to build the child
          return child;
        } catch (e, stackTrace) {
          // Log the error
          print('Error in graph rendering: $e\n$stackTrace');

          // Return a fallback widget
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.orange[300],
                  size: 40,
                ),
                SizedBox(height: 8),
                Text(
                  'Could not display this chart',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

class _RecommendationPageState extends State<RecommendationPage> {
  int _selectedIndex = 1;

  String? userId = FirebaseAuth.instance.currentUser?.uid;
  List<Map<String, dynamic>> recentData = [];
  List<Map<String, dynamic>> activityData = [];
  List<Map<String, dynamic>> weatherData = [];
  List<Map<String, dynamic>> nutritionData = [];
  // Baseline comparison data
  Map<String, dynamic> baselineComparison = {};
  bool hasActiveSubgoal = false;
  String subgoalType = ""; // "distance", "pace", "duration", or "maintain"
  double subgoalTargetValue = 0.0;
  DateTime subgoalStartDate = DateTime.now();
  DateTime subgoalEndDate = DateTime.now().add(Duration(days: 7));
  List<String> subgoalSuggestions = [];
  List<String> subgoalWarnings = [];

  double baselineDistance = 0.0;
  double baselinePace = 0.0; 
  double baselineDuration = 0.0; 

  String recommendation = "Loading...";
  String feedback = "";
  bool showAllLogs = false;

  PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoadingGraphs = true;
  String? _stravaUserId;
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

  // Historical trend analysis
  Map<String, dynamic> trendAnalysis = {};
  bool isImprovingOverTime = false;
  bool isConsistent = false;
  int consecutiveImprovement = 0;
  int totalActivities = 0;
  double averageDistanceAllTime = 0.0;
  double averageSpeedAllTime = 0.0;
  double averageHeartrateAllTime = 0.0;
  double distanceVariability = 0.0; 
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
  List<int> activityGaps = []; 
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  // Helper method to calculate the weekly calories consumed
double _calculateWeeklyCaloriesConsumed() {
  if (nutritionData.isEmpty) return 0.0;
  
  double weeklyCalories = 0.0;
  
  // Sum up calories from all food diary entries in the nutritionData list
  for (var entry in nutritionData) {
    double dailyCalories = safeParseDouble(entry['total_calories']);
    weeklyCalories += dailyCalories;
  }
  
  return weeklyCalories;
}

Future<Map<String, dynamic>> _fetchWeightAndCalorieData() async {
  if (userId == null) return {'correlationData': <WeightCalorieData>[], 'correlationCoefficient': 0.0};
  
  try {
    // Fetch weight data
    QuerySnapshot weightSnapshot = await FirebaseFirestore.instance
        .collection('userData')
        .where('uid', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(14) // Last 2 weeks of data
        .get();
    
    // Fetch food entries for calorie consumed data
    QuerySnapshot foodSnapshot = await FirebaseFirestore.instance
        .collection('food_entries')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(14) // Last 2 weeks of data
        .get();
    
    // Fetch activity data for calories burned
    QuerySnapshot activitySnapshot = await FirebaseFirestore.instance
        .collection('activities')
        .where('uid', isEqualTo: userId)
        .orderBy('start_date', descending: true)
        .limit(30) // More activities to ensure we cover the date range
        .get();
    
    // Process weight data
    Map<String, double> weightByDate = {};
    for (var doc in weightSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      double weight = safeParseDouble(data['weight']);
      
      if (weight > 0 && data['timestamp'] != null) {
        DateTime date = data['timestamp'].toDate();
        // Convert to date-only key (no time component)
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        weightByDate[dateKey] = weight;
      }
    }
    
    // Process food data to get calories consumed by date
    Map<String, double> caloriesConsumedByDate = {};
    for (var doc in foodSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      double calories = safeParseDouble(data['total_calories']);
      
      if (calories > 0 && data['date'] != null) {
        DateTime date = data['date'].toDate();
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        caloriesConsumedByDate[dateKey] = calories;
      }
    }
    
    // Process activity data to get calories burned by date
    Map<String, double> caloriesBurnedByDate = {};
    for (var doc in activitySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      double calories = safeParseDouble(data['calories_burned']);
      
      if (calories > 0 && data['start_date'] != null) {
        DateTime date = data['start_date'].toDate();
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        // Sum up multiple activities on the same day
        caloriesBurnedByDate[dateKey] = (caloriesBurnedByDate[dateKey] ?? 0) + calories;
      }
    }
    
    // Create correlated data points where we have both weight and calorie data
    List<WeightCalorieData> correlationData = [];
    Set<String> allDates = {...weightByDate.keys, ...caloriesConsumedByDate.keys, ...caloriesBurnedByDate.keys};
    
    // Sort dates chronologically
    List<String> sortedDates = allDates.toList()..sort();
    
    for (String dateKey in sortedDates) {
      // We need at least weight data for the correlation
      if (weightByDate.containsKey(dateKey)) {
        double weight = weightByDate[dateKey]!;
        double caloriesConsumed = caloriesConsumedByDate[dateKey] ?? 0;
        double caloriesBurned = caloriesBurnedByDate[dateKey] ?? 0;
        double netCalories = caloriesConsumed - caloriesBurned;
        
        DateTime date = DateFormat('yyyy-MM-dd').parse(dateKey);
        correlationData.add(WeightCalorieData(date, weight, netCalories));
      }
    }
    
    // Calculate the correlation coefficient between weight and net calories
    double correlationCoefficient = 0.0;
    
    if (correlationData.length >= 3) {
      List<double> weights = correlationData.map((e) => e.weight).toList();
      List<double> netCalories = correlationData.map((e) => e.netCalories).toList();
      
      correlationCoefficient = _calculatePearsonCorrelation(weights, netCalories);
    }
    
    return {
      'correlationData': correlationData,
      'correlationCoefficient': correlationCoefficient,
    };
  } catch (e) {
    print("Error fetching correlation data: $e");
    return {'correlationData': <WeightCalorieData>[], 'correlationCoefficient': 0.0};
  }
}

// Helper method to calculate Pearson correlation coefficient
double _calculatePearsonCorrelation(List<double> x, List<double> y) {
  if (x.length != y.length || x.isEmpty) return 0.0;
  
  // Calculate means
  double xMean = x.reduce((a, b) => a + b) / x.length;
  double yMean = y.reduce((a, b) => a + b) / y.length;
  
  // Calculate numerator and denominators
  double numerator = 0;
  double xDenominator = 0;
  double yDenominator = 0;
  
  for (int i = 0; i < x.length; i++) {
    double xDiff = x[i] - xMean;
    double yDiff = y[i] - yMean;
    numerator += xDiff * yDiff;
    xDenominator += xDiff * xDiff;
    yDenominator += yDiff * yDiff;
  }
  
  // Prevent division by zero
  if (xDenominator == 0 || yDenominator == 0) return 0.0;
  
  return numerator / (math.sqrt(xDenominator) * math.sqrt(yDenominator));
}

// Helper method to calculate the weekly calories burned from actual activity data
double _calculateWeeklyCaloriesBurned() {
  if (activityData.isEmpty) return 0.0;
  
  double weeklyCalories = 0.0;
  DateTime oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
  
  // Sum up calories from all activities in the past week
  for (var activity in activityData) {
    if (activity['start_date'] != null) {
      DateTime activityDate = activity['start_date'].toDate();
      if (activityDate.isAfter(oneWeekAgo)) {
        double caloriesBurned = safeParseDouble(activity['calories_burned']);
        weeklyCalories += caloriesBurned;
      }
    }
  }
  
  return weeklyCalories;
}
// Method to fetch active subgoal when loading the page
Future<void> _fetchActiveSubgoal() async {
  if (userId == null) return;
  
  try {
    QuerySnapshot subgoalQuery = await FirebaseFirestore.instance
        .collection('cycling_subgoals')
        .where('userId', isEqualTo: userId)
        .where('endDate', isGreaterThan: DateTime.now())
        .orderBy('endDate', descending: false)
        .limit(1)
        .get();
    
    if (subgoalQuery.docs.isNotEmpty) {
      DocumentSnapshot subgoalDoc = subgoalQuery.docs.first;
      var data = subgoalDoc.data() as Map<String, dynamic>;
      
      setState(() {
        hasActiveSubgoal = true; 
        subgoalType = data['subgoalType'];
        subgoalTargetValue = data['targetValue'];
        subgoalStartDate = data['startDate'].toDate();
        subgoalEndDate = data['endDate'].toDate();
        
        if (data.containsKey('suggestions')) {
          subgoalSuggestions = List<String>.from(data['suggestions']);
        }
        
        if (data.containsKey('warnings')) {
          subgoalWarnings = List<String>.from(data['warnings']);
        }
      });
      print("Active subgoal found and loaded: $subgoalType");
    } else {
      setState(() {
        hasActiveSubgoal = false;
      });
      print("No active subgoal found");
    }
  } catch (e) {
    print("Error fetching active subgoal: $e");
  }
}

// Method to set a new cycling subgoal
void _setCyclingSubgoal(String type, double targetValue) {
  if (baselineDistance == 0.0) {
    _calculateBaselines();
  }
  
  String title = "";
  List<String> suggestions = [];
  List<String> warnings = [];
  
  switch (type) {
    case "distance":
      title = "Increase cycling distance to ${targetValue.toStringAsFixed(1)} km";
      
      // Generate suggestions
      suggestions.add("Start with a proper warm-up to prepare for the longer distance");
      suggestions.add("Increase your hydration for longer rides");
      suggestions.add("Plan a route with the target distance in advance");
      
      // Check if it's a big jump and add warnings if needed
      if (targetValue > baselineDistance * 1.3 && baselineDistance > 0) {
        warnings.add("This is a ${((targetValue/baselineDistance - 1) * 100).toStringAsFixed(0)}% increase from your average. Consider a more gradual progression.");
      }
      
      if (respiratoryCondition == "Yes" && targetValue > baselineDistance * 1.2) {
        warnings.add("With your respiratory condition, consider a more moderate increase in distance.");
      }
      break;
      
    case "pace":
      // For pace, a lower number is better (faster)
      double currentPaceMinPerKm = baselinePace;
      title = "Improve cycling pace to ${targetValue.toStringAsFixed(1)} min/km";
      
      suggestions.add("Include interval training in your routine");
      suggestions.add("Focus on consistent pedaling cadence");
      suggestions.add("Make sure your bike is properly maintained for optimal efficiency");
      
      if (currentPaceMinPerKm > 0 && targetValue < currentPaceMinPerKm * 0.8) {
        warnings.add("This is a ${((1 - targetValue/currentPaceMinPerKm) * 100).toStringAsFixed(0)}% speed increase, which may be challenging. Consider a gradual approach.");
      }
      
      if (cardiovascularCondition == "Yes") {
        warnings.add("With your cardiovascular condition, consult a healthcare provider before significantly increasing intensity.");
      }
      break;
      
    case "duration":
      title = "Extend cycling duration to ${targetValue.toStringAsFixed(0)} minutes";
      
      suggestions.add("Build endurance with a steady pace");
      suggestions.add("Ensure proper nutrition before longer sessions");
      suggestions.add("Take small breaks if needed during the extended ride");
      
      if (targetValue > baselineDuration * 1.5 && baselineDuration > 0) {
        warnings.add("This is a ${((targetValue/baselineDuration - 1) * 100).toStringAsFixed(0)}% increase in duration, which may lead to fatigue. Consider a more gradual approach.");
      }
      
      break;
      
    case "maintain":
      title = "Maintain current cycling performance";
      
      suggestions.add("Focus on consistency in your current routine");
      suggestions.add("Work on technique refinement");
      suggestions.add("Use this period to establish a sustainable rhythm");
      break;
  }
  
  setState(() {
    hasActiveSubgoal = true;
    subgoalType = type;
    subgoalTargetValue = targetValue;
    subgoalStartDate = DateTime.now();
    subgoalEndDate = DateTime.now().add(Duration(days: 7));
    subgoalSuggestions = suggestions;
    subgoalWarnings = warnings;
  });
  
  _saveCyclingSubgoalToFirestore(type, targetValue, suggestions, warnings);
}
Future<void> _fetchFoodDiaryData() async {
  if (userId == null) return;
  
  try {
    // Get the current date (without time)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final oneWeekAgo = today.subtract(Duration(days: 7));
    
    QuerySnapshot foodEntrySnapshot = await FirebaseFirestore.instance
        .collection('food_entries')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(oneWeekAgo))
        .orderBy('date', descending: true)
        .limit(7) // Get a week's worth of food data
        .get();

    if (foodEntrySnapshot.docs.isNotEmpty) {
      List<Map<String, dynamic>> newNutritionData = [];

      for (var doc in foodEntrySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        
        newNutritionData.add({
          "documentId": doc.id,
          "breakfast": data['breakfast'] ?? "-",
          "lunch": data['lunch'] ?? "-",
          "dinner": data['dinner'] ?? "-",
          "breakfast_calories": data['breakfast_calories'] ?? 0,
          "lunch_calories": data['lunch_calories'] ?? 0,
          "dinner_calories": data['dinner_calories'] ?? 0,
          "total_calories": data['total_calories'] ?? 0,
          "date": data['date'],
          "timestamp": data['timestamp'],
        });
      }

      setState(() {
        nutritionData = newNutritionData;
        if (nutritionData.isNotEmpty) {
          foodIntake = "${nutritionData[0]['breakfast']}, ${nutritionData[0]['lunch']}, ${nutritionData[0]['dinner']}";
          caloriesConsumed = nutritionData[0]['total_calories'].toString();
          print('Calories Consumed: $caloriesConsumed');
        }
      });
    }
  } catch (e) {
    print("Error fetching food diary data: $e");
  }
}

void _generateNutritionRecommendationsFromFoodDiary() {
  nutritionRecommendations.clear();
  
  if (nutritionData.isEmpty) {
    nutritionRecommendations.add("Complete your food diary to get personalized nutrition recommendations.");
    return;
  }
  
  var latestFoodEntry = nutritionData[0];
  double totalCalories = safeParseDouble(latestFoodEntry['total_calories'].toString());
  double breakfastCalories = safeParseDouble(latestFoodEntry['breakfast_calories'].toString());
  double lunchCalories = safeParseDouble(latestFoodEntry['lunch_calories'].toString());
  double dinnerCalories = safeParseDouble(latestFoodEntry['dinner_calories'].toString());
  
  double bmr = safeParseDouble(basalMetabolicRate);
  double activityFactor = 1.2;
  if (goalType == "Leisure") {
    activityFactor = 1.375; 
  } else if (goalType == "Endurance") {
    activityFactor = 1.55; 
  } else if (goalType == "High Intensity Cycling") {
    activityFactor = 1.725; 
  }
  
  double dailyCalorieNeeds = bmr * activityFactor;
  
  if (totalCalories < dailyCalorieNeeds * 0.7) {
    nutritionRecommendations.add("Your calorie intake is significantly below your estimated needs (${dailyCalorieNeeds.toInt()} kcal). Consider increasing your intake for optimal performance.");
  } else if (totalCalories > dailyCalorieNeeds * 1.2 && goalType == "High Intensity Cycling") {
    nutritionRecommendations.add("Your calorie intake exceeds your calculated needs by ${(totalCalories - dailyCalorieNeeds).toInt()} kcal. Adjust portion sizes to align with your weight management goals.");
  }
  
  double breakfastPercent = totalCalories > 0 ? (breakfastCalories / totalCalories) * 100 : 0;
  double lunchPercent = totalCalories > 0 ? (lunchCalories / totalCalories) * 100 : 0;
  double dinnerPercent = totalCalories > 0 ? (dinnerCalories / totalCalories) * 100 : 0;
  
  if (breakfastPercent < 20 && totalCalories > 0) {
    nutritionRecommendations.add("Your breakfast (${breakfastPercent.toInt()}% of daily calories) is smaller than recommended. Aim for 20-25% of daily calories at breakfast for sustained energy.");
  }
  
  if (goalType == "Endurance") {
    nutritionRecommendations.add("For endurance training, include a balanced lunch with lean protein, complex carbs, and healthy fats. Good options include whole grain sandwiches with lean protein, pasta with vegetables, or grain bowls.");
    nutritionRecommendations.add("If cycling in the afternoon, have a lunch rich in complex carbs 2-3 hours before your ride, and include easily digestible foods.");
  } else if (goalType == "High Intensity Cycling") {
    nutritionRecommendations.add("For high-intensity training, your lunch should include quality protein (chicken, fish, tofu, legumes) paired with complex carbs and plenty of vegetables.");
    nutritionRecommendations.add("If training within 2 hours after lunch, keep the meal lighter and focus on easily digestible carbs with moderate protein.");
  } else if (goalType == "Leisure") {
    nutritionRecommendations.add("For leisure cycling, focus on balanced lunches with colorful vegetables, lean proteins, and whole grains. This supports general health and provides steady energy for casual rides.");
  }
  if (goalType == "Endurance") {
    nutritionRecommendations.add("For endurance training, focus on complex carbs (50-60% of calories) like whole grains, fruits, and starchy vegetables.");
    
    if (activityData.isNotEmpty) {
      nutritionRecommendations.add("For rides longer than 90 minutes, consume 30-60g carbs/hour during your ride.");
    }
  } else if (goalType == "High Intensity Cycling") {
    nutritionRecommendations.add("For high-intensity training, include adequate protein (1.2-1.6g per kg of body weight) to support muscle recovery.");
    nutritionRecommendations.add("Timing matters: consume carbs and protein within 30 minutes after intense sessions.");
  } else if (goalType == "Leisure") {
    nutritionRecommendations.add("For leisure cycling, maintain balanced nutrition with plenty of fruits and vegetables (5+ servings/day).");
  }
  
  nutritionRecommendations.add("Remember to stay well-hydrated with 2-3 liters of water daily, plus additional 500-750ml per hour of cycling.");
}

void _saveCyclingSubgoalToFirestore(String type, double targetValue, List<String> suggestions, List<String> warnings) {
  try {
    FirebaseFirestore.instance.collection('cycling_subgoals').add({
      'userId': userId,
      'subgoalType': type,
      'targetValue': targetValue, 
      'baselineDistance': baselineDistance, 
      'baselinePace': baselinePace,
      'baselineDuration': baselineDuration,
      'suggestions': suggestions,
      'warnings': warnings,
      'startDate': subgoalStartDate,
      'endDate': subgoalEndDate,
      'createdAt': DateTime.now(),
      'isWeeklyAverage': true,
    });
  } catch (e) {
    print("Error saving cycling subgoal: $e");
  }
}
Widget _buildTemperatureCyclingCorrelationGraph() {
  return FutureBuilder<Map<String, dynamic>>(
    future: _fetchTemperatureCyclingData(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildLoadingGraph();
      }

      if (snapshot.hasError || !snapshot.hasData) {
        return _buildEmptyGraph("Error loading temperature and activity data");
      }

      var correlationData = snapshot.data!;
      List<TemperatureActivityData> data = correlationData['temperatureActivityData'] ?? [];
      
      if (data.isEmpty) {
        return _buildEmptyGraph("No matching temperature and activity data found");
      }

      if (data.length > 7) {
        data = data.sublist(data.length - 7);
      }

      List<String> sessionDates = [];

      for (var item in data) {
        sessionDates.add(DateFormat('MM/dd').format(item.date));
      }

      // Convert sessionDates to DateTime objects for sorting
      List<DateTime> parsedDates = sessionDates.map((date) => DateFormat('MM/dd').parse(date)).toList();

      // Sort the dates in ascending order (oldest to latest)
      parsedDates.sort((a, b) => a.compareTo(b));

      // Convert the sorted DateTime objects back to strings
      sessionDates = parsedDates.map((date) => DateFormat('MM/dd').format(date)).toList();
      double tempSpeedCorrelation = 0.0;
      double tempDistanceCorrelation = 0.0;
      double tempDurationCorrelation = 0.0;
      
      if (data.length > 2) {
        List<double> temps = [];
        List<double> speeds = [];
        List<double> distances = [];
        List<double> durations = [];
        
        for (var item in data) {
          temps.add(item.temperature);
          speeds.add(item.speed);
          distances.add(item.distance);
          durations.add(item.duration);
        }
        
        tempSpeedCorrelation = _calculatePearsonCorrelation(temps, speeds);
        tempDistanceCorrelation = _calculatePearsonCorrelation(temps, distances);
        tempDurationCorrelation = _calculatePearsonCorrelation(temps, durations);
      }

      double maxSpeed = 0, maxDistance = 0, maxDuration = 0;
      for (var item in data) {
        if (item.speed > maxSpeed) maxSpeed = item.speed;
        if (item.distance > maxDistance) maxDistance = item.distance;
        if (item.duration > maxDuration) maxDuration = item.duration;
      }

      return _buildGraphContainer(
        title: "Temperature\n Analysis",
        subtitle: "Weather impact on cycling",
        height: 2000,
        child: Column(
          children: [
            // Main chart section
            Expanded(
              child: SfCartesianChart(
                margin: EdgeInsets.all(10),
                primaryXAxis: CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: Colors.grey[700],
                  ),
                  labelRotation: 0,
                  title: AxisTitle(
                    text: 'Date',
                    textStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                primaryYAxis: NumericAxis(
                  name: 'Temperature',
                  labelFormat: '{value}°C',
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: Colors.red[600],
                  ),
                  majorGridLines: MajorGridLines(
                    width: 0.5,
                    color: Colors.grey[200],
                    dashArray: <double>[3, 3],
                  ),
                  title: AxisTitle(
                    text: 'Temperature (°C)',
                    textStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.red[600],
                    ),
                  ),
                ),
                axes: <ChartAxis>[
                  NumericAxis(
                    name: 'Speed',
                    opposedPosition: true,
                    labelFormat: '{value} km/h',
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: Colors.blue[700],
                    ),
                    majorGridLines: MajorGridLines(width: 0),
                    title: AxisTitle(
                      text: 'Speed',
                      textStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  NumericAxis(
                    name: 'Distance',
                    opposedPosition: true,
                    labelFormat: '{value} km',
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 0,  
                      color: Colors.green[700],
                    ),
                    majorGridLines: MajorGridLines(width: 0),
                    minimum: 0,
                    maximum: maxDistance * 1.1,
                    axisLine: AxisLine(width: 0),
                  ),
                  NumericAxis(
                    name: 'Duration',
                    opposedPosition: true,
                    labelFormat: '{value} min',
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 0,  
                      color: Colors.purple[700],
                    ),
                    majorGridLines: MajorGridLines(width: 0),
                    minimum: 0,
                    maximum: maxDuration * 1.1,
                    axisLine: AxisLine(width: 0),
                  ),
                ],
                series: <ChartSeries>[
                  ColumnSeries<TemperatureActivityData, String>(
                    name: 'Temperature (°C)',
                    dataSource: data,
                    xValueMapper: (TemperatureActivityData data, index) => sessionDates[index],
                    yValueMapper: (TemperatureActivityData data, _) => data.temperature,
                    width: 0.6,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                    gradient: LinearGradient(
                      colors: [
                        Colors.red[300]!,
                        Colors.red[500]!,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    dataLabelSettings: DataLabelSettings(
                      isVisible: false,
                      labelAlignment: ChartDataLabelAlignment.top,
                      textStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  SplineSeries<TemperatureActivityData, String>(
                    name: 'Speed (km/h)',
                    dataSource: data,
                    xValueMapper: (TemperatureActivityData data, index) => sessionDates[index],
                    yValueMapper: (TemperatureActivityData data, _) => data.speed,
                    yAxisName: 'Speed',
                    color: Colors.blue[600],
                    width: 2,
                    markerSettings: MarkerSettings(
                      isVisible: true,
                      shape: DataMarkerType.circle,
                      width: 2,
                      height: 2,
                      borderWidth: 2,
                      borderColor: Colors.blue[800],
                    ),
                    dataLabelSettings: DataLabelSettings(
                      isVisible: false,
                      labelAlignment: ChartDataLabelAlignment.top,
                      textStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Colors.blue[800],
                      ),
                    ),
                  ),
                  
                  SplineSeries<TemperatureActivityData, String>(
                    name: 'Distance (km)',
                    dataSource: data,
                    xValueMapper: (TemperatureActivityData data, index) => sessionDates[index],
                    yValueMapper: (TemperatureActivityData data, _) => data.distance,
                    yAxisName: 'Distance',
                    color: Colors.green[600],
                    width: 2,
                    markerSettings: MarkerSettings(
                      isVisible: true,
                      shape: DataMarkerType.diamond,
                      width: 2,
                      height: 2,
                      borderWidth: 2,
                      borderColor: Colors.green[800],
                    ),
                    dataLabelSettings: DataLabelSettings(
                      isVisible: false,
                      labelAlignment: ChartDataLabelAlignment.top,
                      textStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Colors.green[800],
                      ),
                    ),
                  ),
                  
                  SplineSeries<TemperatureActivityData, String>(
                    name: 'Duration (min)',
                    dataSource: data,
                    xValueMapper: (TemperatureActivityData data, index) => sessionDates[index],
                    yValueMapper: (TemperatureActivityData data, _) => data.duration,
                    yAxisName: 'Duration',
                    color: Colors.purple[600],
                    width: 2,
                    markerSettings: MarkerSettings(
                      isVisible: true,
                      shape: DataMarkerType.triangle,
                      width: 2,
                      height: 2,
                      borderWidth: 2,
                      borderColor: Colors.purple[800],
                    ),
                    dataLabelSettings: DataLabelSettings(
                      isVisible: false,
                      labelAlignment: ChartDataLabelAlignment.top,
                      textStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Colors.purple[800],
                      ),
                    ),
                  ),
                ],
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  color: Colors.grey[800],
                  textStyle: TextStyle(color: Colors.white, fontSize: 12),
                ),
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap,
                  textStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Colors.grey[800],
                  ),
                  iconHeight: 14,
                  iconWidth: 14,
                ),
              ),
            ),
            
            Container(
              margin: EdgeInsets.fromLTRB(12, 4, 12, 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.insights_rounded,
                    color: Colors.blue[700],
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTemperatureInsightText(tempSpeedCorrelation, tempDistanceCorrelation, tempDurationCorrelation),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: Colors.grey[800],
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          ],
        ),
      );
    },
  );
}
// Helper method to create a correlation strength indicator
String _getTemperatureInsightText(double speedCorr, double distanceCorr, double durationCorr) {
  String insight = "";
  
  // Determine strongest correlation
  if (speedCorr.abs() >= distanceCorr.abs() && speedCorr.abs() >= durationCorr.abs() && speedCorr.abs() > 0.3) {
    insight = speedCorr > 0 
        ? "Your cycling speed tends to increase in warmer weather." 
        : "Your cycling speed tends to be faster in cooler weather.";
  } 
  else if (distanceCorr.abs() >= speedCorr.abs() && distanceCorr.abs() >= durationCorr.abs() && distanceCorr.abs() > 0.3) {
    insight = distanceCorr > 0 
        ? "You tend to ride longer distances in warmer weather." 
        : "You tend to ride longer distances in cooler weather.";
  }
  else if (durationCorr.abs() > 0.3) {
    insight = durationCorr > 0 
        ? "Your rides tend to last longer in warmer weather." 
        : "Your rides tend to be shorter in warmer weather.";
  }
  else {
    insight = "Temperature has minimal effect on your cycling performance.";
  }
  
  return insight;
}
// Method to fetch temperature and activity data
Future<Map<String, dynamic>> _fetchTemperatureCyclingData() async {
  if (userId == null) return {'temperatureActivityData': []};

  try {
    // Fetch activities for the user
    QuerySnapshot activitySnapshot = await FirebaseFirestore.instance
        .collection('activities')
        .where('uid', isEqualTo: userId)
        .orderBy('start_date', descending: true)
        .limit(20)
        .get();

    // Fetch weather data for the user
    QuerySnapshot weatherSnapshot = await FirebaseFirestore.instance
        .collection('weatherData')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(30)
        .get();

    // Organize weather data by date for easy lookup
    Map<String, double> weatherByDate = {};
    for (var doc in weatherSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['timestamp'] != null && data['temperature'] != null) {
        DateTime date = data['timestamp'].toDate();
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        double temperature = safeParseDouble(data['temperature']);
        weatherByDate[dateKey] = temperature;
      }
    }

    // Create correlation data points
    List<TemperatureActivityData> temperatureActivityData = [];
    for (var doc in activitySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      
      if (data['start_date'] != null) {
        DateTime activityDate = data['start_date'].toDate();
        String dateKey = DateFormat('yyyy-MM-dd').format(activityDate);
        
        if (weatherByDate.containsKey(dateKey)) {
          double temperature = weatherByDate[dateKey]!;
          double speed = safeParseDouble(data['average_speed']);
          double distance = safeParseDouble(data['distance']);
          double durationSeconds = safeParseDouble(data['elapsed_time']);
          double durationMinutes = durationSeconds / 60.0;
          
          if (temperature > -50 && temperature < 50 && speed > 0) {
            temperatureActivityData.add(
              TemperatureActivityData(
                temperature,
                speed,
                distance,
                durationMinutes,
                activityDate
              )
            );
          }
        }
      }
    }

    return {'temperatureActivityData': temperatureActivityData};
  } catch (e) {
    print("Error fetching temperature-activity data: $e");
    return {'temperatureActivityData': []};
  }
}
// Widget to display subgoal selection options
// Modify the _buildSubgoalSelectionCard() method to check if the user has completed their weekly commitment:

Widget _buildSubgoalSelectionCard() {
  if (hasActiveSubgoal || goalType != "High Intensity Cycling") return SizedBox.shrink();
  
  int targetDaysPerWeek = int.tryParse(daysPerWeek) ?? 0;
  
  bool hasCompletedWeeklyCommitment = weeklyActivityCount >= targetDaysPerWeek;
  
  if (!hasCompletedWeeklyCommitment || targetDaysPerWeek == 0) {
    return Container(
      margin: EdgeInsets.only(top: 20, bottom: 20),
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
          Text(
            "Weekly Goal Progress",
            style: TextStyle(
              fontFamily: 'Fredoka-SemiBold',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          
          // Progress information
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions_bike_outlined, color: Colors.blue[700], size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$weeklyActivityCount of $targetDaysPerWeek weekly sessions completed",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Complete your weekly commitment to unlock next week's goals",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 8,
                    width: targetDaysPerWeek > 0 
                        ? MediaQuery.of(context).size.width * 0.8 * (weeklyActivityCount / targetDaysPerWeek)
                        : 0,
                    decoration: BoxDecoration(
                      color: Colors.blue[500],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Current: $weeklyActivityCount sessions",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    "Target: $targetDaysPerWeek sessions",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Motivation message
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[100]!, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 20, color: Colors.orange[700]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Complete ${targetDaysPerWeek - weeklyActivityCount} more cycling ${(targetDaysPerWeek - weeklyActivityCount) == 1 ? 'session' : 'sessions'} this week to unlock personalized goals for next week.",
                    style: TextStyle(fontSize: 14, color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  if (baselineDistance == 0.0) {
    _calculateBaselines();
  }
  
  if (activityData.isEmpty || weeklyActivityCount < 2) {
    return Container(
      margin: EdgeInsets.only(top: 20, bottom: 20),
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
          Text(
            "Weekly Goal Completed!",
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline, color: Colors.green[700], size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You've completed your weekly commitment!",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "We need more activity data to suggest your next weekly average goal. Keep cycling!",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  double distanceOption1 = math.max(baselineDistance * 1.1, baselineDistance + 1).roundToDouble(); 
  double distanceOption2 = math.max(baselineDistance * 1.2, baselineDistance + 2).roundToDouble(); 
  
  double paceOption1 = baselinePace > 0 ? math.max(baselinePace * 0.95, baselinePace - 0.5) : 0;
  double paceOption2 = baselinePace > 0 ? math.max(baselinePace * 0.9, baselinePace - 1) : 0;
  
  double durationOption1 = math.max(baselineDuration * 1.1, baselineDuration + 10).roundToDouble(); 
  double durationOption2 = math.max(baselineDuration * 1.2, baselineDuration + 15).roundToDouble(); 
  
  return Container(
    margin: EdgeInsets.only(top: 20, bottom: 20),
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
          Expanded(
            child: 
              Text(
              "Set Your Next Week's Goal!",
              style: GoogleFonts.fredoka(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
        SizedBox(height: 8),
        Text(
          "Set a goal for your weekly average cycling metrics based on your data from this week.",
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        SizedBox(height: 16),
        
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[100]!, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your Current Weekly Averages:",
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800]
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        "${baselineDistance.toStringAsFixed(1)} km",
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87
                        ),
                      ),
                      Text(
                        "Distance",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700]
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        "${baselinePace > 0 ? baselinePace.toStringAsFixed(1) : '-'} min/km",
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87
                        ),
                      ),
                      Text(
                        "Pace",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700]
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        "${baselineDuration.toStringAsFixed(0)} min",
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87
                        ),
                      ),
                      Text(
                        "Duration",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700]
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 4),
              Center(
                child: Text(
                  "Based on your ${weeklyActivityCount} activities this week",
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700]
                  ),
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // Distance option
        _buildSubgoalOptionTitle("Weekly Average Distance", Icons.straighten_outlined),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSubgoalOptionButton(
                "Moderate",
                "${distanceOption1.toStringAsFixed(1)} km/ride",
                "From ${baselineDistance.toStringAsFixed(1)} km avg",
                Colors.blue[700]!,
                "distance",  // Add type parameter
                distanceOption1  // Add targetValue parameter
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildSubgoalOptionButton(
                "Challenging",
                "${distanceOption2.toStringAsFixed(1)} km/ride",
                "From ${baselineDistance.toStringAsFixed(1)} km avg",
                Colors.blue[900]!,
                "distance",  // Add type parameter
                distanceOption2  // Add targetValue parameter
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16),
        
        if (baselinePace > 0) ...[
          _buildSubgoalOptionTitle("Weekly Average Pace", Icons.speed_outlined),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSubgoalOptionButton(
                  "Moderate",
                  "${paceOption1.toStringAsFixed(1)} min/km",
                  "From ${baselinePace.toStringAsFixed(1)} min/km avg",
                  Colors.orange[700]!,
                  "pace",  // Add type parameter
                  paceOption1  // Add targetValue parameter
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildSubgoalOptionButton(
                  "Challenging",
                  "${paceOption2.toStringAsFixed(1)} min/km",
                  "From ${baselinePace.toStringAsFixed(1)} min/km avg",
                  Colors.orange[900]!,
                  "pace",  // Add type parameter
                  paceOption2  // Add targetValue parameter
                ),
              ),
            ],
          ),
        ],
        
        SizedBox(height: 16),
        
        _buildSubgoalOptionTitle("Weekly Average Duration", Icons.timer_outlined),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSubgoalOptionButton(
                "Moderate",
                "${durationOption1.toStringAsFixed(0)} min/ride",
                "From ${baselineDuration.toStringAsFixed(0)} min avg",
                Colors.green[700]!,
                "duration", 
                durationOption1  
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildSubgoalOptionButton(
                "Challenging",
                "${durationOption2.toStringAsFixed(0)} min/ride",
                "From ${baselineDuration.toStringAsFixed(0)} min avg",
                Colors.green[900]!,
                "duration",  // Add type parameter
                durationOption2  // Add targetValue parameter
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16),
        
        _buildSubgoalOptionTitle("Maintain Current Level", Icons.equalizer_outlined),
        SizedBox(height: 8),
        InkWell(
        onTap: () => _showSubgoalConfirmationDialog("maintain", 0),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.grey[700], size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Maintain Weekly Averages",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Focus on consistency and technique",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
        
        SizedBox(height: 16),
        
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[700]),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Goals are based on your weekly average per ride, not individual activities. Progress will be measured across all your rides next week.",
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _showSubgoalConfirmationDialog(String type, double targetValue) {
  // Format the goal text based on type
  String goalText = "";
  switch (type) {
    case "distance":
      goalText = "increase your weekly average distance to ${targetValue.toStringAsFixed(1)} km";
      break;
    case "pace":
      goalText = "improve your weekly average pace to ${targetValue.toStringAsFixed(1)} min/km";
      break;
    case "duration":
      goalText = "extend your weekly average duration to ${targetValue.toStringAsFixed(0)} minutes";
      break;
    case "maintain":
      goalText = "maintain your current cycling performance levels";
      break;
  }

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "Confirm Your Goal",
          style: TextStyle(
            fontFamily: 'Fredoka-SemiBold',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Are you sure you want to $goalText for the next week?",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xffFFA500).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0xffFFA500).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xffFFA500),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      "This goal will be used to track your progress for the next 7 days.",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(
              "Cancel",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xffFFA500), Color(0xffFF8C00)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              child: Text(
                "Confirm",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _setCyclingSubgoal(type, targetValue);
              },
            ),
          ),
        ],
      );
    },
  );
}

void _calculateBaselines() {
  if (activityData.isEmpty) return;
  
  List<double> distances = [];
  List<double> durations = [];
  List<double> paces = [];
  
  // Get activities from the past week
  DateTime oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
  List<Map<String, dynamic>> thisWeeksActivities = [];
  
  for (var activity in activityData) {
    if (activity['start_date'] != null) {
      DateTime activityDate = activity['start_date'].toDate();
      if (activityDate.isAfter(oneWeekAgo)) {
        thisWeeksActivities.add(activity);
      }
    }
  }
  
  if (thisWeeksActivities.isEmpty) {
    // Get last 5 activities or fewer if less data is available
    int count = math.min(activityData.length, 5);
    thisWeeksActivities = activityData.sublist(0, count);
  }
  
  for (var activity in thisWeeksActivities) {
    double distance = safeParseDouble(activity['distance']);
    double durationSeconds = safeParseDouble(activity['elapsed_time']);
    double durationMinutes = durationSeconds / 60.0;
    
    if (distance > 0) distances.add(distance);
    if (durationMinutes > 0) durations.add(durationMinutes);
    
    if (distance > 0 && durationMinutes > 0) {
      double pace = durationMinutes / distance;
      paces.add(pace);
    }
  }
  
  if (distances.isNotEmpty) {
    baselineDistance = distances.reduce((a, b) => a + b) / distances.length;
  }
  
  if (durations.isNotEmpty) {
    baselineDuration = durations.reduce((a, b) => a + b) / durations.length;
  }
  
  if (paces.isNotEmpty) {
    baselinePace = paces.reduce((a, b) => a + b) / paces.length;
  }
}

Widget _buildSubgoalOptionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[800]),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Fredoka-SemiBold',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildSubgoalOptionButton(
    String title, 
    String value, 
    String baseline, 
    Color color, 
    String type,
    double targetValue 
  ) {
    return InkWell(
      onTap: () => _showSubgoalConfirmationDialog(type, targetValue), 
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Fredoka-SemiBold',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              baseline,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchUserData() async {
    if (userId == null) return;

    setState(() {
      _isLoadingGraphs = true;
    });

    try {
      // Fetch the most recent document from goals collection
      QuerySnapshot goalsQuery = await FirebaseFirestore.instance
          .collection('goals')
          .where('uid', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      DateTime? currentGoalTimestamp;

      if (goalsQuery.docs.isNotEmpty) {
        DocumentSnapshot goalsDoc = goalsQuery.docs.first;
        if (goalsDoc['timestamp'] != null) {
          currentGoalTimestamp = goalsDoc['timestamp'].toDate();
        }
        print("Current goal timestamp: $currentGoalTimestamp");

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
      // Load Strava ID
      try {
        FirebaseAuth auth = FirebaseAuth.instance;
        User? user = auth.currentUser;

        if (user != null) {
          QuerySnapshot athleteSnapshot = await FirebaseFirestore.instance
              .collection('athletes')
              .where("app_id", isEqualTo: user.uid)
              .limit(1)
              .get();

          if (athleteSnapshot.docs.isNotEmpty) {
            String stravaUserIdString = athleteSnapshot.docs.first.id;

            setState(() {
              _stravaUserId = stravaUserIdString;
            });
          }
        }
      } catch (e) {
        print("Error fetching Strava User ID: $e");
      }

      QuerySnapshot activitiesQuery = await FirebaseFirestore.instance
          .collection('activities')
          .where('uid', isEqualTo: userId)
          .where('start_date', isGreaterThanOrEqualTo: currentGoalTimestamp)
          .orderBy('start_date', descending: true)
          .limit(30) 
          .get();

      if (activitiesQuery.docs.isNotEmpty) {
        List<Map<String, dynamic>> newActivityData = [];

        for (var doc in activitiesQuery.docs) {
          var data = doc.data() as Map<String, dynamic>;

          newActivityData.add({
            "documentId": doc.id,
            "average_heartrate": data['average_heartrate'],
            "average_speed": data['average_speed'],
            "calories_burned": data['calories_burned'],
            "distance": data['distance'],
            "elapsed_time": data['elapsed_time'],
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
              daysSinceLastActivity =
                  DateTime.now().difference(lastActivityDate).inDays;
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
          healthCondition = data['healthCondition'] ?? "-";

          // Parse health conditions into specific types
          if (healthCondition.toLowerCase().contains('respiratory')) {
            respiratoryCondition = "Yes";
          }
          if (healthCondition.toLowerCase().contains('cardiovascular')) {
            cardiovascularCondition = "Yes";
          }

          height = data['height']?.toString() ?? "0";
          weight = data.containsKey('weight')
              ? data['weight']?.toString() ?? "0"
              : "0";
          bodyFat = data.containsKey('bodyFat')
              ? data['bodyFat']?.toString() ?? "0"
              : "0";
          basalMetabolicRate = data.containsKey('basalMetabolicRate')
              ? data['basalMetabolicRate']?.toString() ?? "0"
              : "0";

          // Calculate heart rate zones
          maxHeartRateCalculated = 220 - age;
          zone1HeartRate =
              (maxHeartRateCalculated * 0.6).round(); // 50-60% of max HR
          zone2HeartRate =
              (maxHeartRateCalculated * 0.7).round(); // 60-70% of max HR
          zone3HeartRate =
              (maxHeartRateCalculated * 0.8).round(); // 70-80% of max HR
          zone4HeartRate =
              (maxHeartRateCalculated * 0.9).round(); // 80-90% of max HR
          zone5HeartRate =
              (maxHeartRateCalculated * 0.95).round(); // 90-100% of max HR
          recommendedHeartRate = maxHeartRateCalculated;
        });
      }

      // Fetch after_exercise data - now with increased limit (20 instead of 10)
      if (goalType != "Leisure") {
        print("Attempting to fetch user data...");
        QuerySnapshot afterExerciseSnapshot = await FirebaseFirestore.instance
            .collection('userData')
            .where('uid', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();

        print(
            "Query completed. Document count: ${afterExerciseSnapshot.docs.length}");

        if (afterExerciseSnapshot.docs.isNotEmpty) {
          List<Map<String, dynamic>> newRecentData = [];

          for (var doc in afterExerciseSnapshot.docs) {
            var data = doc.data() as Map<String, dynamic>;

            newRecentData.add({
              "timestamp": data['timestamp'],
              "userId": data['userId'],
              "weight": data['weight'] ?? weight,
              "bodyFat": data['bodyFat'] ?? bodyFat,
              "basalMetabolicRate": data['basalMetabolicRate'] ?? basalMetabolicRate,
              "gender": data['gender'] ?? gender,
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
            .collection('weatherData')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(5) 
            .get();

        if (weatherSnapshot.docs.isNotEmpty) {
          List<Map<String, dynamic>> newWeatherData = [];

          for (var doc in weatherSnapshot.docs) {
            var data = doc.data() as Map<String, dynamic>;

            newWeatherData.add({
              "documentId": doc.id,
              "temperature": data['temperature'] ?? "0",
              "humidity": data['humidity'] ?? "0",
              "airQuality": data['airQuality'] ?? "Good",
              "timestamp": data['timestamp'],
            });
          }

          setState(() {
            weatherData = newWeatherData;
            if (weatherData.isNotEmpty) {
              temperature = weatherData[0]['temperature'].toString();
              humidity = weatherData[0]['humidity'].toString();
              airQuality = weatherData[0]['airQuality'];

              _generateSeasonalAdvice();
            }
          });
        }
      } catch (e) {
        print("Weather data collection may not exist: $e");
      }
      try {
        QuerySnapshot nutritionSnapshot = await FirebaseFirestore.instance
            .collection('food_entries')
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
              "breakfast_calories": data['breakfast_calories'] ?? "-",
              "lunch_calories": data['lunch_calories'] ?? "-",
              "dinner_calories": data['dinner_calories'] ?? "0",
              "total_calories": data['total_calories'] ?? "0",
              "timestamp": data['timestamp'],
            });
              }
            }
          } catch (e) {
            print("Nutrition data collection may not exist: $e");
          }
          await _fetchFoodDiaryData();
          // Generate recommendations based on the fetched data
          _generateRecommendation();
          if (goalType == "High Intensity Cycling") {
            _calculateBaselines(); 
            await _fetchActiveSubgoal(); 
          }
          setState(() {
            _isLoadingGraphs = false;
          });
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  // New method to analyze historical trends across all activities
  void _analyzeHistoricalTrends() {
    if (activityData.length < 2) return;

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
      dates.sort((a, b) => b.compareTo(a)); 
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
      averageDistanceAllTime =
          distances.reduce((a, b) => a + b) / distances.length;
      distanceVariability = _calculateCoeffOfVariation(distances);
      distanceProgression = distances.reversed.toList();
    }

    if (speeds.isNotEmpty) {
      bestSpeed = speeds.reduce(math.max);
      averageSpeedAllTime = speeds.reduce((a, b) => a + b) / speeds.length;
      speedVariability = _calculateCoeffOfVariation(speeds);
      speedProgression = speeds.reversed.toList();
    }

    if (heartRates.isNotEmpty) {
      lowestHeartRate = heartRates.reduce(math.min);
      averageHeartrateAllTime =
          heartRates.reduce((a, b) => a + b) / heartRates.length;
      heartrateVariability = _calculateCoeffOfVariation(heartRates);
      heartrateProgression =
          heartRates.reversed.toList(); 
    }

    // Find best performance date (highest distance or speed)
    if (activityData.isNotEmpty) {
      int bestIndex = 0;
      double bestMetric = 0;

      for (int i = 0; i < activityData.length; i++) {
        double distance = safeParseDouble(activityData[i]['distance']);
        double speed = safeParseDouble(activityData[i]['average_speed']);
        double combined = distance * speed; 

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

    isConsistent = dayGaps.isNotEmpty &&
        _calculateCoeffOfVariation(dayGaps.map((g) => g.toDouble()).toList()) <
            0.5;

    // Set the latest and previous values for basic comparison
    if (activityData.length >= 2) {
      var latestActivityData = activityData[0];
      var previousActivityData = activityData[1];

      latestDistance = safeParseDouble(latestActivityData['distance']);
      previousDistance = safeParseDouble(previousActivityData['distance']);

      latestCaloriesBurned =
          safeParseDouble(latestActivityData['calories_burned']);
      previousCaloriesBurned =
          safeParseDouble(previousActivityData['calories_burned']);

      latestAverageSpeed = safeParseDouble(latestActivityData['average_speed']);
      previousAverageSpeed =
          safeParseDouble(previousActivityData['average_speed']);

      latestAverageHeartrate =
          safeParseDouble(latestActivityData['average_heartrate']);
      previousAverageHeartrate =
          safeParseDouble(previousActivityData['average_heartrate']);

      // Update relevant activity metrics for recommendations
      averageHeartrate =
          latestActivityData['average_heartrate']?.toString() ?? "0";
      averageSpeed = latestActivityData['average_speed']?.toString() ?? "0";
      caloriesBurned = latestActivityData['calories_burned']?.toString() ?? "0";
      distance = latestActivityData['distance']?.toString() ?? "0";
      sessionDuration = latestActivityData['elapsed_time']?.toString() ?? "0";
    } else if (activityData.length == 1) {
      var latestActivityData = activityData[0];

      latestDistance = safeParseDouble(latestActivityData['distance']);
      latestCaloriesBurned =
          safeParseDouble(latestActivityData['calories_burned']);
      latestAverageSpeed = safeParseDouble(latestActivityData['average_speed']);
      latestAverageHeartrate =
          safeParseDouble(latestActivityData['average_heartrate']);

      // Update relevant activity metrics for recommendations
      averageHeartrate =
          latestActivityData['average_heartrate']?.toString() ?? "0";
      averageSpeed = latestActivityData['average_speed']?.toString() ?? "0";
      caloriesBurned = latestActivityData['calories_burned']?.toString() ?? "0";
      distance = latestActivityData['distance']?.toString() ?? "0";
      sessionDuration = latestActivityData['elapsed_time']?.toString() ?? "0";
    }
  }

  // Analyze body composition trends
  void _analyzeBodyCompositionTrends() {
    if (recentData.length < 2) return;

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
  double humid = safeParseDouble(humidity);
  
  // Check if it's indoor training season
  isIndoorSeason = temp < 5 || 
      temp > 35 || 
      (airQuality != "Good" && airQuality != "Moderate") || 
      humid > 85;  

  if (isIndoorSeason) {
    if (temp < 5) {
      seasonalAdvice = 
          "Cold weather season: Consider indoor training options or proper cold-weather gear.";
    } else if (temp > 35) {
      seasonalAdvice = 
          "Hot weather season: Early morning rides or indoor training recommended to avoid heat stress.";
    } else if (airQuality == "Poor" || airQuality == "Very Poor" || airQuality == "Extremely Poor") {
      seasonalAdvice = 
          "Poor air quality: Consider indoor training to protect respiratory health.";
    } else if (humid > 85) {
      seasonalAdvice = 
          "High humidity: Consider indoor training or early morning rides. Stay hydrated!";
    }
  } else {
    // Good conditions
    if (temp >= 15 && temp <= 25 && airQuality == "Good" && humid < 70) {
      seasonalAdvice = 
          "Perfect cycling conditions! Enjoy your outdoor ride.";
    } else {
      seasonalAdvice = 
          "Current weather conditions are acceptable for outdoor cycling.";
    }
  }
}
  double _calculateCoeffOfVariation(List<double> values) {
    if (values.isEmpty || values.length < 2) return 0.0;

    double mean = values.reduce((a, b) => a + b) / values.length;
    num sumSquaredDiff =
        values.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b);
    double stdDev = math.sqrt(sumSquaredDiff / (values.length - 1));

    return mean > 0 ? stdDev / mean : 0.0;
  }

  // Check if there's a consistent improvement trend
  bool _checkImprovementTrend() {
    if (distanceProgression.length < 3) return false;

    consecutiveImprovement = 0;
    for (int i = 1; i < distanceProgression.length; i++) {
      if (distanceProgression[i] > distanceProgression[i - 1]) {
        consecutiveImprovement++;
      } else {
        break; 
      }
    }

    return consecutiveImprovement >= 2; 
  }

 void _generateRecommendation() {
  print("Starting recommendation generation");
  print("Goal type: $goalType");
  print("Recent data count: ${recentData.length}");
  print("Activity data count: ${activityData.length}");

  if (activityData.isEmpty) {
    setState(() {
      recommendation = "No activity data available.";
      feedback =
          "Please sync your Strava data or record some activities to generate recommendations.";
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
      _generateNutritionRecommendationsFromFoodDiary();
      break;
    case "High Intensity Cycling":
      _generateWeightManagementRecommendations();
      _generateNutritionRecommendationsFromFoodDiary();
      _generateSeasonalAdvice();
      break;
    case "Endurance":
      _generateCyclingEnduranceRecommendations();
      _generateNutritionRecommendationsFromFoodDiary();
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

    if (!isConsistent && activityData.length >= 5) {
      progressRecommendations.add(
          "Your cycling schedule shows some inconsistency. Try establishing a regular weekly routine for better results.");

      if (hasRegularSchedule) {
        progressRecommendations.add(
            "You tend to ride most frequently on $mostFrequentDay. Consider adding 1-2 more days to your weekly schedule.");
      }
    }

    // Distance progress
    if (distanceProgression.length >= 3) {
      if (isImprovingOverTime) {
        progressRecommendations.add(
            "Great progress! You've shown consistent improvement over your last ${consecutiveImprovement + 1} rides.");
      } else if (distanceVariability > 0.3) {
        progressRecommendations.add(
            "Your ride distances vary significantly (±${(distanceVariability * 100).toStringAsFixed(0)}%). Consider a more structured training plan.");
      }
    }

    if (speedProgression.length >= 3) {
      double recentAverage = 0;
      double earlierAverage = 0;

      if (speedProgression.length >= 6) {
        int midpoint = speedProgression.length ~/ 2;
        recentAverage =
            speedProgression.sublist(0, midpoint).reduce((a, b) => a + b) /
                midpoint;
        earlierAverage =
            speedProgression.sublist(midpoint).reduce((a, b) => a + b) /
                (speedProgression.length - midpoint);

        double percentChange =
            ((recentAverage - earlierAverage) / earlierAverage) * 100;

        if (percentChange > 5) {
          progressRecommendations.add(
              "Your average speed has improved by ${percentChange.toStringAsFixed(1)}% compared to your earlier rides. Excellent progress!");
        } else if (percentChange < -5) {
          progressRecommendations.add(
              "Your average speed has decreased by ${(-percentChange).toStringAsFixed(1)}% compared to your earlier rides. Focus on technique and interval training.");
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
        recentAverage =
            heartrateProgression.sublist(0, midpoint).reduce((a, b) => a + b) /
                midpoint;
        earlierAverage =
            heartrateProgression.sublist(midpoint).reduce((a, b) => a + b) /
                (heartrateProgression.length - midpoint);

        double percentChange =
            ((recentAverage - earlierAverage) / earlierAverage) * 100;

        if (percentChange < -3 && goalType != "High Intensity Cycling") {
          progressRecommendations.add(
              "Your average heart rate has decreased by ${(-percentChange).toStringAsFixed(1)}% while maintaining performance. This indicates improved cardiovascular efficiency!");
        }
      }
    }

    // Best performance insight
    if (bestDistance > 0 && bestSpeed > 0) {
      String formattedDate = DateFormat('MMM d, y').format(bestPerformanceDate);
      progressRecommendations.add(
          "Your best overall performance was on $formattedDate. Analyze what made that ride successful and try to replicate those conditions.");
    }

    // Weekly volume insights
    if (weeklyDistanceTotal > 0 && activityData.length >= 3) {
      double targetWeeklyDistance = 0;

      if (goalType == "Leisure") {
        targetWeeklyDistance =
            safeParseDouble(daysPerWeek) * 15; // 15km per leisure ride
      } else if (goalType == "High Intensity Cycling") {
        targetWeeklyDistance =
            safeParseDouble(daysPerWeek) * 20; // 20km per high intensity ride
      } else if (goalType == "Endurance") {
        targetWeeklyDistance = safeParseDouble(targetDistance) *
            1.5; // 1.5x target distance for training
      }

      if (targetWeeklyDistance > 0) {
        double percentOfTarget =
            (weeklyDistanceTotal / targetWeeklyDistance) * 100;

        if (percentOfTarget < 70) {
          progressRecommendations.add(
              "You're currently at ${percentOfTarget.toStringAsFixed(0)}% of your ideal weekly distance. Try adding ${(targetWeeklyDistance - weeklyDistanceTotal).toStringAsFixed(0)} km to your weekly total.");
        } else if (percentOfTarget > 120) {
          progressRecommendations.add(
              "You're exceeding your weekly distance target by ${(percentOfTarget - 100).toStringAsFixed(0)}%. Consider focusing on quality over quantity to prevent overtraining.");
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
    double targetHeartRateUpper =
        maxHeartRate * 0.7; // 70% of max HR for leisure
    double targetHeartRateLower =
        maxHeartRate * 0.5; // 50% of max HR for leisure

    // Get latest activity metrics
    double latestHeartRate = safeParseDouble(averageHeartrate);
    double latestExertion = safeParseDouble(levelOfExertion);
    double targetDaysPerWeek = safeParseDouble(daysPerWeek);

    // Primary recommendation based on heart rate zones
    if (latestHeartRate > targetHeartRateUpper && latestHeartRate > 0) {
      setState(() {
        recommendation = "⚠️ Warning";
        feedback =
            "Heart rate too high for leisure cycling. Aim for ${targetHeartRateLower.toInt()}-${targetHeartRateUpper.toInt()} bpm for recovery and enjoyment.";
      });
    } else if (latestHeartRate >= targetHeartRateLower &&
        latestHeartRate <= targetHeartRateUpper &&
        latestExertion <= 5 &&
        latestHeartRate > 0) {
      setState(() {
        recommendation = "✅ Good";
        feedback =
            "Perfect leisure zone! Your heart rate and effort level are ideal for enjoyable, recreational cycling.";
      });
    } else if (latestHeartRate < targetHeartRateLower && latestHeartRate > 0) {
      setState(() {
        recommendation = "ℹ️ Info";
        feedback =
            "Heart rate is on the lower side. Consider slightly increasing intensity for better cardiovascular benefits.";
      });
    } else {
      setState(() {
        recommendation = "ℹ️ Info";
        feedback =
            "Use a heart rate monitor for more personalized recommendations.";
      });
    }

    // Historical data insights for leisure cycling
    if (averageHeartrateAllTime > 0 && activityData.length > 3) {
      if (averageHeartrateAllTime > targetHeartRateUpper) {
        trainingRecommendations.add(
            "Your historical average heart rate (${averageHeartrateAllTime.toInt()} bpm) is above the leisure zone. Focus on more relaxed rides.");
      }

      // Consistency recommendations based on historical data
      if (activityGaps.isNotEmpty) {
        double avgGap =
            activityGaps.reduce((a, b) => a + b) / activityGaps.length;
        if (avgGap > 7) {
          trainingRecommendations.add(
              "You tend to have ${avgGap.toStringAsFixed(0)} days between rides. For leisure benefits, try riding more regularly.");
        }
      }
    }

    // Training recommendations
    if (weeklyActivityCount < targetDaysPerWeek && targetDaysPerWeek > 0) {
      trainingRecommendations.add(
          "Try adding ${(targetDaysPerWeek - weeklyActivityCount).toInt()} more rides to meet your weekly goal.");
    }

    if (daysSinceLastActivity > 3) {
      trainingRecommendations.add(
          "It's been ${daysSinceLastActivity} days since your last ride. Consider a short, easy ride soon.");
    }

    trainingRecommendations
        .add("Aim for 30-60 min rides at conversational pace.");

    if (safeParseDouble(distance) > 20) {
      trainingRecommendations
          .add("Try shorter routes focused on enjoyment rather than distance.");
    }

    // Weather and air quality recommendations
    if (weatherData.isNotEmpty) {
      double currentTemp = safeParseDouble(temperature);

      if (currentTemp > 30) {
        trainingRecommendations
            .add("High temp: Ride in early morning or evening.");
        nutritionRecommendations.add("Increase fluid intake in this heat.");
      } else if (currentTemp < 10) {
        trainingRecommendations
            .add("Cold temp: Extend warm-up to 10-15 minutes.");
        equipmentRecommendations
            .add("Dress in layers with gloves for cold weather.");
      }

    }

    // Health condition recommendations
    if (respiratoryCondition == "Yes") {
      healthRecommendations
          .add("Monitor breathing with 'talk test' during rides.");
      healthRecommendations
          .add("Check air quality before rides (aim for AQI < 100).");
    }

    if (cardiovascularCondition == "Yes") {
      healthRecommendations.add(
          "Stay in ${targetHeartRateLower.toInt()}-${targetHeartRateUpper.toInt()} bpm zone.");
      healthRecommendations
          .add("Be cautious on high AQI days due to cardiovascular stress.");
    }

    // Nutrition recommendations
    nutritionRecommendations.add("Water is sufficient for rides under 1 hour.");
    nutritionRecommendations
        .add("Light snack 30-60 min before riding for energy.");

    // Health recommendations
    healthRecommendations.add("Stretch after rides for flexibility.");

    // Equipment recommendations
    equipmentRecommendations.add("Ensure proper bike fit and saddle height.");
    equipmentRecommendations.add("Consider padded shorts for longer rides.");
  }

void _generateWeightManagementRecommendations() {

  double targetWeightValue = safeParseDouble(targetWeight);
  double currentWeightValue = safeParseDouble(weight);
  double bmr = safeParseDouble(basalMetabolicRate);
  double bodyFatPercentage = safeParseDouble(bodyFat);
  double totalCaloriesBurned = safeParseDouble(caloriesBurned);

  double maxHeartRate = 220 - age.toDouble();
  double fatBurningZoneLower = maxHeartRate * 0.7; 
  double fatBurningZoneUpper = maxHeartRate * 0.85; 

  double latestHeartRate = safeParseDouble(averageHeartrate);

  if (latestWeight < previousWeight &&
      latestBodyFat < previousBodyFat &&
      latestWeight > 0 &&
      previousWeight > 0 &&
      latestBodyFat > 0 &&
      previousBodyFat > 0) {
    setState(() {
      recommendation = "✅ Great Progress";
      feedback =
          "You're losing both weight and body fat! Your high-intensity cycling is working effectively.";
    });
  } else if (latestWeight < previousWeight &&
      latestBodyFat >= previousBodyFat &&
      latestWeight > 0 &&
      previousWeight > 0 &&
      latestBodyFat > 0 &&
      previousBodyFat > 0) {
    setState(() {
      recommendation = "⚠️ Mixed Results";
      feedback =
          "Losing weight but not body fat. Add interval training and hill climbs to your routine.";
    });
  } else if (latestWeight > previousWeight &&
      latestBodyFat < previousBodyFat &&
      latestWeight > 0 &&
      previousWeight > 0 &&
      latestBodyFat > 0 &&
      previousBodyFat > 0) {
    setState(() {
      recommendation = "✅ Gaining Muscle";
      feedback =
          "Gaining weight while reducing body fat suggests muscle building. Great work!";
    });
  } else if (latestWeight == previousWeight &&
      latestBodyFat < previousBodyFat &&
      latestWeight > 0 &&
      previousWeight > 0 &&
      latestBodyFat > 0 &&
      previousBodyFat > 0) {
    setState(() {
      recommendation = "✅ Body Recomposition";
      feedback =
          "Stable weight with reduced body fat means you're building muscle. Keep it up!";
    });
  } else if (latestWeight >= previousWeight &&
      latestBodyFat >= previousBodyFat &&
      latestWeight > 0 &&
      previousWeight > 0 &&
      latestBodyFat > 0 &&
      previousBodyFat > 0) {
    setState(() {
      recommendation = "⚠️ Needs Adjustment";
      feedback =
          "Adjust your training and nutrition strategy to kickstart fat loss.";
    });
  } else if (latestWeight > 0 && currentWeightValue > targetWeightValue) {
    setState(() {
      recommendation = "ℹ️ In Progress";
      feedback =
          "You're ${(currentWeightValue - targetWeightValue).toStringAsFixed(1)} kg from your target. Let's refine your strategy.";
    });
  } else {
    if (latestWeight > 0 && latestBodyFat > 0) {
      setState(() {
        recommendation = "ℹ️ Monitoring Progress";
        feedback =
            "Your current metrics: ${latestWeight.toStringAsFixed(1)} kg weight and ${latestBodyFat.toStringAsFixed(1)}% body fat. Continue tracking for trend analysis.";
      });
    } else if (safeParseDouble(weight) > 0 && safeParseDouble(bodyFat) > 0) {
      setState(() {
        recommendation = "ℹ️ Starting Point Established";
        feedback =
            "Your profile metrics: ${weight} kg weight and ${bodyFat}% body fat. Record post-workout data to see progress.";
            print("latestWeight: $latestWeight");
            print("PreviousWeight: $previousWeight");
            print("latestBodyFat: $latestBodyFat");
            print("PreviousBodyFat: $previousBodyFat");
      });
    } else {
      setState(() {
        recommendation = "ℹ️ Building Baseline";
        feedback =
            "Track metrics consistently for personalized recommendations.";
      });
    }
  }

  if (totalCaloriesBurned > 0) {
    double monthlyDeficitNeeded = 3500 * 4; 
    double dailyDeficitNeeded = monthlyDeficitNeeded / 30; 
    
    if (totalCaloriesBurned < dailyDeficitNeeded / 2 && activityData.isNotEmpty) {
      trainingRecommendations.add(
          "Your recent average of ${totalCaloriesBurned.toInt()} kcal burned per session may be insufficient for your goals. Try increasing duration by 15-20 minutes.");
    } else if (totalCaloriesBurned > dailyDeficitNeeded) {
      trainingRecommendations.add(
          "You're burning ${totalCaloriesBurned.toInt()} kcal per session, which is excellent for weight loss. Ensure proper recovery and nutrition.");
    }
  }

  if (bodyFatPercentage > 0) {
    bool isMale = gender.toLowerCase() == "male";
    String userName = FirebaseAuth.instance.currentUser?.displayName ?? "You";
    
    String bodyFatCategory = "";
    if (isMale) {
      if (bodyFatPercentage < 6) {
        bodyFatCategory = "essential fat";
      } else if (bodyFatPercentage < 14) {
        bodyFatCategory = "athletic";
      } else if (bodyFatPercentage < 18) {
        bodyFatCategory = "fitness";
      } else if (bodyFatPercentage < 25) {
        bodyFatCategory = "average";
      } else {
        bodyFatCategory = "obesity";
      }
    } else { // Female
      if (bodyFatPercentage < 16) {
        bodyFatCategory = "essential fat";
      } else if (bodyFatPercentage < 24) {
        bodyFatCategory = "athletic";
      } else if (bodyFatPercentage < 31) {
        bodyFatCategory = "fitness";
      } else if (bodyFatPercentage < 36) {
        bodyFatCategory = "average";
      } else {
        bodyFatCategory = "obesity";
      }
    }
    
    healthRecommendations.add(
        "$userName, your current body fat percentage (${bodyFatPercentage.toStringAsFixed(1)}%) is in the '$bodyFatCategory' range for your gender.");
    
    double targetBodyFat = isMale ? 
        math.max(bodyFatPercentage - 5, 10) : 
        math.max(bodyFatPercentage - 5, 18);  
    
    if (bodyFatCategory == "obesity") {
      int recommendedSessions = weeklyActivityCount < 2 ? 3 : 4; 
      double userZoneLower = maxHeartRate * 0.6; 
      double userZoneUpper = maxHeartRate * 0.7;
      
      healthRecommendations.add(
          "Based on your current activity level (${weeklyActivityCount} sessions/week), aim to gradually build to ${recommendedSessions}-5 sessions per week with a mix of moderate intensity (${userZoneLower.toInt()}-${userZoneUpper.toInt()} bpm) and short interval sessions.");
      
      int recommendedDeficit = bmr > 1800 ? 750 : 500; 
      
      healthRecommendations.add(
          "With your BMR of ${bmr.toInt()} kcal, create a daily deficit of ${recommendedDeficit} kcal through a combination of diet and your cycling routine to work toward your target body fat of ${targetBodyFat.toStringAsFixed(1)}%.");
    } else if (bodyFatCategory == "average") {
      bool hasHighIntensitySessions = latestAverageHeartrate > fatBurningZoneLower;
      String intensityRecommendation = hasHighIntensitySessions ? 
          "continue your high-intensity work" : 
          "incorporate more intervals to your routine";
      
      healthRecommendations.add(
          "For your body composition goals, ${intensityRecommendation} with a 2:1 ratio of high-intensity intervals to steady-state cardio to maximize fat loss while preserving muscle.");
      
      int strengthDays = daysSinceLastActivity > 2 ? 2 : 3; 
      
      healthRecommendations.add(
          "With your current cycling frequency, add ${strengthDays} resistance training sessions weekly on ${mostFrequentDay != "" ? "days other than $mostFrequentDay" : "your rest days"} to increase muscle mass and boost your metabolic rate.");
    } else if (bodyFatCategory == "fitness") {
      String nutritionTiming = nutritionData.isNotEmpty ? 
          "adjust your current meal timing to include more protein daily)" : 
          "focus on nutrition timing with pre-workout carbs and post-workout protein";
      
      healthRecommendations.add(
          "To further reduce your body fat from ${bodyFatPercentage.toStringAsFixed(1)}% to your ideal range, ${nutritionTiming} for optimal body composition.");
      
      // Morning session recommendation based on schedule
      String morningRecommendation = hasRegularSchedule ? 
          "Based on your regular cycling schedule, add 1-2 fasted morning sessions" : 
          "Consider adding 1-2 early morning sessions before breakfast";
      
      healthRecommendations.add(
          "$morningRecommendation to target stubborn fat stores. This complements your current ${averageDistanceAllTime.toStringAsFixed(1)} km average distance rides.");
    } else if (bodyFatCategory == "athletic") {
      // Performance focus
      double bestPerformanceMetric = math.max(bestDistance, 20);
      
      healthRecommendations.add(
          "With your athletic ${bodyFatPercentage.toStringAsFixed(1)}% body fat, shift focus to performance goals such as reaching ${(bestPerformanceMetric * 1.1).toStringAsFixed(1)} km distance or improving your average speed of ${averageSpeedAllTime.toStringAsFixed(1)} km/h.");
      
      // Nutrition cycling based on activity pattern
      String highCarb = hasRegularSchedule ? mostFrequentDay : "training days";
      String lowCarb = hasRegularSchedule ? "days after $mostFrequentDay" : "rest days";
      
      healthRecommendations.add(
          "Implement carb cycling with higher carbs on $highCarb (${(safeParseDouble(weight) * 4).toInt()}g) and lower carbs on $lowCarb (${(safeParseDouble(weight) * 2).toInt()}g) to maintain your excellent body fat levels.");
    } else if (bodyFatCategory == "essential fat") {
      healthRecommendations.add(
          "At ${bodyFatPercentage.toStringAsFixed(1)}%, your body fat is at or near essential levels. Focus on maintaining this level through consistent performance rather than further reduction.");
      
      // Personalized fat intake recommendation
      double idealFatIntake = safeParseDouble(weight) * 0.7;
      
      healthRecommendations.add(
          "For hormonal health at your low body fat percentage, ensure you're consuming at least ${idealFatIntake.toInt()}g of healthy fats daily, especially around your ${weeklyActivityCount} weekly high-intensity sessions.");
    }
    
    // Add recommendations for optimal monthly body fat reduction
    if (bodyFatCategory != "essential fat" && bodyFatCategory != "athletic") {
      // Calculate personalized monthly target
      double monthlyReductionTarget = bodyFatPercentage > 25 ? 2.0 : 1.0;
      double currentWeight = safeParseDouble(weight);
      double fatMassKg = currentWeight * (bodyFatPercentage / 100);
      double targetFatLossKg = (bodyFatPercentage - monthlyReductionTarget) / 100 * currentWeight;
      double kgToLose = fatMassKg - targetFatLossKg;
      
      healthRecommendations.add(
          "Based on your metrics, aim for a ${monthlyReductionTarget}% body fat reduction this month (approximately ${kgToLose.toStringAsFixed(1)} kg of fat) through your high-intensity cycling, ${totalActivities > 15 ? "maintaining your impressive consistency" : "gradually increasing your cycling frequency"}, and proper nutrition.");
    }
  }

  if (bmr > 0) {
    // Calculate daily calorie targets
    double maintenanceCalories = bmr * 1.2;
    double weightLossTarget = maintenanceCalories - 500; 
    
    trainingRecommendations.add(
        "Based on your BMR of ${bmr.toInt()} kcal, aim for a daily intake of ${weightLossTarget.toInt()} kcal to support weight loss while maintaining energy for cycling.");
    
    if (bmr > 1800) {
      trainingRecommendations.add(
          "With your higher metabolic rate, incorporate 1-2 longer steady-state rides (60+ min) weekly to maximize fat utilization.");
    } else if (bmr < 1400) {
      trainingRecommendations.add(
          "With your current metabolic rate, focus on building muscle through resistance training 2x weekly to boost your BMR.");
    }
  }

  // Historical heart rate analysis - extended to consider monthly patterns
  if (heartrateProgression.length >= 10) { // More data points for monthly analysis
    double avgHistoricalHR = heartrateProgression.reduce((a, b) => a + b) /
        heartrateProgression.length;
    String userName = FirebaseAuth.instance.currentUser?.displayName?.split(' ')[0] ?? "your";

    // Personalized heart rate recommendations
    if (avgHistoricalHR < fatBurningZoneLower) {
      // Calculate the intensity gap
      int intensityGap = fatBurningZoneLower.toInt() - avgHistoricalHR.toInt();
      String intensityAdvice = intensityGap > 15 ? 
          "gradually increase your intensity by adding short 2-minute bursts at ${(avgHistoricalHR + 15).toInt()} bpm" : 
          "increase your intensity to ${fatBurningZoneLower.toInt()}-${fatBurningZoneUpper.toInt()} bpm";
      
      trainingRecommendations.add(
          "${userName}'s monthly heart rate average (${avgHistoricalHR.toInt()} bpm) is ${intensityGap} bpm below your optimal fat-burning zone. To maximize results, $intensityAdvice during your next few workouts.");
    } else if (avgHistoricalHR > fatBurningZoneUpper) {
      // Calculate percent above threshold
      int excessBPM = avgHistoricalHR.toInt() - fatBurningZoneUpper.toInt();
      
      // Personalize based on health conditions
      String recoveryAdvice = respiratoryCondition == "Yes" || cardiovascularCondition == "Yes" ? 
          "incorporate more Zone 2 (${zone2HeartRate} bpm) training sessions for safety and recovery" : 
          "add 1-2 Zone 2 (${zone2HeartRate} bpm) sessions weekly for better fat utilization";
      
      trainingRecommendations.add(
          "Your monthly heart rates average ${avgHistoricalHR.toInt()} bpm, which is ${excessBPM} bpm above your ideal zone. For your body composition goals, $recoveryAdvice while maintaining your impressive intensity on key training days.");
    } else {
      // If they're in the perfect zone, acknowledge it
      trainingRecommendations.add(
          "Excellent work! Your average heart rate of ${avgHistoricalHR.toInt()} bpm is perfectly within your fat-burning zone. This is ideal for your current body composition goals.");
    }
    
    // Monthly trend analysis
    if (heartrateProgression.length >= 20) { // At least 20 data points for reliable trend
      List<double> recentHRs = heartrateProgression.sublist(0, 10);
      List<double> earlierHRs = heartrateProgression.sublist(10, math.min(20, heartrateProgression.length));
      
      double recentAvg = recentHRs.reduce((a, b) => a + b) / recentHRs.length;
      double earlierAvg = earlierHRs.reduce((a, b) => a + b) / earlierHRs.length;
      
      double hrChangePercent = ((recentAvg - earlierAvg) / earlierAvg) * 100;
      
      if (hrChangePercent < -5) {
        // Calculate fitness improvement estimate
        double fitnessImprovement = (-hrChangePercent) * 0.5; // Rough estimate of VO2max improvement
        String improvedPerformance = "";
        
        if (distanceProgression.length >= 10) {
          List<double> recentDistances = distanceProgression.sublist(0, 5);
          List<double> earlierDistances = distanceProgression.sublist(5, 10);
          double recentDistAvg = recentDistances.reduce((a, b) => a + b) / recentDistances.length;
          double earlierDistAvg = earlierDistances.reduce((a, b) => a + b) / earlierDistances.length;
          
          if (recentDistAvg > earlierDistAvg) {
            improvedPerformance = " This has translated to ${((recentDistAvg - earlierDistAvg) / earlierDistAvg * 100).toStringAsFixed(1)}% longer rides at the same effort level!";
          }
        }
        
        trainingRecommendations.add(
            "Great progress! Your heart rate has decreased by ${(-hrChangePercent).toStringAsFixed(1)}% over the past month, suggesting a ${fitnessImprovement.toStringAsFixed(1)}% improvement in cardiovascular efficiency.$improvedPerformance Continue with your current training approach.");
      } else if (hrChangePercent > 5) {
        // Personalized recovery recommendation based on activity frequency
        String recoveryAdvice = weeklyActivityCount > 4 ? 
            "add an additional rest day this week" : 
            "maintain your current frequency but lower the intensity of 1-2 sessions";
        
        // Check weather and other factors for additional context
        String additionalContext = "";
        if (safeParseDouble(temperature) > 28) {
          additionalContext = " The higher temperatures (${temperature}°C) may be contributing to this, so consider earlier morning rides when it's cooler.";
        } else if (daysSinceLastActivity < 1 && weeklyActivityCount > 5) {
          additionalContext = " Your training frequency (${weeklyActivityCount} sessions/week) may be limiting recovery time.";
        }
        
        trainingRecommendations.add(
            "Your heart rate has increased by ${hrChangePercent.toStringAsFixed(1)}% over the past month, which may indicate accumulated fatigue.$additionalContext To prevent overtraining, $recoveryAdvice and ensure adequate sleep (7-9 hours nightly).");
      }
    }
  }
  if (latestHeartRate > 0) {
    if (latestHeartRate < fatBurningZoneLower) {
      trainingRecommendations.add(
          "Increase intensity to ${fatBurningZoneLower.toInt()}-${fatBurningZoneUpper.toInt()} bpm for optimal fat burning.");
    } else if (latestHeartRate > fatBurningZoneUpper) {
      trainingRecommendations
          .add("Try intervals between high intensity and recovery periods.");
    } else {
      trainingRecommendations
          .add("Perfect fat-burning zone! Maintain this intensity.");
    }
  }

  // Training structure based on historical data - adjusted for monthly view
  int totalHighIntensitySessions = 0;
  List<int> lastFiveHeartRates = [];

  // Count high intensity sessions from historical data - expanded sample size
  for (int i = 0; i < math.min(activityData.length, 20); i++) { // Increased from 10 to 20
    double hr = safeParseDouble(activityData[i]['average_heartrate']);
    if (hr > fatBurningZoneLower) totalHighIntensitySessions++;

    if (i < 5 && hr > 0) lastFiveHeartRates.add(hr.toInt());
  }

  // Monthly target adjustment (12 high intensity sessions per month minimum)
  if (totalHighIntensitySessions < 12 && activityData.length >= 15) { 
    trainingRecommendations.add(
        "Of your last ${math.min(activityData.length, 20)} rides, only $totalHighIntensitySessions were at high intensity. Aim for at least 12 per month for effective weight management.");
  }

  if (lastFiveHeartRates.length >= 3) {
    String hrTrend = lastFiveHeartRates.join(" → ");
    trainingRecommendations.add(
        "Your recent heart rate trend (bpm): $hrTrend. Aim for consistent intensity in the fat-burning zone.");
  }

  // Personalized standard training recommendations based on user profile and history
  String userName = FirebaseAuth.instance.currentUser?.displayName?.split(' ')[0] ?? "Your";
  
  // Calculate personalized monthly session target based on current activity level and health
  int baseMonthlyTarget = 16; // Standard recommendation is 16 sessions/month (4/week)
  
  // Adjust based on health conditions
  if (respiratoryCondition == "Yes" || cardiovascularCondition == "Yes") {
    baseMonthlyTarget = 12; // Lower target for health conditions (3/week)
  }
  
  // Adjust based on current activity level for gradual progression
  int personalizedMonthlyTarget;
  if (weeklyActivityCount * 4 > baseMonthlyTarget) {
    // If already exceeding target, recommend maintaining with slight increase
    personalizedMonthlyTarget = (weeklyActivityCount * 4).round() + 1;
  } else if (weeklyActivityCount < 1) {
    // If very inactive, start conservatively
    personalizedMonthlyTarget = baseMonthlyTarget - 4;
  } else {
    // Otherwise, recommend gradual increase toward base target
    personalizedMonthlyTarget = (weeklyActivityCount * 4 + 2).round();
    personalizedMonthlyTarget = math.min(personalizedMonthlyTarget, baseMonthlyTarget);
  }
  
  // Personalize interval structure based on fitness level and goal
  int intervalLength = 2; // Default interval length in minutes
  int recoveryLength = 2; // Default recovery length in minutes
  
  // Adjust interval structure based on heart rate data
  if (averageHeartrateAllTime > 0) {
    if (averageHeartrateAllTime > fatBurningZoneUpper + 10) {
      // If consistently training too hard, recommend longer recoveries
      recoveryLength = 3;
    } else if (averageHeartrateAllTime < fatBurningZoneLower - 10) {
      // If consistently training too easy, recommend longer intervals
      intervalLength = 3;
    }
  }
  
  // Adjust based on reported exertion level if available
  double exertion = safeParseDouble(levelOfExertion);
  if (exertion > 0) {
    if (exertion > 8) {
      // If reporting very high exertion, reduce interval length
      intervalLength = math.max(1, intervalLength - 1);
    } else if (exertion < 4) {
      // If reporting very low exertion, increase interval length
      intervalLength += 1;
    }
  }
  
  if (weeklyActivityCount < 3) {
    // Personalized frequency recommendation based on constraints
    String frequencyAdvice = daysSinceLastActivity > 5 ? 
        "start with just one session this week, then add another session next week" : 
        "gradually build to 3 sessions per week";
    
    trainingRecommendations.add(
        "Based on your current activity level (${weeklyActivityCount} sessions/week), $frequencyAdvice, aiming for 12+ monthly sessions for effective weight management. ${mostFrequentDay.isNotEmpty ? "You tend to ride on $mostFrequentDay - try adding sessions on other days too." : ""}");
  }

  // Personalized calorie recommendations with historical context - adjusted for monthly targets
  if (bmr > 0 && activityData.length >= 5) {
    List<double> allCalories = [];
    for (var activity in activityData) {
      double cals = safeParseDouble(activity['calories_burned']);
      if (cals > 0) allCalories.add(cals);
    }

    if (allCalories.isNotEmpty) {
      double avgCaloriesPerSession =
          allCalories.reduce((a, b) => a + b) / allCalories.length;
      double monthlyCalorieBurn = avgCaloriesPerSession * (weeklyActivityCount * 4); // Estimated monthly burn
      double dailyDeficitFromExercise = monthlyCalorieBurn / 30.0; // 30 days per month
      
      // Calculate target weight loss rate (0.5-1 kg per week based on starting weight)
      double targetWeightLossPerMonth = safeParseDouble(weight) > 100 ? 4.0 : 2.0;
      double targetDailyDeficit = (targetWeightLossPerMonth * 7700) / 30; // Convert kg to calories (7700 cal/kg)
      
      // Calculate difference between current and target
      double deficitGap = targetDailyDeficit - dailyDeficitFromExercise;

      if (dailyDeficitFromExercise < 250) {
        // Calculate session duration increase needed
        double currentDuration = safeParseDouble(sessionDuration) / 60; // Convert to minutes
        double targetDuration = currentDuration * (400 / avgCaloriesPerSession);
        
        trainingRecommendations.add(
            "Your rides currently burn ${avgCaloriesPerSession.toInt()} kcal per session. For your weight management goals, aim to increase your average ride duration from ${currentDuration.toInt()} min to ${targetDuration.toInt()} min, or add one extra session weekly to create a ${deficitGap.toInt()} kcal larger daily deficit.");
      } else if (dailyDeficitFromExercise > 1000) {
        // Calculate estimated weight loss from current deficit
        double estimatedMonthlyLoss = (dailyDeficitFromExercise * 30) / 7700; // Convert calories to kg
        
        // Personalized high-calorie burn advice
        String nutritionAdvice = nutritionData.isNotEmpty ?
            "increase your carbohydrate intake by ~${(estimatedMonthlyLoss * 50).toInt()}g on training days" :
            "consume a carb-protein snack (3:1 ratio) within 30 minutes post-workout";
        
        trainingRecommendations.add(
            "You're burning an impressive ${avgCaloriesPerSession.toInt()} kcal per workout, creating a ${dailyDeficitFromExercise.toInt()} kcal daily deficit. This could yield approximately ${estimatedMonthlyLoss.toStringAsFixed(1)} kg weight loss per month. To maintain your energy levels and performance, $nutritionAdvice.");
      }
    }
  }

  // Personalized weather recommendations
  if (weatherData.isNotEmpty) {
    double currentTemp = safeParseDouble(temperature);
    double currentHumidity = safeParseDouble(humidity);
    
    if (currentTemp > 30) {
      // Personalized hot weather recommendations based on time of day patterns
      List<DateTime> activityTimes = [];
      for (var activity in activityData) {
        if (activity['start_date'] != null) {
          DateTime date = activity['start_date'].toDate();
          activityTimes.add(date);
        }
      }
      
      bool mostlyEveningRider = activityTimes.where((time) => time.hour >= 17).length > 
                               activityTimes.where((time) => time.hour < 17).length;
      
      String timeRecommendation = mostlyEveningRider ? 
          "shift your usual evening rides to early morning (5-8 AM)" : 
          "continue your morning rides, but start 1-2 hours earlier";
      
      String hydrationAdvice = currentHumidity > 70 ? 
          "increase your hydration by 150-200ml per 20 minutes in this heat and humidity" : 
          "increase your hydration by 100-150ml per 20 minutes in this heat";
      
      trainingRecommendations.add(
          "Current weather (${currentTemp.toStringAsFixed(1)}°C, ${currentHumidity.toStringAsFixed(0)}% humidity): For your high-intensity sessions, $timeRecommendation for better fat burning efficiency. Also, $hydrationAdvice.");
    }

  // Health condition recommendations
  if (respiratoryCondition == "Yes") {
    healthRecommendations.add(
        "Use shorter intervals (30s-1min) with longer recovery periods.");
  }

  if (cardiovascularCondition == "Yes") {
    healthRecommendations.add(
        "Focus on moderate intensity (60-70% max HR) for longer durations.");
  }
  
  // Health recommendations
  healthRecommendations
      .add("Include 2 rest days weekly to prevent hormonal imbalances.");
  healthRecommendations
      .add("Aim for 7-9 hours sleep to regulate hunger hormones.");

  // Equipment recommendations
  equipmentRecommendations
      .add("Ensure proper bike fit to prevent injury during hard efforts.");
  equipmentRecommendations
      .add("Use a heart rate monitor for optimal fat-burning zone training.");
}
}
  void _generateCyclingEnduranceRecommendations() {
    // Basic data
    double targetDistanceValue = safeParseDouble(targetDistance);
    double currentDistanceValue = safeParseDouble(distance);
    double targetDurationValue = safeParseDouble(targetDuration);
    double currentDurationValue =
        safeParseDouble(sessionDuration) / 60; 

    // Heart rate zones
    double maxHeartRate = 220 - age.toDouble();
    double enduranceZoneLower = maxHeartRate * 0.65; // 65% of max HR
    double enduranceZoneUpper = maxHeartRate * 0.75; // 75% of max HR
    double thresholdZoneLower = maxHeartRate * 0.76; // 76% of max HR
    double thresholdZoneUpper = maxHeartRate * 0.90; // 90% of max HR

    double latestHeartRate = safeParseDouble(averageHeartrate);

    if (latestDistance > previousDistance &&
        latestDistance > 0 &&
        previousDistance > 0) {
      setState(() {
        recommendation = "✅ Distance Improving";
        feedback =
            "Great progress! Your distance increased from ${previousDistance.toStringAsFixed(1)} km to ${latestDistance.toStringAsFixed(1)} km.";
      });
    } else if (latestAverageSpeed > previousAverageSpeed &&
        latestAverageSpeed > 0 &&
        previousAverageSpeed > 0) {
      setState(() {
        recommendation = "✅ Speed Improving";
        feedback =
            "Your speed increased while maintaining distance. Cycling efficiency is improving!";
      });
    } else if (latestAverageHeartrate < previousAverageHeartrate &&
        latestDistance >= previousDistance &&
        latestAverageHeartrate > 0 &&
        previousAverageHeartrate > 0) {
      setState(() {
        recommendation = "✅ Efficiency Improving";
        feedback =
            "Lower heart rate at same/higher distance shows improved cardiovascular efficiency!";
      });
    } else if (latestDistance < previousDistance &&
        latestDistance > 0 &&
        previousDistance > 0) {
      setState(() {
        recommendation = "⚠️ Distance Decreasing";
        feedback =
            "Recent ride was shorter than previous. Focus on recovery before next endurance effort.";
      });
    } else if (latestAverageSpeed < previousAverageSpeed &&
        latestAverageSpeed > 0 &&
        previousAverageSpeed > 0) {
      setState(() {
        recommendation = "⚠️ Speed Decreasing";
        feedback =
            "Average speed dropped. Work on consistent pacing during long rides.";
      });
    } else if (latestDistance > 0 &&
        currentDistanceValue < targetDistanceValue) {
      setState(() {
        recommendation = "ℹ️ Building Endurance";
        feedback =
            "Currently at ${currentDistanceValue.toStringAsFixed(1)} km toward ${targetDistanceValue.toStringAsFixed(1)} km goal.";
      });
    } else {
      setState(() {
        recommendation = "ℹ️ Establishing Baseline";
        feedback =
            "Track rides consistently for personalized endurance recommendations.";
      });
    }

    // Historical distance progression analysis
    if (distanceProgression.length >= 5) {
      double oldestAvg = 0;
      double newestAvg = 0;

      int midpoint = distanceProgression.length ~/ 2;
      if (midpoint > 1) {
        oldestAvg =
            distanceProgression.sublist(midpoint).reduce((a, b) => a + b) /
                (distanceProgression.length - midpoint);
        newestAvg =
            distanceProgression.sublist(0, midpoint).reduce((a, b) => a + b) /
                midpoint;

        double improvementPercent = ((newestAvg - oldestAvg) / oldestAvg) * 100;

        if (improvementPercent > 10) {
          trainingRecommendations.add(
              "Your endurance has improved ${improvementPercent.toStringAsFixed(0)}% compared to your earlier rides. Excellent progression!");
        } else if (improvementPercent < -10) {
          trainingRecommendations.add(
              "Your recent distances are ${(-improvementPercent).toStringAsFixed(0)}% shorter than your earlier rides. Consider adjusting your training load.");
        } else {
          trainingRecommendations.add(
              "Your distance progression is stable. To continue improving, try gradually increasing your longest ride each week.");
        }
      }

      // Find longest ride ever
      double longestRide = distanceProgression.reduce(math.max);
      if (longestRide > 0 && targetDistanceValue > 0) {
        double percentOfTarget = (longestRide / targetDistanceValue) * 100;
        trainingRecommendations.add(
            "Your longest ride to date (${longestRide.toStringAsFixed(1)} km) is ${percentOfTarget.toStringAsFixed(0)}% of your target distance.");
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

      double endurancePercent =
          (enduranceZoneCount / heartrateProgression.length) * 100;
      double thresholdPercent =
          (aboveThresholdCount / heartrateProgression.length) * 100;

      if (endurancePercent < 60 && thresholdPercent > 30) {
        trainingRecommendations.add(
            "${thresholdPercent.toStringAsFixed(0)}% of your rides are above threshold zone. For endurance, focus more on Zone 2 (${enduranceZoneLower.toInt()}-${enduranceZoneUpper.toInt()} bpm).");
      }
    }

    // Current heart rate recommendations
    if (latestHeartRate > 0) {
      if (latestHeartRate > thresholdZoneUpper) {
        trainingRecommendations.add(
            "Heart rate too high for endurance. Stay within ${enduranceZoneLower.toInt()}-${enduranceZoneUpper.toInt()} bpm range.");
      } else if (latestHeartRate < enduranceZoneLower) {
        trainingRecommendations.add(
            "Increase intensity to ${enduranceZoneLower.toInt()}-${enduranceZoneUpper.toInt()} bpm for aerobic development.");
      } else if (latestHeartRate >= enduranceZoneLower &&
          latestHeartRate <= enduranceZoneUpper) {
        trainingRecommendations.add(
            "Perfect endurance zone! Great for building aerobic capacity.");
      } else {
        trainingRecommendations.add(
            "You're in threshold zone - good for tempo sessions but not longer rides.");
      }
    }

    // Training structure
    trainingRecommendations.add(
        "Follow 80/20 rule: 80% low intensity, 20% higher intensity rides.");

    // Distance progression
    if (currentDistanceValue > 0 &&
        targetDistanceValue > 0 &&
        currentDistanceValue < targetDistanceValue) {
      double percentComplete =
          (currentDistanceValue / targetDistanceValue) * 100;
      double weeklyIncrease = targetDistanceValue * 0.1;

      trainingRecommendations.add(
          "You're ${percentComplete.toStringAsFixed(0)}% to goal. Increase long ride by ~${weeklyIncrease.toStringAsFixed(1)} km/week.");
    }

    if (weeklyActivityCount < 3) {
      trainingRecommendations
          .add("Aim for 3-4 rides/week: one long, 2-3 shorter recovery rides.");
    }

    // Specific training strategies
    trainingRecommendations.add(
        "Include one 'tempo' ride weekly at ${thresholdZoneLower.toInt()}-${thresholdZoneUpper.toInt()} bpm.");

    // Weather and air quality
    if (weatherData.isNotEmpty) {
      double currentTemp = safeParseDouble(temperature);

      if (currentTemp > 30) {
        trainingRecommendations.add(
            "Hot weather: Lower heart rate target by 5-10% and hydrate more.");
      }
    }

    // Health condition recommendations
    if (respiratoryCondition == "Yes") {
      healthRecommendations.add(
          "With respiratory condition, build endurance gradually (max 10%/week).");
      healthRecommendations
          .add("Only ride outdoors when AQI < 100, preferably < 50.");
    }

    if (cardiovascularCondition == "Yes") {
      healthRecommendations.add(
          "Focus on Zone 2 (${enduranceZoneLower.toInt()}-${enduranceZoneUpper.toInt()} bpm) for cardiovascular efficiency.");
      healthRecommendations
          .add("Be extra cautious when AQI > 100 with your condition.");
    }
    // Health recommendations
    healthRecommendations
        .add("Balance training stress with recovery between sessions.");
    healthRecommendations
        .add("Post-ride: 3:1 carb:protein ratio within 30 minutes.");

    if (daysSinceLastActivity < 1 && weeklyActivityCount > 5) {
      healthRecommendations
          .add("Add dedicated recovery days to prevent overtraining.");
    }

    // Equipment recommendations
    equipmentRecommendations.add(
        "Bike fit is crucial for endurance - small discomforts become major on long rides.");
    equipmentRecommendations
        .add("Quality padded shorts and chamois cream for rides > 2 hours.");

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
      body: _isLoadingGraphs 
      ? _buildLoadingScreen()
      : AnimatedSwitcher(
          duration: Duration(milliseconds: 500),
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16),
                  _buildHeaderSection(),
                  
                  // Primary recommendation card with animation
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 800),
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
                    child: _buildPrimaryRecommendationCard(),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Show subgoal selection card if needed
                  if (goalType == "High Intensity Cycling") 
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 800),
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
                      child: _buildSubgoalSelectionCard(),
                    ),
                  
                  SizedBox(height: 16),

                  // Section title with animation
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
                    child: _buildSectionTitle("Personalized Insights", Icons.lightbulb_outline_rounded),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Recommendation carousel with animation
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 900),
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
                    child: _buildRecommendationCarousel(),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Analytics section title
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
                    child: _buildSectionTitle("Your Analytics", Icons.insert_chart_outlined_rounded),
                  ),
                  
                  SizedBox(height: 50),

                  _buildWeeklySummary(),
                  
                  // Goal based graphs with animation
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
                    child: _buildGoalBasedGraphs(),
                  ),
                  
                  SizedBox(height: 50),
                  
                  // Activity section title
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
                  
                  // Activity logs with animation
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
                  
                  SizedBox(height: 40),
                ],
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
      ),
    );
  }

   Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: Color(0xffFFA500),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            "Loading your insights...",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // Header section with welcome message
  Widget _buildHeaderSection() {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your Cycling Insights",
            style: TextStyle(
              fontFamily: 'Fredoka-SemiBold',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 6),
          Text(
            goalType != "-" 
              ? "Personalized for your ${goalType.toLowerCase()} goals" 
              : "Connect your Strava to get personalized insights",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Section title widget
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 25,
          color: Color(0xffFFA500),
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Fredoka-SemiBold',
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryRecommendationCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xffFFF8E1), 
            Color(0xffFFE0B2), 
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xffFFA500).withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(color: Color(0xffFFA500).withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xffFFA500),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getRecommendationIcon(recommendation),
                  size: 26,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  recommendation,
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xffE65100), 
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            feedback,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: Colors.brown[700],
            ),
          ),

          if (activityData.length >= 3) ...[
            SizedBox(height: 16),
            Divider(color: Color(0xffFFA500).withOpacity(0.3), thickness: 1),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: Color(0xffFFA500)),
                SizedBox(width: 6),
                Text(
                  "Based on ${activityData.length} activities over ${_calculateActivitySpan()} days",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Color(0xffF57C00), 
                  ),
                ),
              ],
            ),
          ],
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
                    showAllLogs ? Icons.visibility_off_rounded : Icons.visibility_rounded,
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

  // Activity logs list
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
                    // Activity name and date
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
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Widget _buildRecommendationCarousel() {
    List<Map<String, dynamic>> recommendationCategories = [];
    int currentPage = 0;

    if (trainingRecommendations.isNotEmpty) {
      recommendationCategories.add({
        "title": "Training Tips",
        "icon": Icons.directions_bike_rounded,
        "color": Color(0xFF1E88E5), 
        "gradientColors": [Color(0xFF1E88E5), Color(0xFF0D47A1)], 
        "recommendations": trainingRecommendations,
      });
    }

    if (nutritionRecommendations.isNotEmpty) {
      recommendationCategories.add({
        "title": "Nutrition & Hydration",
        "icon": Icons.restaurant_rounded,
        "color": Color(0xFF43A047),
        "gradientColors": [Color(0xFF43A047), Color(0xFF2E7D32)], 
        "recommendations": nutritionRecommendations,
      });
    }

    if (healthRecommendations.isNotEmpty) {
      recommendationCategories.add({
        "title": "Health & Recovery",
        "icon": Icons.favorite_rounded,
        "color": Color(0xFFEC407A),
        "gradientColors": [Color(0xFFEC407A), Color(0xFFC2185B)],
        "recommendations": healthRecommendations,
      });
    }

    if (equipmentRecommendations.isNotEmpty) {
      recommendationCategories.add({
        "title": "Equipment & Gear",
        "icon": Icons.handyman_rounded,
        "color": Color(0xFF546E7A), 
        "gradientColors": [Color(0xFF546E7A), Color(0xFF37474F)], 
        "recommendations": equipmentRecommendations,
      });
    }

    // Add Progress Insights category if available
    if (progressRecommendations.isNotEmpty) {
      recommendationCategories.add({
        "title": "Progress Insights",
        "icon": Icons.insights_rounded,
        "color": Color(0xFF8E24AA), 
        "gradientColors": [Color(0xFF8E24AA), Color(0xFF5E35B1)], 
        "recommendations": progressRecommendations,
      });
    }

    // If no recommendations are available
    if (recommendationCategories.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.grey[500], size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Track more cycling activities to receive personalized recommendations.",
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

    PageController pageController = PageController(
      initialPage: 0,
      viewportFraction: 0.92,
    );

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          children: [
            Container(
              height: 350,
              child: PageView.builder(
                controller: pageController,
                itemCount: recommendationCategories.length,
                itemBuilder: (context, index) {
                  var category = recommendationCategories[index];
                  return _buildRecommendationCard(
                    category["title"],
                    category["icon"],
                    category["color"],
                    category["gradientColors"],
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
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                recommendationCategories.length,
                (index) => AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  width: currentPage == index ? 16 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: currentPage == index
                        ? (recommendationCategories[index]["color"] as Color)
                        : Colors.orange.withOpacity(0.2),
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
  Widget _buildRecommendationCard(
      String title, IconData icon, Color color, List<Color> gradientColors, List<String> recommendations) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              itemCount: recommendations.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.1), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: color,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          recommendations[index],
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14, 
                            color: Colors.black87,
                            height: 1.4,
                          ),
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
            padding: EdgeInsets.only(bottom: 12),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 24,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityMetric(String label, String value, IconData icon, Color color) {
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

  IconData _getRecommendationIcon(String recommendation) {
    if (recommendation.contains("✅") ||
        recommendation.contains("Good") ||
        recommendation.contains("Improving") ||
        recommendation.contains("Progress")) {
      return Icons.check_circle_rounded;
    } else if (recommendation.contains("⚠️") ||
        recommendation.contains("Warning") ||
        recommendation.contains("Needs") ||
        recommendation.contains("Decreasing")) {
      return Icons.warning_rounded;
    } else if (recommendation.contains("❌") || recommendation.contains("Bad")) {
      return Icons.error_rounded;
    } else if (recommendation.contains("ℹ️") ||
        recommendation.contains("Info") ||
        recommendation.contains("Building") ||
        recommendation.contains("In Progress")) {
      return Icons.info_rounded;
    } else {
      return Icons.lightbulb_rounded;
    }
  }
Future<List<PaceCaloriesData>> _fetchAllPaceCaloriesData() async {
  if (userId == null) {
    return [];
  }
  
  try {
    List<PaceCaloriesData> chartData = [];
    
    if (activityData.isNotEmpty) {
      for (var activity in activityData) {
        double elapsedTime = safeParseDouble(activity['elapsed_time']); 
        double distance = safeParseDouble(activity['distance']); 
        double calories = safeParseDouble(activity['calories_burned']);
        String activityName = activity['name'] ?? 'Cycling Activity';
        
        if (activity['start_date'] != null) {
          DateTime date = activity['start_date'].toDate();
          
          if (elapsedTime > 0 && distance > 0 && calories > 0) {
            double paceMinPerKm = (elapsedTime / 60) / distance;
            paceMinPerKm = double.parse(paceMinPerKm.toStringAsFixed(2));
            calories = double.parse(calories.toStringAsFixed(2));
            
            chartData.add(PaceCaloriesData(date, paceMinPerKm, calories, activityName));
          }
        }
      }
    } else {
      QuerySnapshot activitySnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .where('uid', isEqualTo: userId)
          .orderBy('start_date', descending: true)
          .limit(30) 
          .get();
      
      for (var doc in activitySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        
        double elapsedTime = safeParseDouble(data['elapsed_time']); 
        double distance = safeParseDouble(data['distance']); 
        double calories = safeParseDouble(data['calories_burned']);
        String activityName = data['name'] ?? 'Cycling Activity';
        
        if (elapsedTime > 0 && distance > 0 && calories > 0) {
          double paceMinPerKm = (elapsedTime / 60) / distance;
          paceMinPerKm = double.parse(paceMinPerKm.toStringAsFixed(2));
          calories = double.parse(calories.toStringAsFixed(2));
          
          DateTime date = data['start_date'].toDate();
          
          chartData.add(PaceCaloriesData(date, paceMinPerKm, calories, activityName));
        }
      }
    }
    
    return chartData;
  } catch (e) {
    print("Error fetching pace-calories data: $e");
    return [];
  }
}
Widget _buildPaceCaloriesCorrelationGraph() {
  return FutureBuilder<List<PaceCaloriesData>>(
    future: _fetchAllPaceCaloriesData(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildLoadingGraph();
      }

      if (snapshot.hasError || !snapshot.hasData) {
        return _buildEmptyGraph("Error loading pace and calories data");
      }

      List<PaceCaloriesData> chartData = snapshot.data!;
      
      if (chartData.isEmpty) {
        return _buildEmptyGraph("No activities found");
      }

      chartData.sort((a, b) => b.date.compareTo(a.date));

      if (chartData.length > 7) {
        chartData = chartData.sublist(0, 7);
      }

      chartData = chartData.reversed.toList();

      List<String> sessionDates = chartData.map((e) => DateFormat('MM/dd').format(e.date)).toList();
      
      double avgPace = chartData.map((e) => e.pace).reduce((a, b) => a + b) / chartData.length;
      double avgCalories = chartData.map((e) => e.calories).reduce((a, b) => a + b) / chartData.length;
      
      double minCalories = chartData.map((e) => e.calories).reduce(math.min);
      double maxCalories = chartData.map((e) => e.calories).reduce(math.max);
      
      PaceCaloriesData fastestSession = chartData.reduce((a, b) => a.pace < b.pace ? a : b);
      PaceCaloriesData highestCalorieSession = chartData.reduce((a, b) => a.calories > b.calories ? a : b);
      int fastestIdx = chartData.indexOf(fastestSession);
      int highestCalorieIdx = chartData.indexOf(highestCalorieSession);

      return _buildGraphContainer(
        title: "Pace & Calories\nAnalysis",
        subtitle: "Recent Activities",
        height: 2000,
        child: Column(
          children: [
            Expanded(
              child: SfCartesianChart(
                margin: EdgeInsets.all(10),
                primaryXAxis: CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: Colors.grey[700],
                  ),
                ),
                primaryYAxis: NumericAxis(
                  name: 'Calories',
                  labelFormat: '{value} kcal',
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: Colors.orange[700],
                  ),
                  majorGridLines: MajorGridLines(
                    width: 0.5,
                    color: Colors.grey[200],
                    dashArray: <double>[3, 3],
                  ),
                  plotBands: [
                    PlotBand(
                      isVisible: true,
                      start: avgCalories,
                      end: avgCalories,
                      borderColor: Colors.orange,
                      borderWidth: 1,
                      dashArray: <double>[3, 3],
                    )
                  ],
                ),
                axes: <ChartAxis>[
                  NumericAxis(
                    name: 'Pace',
                    opposedPosition: true,
                    labelFormat: '{value} min/km',
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: Colors.blue[700],
                    ),
                    majorGridLines: MajorGridLines(width: 0),
                    isInversed: true, 
                    plotBands: [
                      PlotBand(
                        isVisible: true,
                        start: avgPace,
                        end: avgPace,
                        borderColor: Colors.blue,
                        borderWidth: 1,
                        dashArray: <double>[3, 3],
                      )
                    ],
                  ),
                ],
                series: <ChartSeries>[
                  ColumnSeries<PaceCaloriesData, String>(
                    name: 'Calories',
                    dataSource: chartData,
                    xValueMapper: (PaceCaloriesData data, index) => sessionDates[index],
                    yValueMapper: (PaceCaloriesData data, _) => data.calories,
                    width: 0.6,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange[300]!,
                        Colors.orange[500]!,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    dataLabelSettings: DataLabelSettings(
                      isVisible: false,
                    ),
                    pointColorMapper: (PaceCaloriesData data, _) => 
                      data == highestCalorieSession ? Colors.orange[700] : null,
                  ),
                  // Pace as line chart
                  SplineSeries<PaceCaloriesData, String>(
                    name: 'Pace',
                    dataSource: chartData,
                    xValueMapper: (PaceCaloriesData data, index) => sessionDates[index],
                    yValueMapper: (PaceCaloriesData data, _) => data.pace,
                    yAxisName: 'Pace',
                    color: Colors.blue[600],
                    width: 2.5,
                    markerSettings: MarkerSettings(
                      isVisible: true,
                      shape: DataMarkerType.circle,
                      width: 8,
                      height: 4,
                      borderWidth: 2,
                      borderColor: Colors.white,
                    ),
                    pointColorMapper: (PaceCaloriesData data, _) => 
                      data == fastestSession ? Colors.green[600] : Colors.blue[600],
                  ),
                ],
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  color: Colors.grey[800],
                  textStyle: TextStyle(color: Colors.white, fontSize: 12),
                  header: '',
                ),
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: EdgeInsets.fromLTRB(10, 8, 10, 0),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Column(
                children: [
                  
                  Divider(height: 1, thickness: 5, color: Colors.grey[200]),
                  // Insight message
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _generateEnhancedInsightText(chartData, avgPace, avgCalories, fastestSession, highestCalorieSession),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

String _generateEnhancedInsightText(List<PaceCaloriesData> data, double avgPace, double avgCalories, 
    PaceCaloriesData fastestSession, PaceCaloriesData highestCalorieSession) {
  
  List<PaceCaloriesData> recentSessions = data.length >= 3 ? data.sublist(data.length - 3) : data;
  bool improvingPace = true;
  bool increasingCalories = true;
  
  for (int i = 1; i < recentSessions.length; i++) {
    if (recentSessions[i].pace <= recentSessions[i-1].pace) {
      improvingPace = false;
    }
    if (recentSessions[i].calories <= recentSessions[i-1].calories) {
      increasingCalories = false;
    }
  }
  
  if (fastestSession == highestCalorieSession) {
    return "Your most efficient ride combined both your fastest pace and highest calorie burn. Aim to replicate this intensity level for optimal results.";
  } else if (improvingPace && increasingCalories) {
    return "Great job! Your recent rides show both improving pace and increasing calorie burn. Keep this momentum going.";
  } else if (improvingPace) {
    return "Your pace is getting faster! Focus on maintaining this progression while gradually extending your ride duration to boost calorie burn.";
  } else if (increasingCalories) {
    return "Your calorie burn is trending upward. Try incorporating interval training to improve your pace while maintaining high calorie burn.";
  } else {
    bool aboveAvgPace = data.last.pace < avgPace; 
    bool aboveAvgCalories = data.last.calories > avgCalories;
    
    if (aboveAvgPace && aboveAvgCalories) {
      return "Your latest ride exceeded your average performance in both pace and calories burned. Great progress!";
    } else if (aboveAvgPace) {
      return "Your latest ride was faster than your average pace. Try extending your duration to increase calorie burn.";
    } else if (aboveAvgCalories) {
      return "Your recent calorie burn was above average. Focus on maintaining this while working to improve your pace.";
    } else {
      return "Try mixing high-intensity intervals with longer rides to improve both pace and calorie burn in your next sessions.";
    }
  }
}


Widget _buildCalorieWeightCorrelationGraph() {
  return FutureBuilder<Map<String, dynamic>>(
    future: _fetchWeightAndCalorieData(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildLoadingGraph();
      }

      if (snapshot.hasError || !snapshot.hasData) {
        return _buildEmptyGraph("Error loading correlation data");
      }

      var data = snapshot.data!;
      List<WeightCalorieData> chartData = data['correlationData'];
      
      if (chartData.isEmpty) {
        return _buildEmptyGraph("Not enough data for correlation analysis");
      }

      String correlationStrength = "No correlation";
      String correlationExplanation = "Need more data points to determine correlation.";
      
      bool isInSurplus = false;
      double latestNetCalories = 0;
      
      if (chartData.isNotEmpty) {
        chartData.sort((a, b) => b.date.compareTo(a.date));
        latestNetCalories = chartData[0].netCalories;
        isInSurplus = latestNetCalories >= 0;
      }
      
      if (chartData.length >= 3) {
        double correlationCoefficient = data['correlationCoefficient'];
        
        if (correlationCoefficient < -0.7) {
          correlationStrength = "Strong negative";
          correlationExplanation = isInSurplus ? 
            "Warning: Your caloric surplus is strongly associated with weight gain. Consider reducing calorie intake for better results." : 
            "Great job! Your caloric deficit is strongly associated with weight loss. Continue your current approach.";
        } else if (correlationCoefficient < -0.3) {
          correlationStrength = "Moderate negative";
          correlationExplanation = isInSurplus ? 
            "Note: Your caloric surplus shows moderate association with weight changes. Aim for a deficit to improve results." : 
            "Good progress! Your caloric deficit is showing moderate association with weight loss. Maintain consistency for better results.";
        } else if (correlationCoefficient < 0.3) {
          correlationStrength = "Weak/No correlation";
          correlationExplanation = isInSurplus ? 
            "Your caloric surplus doesn't yet show a clear relationship with weight changes. Consider tracking more consistently." : 
            "Your caloric deficit hasn't yet shown a clear relationship with weight. Ensure you're tracking accurately and consistently.";
        } else if (correlationCoefficient < 0.7) {
          correlationStrength = "Moderate positive";
          correlationExplanation = isInSurplus ? 
            "Caution: Your caloric surplus is moderately associated with weight gain, which may conflict with your goals." : 
            "Unusual pattern: Despite caloric deficits, you're showing moderate weight gain. Consider reviewing tracking accuracy or consulting a professional.";
        } else {
          correlationStrength = "Strong positive";
          correlationExplanation = isInSurplus ? 
            "Warning: Your caloric surplus is strongly driving weight gain, which may hinder your cycling performance goals." : 
            "Unexpected trend: Despite tracking deficits, weight is increasing. Consider reviewing measurement accuracy or consulting a nutritionist.";
        }
      } else {
        correlationExplanation = isInSurplus ? 
          "You're currently in a caloric surplus, which may slow weight loss progress. Track more data for better insights." : 
          "You're currently in a caloric deficit, which supports weight loss goals. Track more data for personalized insights.";
      }

      chartData.sort((a, b) => a.date.compareTo(b.date));
      
      List<WeightCalorieData> surplusData = [];
      List<WeightCalorieData> deficitData = [];
      
      for (var point in chartData) {
        if (point.netCalories >= 0) {
          surplusData.add(point);
        } else {
          deficitData.add(point);
        }
      }

      return _buildGraphContainer(
        title: "Calories &\nWeight Correlation",
        subtitle: isInSurplus ? "Caloric Surplus" : "Caloric Deficit",
        height: 2000,
        child: Column(
          children: [
            Expanded(
              child: SfCartesianChart(
                margin: EdgeInsets.fromLTRB(10, 10, 16, 5),
                zoomPanBehavior: ZoomPanBehavior(
                  enablePinching: true,
                  enablePanning: true,
                  zoomMode: ZoomMode.x,
                ),
                primaryXAxis: DateTimeAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  minorGridLines: MinorGridLines(width: 0),
                  axisLine: AxisLine(width: 1, color: Colors.grey[200]),
                  labelStyle: TextStyle(
                    color: Colors.grey[700],
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  dateFormat: DateFormat('MM/dd'),
                  intervalType: DateTimeIntervalType.days,
                  labelRotation: 0,
                ),
                // Primary Y axis for weight
                primaryYAxis: NumericAxis(
                  name: 'Weight',
                  majorGridLines: MajorGridLines(
                    width: 0.5,
                    color: Colors.grey[200],
                    dashArray: <double>[3, 3],
                  ),
                  axisLine: AxisLine(width: 0),
                  labelFormat: '{value} kg',
                  labelStyle: TextStyle(
                    color: Colors.blue[700],
                    fontFamily: 'Inter',
                    fontSize: 10,
                  ),
                ),
                axes: <ChartAxis>[
                  NumericAxis(
                    name: 'Calories',
                    opposedPosition: true, 
                    majorGridLines: MajorGridLines(width: 0),
                    axisLine: AxisLine(width: 0),
                    labelFormat: '{value} kcal',
                    labelStyle: TextStyle(
                      color: isInSurplus ? Colors.red[700] : Colors.green[700],
                      fontFamily: 'Inter',
                      fontSize: 10,
                    ),
                    plotBands: <PlotBand>[
                      PlotBand(
                        isVisible: true,
                        start: 0,
                        end: 0,
                        borderWidth: 1,
                        borderColor: Colors.grey,
                        dashArray: <double>[5, 5],
                      )
                    ],
                  ),
                ],
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap,
                  textStyle: TextStyle(
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
                  SplineSeries<WeightCalorieData, DateTime>(
                    name: 'Weight (kg)',
                    dataSource: chartData,
                    xValueMapper: (WeightCalorieData data, _) => data.date,
                    yValueMapper: (WeightCalorieData data, _) => data.weight,
                    color: Colors.blue[700],
                    width: 2.5,
                    markerSettings: MarkerSettings(
                      isVisible: true,
                      shape: DataMarkerType.circle,
                      color: Colors.blue[700],
                      borderColor: Colors.white,
                      borderWidth: 2,
                      height: 8,
                      width: 8,
                    ),
                  ),
                  if (surplusData.isNotEmpty)
                    SplineSeries<WeightCalorieData, DateTime>(
                      name: 'Calorie Surplus',
                      dataSource: surplusData,
                      xValueMapper: (WeightCalorieData data, _) => data.date,
                      yValueMapper: (WeightCalorieData data, _) => data.netCalories,
                      yAxisName: 'Calories',
                      color: Colors.red[500],
                      width: 2.0,
                      markerSettings: MarkerSettings(
                        isVisible: true,
                        shape: DataMarkerType.diamond,
                        color: Colors.red[500],
                        borderColor: Colors.white,
                        borderWidth: 1,
                        height: 8,
                        width: 8,
                      ),
                      emptyPointSettings: EmptyPointSettings(
                        mode: EmptyPointMode.gap,
                      ),
                    ),
                  if (deficitData.isNotEmpty)
                    SplineSeries<WeightCalorieData, DateTime>(
                      name: 'Calorie Deficit',
                      dataSource: deficitData,
                      xValueMapper: (WeightCalorieData data, _) => data.date,
                      yValueMapper: (WeightCalorieData data, _) => data.netCalories,
                      yAxisName: 'Calories',
                      color: Colors.green[500],
                      width: 2.0,
                      markerSettings: MarkerSettings(
                        isVisible: true,
                        shape: DataMarkerType.diamond,
                        color: Colors.green[500],
                        borderColor: Colors.white,
                        borderWidth: 1,
                        height: 8,
                        width: 8,
                      ),
                      emptyPointSettings: EmptyPointSettings(
                        mode: EmptyPointMode.gap,
                      ),
                    ),
                ],
                annotations: <CartesianChartAnnotation>[
                  CartesianChartAnnotation(
                    widget: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.green[200]!, width: 1),
                      ),
                      child: Text(
                        'Deficit Zone',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    coordinateUnit: CoordinateUnit.point,
                    x: chartData[0].date,
                    y: -400,
                    yAxisName: 'Calories',
                  ),
                  CartesianChartAnnotation(
                    widget: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.red[200]!, width: 1),
                      ),
                      child: Text(
                        'Surplus Zone',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    coordinateUnit: CoordinateUnit.point,
                    x: chartData[0].date, 
                    y: 400,
                    yAxisName: 'Calories',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4, left: 16, right: 16),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isInSurplus ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isInSurplus ? Colors.red[200]! : Colors.green[200]!, 
                    width: 1
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isInSurplus ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      size: 16, 
                      color: isInSurplus ? Colors.red[700] : Colors.green[700]
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        correlationExplanation,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isInSurplus ? Colors.red[900] : Colors.green[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildLoadingGraph() {
    return Container(
      height: 1000,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: Color(0xffFFA500),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              "Loading your data...",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyGraph(String message) {
    return Container(
      height: 280,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
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
              Icons.insert_chart_outlined_rounded,
              color: Colors.grey[300],
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

Widget _buildGoalBasedGraphs() {
  if (_isLoadingGraphs) {
    return _buildLoadingGraph();
  }
  if (goalType == '-' || _stravaUserId == null) {
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
            SizedBox(height: 18),
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
  List<Widget> goalGraphs = [];

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

  switch (goalType) {
    case 'Leisure':
      goalGraphs.add(_buildSessionsPerWeekGraph());
      break;
    case 'Endurance':
      goalGraphs.add(_buildDistancePerSessionGraph());
      goalGraphs.add(_buildDurationPerSessionGraph());
      break;
    case 'High Intensity Cycling':
      goalGraphs.add(_buildCalorieWeightCorrelationGraph());
      goalGraphs.add(_buildPaceCaloriesCorrelationGraph());
      goalGraphs.add(_buildTemperatureCyclingCorrelationGraph());
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
  if (baselineComparison.isNotEmpty) {
    goalGraphs.add(_buildBaselineComparisonGraph());
  }

  if (goalGraphs.length == 1) {
    return Container(
      height: 320, 
      child: goalGraphs.first,
    );
  }

  return Column(
    children: [
      Container(
        height: 320, 
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

    Map<String, int> sessionsPerDay = {
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };

    for (var activity in activityData) {
      if (activity['start_date'] != null) {
        Timestamp timestamp = activity['start_date'];
        DateTime date = timestamp.toDate();

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
  Widget _buildDistancePerSessionGraph() {
    List<ActivitySessionData> chartData = [];
    int sessionCount = 1;

    for (var activity in activityData.reversed) {
      double distance = safeParseDouble(activity['distance']);

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

  Widget _buildDurationPerSessionGraph() {
    List<ActivitySessionData> chartData = [];
    int sessionCount = 1;

    for (var activity in activityData.reversed) {
  
      double duration = safeParseDouble(activity['elapsed_time']);
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
            color: Color(0xff4CAF50), 
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

   Widget _buildGraphContainer({
    required String title,
    required String subtitle,
    required Widget child,
    double height = 2000,
  }) {
    return Container(
      height: 2000,
      margin: EdgeInsets.only(bottom: 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Fredoka-SemiBold',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xffFFA500).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xffFFA500).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xffFFA500),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ErrorBoundary(child: child),
          ),
        ],
      ),
    );
  }

  Widget _buildBaselineComparisonGraph() {
    if (baselineComparison.isEmpty) {
      return _buildEmptyGraph("No baseline data available yet");
    }

    List<BaselineComparisonData> chartData = [];

    // Add distance comparison if available
    if (baselineComparison.containsKey('activity') &&
        baselineComparison['activity'].containsKey('baselineAvgDistance') &&
        baselineComparison['activity'].containsKey('currentAvgDistance')) {
      double baseline = baselineComparison['activity']['baselineAvgDistance'];
      double current = baselineComparison['activity']['currentAvgDistance'];
      double change = baselineComparison['activity']['distanceChange'];
      chartData
          .add(BaselineComparisonData("Distance", baseline, current, change));
    }

    // Add speed comparison if available
    if (baselineComparison.containsKey('activity') &&
        baselineComparison['activity'].containsKey('baselineAvgSpeed') &&
        baselineComparison['activity'].containsKey('currentAvgSpeed')) {
      double baseline = baselineComparison['activity']['baselineAvgSpeed'];
      double current = baselineComparison['activity']['currentAvgSpeed'];
      double change = baselineComparison['activity']['speedChange'];
      chartData.add(BaselineComparisonData("Speed", baseline, current, change));
    }

    // Add heart rate comparison if available
    if (baselineComparison.containsKey('activity') &&
        baselineComparison['activity'].containsKey('baselineAvgHeartRate') &&
        baselineComparison['activity'].containsKey('currentAvgHeartRate')) {
      double baseline = baselineComparison['activity']['baselineAvgHeartRate'];
      double current = baselineComparison['activity']['currentAvgHeartRate'];
      double change = baselineComparison['activity']['heartRateChange'];
      chartData
          .add(BaselineComparisonData("Heart Rate", baseline, current, change));
    }

    // For High Intensity goal, add body composition metrics
    if (goalType == "High Intensity Cycling" &&
        baselineComparison.containsKey('body')) {
      if (baselineComparison['body'].containsKey('baselineWeight') &&
          baselineComparison['body'].containsKey('currentWeight')) {
        double baseline = baselineComparison['body']['baselineWeight'];
        double current = baselineComparison['body']['currentWeight'];
        double change = baselineComparison['body']['weightChange'];
        chartData
            .add(BaselineComparisonData("Weight", baseline, current, change));
      }

      if (baselineComparison['body'].containsKey('baselineBodyFat') &&
          baselineComparison['body'].containsKey('currentBodyFat')) {
        double baseline = baselineComparison['body']['baselineBodyFat'];
        double current = baselineComparison['body']['currentBodyFat'];
        double change = baselineComparison['body']['bodyFatChange'];
        chartData
            .add(BaselineComparisonData("Body Fat", baseline, current, change));
      }
    }

    return _buildGraphContainer(
      title: "Baseline Comparison",
      subtitle: "Progress from initial week",
      height: 2000, 
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
        legend: Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          overflowMode: LegendItemOverflowMode.wrap,
        ),
        series: <ChartSeries>[
          // Baseline values
          ColumnSeries<BaselineComparisonData, String>(
            name: 'Baseline',
            dataSource: chartData,
            xValueMapper: (BaselineComparisonData data, _) => data.metric,
            yValueMapper: (BaselineComparisonData data, _) =>
                data.baselineValue,
            color: Colors.blue[300],
            width: 0.4,
            spacing: 0.2,
          ),
          // Current values
          ColumnSeries<BaselineComparisonData, String>(
            name: 'Current',
            dataSource: chartData,
            xValueMapper: (BaselineComparisonData data, _) => data.metric,
            yValueMapper: (BaselineComparisonData data, _) => data.currentValue,
            color: Colors.orange[500],
            width: 0.4,
            spacing: 0.2,
          ),
        ],
        annotations: [
          // Add improvement percentage annotations above each metric
          ...chartData.asMap().entries.map((entry) {
            int index = entry.key;
            BaselineComparisonData data = entry.value;
            Color color = data.changePercent > 0
                ? (data.metric == "Heart Rate" ||
                        data.metric == "Weight" ||
                        data.metric == "Body Fat"
                    ? Colors.red
                    : Colors.green)
                : (data.metric == "Heart Rate" ||
                        data.metric == "Weight" ||
                        data.metric == "Body Fat"
                    ? Colors.green
                    : Colors.red);

            return CartesianChartAnnotation(
              widget: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withOpacity(0.3), width: 1),
                ),
                child: Text(
                  '${data.changePercent > 0 ? '+' : ''}${data.changePercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              coordinateUnit: CoordinateUnit.point,
              x: data.metric,
              y: math.max(data.baselineValue, data.currentValue) * 1.1,
            );
          }).toList(),
        ],
      ),
    );
  }
Widget _buildWeeklySummary() {
  var media = MediaQuery.of(context).size;
  
  double weeklyCaloriesBurned = _calculateWeeklyCaloriesBurned();
  double weeklyCaloriesConsumed = _calculateWeeklyCaloriesConsumed();
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Weekly Summary Section Title
      Padding(
        padding: const EdgeInsets.only(left: 5, bottom: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Weekly Summary",
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xffFFA500), Color(0xffFF8C00)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                "This Week",
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      
      // Cards Row 1 - Cycling Sessions and Calories
      Row(
        children: [
          // Cycling Sessions Card
          Expanded(
            child: Container(
              height: media.width * 0.45,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            "Cycling\nSessions",
                            style: TextStyle(
                              fontFamily: 'Fredoka-SemiBold',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xffFFA500).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.directions_bike_rounded,
                            color: Color(0xffFFA500),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [Color(0xffFFA500), Color(0xffFF8C00)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight
                      ).createShader(Rect.fromLTRB(0, 0, bounds.width, bounds.height));
                    },
                    child: Text(
                      "$weeklyActivityCount",
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    "of ${daysPerWeek} goal",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: weeklyActivityCount / (int.tryParse(daysPerWeek) ?? 7),
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xffFFA500)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
          
          // Calories Burned Card
          Expanded(
            child: Container(
              height: media.width * 0.45,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            "Calories\nBurned",
                            style: TextStyle(
                              fontFamily: 'Fredoka-SemiBold',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xffFF7E00).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xffFF7E00),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: [Color(0xffFF7E00), Color(0xffFF5900)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight
                              ).createShader(Rect.fromLTRB(0, 0, bounds.width, bounds.height));
                            },
                            child: Text(
                              "${weeklyCaloriesBurned.toInt()}",
                              style: TextStyle(
                                fontFamily: 'Fredoka-SemiBold',
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            "kcal this week",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Colors.grey[600],
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
        ],
      ),
      
      SizedBox(height: 15),
      
      // Cards Row 2 - Heart Rate and Weight
      Row(
        children: [
          // Heart Rate Card
          Expanded(
            child: Container(
              height: media.width * 0.45,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            "Heart Rate",
                            style: TextStyle(
                              fontFamily: 'Fredoka-SemiBold',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xffFF5900).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.favorite_rounded,
                            color: Color(0xffFF5900),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [Color(0xffFF5900), Color(0xffFF3800)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight
                      ).createShader(Rect.fromLTRB(0, 0, bounds.width, bounds.height));
                    },
                    child: Text(
                      "${latestAverageHeartrate.toInt()}",
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    "bpm avg",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHRZone(
                          "Z1",
                          latestAverageHeartrate <= zone1HeartRate,
                          Colors.green,
                        ),
                        SizedBox(width: 3),
                        _buildHRZone(
                          "Z2",
                          latestAverageHeartrate > zone1HeartRate && 
                          latestAverageHeartrate <= zone2HeartRate,
                          Color(0xffFFA500),
                        ),
                        SizedBox(width: 3),
                        _buildHRZone(
                          "Z3",
                          latestAverageHeartrate > zone2HeartRate && 
                          latestAverageHeartrate <= zone3HeartRate,
                          Color(0xffFF7E00),
                        ),
                        SizedBox(width: 3),
                        _buildHRZone(
                          "Z4",
                          latestAverageHeartrate > zone3HeartRate && 
                          latestAverageHeartrate <= zone4HeartRate,
                          Color(0xffFF5900),
                        ),
                        SizedBox(width: 3),
                        _buildHRZone(
                          "Z5",
                          latestAverageHeartrate > zone4HeartRate,
                          Color(0xffFF3800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
          
          // Weight Card
          Expanded(
            child: Container(
              height: media.width * 0.45,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            "Weight",
                            style: TextStyle(
                              fontFamily: 'Fredoka-SemiBold',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xffFF3800).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.monitor_weight_rounded,
                            color: Color(0xffFF3800),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: [Color(0xffFF3800), Color(0xffE62200)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight
                              ).createShader(Rect.fromLTRB(0, 0, bounds.width, bounds.height));
                            },
                            child: Text(
                              "${weight}",
                              style: TextStyle(
                                fontFamily: 'Fredoka-SemiBold',
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            "kg | ${bodyFat}% fat",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: Center(
                      child: (previousWeight > 0 && latestWeight > 0)
                        ? Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: latestWeight < previousWeight ? 
                                Colors.green.withOpacity(0.1) : 
                                Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  latestWeight < previousWeight ? 
                                    Icons.arrow_downward_rounded : 
                                    Icons.arrow_upward_rounded,
                                  size: 14,
                                  color: latestWeight < previousWeight ? 
                                    Colors.green : Colors.red,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  "${(latestWeight - previousWeight).abs().toStringAsFixed(1)} kg",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: latestWeight < previousWeight ? 
                                      Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SizedBox(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
      SizedBox(height: 15),
      
      // Bottom Card - Caloric Balance
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Caloric Balance",
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xffFFA500).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.equalizer_rounded,
                      color: Color(0xffFFA500),
                      size: 18,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              
              // Single bar balance visualization
              Container(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xffFFA500), Color(0xffFF8C00)],
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            SizedBox(width: 5),
                            Text(
                              "Burned: ${weeklyCaloriesBurned.toInt()} kcal",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xff4CAF50), Color(0xff388E3C)],
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            SizedBox(width: 5),
                            Text(
                              "Consumed: ${weeklyCaloriesConsumed.toInt()} kcal",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    // Balance bar
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            flex: weeklyCaloriesBurned.toInt(),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xffFFA500), Color(0xffFF8C00)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(5),
                                  bottomLeft: Radius.circular(5),
                                  topRight: weeklyCaloriesConsumed == 0 ? Radius.circular(5) : Radius.zero,
                                  bottomRight: weeklyCaloriesConsumed == 0 ? Radius.circular(5) : Radius.zero,
                                ),
                              ),
                            ),
                          ),
                          Flexible(
                            flex: weeklyCaloriesConsumed.toInt(),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xff4CAF50), Color(0xff388E3C)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(5),
                                  bottomRight: Radius.circular(5),
                                  topLeft: weeklyCaloriesBurned == 0 ? Radius.circular(5) : Radius.zero,
                                  bottomLeft: weeklyCaloriesBurned == 0 ? Radius.circular(5) : Radius.zero,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 15),
              
              // Net caloric balance
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: weeklyCaloriesBurned > weeklyCaloriesConsumed ? 
                            [Color(0xffFFA500), Color(0xffFF8C00)] : 
                            [Color(0xff4CAF50), Color(0xff388E3C)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: weeklyCaloriesBurned > weeklyCaloriesConsumed ? 
                              Color(0xffFFA500).withOpacity(0.3) : 
                              Color(0xff4CAF50).withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            weeklyCaloriesBurned > weeklyCaloriesConsumed ? 
                              Icons.trending_down_rounded : 
                              Icons.trending_up_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "Net: ${(weeklyCaloriesBurned - weeklyCaloriesConsumed).abs().toInt()} kcal ${weeklyCaloriesBurned > weeklyCaloriesConsumed ? 'deficit' : 'surplus'}",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              if (nutritionData.isNotEmpty) ...[
                SizedBox(height: 20),
                Divider(),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Latest Meals",
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xffFFA500), Color(0xffFF8C00)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        "Today",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                // Enhanced meal cards in a column layout
                Column(
                  children: [
                    if (nutritionData[0]['breakfast'] != "-")
                      _buildEnhancedMealCard(
                        "B", 
                        "Breakfast",
                        nutritionData[0]['breakfast'],
                        "${nutritionData[0]['breakfast_calories']} kcal",
                        Color(0xffFFA500),
                        Icons.wb_sunny_outlined,
                      ),
                    SizedBox(height: nutritionData[0]['breakfast'] != "-" ? 10 : 0),
                    
                    if (nutritionData[0]['lunch'] != "-")
                      _buildEnhancedMealCard(
                        "L", 
                        "Lunch",
                        nutritionData[0]['lunch'],
                        "${nutritionData[0]['lunch_calories']} kcal",
                        Color(0xffFF7E00),
                        Icons.restaurant_outlined,
                      ),
                    SizedBox(height: nutritionData[0]['lunch'] != "-" ? 10 : 0),
                    
                    if (nutritionData[0]['dinner'] != "-")
                      _buildEnhancedMealCard(
                        "D", 
                        "Dinner",
                        nutritionData[0]['dinner'],
                        "${nutritionData[0]['dinner_calories']} kcal",
                        Color(0xffFF5900),
                        Icons.nightlight_outlined,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildEnhancedMealCard(String letter, String mealType, String mealDesc, String calories, Color color, IconData icon) {
  return TweenAnimationBuilder(
    tween: Tween<double>(begin: 0, end: 1),
    duration: Duration(milliseconds: 800),
    curve: Curves.easeOutBack,
    builder: (context, double value, child) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..translate(0.0, -4.0 * value), // floating effect
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.1), 
                color.withOpacity(0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.12 * value),
                spreadRadius: 1 * value,
                blurRadius: 8 * value,
                offset: Offset(0, 3 * value),
              ),
            ],
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mealType,
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      mealDesc,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  calories,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildHRZone(String zone, bool isActive, Color color) {
  return Container(
    width: 24, // Reduced size slightly
    height: 24, // Reduced size slightly
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: isActive ? color : Colors.grey[200],
      boxShadow: isActive ? [
        BoxShadow(
          color: color.withOpacity(0.3),
          spreadRadius: 1,
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ] : null,
    ),
    child: Center(
      child: Text(
        zone,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10, // Reduced font size
          color: isActive ? Colors.white : Colors.grey[600],
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

// Helper widget for meal cards
Widget _buildMealCard(String letter, String meal, String calories, Color color) {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 3),
    padding: EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                meal,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 27),
          child: Text(
            calories,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
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
    case 1:
      // When navigating back to the recommendation page, simply reload the page
      // instead of creating a new instance
      // This will fix the immediate issue but may cause other state issues
      // A better solution would be to use a state management solution like Provider
      if (_selectedIndex != 1) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RecommendationPage()),
        );
      }
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

