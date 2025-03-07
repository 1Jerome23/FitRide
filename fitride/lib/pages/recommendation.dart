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

  // Baseline values for comparisons
  double baselineDistance = 0.0;
  double baselinePace = 0.0; // in min/km
  double baselineDuration = 0.0; //

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

  // BMR-related metrics
  double calculatedBMR = 0.0;
  double calculatedTDEE = 0.0;
  double recommendedCalorieIntake = 0.0;
  double metabolicEfficiency = 0.0;
  double metabolicHealthScore = 0.0;

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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        hasActiveSubgoal = true; // Make sure this is set to true
        subgoalType = data['subgoalType'];
        subgoalTargetValue = data['targetValue'];
        subgoalStartDate = data['startDate'].toDate();
        subgoalEndDate = data['endDate'].toDate();
        
        // Load stored suggestions and warnings
        if (data.containsKey('suggestions')) {
          subgoalSuggestions = List<String>.from(data['suggestions']);
        }
        
        if (data.containsKey('warnings')) {
          subgoalWarnings = List<String>.from(data['warnings']);
        }
      });
      print("Active subgoal found and loaded: $subgoalType");
    } else {
      // Explicitly set hasActiveSubgoal to false if no active subgoal is found
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
  // Calculate baselines if not already done
  if (baselineDistance == 0.0) {
    _calculateBaselines();
  }
  
  // Generate subgoal title and progress tracking info
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

// Widget to display subgoal selection options
// Modify the _buildSubgoalSelectionCard() method to check if the user has completed their weekly commitment:

Widget _buildSubgoalSelectionCard() {
  if (hasActiveSubgoal || goalType != "High Intensity Cycling") return SizedBox.shrink();
  
  // Get the number of days per week from the user's goal
  int targetDaysPerWeek = int.tryParse(daysPerWeek) ?? 0;
  
  // Check if the user has completed their weekly commitment
  bool hasCompletedWeeklyCommitment = weeklyActivityCount >= targetDaysPerWeek;
  
  // If the user hasn't completed their weekly commitment, show a message instead
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
  
  // Calculate baseline if it hasn't been calculated yet
  if (baselineDistance == 0.0) {
    _calculateBaselines();
  }
  
  // Make sure we have sufficient activity data from the past week
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
  
  // Define goal options based on user's current weekly average performance
  double distanceOption1 = math.max(baselineDistance * 1.1, baselineDistance + 1).roundToDouble(); // 10% increase or +1km
  double distanceOption2 = math.max(baselineDistance * 1.2, baselineDistance + 2).roundToDouble(); // 20% increase or +2km
  
  // For pace, lower is better (faster pace)
  double paceOption1 = baselinePace > 0 ? math.max(baselinePace * 0.95, baselinePace - 0.5) : 0;
  double paceOption2 = baselinePace > 0 ? math.max(baselinePace * 0.9, baselinePace - 1) : 0;
  
  // For duration, longer is more challenging
  double durationOption1 = math.max(baselineDuration * 1.1, baselineDuration + 10).roundToDouble(); // 10% increase or +10 min
  double durationOption2 = math.max(baselineDuration * 1.2, baselineDuration + 15).roundToDouble(); // 20% increase or +15 min
  
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
            Text(
              "Set Your Next Week's Goal",
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green[300]!, width: 1),
              ),
              child: Text(
                "Weekly Goal Completed!",
                style: GoogleFonts.lato(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
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
        
        // Current weekly averages information box
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
        
        // Pace option (if baseline pace is available)
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
        
        // Duration option
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
        
        // Maintain current performance
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
        
        // Weekly average explanation
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
  // We specifically want to calculate weekly averages
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
  
  // If no activities this week, fall back to the most recent activities
  if (thisWeeksActivities.isEmpty) {
    // Get last 5 activities or fewer if less data is available
    int count = math.min(activityData.length, 5);
    thisWeeksActivities = activityData.sublist(0, count);
  }
  
  // Calculate metrics from activities
  for (var activity in thisWeeksActivities) {
    double distance = safeParseDouble(activity['distance']);
    double durationSeconds = safeParseDouble(activity['elapsed_time']);
    double durationMinutes = durationSeconds / 60.0;
    
    if (distance > 0) distances.add(distance);
    if (durationMinutes > 0) durations.add(durationMinutes);
    
    // Calculate pace (minutes per km)
    if (distance > 0 && durationMinutes > 0) {
      double pace = durationMinutes / distance;
      paces.add(pace);
    }
  }
  
  // Calculate averages - these represent the weekly averages
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

// Section title widget helper
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

// Option button widget helper
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

// Widget to display active subgoal
Widget _buildActiveSubgoalCard() {
  if (!hasActiveSubgoal) return SizedBox.shrink();
  
  // Calculate days remaining
  int daysRemaining = subgoalEndDate.difference(DateTime.now()).inDays;
  if (daysRemaining < 0) daysRemaining = 0;
  
  // Calculate current week's average performance
  double currentWeekAvgDistance = 0.0;
  double currentWeekAvgPace = 0.0;
  double currentWeekAvgDuration = 0.0;
  
  // Get activities from the current week for calculating current averages
  DateTime oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
  List<double> currentWeekDistances = [];
  List<double> currentWeekPaces = [];
  List<double> currentWeekDurations = [];
  
  for (var activity in activityData) {
    if (activity['start_date'] != null) {
      DateTime activityDate = activity['start_date'].toDate();
      if (activityDate.isAfter(oneWeekAgo)) {
        double distance = safeParseDouble(activity['distance']);
        double durationSeconds = safeParseDouble(activity['elapsed_time']);
        double durationMinutes = durationSeconds / 60.0;
        
        if (distance > 0) currentWeekDistances.add(distance);
        if (durationMinutes > 0) currentWeekDurations.add(durationMinutes);
        
        // Calculate pace (minutes per km)
        if (distance > 0 && durationMinutes > 0) {
          double pace = durationMinutes / distance;
          currentWeekPaces.add(pace);
        }
      }
    }
  }
  
  // Calculate current week's averages
  if (currentWeekDistances.isNotEmpty) {
    currentWeekAvgDistance = currentWeekDistances.reduce((a, b) => a + b) / currentWeekDistances.length;
  } else {
    // Fall back to latest activity if no weekly data
    currentWeekAvgDistance = latestDistance; 
  }
  
  if (currentWeekPaces.isNotEmpty) {
    currentWeekAvgPace = currentWeekPaces.reduce((a, b) => a + b) / currentWeekPaces.length;
  } else if (latestDistance > 0 && safeParseDouble(sessionDuration) > 0) {
    // Fall back to latest activity if no weekly data
    currentWeekAvgPace = (safeParseDouble(sessionDuration) / 60) / latestDistance;
  } else {
    currentWeekAvgPace = baselinePace;
  }
  
  if (currentWeekDurations.isNotEmpty) {
    currentWeekAvgDuration = currentWeekDurations.reduce((a, b) => a + b) / currentWeekDurations.length;
  } else {
    // Fall back to latest activity if no weekly data
    currentWeekAvgDuration = safeParseDouble(sessionDuration) / 60;
  }
  
  // Calculate progress based on subgoal type using weekly averages
  double progressPercent = 0.0;
  String currentValueText = "";
  String targetValueText = "";
  String baselineValueText = "";
  bool isCompleted = false;
  
  switch (subgoalType) {
    case "distance":
      // Calculate progress using weekly averages
      double baselineDistance = this.baselineDistance; // Average distance from previous week
      double targetDistance = subgoalTargetValue;      // Target average distance for this week
      
      // Calculate progress as a percentage of the additional distance needed
      if (targetDistance > baselineDistance) {
        // Progress is how much of the gap between baseline and target has been covered
        progressPercent = (currentWeekAvgDistance - baselineDistance) / (targetDistance - baselineDistance);
        
        // Check if goal is completed
        isCompleted = currentWeekAvgDistance >= targetDistance;
        
        // Cap progress between 0-100%
        if (progressPercent < 0) progressPercent = 0;
        if (progressPercent > 1) progressPercent = 1;
      } else {
        // If target is somehow lower than baseline, show 100% progress
        progressPercent = 1.0;
        isCompleted = true;
      }
      
      currentValueText = "${currentWeekAvgDistance.toStringAsFixed(1)} km";
      baselineValueText = "${baselineDistance.toStringAsFixed(1)} km";
      targetValueText = "${targetDistance.toStringAsFixed(1)} km";
      break;
      
    case "pace":
      // For pace, lower is better (faster)
      double baselinePace = this.baselinePace;     // Average pace from previous week
      double targetPace = subgoalTargetValue;      // Target average pace for this week
      
      // Calculate progress from baseline to target (remember, for pace lower is better)
      if (baselinePace > targetPace) {
        // Progress is how much of the gap between baseline and target has been covered
        progressPercent = (baselinePace - currentWeekAvgPace) / (baselinePace - targetPace);
        
        // Check if goal is completed
        isCompleted = currentWeekAvgPace <= targetPace;
        
        // Cap progress between 0-100%
        if (progressPercent < 0) progressPercent = 0;
        if (progressPercent > 1) progressPercent = 1;
      } else {
        // If baseline is somehow faster than target, show 100% progress
        progressPercent = 1.0;
        isCompleted = true;
      }
      
      currentValueText = "${currentWeekAvgPace.toStringAsFixed(1)} min/km";
      baselineValueText = "${baselinePace.toStringAsFixed(1)} min/km";
      targetValueText = "${targetPace.toStringAsFixed(1)} min/km";
      break;
      
    case "duration":
      double baselineDuration = this.baselineDuration;  // Average duration from previous week
      double targetDuration = subgoalTargetValue;       // Target average duration for this week
      
      // Calculate progress from baseline to target
      if (targetDuration > baselineDuration) {
        // Progress is how much of the gap between baseline and target has been covered
        progressPercent = (currentWeekAvgDuration - baselineDuration) / (targetDuration - baselineDuration);
        
        // Check if goal is completed
        isCompleted = currentWeekAvgDuration >= targetDuration;
        
        // Cap progress between 0-100%
        if (progressPercent < 0) progressPercent = 0;
        if (progressPercent > 1) progressPercent = 1;
      } else {
        // If target is somehow shorter than baseline, show 100% progress
        progressPercent = 1.0;
        isCompleted = true;
      }
      
      currentValueText = "${currentWeekAvgDuration.toStringAsFixed(0)} min";
      baselineValueText = "${baselineDuration.toStringAsFixed(0)} min";
      targetValueText = "${targetDuration.toStringAsFixed(0)} min";
      break;
      
    case "maintain":
      // For maintenance, we calculate how close the current average is to the baseline
      double baseline = 0.0;
      double current = 0.0;
      double tolerance = 0.0;
      
      switch (subgoalTargetValue.toInt()) {
        case 1: // Maintain distance
          baseline = baselineDistance;
          current = currentWeekAvgDistance;
          tolerance = baseline * 0.1; // 10% tolerance
          break;
        case 2: // Maintain pace
          baseline = baselinePace;
          current = currentWeekAvgPace;
          tolerance = baseline * 0.1; // 10% tolerance
          break;
        case 3: // Maintain duration
          baseline = baselineDuration;
          current = currentWeekAvgDuration;
          tolerance = baseline * 0.1; // 10% tolerance
          break;
        default:
          baseline = baselineDistance;
          current = currentWeekAvgDistance;
          tolerance = baseline * 0.1;
      }
      
      // Calculate how far the current value is from baseline, as a percentage of tolerance
      double deviation = math.cos(current - baseline) / tolerance;
      
      // Convert to a progress percentage (closer to baseline = higher progress)
      progressPercent = 1.0 - math.min(deviation, 1.0);
      
      // For maintain goal, consider it completed after a week of maintenance
      isCompleted = currentWeekDistances.length >= 3 && progressPercent >= 0.8;
      
      currentValueText = "Current: ${currentWeekAvgDistance.toStringAsFixed(1)} km";
      baselineValueText = "Target: Maintain baseline";
      targetValueText = "";
      break;
  }
  
  // Get goal title
  String goalTitle = "";
  
  switch (subgoalType) {
    case "distance":
      goalTitle = "Increase weekly average distance to ${subgoalTargetValue.toStringAsFixed(1)} km";
      break;
    case "pace":
      goalTitle = "Improve weekly average pace to ${subgoalTargetValue.toStringAsFixed(1)} min/km";
      break;
    case "duration":
      goalTitle = "Extend weekly average duration to ${subgoalTargetValue.toStringAsFixed(0)} minutes";
      break;
    case "maintain":
      goalTitle = "Maintain current cycling performance";
      break;
  }
  
  Color progressColor = progressPercent >= 1.0 ? Colors.green[500]! : Colors.orange[500]!;
  
  // If the goal is completed, show completion card
  if (isCompleted && progressPercent >= 1.0) {
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
              Text(
                "Goal Achieved!",
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green[300]!, width: 1),
                ),
                child: Text(
                  "100% Complete",
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            "Congratulations! You've achieved your weekly goal:",
            style: GoogleFonts.lato(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            goalTitle,
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Reset the subgoal
              _resetCompletedSubgoal();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Center(
              child: Text(
                "Set New Goal",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // If not completed, show the regular progress card
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
            Text(
              "This Week's Cycling Goal",
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange[300]!, width: 1),
              ),
              child: Text(
                "$daysRemaining days left",
                style: GoogleFonts.lato(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        // Goal description - clarify this is based on weekly averages
        Text(
          goalTitle,
          style: GoogleFonts.lato(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        
        SizedBox(height: 16),
        
        // Progress visualization with baseline included
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subgoalType != "maintain") ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Last Week's Avg: $baselineValueText",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    "Target Avg: $targetValueText",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Current Avg: $currentValueText",
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold,
                      color: Colors.black87
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentValueText,
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold,
                      color: Colors.black87
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
            ],
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
                  width: MediaQuery.of(context).size.width * 0.7 * progressPercent,
                  decoration: BoxDecoration(
                    color: progressColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              subgoalType == "maintain" 
                  ? "Maintaining consistent performance"
                  : "${(progressPercent * 100).toInt()}% of goal achieved",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (currentWeekDistances.length > 0) ...[
              SizedBox(height: 4),
              Text(
                "Based on ${currentWeekDistances.length} activities this week",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        
        SizedBox(height: 16),
        
        // Divider
        Divider(),
        
        // Suggestions title
        Text(
          "Action Plan:",
          style: GoogleFonts.lato(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        
        SizedBox(height: 8),
        
        // Suggestions list
        Column(
          children: subgoalSuggestions.map((suggestion) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: Colors.green[700]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion,
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
        
        // Warnings if available
        if (subgoalWarnings.isNotEmpty) ...[
          SizedBox(height: 12),
          Text(
            "Important Notes:",
            style: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Column(
            children: subgoalWarnings.map((warning) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_outlined, size: 16, color: Colors.orange[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ],
    ),
  );
}

// Add this method to reset the subgoal
Future<void> _resetCompletedSubgoal() async {
  if (userId == null) return;
  
  try {
    // First, mark the completed subgoal as completed in Firestore
    QuerySnapshot subgoalQuery = await FirebaseFirestore.instance
        .collection('cycling_subgoals')
        .where('userId', isEqualTo: userId)
        .where('endDate', isGreaterThan: DateTime.now())
        .orderBy('endDate', descending: false)
        .limit(1)
        .get();
    
    if (subgoalQuery.docs.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('cycling_subgoals')
          .doc(subgoalQuery.docs.first.id)
          .update({
            'completedAt': DateTime.now(),
            'endDate': DateTime.now(), // Set end date to now so it won't show up in future queries
            'isCompleted': true
          });
    }
    
    // Reset local state
    setState(() {
      hasActiveSubgoal = false;
      subgoalType = "";
      subgoalTargetValue = 0.0;
      subgoalSuggestions = [];
      subgoalWarnings = [];
    });
    
    // Recalculate baselines for the next subgoal
    _calculateBaselines();
  } catch (e) {
    print("Error resetting completed subgoal: $e");
  }
}

  void _calculateBaselineComparison() {
    if (activityData.length < 4) return;

    // Split data into baseline period (first half) and current period (second half)
    int midpoint = activityData.length ~/ 2;
    List<Map<String, dynamic>> baselineActivities =
        activityData.sublist(midpoint);
    List<Map<String, dynamic>> currentActivities =
        activityData.sublist(0, midpoint);

    // Calculate activity metrics
    Map<String, dynamic> activityComparison = {};

    // Distance comparison
    double baselineAvgDistance = baselineActivities
            .map((a) => safeParseDouble(a['distance']))
            .reduce((a, b) => a + b) /
        baselineActivities.length;

    double currentAvgDistance = currentActivities
            .map((a) => safeParseDouble(a['distance']))
            .reduce((a, b) => a + b) /
        currentActivities.length;

    double distanceChange =
        ((currentAvgDistance - baselineAvgDistance) / baselineAvgDistance) *
            100;

    // Speed comparison
    double baselineAvgSpeed = baselineActivities
            .map((a) => safeParseDouble(a['average_speed']))
            .reduce((a, b) => a + b) /
        baselineActivities.length;

    double currentAvgSpeed = currentActivities
            .map((a) => safeParseDouble(a['average_speed']))
            .reduce((a, b) => a + b) /
        currentActivities.length;

    double speedChange =
        ((currentAvgSpeed - baselineAvgSpeed) / baselineAvgSpeed) * 100;

    // Heart rate comparison
    double baselineAvgHeartRate = baselineActivities
            .map((a) => safeParseDouble(a['average_heartrate']))
            .reduce((a, b) => a + b) /
        baselineActivities.length;

    double currentAvgHeartRate = currentActivities
            .map((a) => safeParseDouble(a['average_heartrate']))
            .reduce((a, b) => a + b) /
        currentActivities.length;

    double heartRateChange =
        ((currentAvgHeartRate - baselineAvgHeartRate) / baselineAvgHeartRate) *
            100;

    activityComparison = {
      'baselineAvgDistance': baselineAvgDistance,
      'currentAvgDistance': currentAvgDistance,
      'distanceChange': distanceChange,
      'baselineAvgSpeed': baselineAvgSpeed,
      'currentAvgSpeed': currentAvgSpeed,
      'speedChange': speedChange,
      'baselineAvgHeartRate': baselineAvgHeartRate,
      'currentAvgHeartRate': currentAvgHeartRate,
      'heartRateChange': heartRateChange,
    };

    // For High Intensity goal, add body composition metrics
    if (goalType == "High Intensity Cycling" && recentData.length >= 4) {
      Map<String, dynamic> bodyComparison = {};

      // Split body data for baseline and current periods
      List<Map<String, dynamic>> baselineBody =
          recentData.sublist(recentData.length ~/ 2);
      List<Map<String, dynamic>> currentBody =
          recentData.sublist(0, recentData.length ~/ 2);

      // Weight comparison
      double baselineWeight = baselineBody
              .map((b) => safeParseDouble(b['weight']))
              .reduce((a, b) => a + b) /
          baselineBody.length;

      double currentWeight = currentBody
              .map((b) => safeParseDouble(b['weight']))
              .reduce((a, b) => a + b) /
          currentBody.length;

      double weightChange =
          ((currentWeight - baselineWeight) / baselineWeight) * 100;

      // Body fat comparison
      double baselineBodyFat = baselineBody
              .map((b) => safeParseDouble(b['bodyFat']))
              .reduce((a, b) => a + b) /
          baselineBody.length;

      double currentBodyFat = currentBody
              .map((b) => safeParseDouble(b['bodyFat']))
              .reduce((a, b) => a + b) /
          currentBody.length;

      double bodyFatChange =
          ((currentBodyFat - baselineBodyFat) / baselineBodyFat) * 100;

      bodyComparison = {
        'baselineWeight': baselineWeight,
        'currentWeight': currentWeight,
        'weightChange': weightChange,
        'baselineBodyFat': baselineBodyFat,
        'currentBodyFat': currentBodyFat,
        'bodyFatChange': bodyFatChange,
      };

      baselineComparison = {
        'activity': activityComparison,
        'body': bodyComparison,
      };
    } else {
      baselineComparison = {
        'activity': activityComparison,
      };
    }
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

      // Fetch MORE activities data for historical analysis (increased limit from 10 to 30)
      QuerySnapshot activitiesQuery = await FirebaseFirestore.instance
          .collection('activities')
          .where('uid', isEqualTo: userId)
          .where('start_date', isGreaterThanOrEqualTo: currentGoalTimestamp)
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
        print("Attempting to fetch after_exercise data...");
        QuerySnapshot afterExerciseSnapshot = await FirebaseFirestore.instance
            .collection('after_exercise')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(20) // Increased for better historical analysis
            .get();

        print(
            "Query completed. Document count: ${afterExerciseSnapshot.docs.length}");

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
              airQualityIndex = weatherData[0]['airQualityIndex'] is int
                  ? weatherData[0]['airQualityIndex']
                  : int.tryParse(
                          weatherData[0]['airQualityIndex'].toString()) ??
                      0;

              // Store for comparison if we have multiple weather entries
              latestAirQualityIndex = airQualityIndex;
              if (weatherData.length > 1) {
                previousAirQualityIndex =
                    weatherData[1]['airQualityIndex'] is int
                        ? weatherData[1]['airQualityIndex']
                        : int.tryParse(
                                weatherData[1]['airQualityIndex'].toString()) ??
                            0;
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
              caloriesConsumed =
                  nutritionData[0]['caloriesConsumed'].toString();
            }
          });
        }
      } catch (e) {
        print("Nutrition data collection may not exist: $e");
      }

      // Generate recommendations based on the fetched data
      _generateRecommendation();

      _calculateBaselineComparison();
      if (goalType == "High Intensity Cycling") {
        _calculateBaselines(); // Calculate baseline metrics
        await _fetchActiveSubgoal(); // Check for any active subgoals
      }
      setState(() {
        _isLoadingGraphs = false;
      });
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
      averageDistanceAllTime =
          distances.reduce((a, b) => a + b) / distances.length;
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
      averageHeartrateAllTime =
          heartRates.reduce((a, b) => a + b) / heartRates.length;
      heartrateVariability = _calculateCoeffOfVariation(heartRates);
      heartrateProgression =
          heartRates.reversed.toList(); // Chronological order
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
    isIndoorSeason = temp < 5 ||
        temp > 35 ||
        weatherCondition.toLowerCase().contains("rain") ||
        weatherCondition.toLowerCase().contains("snow") ||
        airQualityIndex > 150;

    if (isIndoorSeason) {
      if (temp < 5) {
        seasonalAdvice =
            "Cold weather season: Consider indoor training options or proper cold-weather gear.";
      } else if (temp > 35) {
        seasonalAdvice =
            "Hot weather season: Early morning rides or indoor training recommended to avoid heat stress.";
      } else if (weatherCondition.toLowerCase().contains("rain") ||
          weatherCondition.toLowerCase().contains("snow")) {
        seasonalAdvice =
            "Inclement weather: Indoor training recommended. If riding outdoors, use appropriate gear.";
      } else if (airQualityIndex > 150) {
        seasonalAdvice =
            "Poor air quality season: Consider indoor training to protect respiratory health.";
      }
    } else {
      seasonalAdvice =
          "Current weather conditions are favorable for outdoor cycling.";
    }
  }

  // Calculate coefficient of variation (statistical measure of relative variability)
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

    // Count consecutive improvements
    consecutiveImprovement = 0;
    for (int i = 1; i < distanceProgression.length; i++) {
      if (distanceProgression[i] > distanceProgression[i - 1]) {
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

  // Calculate BMR-related metrics first to use in all recommendation types
  _calculateDailyCalorieNeeds();
  _analyzeMetabolicHealth();

  // Generate recommendations based on goal type
  switch (goalType) {
    case "Leisure":
      _generateLeisureRecommendations();
      _generateBMRBasedTrainingRecommendations(); // Add BMR-specific training recommendations
      _generateBMRBasedNutritionRecommendations(); // Add BMR-specific nutrition recommendations
      break;
    case "High Intensity Cycling":
      _generateWeightManagementRecommendations();
      _generateBMRBasedTrainingRecommendations(); // Add BMR-specific training recommendations
      _generateBMRBasedNutritionRecommendations(); // Add BMR-specific nutrition recommendations
      break;
    case "Endurance":
      _generateCyclingEnduranceRecommendations();
      _generateBMRBasedTrainingRecommendations(); // Add BMR-specific training recommendations
      _generateBMRBasedNutritionRecommendations(); // Add BMR-specific nutrition recommendations
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

    // Speed progress
    if (speedProgression.length >= 3) {
      double recentAverage = 0;
      double earlierAverage = 0;

      // Compare recent vs earlier speeds
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

      // Air quality recommendations
      if (airQualityIndex > 0) {
        if (airQualityIndex <= 50) {
          healthRecommendations
              .add("AQI: ${airQualityIndex} - Good air quality for riding.");
        } else if (airQualityIndex <= 100) {
          healthRecommendations.add(
              "AQI: ${airQualityIndex} - Moderate. Most can ride without issues.");
        } else if (airQualityIndex <= 150) {
          healthRecommendations.add(
              "AQI: ${airQualityIndex} - Unhealthy for sensitive groups. Consider indoor cycling.");
          if (respiratoryCondition == "Yes") {
            healthRecommendations.add(
                "With respiratory condition, avoid outdoor cycling when AQI > 100.");
          }
        } else if (airQualityIndex <= 200) {
          healthRecommendations.add(
              "AQI: ${airQualityIndex} - Unhealthy. Consider indoor cycling or wear a mask.");
        } else {
          healthRecommendations.add(
              "AQI: ${airQualityIndex} - Very unhealthy. Indoor cycling recommended.");
        }
      }

      if (weatherCondition.toLowerCase().contains("rain")) {
        equipmentRecommendations.add("Rain expected. Use fenders and lights.");
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
  // Check if we have current weight and body fat data
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
    });
  } else {
    setState(() {
      recommendation = "ℹ️ Building Baseline";
      feedback =
          "Track metrics consistently for personalized recommendations.";
    });
  }
}

    // Historical heart rate analysis
    if (heartrateProgression.length >= 3) {
      double avgHistoricalHR = heartrateProgression.reduce((a, b) => a + b) /
          heartrateProgression.length;

      if (avgHistoricalHR < fatBurningZoneLower) {
        trainingRecommendations.add(
            "Your historical average heart rate (${avgHistoricalHR.toInt()} bpm) is below optimal fat-burning zone. Increase intensity in future workouts.");
      } else if (avgHistoricalHR > fatBurningZoneUpper) {
        trainingRecommendations.add(
            "Your historical heart rates average ${avgHistoricalHR.toInt()} bpm, which is quite high. Mix in some Zone 2 (${zone2HeartRate} bpm) training for recovery.");
      }
    }

    // Heart rate recommendations for current workout
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
      trainingRecommendations.add(
          "Of your last ${math.min(activityData.length, 10)} rides, only $totalHighIntensitySessions were at high intensity. Aim for at least 3 per week for weight management.");
    }

    if (lastFiveHeartRates.length >= 3) {
      String hrTrend = lastFiveHeartRates.join(" → ");
      trainingRecommendations.add(
          "Your recent heart rate trend (bpm): $hrTrend. Aim for consistent intensity in the fat-burning zone.");
    }

    // Standard training recommendations
    trainingRecommendations.add(
        "Aim for 3-5 sessions/week with 4-6 intervals (2-3 min high intensity, 2-3 min recovery).");

    if (weeklyActivityCount < 3) {
      trainingRecommendations.add(
          "Increase to at least 3 sessions per week for weight management.");
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
        double avgCaloriesPerSession =
            allCalories.reduce((a, b) => a + b) / allCalories.length;
        double weeklyCalorieBurn = avgCaloriesPerSession * weeklyActivityCount;
        double dailyDeficitFromExercise = weeklyCalorieBurn / 7.0;

        if (dailyDeficitFromExercise < 250) {
          trainingRecommendations.add(
              "Your average workout burns ${avgCaloriesPerSession.toInt()} kcal. Aim for 400-500 kcal daily deficit through longer/intense rides.");
        } else if (dailyDeficitFromExercise > 1000) {
          trainingRecommendations.add(
              "You're burning an average of ${avgCaloriesPerSession.toInt()} kcal per workout, creating a ${dailyDeficitFromExercise.toInt()} kcal daily deficit. Ensure proper fueling.");
        }
      }
    }

    // Weather and air quality
    if (weatherData.isNotEmpty) {
      double currentTemp = safeParseDouble(temperature);

      if (currentTemp > 30) {
        trainingRecommendations.add(
            "Hot weather: Exercise early morning for better fat burning efficiency.");
        nutritionRecommendations
            .add("Drink 750ml-1L fluid/hour with electrolytes in hot weather.");
      }

      // Air quality for weight management
      if (airQualityIndex > 0) {
        if (airQualityIndex <= 50) {
          healthRecommendations.add(
              "AQI: ${airQualityIndex} - Ideal for high-intensity training.");
        } else if (airQualityIndex <= 100) {
          healthRecommendations.add(
              "AQI: ${airQualityIndex} - Monitor breathing during intervals.");
        } else if (airQualityIndex <= 150) {
          healthRecommendations.add(
              "AQI: ${airQualityIndex} - Consider moderate-intensity instead of intervals.");
          if (respiratoryCondition == "Yes") {
            healthRecommendations.add(
                "With respiratory condition, train indoors when AQI > 100.");
          }
        } else {
          healthRecommendations.add(
              "AQI: ${airQualityIndex} - Switch to indoor cycling for today.");
        }
      }
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

    // Nutrition recommendations
    nutritionRecommendations
        .add("Try fasted morning rides (30-45 min) at moderate intensity.");
    nutritionRecommendations
        .add("Stay well-hydrated for metabolism and recovery.");
    nutritionRecommendations.add(
        "Time carbs around workouts - more on training days, less on rest days.");

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
        nutritionRecommendations
            .add("In heat, increase electrolyte intake to prevent cramping.");
      }

      // Air quality for endurance
      if (airQualityIndex > 0) {
        if (airQualityIndex <= 50) {
          healthRecommendations.add(
              "AQI: ${airQualityIndex} - Excellent for long endurance rides.");
        } else if (airQualityIndex <= 100) {
          healthRecommendations.add(
              "AQI: ${airQualityIndex} - Suitable for training. Shorten very long rides if uncomfortable.");
        } else if (airQualityIndex <= 150) {
          healthRecommendations.add(
              "AQI: ${airQualityIndex} - Consider shorter rides or indoor training.");

          if (targetDistanceValue > 80) {
            trainingRecommendations
                .add("With AQI > 100, do shorter rides or train indoors.");
          }
        } else {
          healthRecommendations.add(
              "AQI: ${airQualityIndex} - Switch to indoor training today.");
        }

        // Air quality improvement/deterioration
        if (previousAirQualityIndex > 0 &&
            latestAirQualityIndex < previousAirQualityIndex &&
            latestAirQualityIndex < 100) {
          healthRecommendations
              .add("Air quality improved - good day for a longer session.");
        } else if (previousAirQualityIndex > 0 &&
            latestAirQualityIndex > previousAirQualityIndex &&
            latestAirQualityIndex > 100) {
          healthRecommendations
              .add("Air quality worsened - adjust training plan accordingly.");
        }
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

    // Nutrition recommendations
    nutritionRecommendations
        .add("Rides < 90 mins: water only. Longer rides: 30-60g carbs/hour.");
    nutritionRecommendations
        .add("Practice nutrition strategy during training for events.");
    nutritionRecommendations
        .add("Start fueling early - within first 30 minutes of long rides.");

    if (currentDurationValue > 120) {
      nutritionRecommendations.add(
          "For ${currentDurationValue.toStringAsFixed(0)}-minute rides: ${(currentDurationValue * 0.5).toStringAsFixed(0)}g carbs + electrolytes.");
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

    if (airQualityIndex > 100) {
      equipmentRecommendations.add(
          "Consider pollution mask if outdoor training is necessary in poor air quality.");
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
            if (goalType == "High Intensity Cycling") ...[
            _buildSubgoalSelectionCard(),
            ],
            _buildRecommendationCarousel(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Your Goal Progress",
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
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
                            _buildActivityMetric(
                              "Air Quality",
                              airQualityIndex > 0
                                  ? "AQI: ${airQualityIndex}"
                                  : "N/A",
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
      viewportFraction:
          0.9, // Slightly increase view fraction to reduce clipping
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
        goalGraphs.add(_buildCalorieBalanceGraphWithBMR());
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

  Widget _buildDistancePerSessionGraph() {
    List<ActivitySessionData> chartData = [];
    int sessionCount = 1;

    // Process activity data to extract distance per session
    for (var activity in activityData.reversed) {
      // Use reversed to show oldest to newest
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

  Widget _buildGraphContainer({
    required String title,
    required String subtitle,
    required Widget child,
    double height = 280, // Increase default height from 250 to 280
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
                // Added Flexible here
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                  overflow:
                      TextOverflow.ellipsis, // Handle overflow with ellipsis
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
            child: ErrorBoundary(child: child), // Wrap in ErrorBoundary
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
      height: 300, // Taller to accommodate the chart and annotations
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

  Widget _buildWeeklySummaryGraph() {
    return _buildGraphContainer(
        title: "Weekly Summary",
        subtitle: "Comprehensive view",
        height: 600, // Increase height for this specific graph
        child: SingleChildScrollView(
          // Add scrolling capability
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

                Divider(height: 24),

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

                SizedBox(height: 16),

                // Caloric balance visualization
                Text(
                  "Caloric Balance:",
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),

                LinearProgressIndicator(
                  value: 0.5, // Should calculate from actual data
                  backgroundColor: Colors.green[100],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    latestCaloriesBurned > safeParseDouble(caloriesConsumed)
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Burned: ${(latestCaloriesBurned * weeklyActivityCount).toInt()} kcal",
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    Text(
                      "Consumed: ${safeParseDouble(caloriesConsumed).toInt()} kcal",
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
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

  void _analyzeMetabolicHealth() {
  double bmrValue = safeParseDouble(basalMetabolicRate);
  if (bmrValue <= 0) {
    _calculateDailyCalorieNeeds();
    bmrValue = calculatedBMR;
  }
  
  double weightKg = safeParseDouble(weight);
  double bodyFatPercentage = safeParseDouble(bodyFat);
  
  // Calculate lean body mass
  double leanBodyMass = 0;
  if (weightKg > 0 && bodyFatPercentage > 0) {
    leanBodyMass = weightKg * (1 - (bodyFatPercentage / 100));
  }
  
  // Calculate BMR per kg of lean body mass (metabolic efficiency)
  double bmrPerLeanKg = 0;
  if (leanBodyMass > 0) {
    bmrPerLeanKg = bmrValue / leanBodyMass;
  }
  
  // Calculate heart rate recovery (if available)
  double heartRateRecovery = 0;
  if (activityData.length >= 2) {
    // This would be more accurate with actual recovery data
    double avgRestingHR = 0;
    double avgMaxHR = 0;
    
    // Use this as a placeholder for heart rate recovery analysis
    if (latestAverageHeartrate > 0 && previousAverageHeartrate > 0) {
      avgRestingHR = math.min(latestAverageHeartrate, previousAverageHeartrate);
      avgMaxHR = math.max(latestAverageHeartrate, previousAverageHeartrate);
      heartRateRecovery = avgMaxHR - avgRestingHR;
    }
  }
  
  // Set states for metabolic health indicators
  setState(() {
    metabolicEfficiency = bmrPerLeanKg;
    metabolicHealthScore = _calculateMetabolicHealthScore(
      bmrPerLeanKg: bmrPerLeanKg,
      heartRateRecovery: heartRateRecovery,
      weeklyActivityCount: weeklyActivityCount,
      bodyFatPercentage: bodyFatPercentage
    );
    
    // Generate recommendations based on metabolic health score
    if (metabolicHealthScore > 80) {
      healthRecommendations.add(
        "Excellent metabolic health! Your BMR of ${bmrValue.toInt()} kcal indicates efficient metabolism. Continue your current training pattern."
      );
    } else if (metabolicHealthScore > 60) {
      healthRecommendations.add(
        "Good metabolic health. Your BMR (${bmrValue.toInt()} kcal) shows good efficiency. Add 1-2 Zone 2 sessions weekly to further improve metabolism."
      );
    } else {
      healthRecommendations.add(
        "Room for metabolic improvement. Focus on consistency with 3-4 Zone 2 sessions weekly to increase your metabolic rate from current ${bmrValue.toInt()} kcal baseline."
      );
    }
  });
}

// Helper function to calculate metabolic health score
double _calculateMetabolicHealthScore({
  required double bmrPerLeanKg,
  required double heartRateRecovery,
  required int weeklyActivityCount,
  required double bodyFatPercentage
}) {
  // Basic scoring system - this could be refined with more clinical data
  double score = 50; // Base score
  
  // BMR per lean kg scoring (26-28 is considered good)
  if (bmrPerLeanKg >= 28) score += 25;
  else if (bmrPerLeanKg >= 26) score += 20;
  else if (bmrPerLeanKg >= 24) score += 15;
  else if (bmrPerLeanKg >= 22) score += 10;
  else score += 5;
  
  // Heart rate recovery scoring (higher is better, to a point)
  if (heartRateRecovery >= 50) score += 15;
  else if (heartRateRecovery >= 40) score += 12;
  else if (heartRateRecovery >= 30) score += 8;
  else if (heartRateRecovery >= 20) score += 5;
  
  // Weekly activity scoring
  if (weeklyActivityCount >= 5) score += 15;
  else if (weeklyActivityCount >= 3) score += 10;
  else if (weeklyActivityCount >= 1) score += 5;
  
  // Body fat percentage adjustment
  if (gender.toLowerCase() == "male") {
    if (bodyFatPercentage <= 15) score += 10;
    else if (bodyFatPercentage <= 20) score += 5;
    else if (bodyFatPercentage >= 30) score -= 10;
    else if (bodyFatPercentage >= 25) score -= 5;
  } else {
    if (bodyFatPercentage <= 22) score += 10;
    else if (bodyFatPercentage <= 27) score += 5;
    else if (bodyFatPercentage >= 37) score -= 10;
    else if (bodyFatPercentage >= 32) score -= 5;
  }
  
  // Ensure score stays within 0-100 range
  return math.min(100, math.max(0, score));
}

void _calculateDailyCalorieNeeds() {
  double bmrValue = safeParseDouble(basalMetabolicRate);
  
  // If BMR is not available, estimate it
  if (bmrValue <= 0) {
    // Estimate BMR using Mifflin-St Jeor Equation
    double weightKg = safeParseDouble(weight);
    double heightCm = safeParseDouble(height);
    
    if (weightKg > 0 && heightCm > 0 && age > 0) {
      if (gender.toLowerCase() == "male") {
        bmrValue = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
      } else {
        bmrValue = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
      }
    } else {
      // Default fallback if data is missing
      bmrValue = gender.toLowerCase() == "male" ? 1800 : 1400;
    }
  }
  
  // Calculate TDEE (Total Daily Energy Expenditure) with activity level
  double activityMultiplier = 1.2; // Sedentary default
  
  // Adjust multiplier based on weekly activity count
  if (weeklyActivityCount >= 5) {
    activityMultiplier = 1.725; // Very active (6-7 times per week)
  } else if (weeklyActivityCount >= 3) {
    activityMultiplier = 1.55; // Moderate activity (3-5 times per week)
  } else if (weeklyActivityCount >= 1) {
    activityMultiplier = 1.375; // Light activity (1-3 times per week)
  }
  
  double tdee = bmrValue * activityMultiplier;
  
  // Store these calculated values for use in recommendations
  setState(() {
    calculatedBMR = bmrValue;
    calculatedTDEE = tdee;
    
    // Calculate deficit or surplus based on goal type
    if (goalType == "High Intensity Cycling") {
      // For weight loss, calculate recommended deficit
      recommendedCalorieIntake = tdee - 500; // 500 calorie deficit for weight loss
      
      // Set minimum calorie floor based on gender to avoid unhealthy restriction
      double minimumCalories = gender.toLowerCase() == "male" ? 1500 : 1200;
      if (recommendedCalorieIntake < minimumCalories) {
        recommendedCalorieIntake = minimumCalories;
      }
    } else if (goalType == "Endurance") {
      // For endurance, calculate recommended surplus or maintenance
      recommendedCalorieIntake = tdee + 300; // Slight surplus for energy needs
    } else {
      // For leisure, maintenance is appropriate
      recommendedCalorieIntake = tdee;
    }
  });
}

// 2. Enhanced nutrition recommendations based on BMR
void _generateBMRBasedNutritionRecommendations() {
  // Make sure we have calculated the values
  if (calculatedBMR <= 0) {
    _calculateDailyCalorieNeeds();
  }
  
  // Clear existing nutrition recommendations
  nutritionRecommendations.clear();
  
  // Add BMR-based nutrition recommendations
  if (goalType == "High Intensity Cycling") {
    nutritionRecommendations.add(
      "With your BMR of ${calculatedBMR.toInt()} kcal, aim for ${recommendedCalorieIntake.toInt()} kcal daily intake for weight loss."
    );
    
    double proteinNeeds = safeParseDouble(weight) * 1.8; // 1.8g per kg for high intensity
    nutritionRecommendations.add(
      "Consume ${proteinNeeds.toInt()}g of protein daily to preserve muscle during weight loss."
    );
    
    // Calculate calorie target for different days
    double trainingDayCalories = recommendedCalorieIntake + 200;
    double restDayCalories = recommendedCalorieIntake - 100;
    nutritionRecommendations.add(
      "Cycling days: ${trainingDayCalories.toInt()} kcal. Rest days: ${restDayCalories.toInt()} kcal."
    );
    
    // Add more specific nutrition timing recommendations
    nutritionRecommendations.add(
      "For optimal fat loss, consume 25% of daily calories before rides and 30% within 2 hours after."
    );
  } 
  else if (goalType == "Endurance") {
    nutritionRecommendations.add(
      "With your BMR of ${calculatedBMR.toInt()} kcal, aim for ${recommendedCalorieIntake.toInt()} kcal daily for endurance training."
    );
    
    // Calculate carb recommendations for endurance
    double carbsInGrams = (recommendedCalorieIntake * 0.6) / 4; // 60% calories from carbs, 4 calories per gram
    nutritionRecommendations.add(
      "Consume ${carbsInGrams.toInt()}g of carbs daily, with higher intake (${(carbsInGrams * 0.4).toInt()}g) before long rides."
    );
    
    // Calculate time-based nutrition windows
    int rideDuration = safeParseDouble(sessionDuration).toInt() ~/ 60; // Convert seconds to minutes
    if (rideDuration > 90) {
      int carbsPerHour = (rideDuration > 150) ? 90 : 60; // Higher intake for rides over 2.5 hours
      nutritionRecommendations.add(
        "For your ${rideDuration} minute rides, consume ${carbsPerHour}g carbs per hour during activity."
      );
    }
  } 
  else { // Leisure
    nutritionRecommendations.add(
      "With your BMR of ${calculatedBMR.toInt()} kcal, aim for ${recommendedCalorieIntake.toInt()} kcal daily to maintain weight."
    );
    
    nutritionRecommendations.add(
      "For leisure rides, proper hydration is more important than nutrition timing. Aim for 500ml of water per hour of riding."
    );
  }
  
  // Add general BMR-related nutrition advice
  nutritionRecommendations.add(
    "Never eat below your BMR of ${calculatedBMR.toInt()} kcal to maintain proper organ function and metabolic health."
  );
  
  // Adjust recommendations based on day of week patterns
  if (mostFrequentDay.isNotEmpty) {
    nutritionRecommendations.add(
      "Increase carbohydrate intake the day before your typical ${mostFrequentDay} rides for better performance."
    );
  }
}

// 3. Enhanced training recommendations using BMR for optimal intensity
void _generateBMRBasedTrainingRecommendations() {
  // Clear existing training recommendations
  trainingRecommendations.clear();
  
  // Calculate target heart rate zones based on BMR efficiency
  double bmrPerKg = calculatedBMR / safeParseDouble(weight);
  
  // BMR efficiency can indicate metabolic health - higher BMR/kg generally indicates better metabolic health
  bool efficientMetabolism = bmrPerKg > 24; // Benchmark value
  
  if (goalType == "High Intensity Cycling") {
    if (efficientMetabolism) {
      trainingRecommendations.add(
        "Your BMR of ${calculatedBMR.toInt()} kcal indicates efficient metabolism. Focus on higher intensity intervals (Zone 4-5) for fat loss."
      );
      
      // Recommend more anaerobic work for those with efficient metabolism
      trainingRecommendations.add(
        "Include 2 HIIT sessions weekly: 30s all-out effort, 90s recovery, 8-10 repeats."
      );
    } else {
      trainingRecommendations.add(
        "Your BMR of ${calculatedBMR.toInt()} kcal suggests room for metabolic improvement. Build base with Zone 2 (${zone2HeartRate} bpm) training."
      );
      
      // Recommend more aerobic work to improve metabolic efficiency
      trainingRecommendations.add(
        "Focus on 45-60 min Zone 2 rides (${zone2HeartRate} bpm) to increase metabolic efficiency before adding intense intervals."
      );
    }
    
    // Calculate optimal workout duration based on BMR
    int optimalDuration = (calculatedBMR * 0.012).toInt(); // Rough formula
    trainingRecommendations.add(
      "Based on your metabolic rate, aim for approximately ${optimalDuration} minute workouts for optimal fat burning."
    );
  } 
  else if (goalType == "Endurance") {
    // For endurance, calculate ideal training zones based on metabolic efficiency
    if (efficientMetabolism) {
      trainingRecommendations.add(
        "Your efficient metabolism (BMR ${calculatedBMR.toInt()} kcal) supports high training volume. Aim for weekly increases of 10% to total distance."
      );
    } else {
      trainingRecommendations.add(
        "With your BMR of ${calculatedBMR.toInt()} kcal, focus on building metabolic efficiency. Limit Zone 3+ work to 20% of your total training volume."
      );
    }
    
    // Calculate ideal long ride duration based on BMR and weight
    double maxRecommendedRideDuration = calculatedBMR * 0.1 / safeParseDouble(weight) * 60; // Convert to minutes
    trainingRecommendations.add(
      "Your longest weekly ride should build toward ${maxRecommendedRideDuration.toInt()} minutes as your endurance improves."
    );
  }
  else { // Leisure
    trainingRecommendations.add(
      "For leisure riding with your BMR of ${calculatedBMR.toInt()} kcal, aim for 3-4 weekly rides of 30-45 minutes in Zone 2 (${zone2HeartRate} bpm)."
    );
  }
  
  // Add recovery recommendations based on metabolic rate
  int recommendedRecoveryHours = efficientMetabolism ? 24 : 36;
  trainingRecommendations.add(
    "With your metabolic rate, allow ${recommendedRecoveryHours} hours between high-intensity sessions for proper recovery."
  );
}

  Widget _buildCalorieBalanceGraphWithBMR() {
  // Define the data for the graph including BMR line
  List<Map<String, dynamic>> dailyData = [];
  DateTime now = DateTime.now();
  
  // Make sure BMR is calculated
  double bmrValue = calculatedBMR > 0 ? calculatedBMR : safeParseDouble(basalMetabolicRate);
  if (bmrValue <= 0) {
    _calculateDailyCalorieNeeds();
    bmrValue = calculatedBMR;
  }
  
  // Generate last 7 days data
  for (int i = 6; i >= 0; i--) {
    DateTime date = now.subtract(Duration(days: i));
    String dayLabel = DateFormat('E').format(date);
    
    // Find activities on this day
    double dayCaloriesBurned = 0;
    for (var activity in activityData) {
      if (activity['start_date'] != null) {
        DateTime activityDate = activity['start_date'].toDate();
        if (activityDate.year == date.year && activityDate.month == date.month && activityDate.day == date.day) {
          dayCaloriesBurned += safeParseDouble(activity['calories_burned']);
        }
      }
    }
    
    // Find nutrition data for this day
    double dayCaloriesConsumed = 0;
    for (var nutrition in nutritionData) {
      if (nutrition['timestamp'] != null) {
        DateTime nutritionDate = nutrition['timestamp'].toDate();
        if (nutritionDate.year == date.year && nutritionDate.month == date.month && nutritionDate.day == date.day) {
          dayCaloriesConsumed += safeParseDouble(nutrition['caloriesConsumed']);
        }
      }
    }
    
    // Add to daily data with BMR included
    dailyData.add({
      'day': dayLabel,
      'caloriesBurned': dayCaloriesBurned,
      'tdee': bmrValue + dayCaloriesBurned, // Total daily energy expenditure
      'bmr': bmrValue, // Base metabolic rate line
      'caloriesConsumed': dayCaloriesConsumed > 0 ? dayCaloriesConsumed : null,
      'balance': (bmrValue + dayCaloriesBurned) - (dayCaloriesConsumed > 0 ? dayCaloriesConsumed : 0)
    });
  }
  
  return _buildGraphContainer(
    title: "Energy Balance with BMR",
    subtitle: "Last 7 days",
    height: 320,
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
        labelFormat: '{value} kcal',
        labelStyle: TextStyle(
          color: Colors.grey[700],
          fontFamily: 'Inter',
          fontSize: 10,
        ),
      ),
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        overflowMode: LegendItemOverflowMode.wrap,
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        color: Colors.grey[800],
        textStyle: TextStyle(color: Colors.white, fontSize: 12),
      ),
      series: <ChartSeries>[
        // BMR base line
        LineSeries<Map<String, dynamic>, String>(
          name: 'BMR (${bmrValue.toInt()} kcal)',
          dataSource: dailyData,
          xValueMapper: (data, _) => data['day'],
          yValueMapper: (data, _) => data['bmr'],
          color: Colors.purple[700],
          width: 2,
          dashArray: <double>[5, 5], // Dashed line
        ),
        // Total Daily Energy Expenditure (BMR + Activity)
        AreaSeries<Map<String, dynamic>, String>(
          name: 'TDEE',
          dataSource: dailyData,
          xValueMapper: (data, _) => data['day'],
          yValueMapper: (data, _) => data['tdee'],
          color: Colors.green[400]!.withOpacity(0.5),
          borderColor: Colors.green[600],
          borderWidth: 2,
        ),
        // Calories Consumed
        ColumnSeries<Map<String, dynamic>, String>(
          name: 'Calories Consumed',
          dataSource: dailyData.where((d) => d['caloriesConsumed'] != null).toList(),
          xValueMapper: (data, _) => data['day'],
          yValueMapper: (data, _) => data['caloriesConsumed'],
          color: Colors.orange[500],
          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        ),
        // Calorie Balance (Net)
        LineSeries<Map<String, dynamic>, String>(
          name: 'Net Balance',
          dataSource: dailyData.where((d) => d['caloriesConsumed'] != null).toList(),
          xValueMapper: (data, _) => data['day'],
          yValueMapper: (data, _) => data['balance'],
          color: Colors.blue[700],
          width: 2,
          markerSettings: MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            color: Colors.blue[700],
            borderColor: Colors.white,
            borderWidth: 2,
            height: 6,
            width: 6,
          ),
        ),
      ],
    )
  );
}

bool _isSubgoalCompleted() {
  if (!hasActiveSubgoal) return false;
  
  // Get current week's performance metrics
  double currentWeekAvgDistance = 0.0;
  double currentWeekAvgPace = 0.0;
  double currentWeekAvgDuration = 0.0;
  
  // Calculate current week stats from activities
  if (activityData.isNotEmpty) {
    List<double> distances = [];
    List<double> durations = [];
    List<double> paces = [];
    
    // Get activities from the current week
    DateTime oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
    
    for (var activity in activityData) {
      if (activity['start_date'] != null) {
        DateTime activityDate = activity['start_date'].toDate();
        if (activityDate.isAfter(oneWeekAgo)) {
          double distance = safeParseDouble(activity['distance']);
          double durationSeconds = safeParseDouble(activity['elapsed_time']);
          double durationMinutes = durationSeconds / 60.0;
          
          if (distance > 0) distances.add(distance);
          if (durationMinutes > 0) durations.add(durationMinutes);
          
          // Calculate pace (minutes per km)
          if (distance > 0 && durationMinutes > 0) {
            double pace = durationMinutes / distance;
            paces.add(pace);
          }
        }
      }
    }
    
    // Calculate averages
    if (distances.isNotEmpty) {
      currentWeekAvgDistance = distances.reduce((a, b) => a + b) / distances.length;
    }
    
    if (durations.isNotEmpty) {
      currentWeekAvgDuration = durations.reduce((a, b) => a + b) / durations.length;
    }
    
    if (paces.isNotEmpty) {
      currentWeekAvgPace = paces.reduce((a, b) => a + b) / paces.length;
    }
  }
  Future<void> _resetCompletedSubgoal() async {
  if (userId == null) return;
  
  try {
    // First, mark the completed subgoal as completed in Firestore
    QuerySnapshot subgoalQuery = await FirebaseFirestore.instance
        .collection('cycling_subgoals')
        .where('userId', isEqualTo: userId)
        .where('endDate', isGreaterThan: DateTime.now())
        .orderBy('endDate', descending: false)
        .limit(1)
        .get();
    
    if (subgoalQuery.docs.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('cycling_subgoals')
          .doc(subgoalQuery.docs.first.id)
          .update({
            'completedAt': DateTime.now(),
            'endDate': DateTime.now(), // Set end date to now so it won't show up in future queries
            'isCompleted': true
          });
    }
    
    // Reset local state
    setState(() {
      hasActiveSubgoal = false;
      subgoalType = "";
      subgoalTargetValue = 0.0;
      subgoalSuggestions = [];
      subgoalWarnings = [];
    });
    
    // Recalculate baselines for the next subgoal
    _calculateBaselines();
  } catch (e) {
    print("Error resetting completed subgoal: $e");
  }
}
  // Check completion based on subgoal type
  switch (subgoalType) {
    case "distance":
      return currentWeekAvgDistance >= subgoalTargetValue;
    case "pace":
      // For pace, lower is better (faster)
      return currentWeekAvgPace <= subgoalTargetValue;
    case "duration":
      return currentWeekAvgDuration >= subgoalTargetValue;
    case "maintain":
      // Maintain goals are considered complete after a week
      return subgoalEndDate.isBefore(DateTime.now());
    default:
      return false;
  }
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

//updated recommendation page without sub-goals