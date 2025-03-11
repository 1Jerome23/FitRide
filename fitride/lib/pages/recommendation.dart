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
  
  // Set state variables
  setState(() {
    hasActiveSubgoal = true;
    subgoalType = type;
    subgoalTargetValue = targetValue;
    subgoalStartDate = DateTime.now();
    subgoalEndDate = DateTime.now().add(Duration(days: 7));
    subgoalSuggestions = suggestions;
    subgoalWarnings = warnings;
  });
  
  // Store in Firestore
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
          // Update food data for recommendations
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
  // Clear previous recommendations
  nutritionRecommendations.clear();
  
  // Check if we have recent nutrition data
  if (nutritionData.isEmpty) {
    nutritionRecommendations.add("Complete your food diary to get personalized nutrition recommendations.");
    return;
  }
  
  // Get latest food entry
  var latestFoodEntry = nutritionData[0];
  double totalCalories = safeParseDouble(latestFoodEntry['total_calories'].toString());
  double breakfastCalories = safeParseDouble(latestFoodEntry['breakfast_calories'].toString());
  double lunchCalories = safeParseDouble(latestFoodEntry['lunch_calories'].toString());
  double dinnerCalories = safeParseDouble(latestFoodEntry['dinner_calories'].toString());
  
  // Calculate caloric needs based on activity level and goal
  double bmr = safeParseDouble(basalMetabolicRate);
  // Activity factor based on goal type
  double activityFactor = 1.2; // Base sedentary
  if (goalType == "Leisure") {
    activityFactor = 1.375; // Lightly active
  } else if (goalType == "Endurance") {
    activityFactor = 1.55; // Moderately active
  } else if (goalType == "High Intensity Cycling") {
    activityFactor = 1.725; // Very active
  }
  
  double dailyCalorieNeeds = bmr * activityFactor;
  
  // Generate recommendations based on meal distribution and overall intake
  if (totalCalories < dailyCalorieNeeds * 0.7) {
    nutritionRecommendations.add("Your calorie intake is significantly below your estimated needs (${dailyCalorieNeeds.toInt()} kcal). Consider increasing your intake for optimal performance.");
  } else if (totalCalories > dailyCalorieNeeds * 1.2 && goalType == "High Intensity Cycling") {
    nutritionRecommendations.add("Your calorie intake exceeds your calculated needs by ${(totalCalories - dailyCalorieNeeds).toInt()} kcal. Adjust portion sizes to align with your weight management goals.");
  }
  
  // Meal distribution recommendations
  double breakfastPercent = totalCalories > 0 ? (breakfastCalories / totalCalories) * 100 : 0;
  double lunchPercent = totalCalories > 0 ? (lunchCalories / totalCalories) * 100 : 0;
  double dinnerPercent = totalCalories > 0 ? (dinnerCalories / totalCalories) * 100 : 0;
  
  if (breakfastPercent < 20 && totalCalories > 0) {
    nutritionRecommendations.add("Your breakfast (${breakfastPercent.toInt()}% of daily calories) is smaller than recommended. Aim for 20-25% of daily calories at breakfast for sustained energy.");
  }
  
  // Tailored lunch content recommendations based on goal type
  if (goalType == "Endurance") {
    nutritionRecommendations.add("For endurance training, include a balanced lunch with lean protein, complex carbs, and healthy fats. Good options include whole grain sandwiches with lean protein, pasta with vegetables, or grain bowls.");
    // If an afternoon ride is likely
    nutritionRecommendations.add("If cycling in the afternoon, have a lunch rich in complex carbs 2-3 hours before your ride, and include easily digestible foods.");
  } else if (goalType == "High Intensity Cycling") {
    nutritionRecommendations.add("For high-intensity training, your lunch should include quality protein (chicken, fish, tofu, legumes) paired with complex carbs and plenty of vegetables.");
    nutritionRecommendations.add("If training within 2 hours after lunch, keep the meal lighter and focus on easily digestible carbs with moderate protein.");
  } else if (goalType == "Leisure") {
    nutritionRecommendations.add("For leisure cycling, focus on balanced lunches with colorful vegetables, lean proteins, and whole grains. This supports general health and provides steady energy for casual rides.");
  }
  // Activity-specific recommendations
  if (goalType == "Endurance") {
    nutritionRecommendations.add("For endurance training, focus on complex carbs (50-60% of calories) like whole grains, fruits, and starchy vegetables.");
    
    // If activity data exists, add specific pre-ride recommendations
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

// Method to save the subgoal to Firestore
void _saveCyclingSubgoalToFirestore(String type, double targetValue, List<String> suggestions, List<String> warnings) {
  try {
    FirebaseFirestore.instance.collection('cycling_subgoals').add({
      'userId': userId,
      'subgoalType': type,
      'targetValue': targetValue, // This is the target weekly average
      'baselineDistance': baselineDistance, // Current weekly average
      'baselinePace': baselinePace,
      'baselineDuration': baselineDuration,
      'suggestions': suggestions,
      'warnings': warnings,
      'startDate': subgoalStartDate,
      'endDate': subgoalEndDate,
      'createdAt': DateTime.now(),
      'isWeeklyAverage': true, // Flag to indicate this is a weekly average goal
    });
  } catch (e) {
    print("Error saving cycling subgoal: $e");
  }
}

Widget _buildFoodItem(String meal, String description, String calories) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            meal[0], // First letter
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[800],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                calories,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
            style: GoogleFonts.roboto(
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
          // Wrap the Text in Expanded to prevent overflow
          Expanded(
            child: Text(
              "Set Your Next Week's Goal",
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis, // Truncate if too long
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
                () => _setCyclingSubgoal("distance", distanceOption1),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildSubgoalOptionButton(
                "Challenging",
                "${distanceOption2.toStringAsFixed(1)} km/ride",
                "From ${baselineDistance.toStringAsFixed(1)} km avg",
                Colors.blue[900]!,
                () => _setCyclingSubgoal("distance", distanceOption2),
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
                  () => _setCyclingSubgoal("pace", paceOption1),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildSubgoalOptionButton(
                  "Challenging",
                  "${paceOption2.toStringAsFixed(1)} min/km",
                  "From ${baselinePace.toStringAsFixed(1)} min/km avg",
                  Colors.orange[900]!,
                  () => _setCyclingSubgoal("pace", paceOption2),
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
                () => _setCyclingSubgoal("duration", durationOption1),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildSubgoalOptionButton(
                "Challenging",
                "${durationOption2.toStringAsFixed(0)} min/ride",
                "From ${baselineDuration.toStringAsFixed(0)} min avg",
                Colors.green[900]!,
                () => _setCyclingSubgoal("duration", durationOption2),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16),
        
        _buildSubgoalOptionTitle("Maintain Current Level", Icons.equalizer_outlined),
        SizedBox(height: 8),
        InkWell(
          onTap: () => _setCyclingSubgoal("maintain", 0),
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
  VoidCallback onTap
) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            baseline,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
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
        safeParseDouble(sessionDuration) / 60; // Convert to minutes

    // Heart rate zones
    double maxHeartRate = 220 - age.toDouble();
    double enduranceZoneLower = maxHeartRate * 0.65; // 65% of max HR
    double enduranceZoneUpper = maxHeartRate * 0.75; // 75% of max HR
    double thresholdZoneLower = maxHeartRate * 0.76; // 76% of max HR
    double thresholdZoneUpper = maxHeartRate * 0.90; // 90% of max HR

    // Latest HR
    double latestHeartRate = safeParseDouble(averageHeartrate);

    // Primary feedback based on recent activities
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
      // Calculate the long-term trend
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
            if (goalType == "High Intensity Cycling") ...[
            _buildSubgoalSelectionCard(),
            ],
            _buildRecommendationCarousel(),
            SizedBox(height: 16),
            _buildGoalBasedGraphs(),
            SizedBox(height: 24),
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
                      style:
                          GoogleFonts.lato(fontSize: 16, color: Colors.orange),
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
                    formattedDate =
                        DateFormat('MMM d, y • h:mm a').format(startDate);
                  }

                  // Convert elapsed time to hours:minutes format
                  String duration = "N/A";
                  int elapsedSeconds = 0;
                  if (data['elapsed_time'] != null) {
                    elapsedSeconds =
                        int.tryParse(data['elapsed_time'].toString()) ?? 0;
                    int hours = elapsedSeconds ~/ 3600;
                    int minutes = (elapsedSeconds % 3600) ~/ 60;
                    duration =
                        hours > 0 ? "${hours}h ${minutes}m" : "${minutes}m";
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
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
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
      viewportFraction:
          0.9, // Slightly increase view fraction to reduce clipping
    );

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          children: [
            Container(
              height: 350, // Fixed height for carousel
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
                    color: currentPage == index
                        ? recommendationCategories[index]["color"]
                        : Colors.grey[300],
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
      String title, IconData icon, Color color, List<String> recommendations) {
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
                          style: GoogleFonts.lato(
                              fontSize: 14, color: Colors.black87),
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
                xValueMapper: (MetricData data, _) => data.date.toString(),
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

  // Function that decides which graph to display based on goal type
  Widget _buildGoalBasedGraphs() {
    // If loading, show a loading indicator
    if (_isLoadingGraphs) {
      return _buildLoadingGraph();
    }

    // If the user goal is unknown or if Strava is not connected, show a message
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
    List<Widget> goalGraphs = [];
    goalGraphs.add(_buildWeeklySummaryGraph());

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

    switch (goalType) {
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
        goalGraphs.add(_buildBMRTrendGraph());
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

    // If there's only one graph, return it directly
    if (goalGraphs.length == 1) {
      return Container(
        height: 320, // Increased from 250
        child: goalGraphs.first,
      );
    }

    // Otherwise, create a carousel with page indicator
    return Column(
      children: [
        Container(
          height: 320, // Increased from 250
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
    double height = 280,
  }) {
    return Container(
      height: height,
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
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                  overflow:
                      TextOverflow.ellipsis, 
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
                    fontSize: 10,
                    color: Colors.grey[700],
                    fontFamily: "Inter",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
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
      height: 300, 
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
Widget _buildBMRTrendGraph() {
  return FutureBuilder<QuerySnapshot>(
    future: FirebaseFirestore.instance
        .collection('userData')
        .where('uid', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(10) // Get the last 10 entries
        .get(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildLoadingGraph();
      }

      if (snapshot.hasError ||
          !snapshot.hasData ||
          snapshot.data!.docs.isEmpty) {
        return _buildEmptyGraph("No BMR tracking data available");
      }

      List<MetricData> chartData = [];
      
      // Check if we have at least 2 entries to show a trend
      if (snapshot.data!.docs.length < 2) {
        return _buildEmptyGraph("Need more data to show BMR trend");
      }

      // Process the data in chronological order (oldest first)
      for (var doc in snapshot.data!.docs.reversed) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('basalMetabolicRate')) {
          double bmr = safeParseDouble(data['basalMetabolicRate']);
          
          // Get the timestamp for the x-axis
          Timestamp timestamp = data['timestamp'];
          DateTime date = timestamp.toDate();
          
          // Format date for display
          String dateLabel = DateFormat('MM/dd HH:mm').format(date);
          
          if (bmr > 0) { // Only add valid BMR readings
            chartData.add(MetricData(dateLabel, bmr));
          }
        }
      }
      
      // If after filtering we don't have enough data
      if (chartData.length < 2) {
        return _buildEmptyGraph("Need more BMR data to show trend");
      }

      return _buildGraphContainer(
        title: "Basal Metabolic Rate Trend",
        subtitle: "Changes over time",
        child: SfCartesianChart(
          margin: EdgeInsets.fromLTRB(10, 10, 10, 10),
          primaryXAxis: CategoryAxis(
            majorGridLines: MajorGridLines(width: 0),
            axisLine: AxisLine(width: 1, color: Colors.grey[200]),
            labelStyle: TextStyle(
              color: Colors.grey[700],
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            labelRotation: 0,
          ),
          primaryYAxis: NumericAxis(
            majorGridLines: MajorGridLines(
              width: 0.5,
              color: Colors.grey[200],
              dashArray: <double>[3, 3],
            ),
            axisLine: AxisLine(width: 0),
            labelFormat: '{value} kcal',
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
            format: 'BMR: point.y kcal\nDate: point.x',
          ),
          series: <ChartSeries>[
            SplineSeries<MetricData, String>(
              dataSource: chartData,
              xValueMapper: (MetricData data, _) => data.date,
              yValueMapper: (MetricData data, _) => data.value,
              color: Colors.orange, // Purple for BMR
              width: 3,
              markerSettings: MarkerSettings(
                isVisible: true,
                shape: DataMarkerType.circle,
                color: Colors.orange,
                borderColor: Colors.white,
                borderWidth: 2,
                height: 8,
                width: 8,
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
                useSeriesColor: true,
              ),
            ),
          ],
          // Add annotations to highlight important information
          annotations: <CartesianChartAnnotation>[
            CartesianChartAnnotation(
              widget: Container(
                padding: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.orange[200]!, width: 1),
                ),
              ),
              coordinateUnit: CoordinateUnit.point,
              x: chartData[chartData.length ~/ 2].date,
              y: chartData.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 0.9,
            ),
          ],
        ),
      );
    },
  );
}
Widget _buildWeeklySummaryGraph() {

  double weeklyCaloriesBurned = _calculateWeeklyCaloriesBurned();
  double weeklyCaloriesConsumed = _calculateWeeklyCaloriesConsumed();

  double balanceRatio = weeklyCaloriesConsumed > 0 ? 
  weeklyCaloriesBurned / weeklyCaloriesConsumed : 0.5;
  balanceRatio = balanceRatio > 1 ? 1 : (balanceRatio < 0 ? 0 : balanceRatio);

  return _buildGraphContainer(
    title: "Weekly Summary",
    subtitle: "Comprehensive view",
    height: 600, 
    child: SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary statistics
            Text(
              "Week Summary",
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),

            // Cycling sessions
            _buildSummaryItem(
              "Cycling Sessions",
              "${weeklyActivityCount}",
              icon: Icons.directions_bike_outlined,
              color: Color(0xffFFA500),
            ),

            // Total calories burned
            _buildSummaryItem(
              "Calories Burned",
              "${(latestCaloriesBurned * weeklyActivityCount).toInt()} kcal",
              icon: Icons.local_fire_department_outlined,
              color: Colors.red[400]!,
            ),

            // Average heart rate
            _buildSummaryItem(
              "Avg HR",
              "${latestAverageHeartrate.toInt()} bpm",
              icon: Icons.favorite_outline,
              color: Colors.pink[400]!,
            ),

            // Add nutrition summary if available
            if (nutritionData.isNotEmpty) ...[
              Divider(height: 24),
              
              Text(
                "Nutrition Summary",
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              
              // Latest food diary entry
              _buildSummaryItem(
                "Daily Calories",
                "${safeParseDouble(caloriesConsumed).toInt()} kcal",
                icon: Icons.restaurant_outlined,
                color: Colors.green[600]!,
              ),
            
            ],

            Divider(height: 24),
            
            // Food diary summary if available
            if (nutritionData.isNotEmpty) ...[
              Text(
                "Latest Food Diary",
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              
              if (nutritionData[0]['breakfast'] != "-")
                _buildFoodItem("Breakfast", nutritionData[0]['breakfast'], 
                  "${nutritionData[0]['breakfast_calories'].toInt()} kcal"),
              
              if (nutritionData[0]['lunch'] != "-")
                _buildFoodItem("Lunch", nutritionData[0]['lunch'], 
                  "${nutritionData[0]['lunch_calories'].toInt()} kcal"),
              
              if (nutritionData[0]['dinner'] != "-")
                _buildFoodItem("Dinner", nutritionData[0]['dinner'], 
                  "${nutritionData[0]['dinner_calories'].toInt()} kcal"),
              
              Divider(height: 24),
            ],

            // Body composition changes
            Row(
              children: [
                Expanded(
                  child: _buildChangeItem(
                    "Weight",
                    "$weight kg",
                    previousWeight > 0
                        ? "${(latestWeight - previousWeight).toStringAsFixed(1)} kg"
                        : "N/A",
                    isPositive: latestWeight < previousWeight,
                    reverseColor: true,
                  ),
                ),
                Expanded(
                  child: _buildChangeItem(
                    "Body Fat",
                    "$bodyFat%",
                    previousBodyFat > 0
                        ? "${(latestBodyFat - previousBodyFat).toStringAsFixed(1)}%"
                        : "N/A",
                    isPositive: latestBodyFat < previousBodyFat,
                    reverseColor: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            Text(
              "Weekly Caloric Balance:",
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),

            LinearProgressIndicator(
              value: balanceRatio,
              backgroundColor: Colors.green[100],
              valueColor: AlwaysStoppedAnimation<Color>(
                weeklyCaloriesBurned > weeklyCaloriesConsumed
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Burned: ${weeklyCaloriesBurned.toInt()} kcal",
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                Text(
                  "Consumed: ${weeklyCaloriesConsumed.toInt()} kcal",
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
            // Add a net caloric balance row
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: weeklyCaloriesBurned > weeklyCaloriesConsumed
                        ? Colors.green[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: weeklyCaloriesBurned > weeklyCaloriesConsumed
                          ? Colors.green.withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    "Net: ${(weeklyCaloriesBurned - weeklyCaloriesConsumed).toInt()} kcal",
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold,
                      color: weeklyCaloriesBurned > weeklyCaloriesConsumed
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
// Helper method for summary items
  Widget _buildSummaryItem(String label, String value,
      {required IconData icon, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

// Helper method for change items
  Widget _buildChangeItem(String label, String value, String change,
      {required bool isPositive, bool reverseColor = false}) {
    final Color changeColor = isPositive
        ? (reverseColor ? Colors.green[700]! : Colors.red[700]!)
        : (reverseColor ? Colors.red[700]! : Colors.green[700]!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 2),
        if (change != "N/A")
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                size: 12,
                color: changeColor,
              ),
              SizedBox(width: 2),
              Text(
                change,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: changeColor,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Color _getRecommendationColor(String recommendation) {
    if (recommendation.contains("✅") ||
        recommendation.contains("Good") ||
        recommendation.contains("Improving") ||
        recommendation.contains("Progress")) {
      return Colors.green[700]!;
    } else if (recommendation.contains("⚠️") ||
        recommendation.contains("Warning") ||
        recommendation.contains("Needs") ||
        recommendation.contains("Decreasing")) {
      return Colors.orange[700]!;
    } else if (recommendation.contains("❌") || recommendation.contains("Bad")) {
      return Colors.red[700]!;
    } else if (recommendation.contains("ℹ️") ||
        recommendation.contains("Info") ||
        recommendation.contains("Building") ||
        recommendation.contains("In Progress")) {
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

