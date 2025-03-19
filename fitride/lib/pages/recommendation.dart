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

class _AnimatedAutoSizingOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final String title;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;
  final List<String> recommendations;

  const _AnimatedAutoSizingOverlay({
    required this.onDismiss,
    required this.title,
    required this.icon,
    required this.color,
    required this.gradientColors,
    required this.recommendations,
  });

  @override
  _AnimatedAutoSizingOverlayState createState() =>
      _AnimatedAutoSizingOverlayState();
}

class _AnimatedFullscreenOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final String title;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;
  final List<String> recommendations;

  const _AnimatedFullscreenOverlay({
    required this.onDismiss,
    required this.title,
    required this.icon,
    required this.color,
    required this.gradientColors,
    required this.recommendations,
  });

  @override
  _AnimatedFullscreenOverlayState createState() =>
      _AnimatedFullscreenOverlayState();
}

class PieEfficiencyData {
  final String sessionLabel;
  final double efficiency;
  final bool isBest;

  PieEfficiencyData(this.sessionLabel, this.efficiency, this.isBest);
}

class PaceCaloriesData {
  final DateTime date;
  final double pace;
  final double calories;
  final String activityName;
  final double? weight;

  PaceCaloriesData(
      this.date, this.pace, this.calories, this.activityName, this.weight);
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

class NutritionActivityData {
  final DateTime date;
  final double? totalCalories;
  final double? totalCarbs;
  final double? totalFat;
  final double? totalProtein;
  final double? elapsedTime;
  final double? distance;
  final double? averageSpeed;

  NutritionActivityData({
    required this.date,
    this.totalCalories,
    this.totalCarbs,
    this.totalFat,
    this.totalProtein,
    this.elapsedTime,
    this.distance,
    this.averageSpeed,
  });
}

class RecommendationPage extends StatefulWidget {
  @override
  _RecommendationPageState createState() => _RecommendationPageState();
}

class TemperatureActivityData {
  final double temperature;
  final double speed;
  final double distance;
  final double duration;
  final DateTime date;

  TemperatureActivityData(
      this.temperature, this.speed, this.distance, this.duration, this.date);
}

class HeartRateSpeedData {
  final DateTime date;
  final double heartRate;
  final double speed;
  final String activityName;

  HeartRateSpeedData(this.date, this.heartRate, this.speed, this.activityName);
}

class HeartRateZoneData {
  final String zoneName;
  final double averageSpeed;
  final int activityCount;
  final Color zoneColor;

  HeartRateZoneData(
      this.zoneName, this.averageSpeed, this.activityCount, this.zoneColor);
}

class ErrorBoundary extends StatelessWidget {
  final Widget child;

  const ErrorBoundary({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext context) {
        try {
          return child;
        } catch (e, stackTrace) {
          print('Error in graph rendering: $e\n$stackTrace');

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

  DateTime baselineStartDate = DateTime.now();
  DateTime baselineEndDate = DateTime.now();
  String? userId = FirebaseAuth.instance.currentUser?.uid;
  List<Map<String, dynamic>> recentData = [];
  List<Map<String, dynamic>> activityData = [];
  List<Map<String, dynamic>> weatherData = [];
  List<Map<String, dynamic>> nutritionData = [];
  Map<String, dynamic> baselineComparison = {};
  bool hasActiveSubgoal = false;
  String subgoalType = "";
  double subgoalTargetValue = 0.0;
  DateTime subgoalStartDate = DateTime.now();
  DateTime subgoalEndDate = DateTime.now().add(Duration(days: 7));
  List<String> subgoalSuggestions = [];
  List<String> subgoalWarnings = [];

  double baselineDistance = 0.0;
  double baselinePace = 0.0;
  double baselineDuration = 0.0;

  double previousWeekDistance = 0.0;
  double previousWeekPace = 0.0;
  double previousWeekDuration = 0.0;

  bool usingPreviousGoal = false;
  double referenceDistance = 0.0;
  double referencePace = 0.0;
  double referenceDuration = 0.0;

  String recommendation = "Loading...";
  String feedback = "";
  bool showAllLogs = false;

  PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoadingGraphs = true;
  String? _stravaUserId;
  String goalType = "-";
  String currentLevel = "0";
  String daysPerWeek = "0";
  String targetDistance = "0";
  String targetWeight = "0";
  String targetDuration = "0";

  int age = 0;
   String gender = "-"; 
  String healthCondition = "-";
  String respiratoryCondition = "No";
  String cardiovascularCondition = "No";
  String height = "0";
  String weight = "0";
  String bodyFat = "0";
  String basalMetabolicRate = "0";

  String levelOfExertion = "0";
  String averageHeartrate = "0";
  String averageSpeed = "0";
  String caloriesBurned = "0";
  String distance = "0";
  String sessionDuration = "0";

  String temperature = "0";
  String humidity = "0";
  String weatherCondition = "-";
  String airQuality = "Good";

  String foodIntake = "-";
  String foodType = "-";
  String caloriesConsumed = "0";

  int recommendedHeartRate = 0;
  int maxHeartRateCalculated = 0;
  int zone1HeartRate = 0;
  int zone2HeartRate = 0;
  int zone3HeartRate = 0;
  int zone4HeartRate = 0;
  int zone5HeartRate = 0;

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

  Future<List<HeartRateSpeedData>> _fetchHeartRateSpeedData() async {
    if (userId == null) return [];

    try {
      List<HeartRateSpeedData> chartData = [];

      QuerySnapshot activitySnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .where('uid', isEqualTo: userId)
          .orderBy('start_date', descending: true)
          .limit(30)
          .get();

      for (var doc in activitySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        double heartRate = safeParseDouble(data['average_heartrate']);
        double speed = safeParseDouble(data['average_speed']);
        String activityName = data['name'] ?? 'Cycling Activity';

        if (data['start_date'] != null && heartRate > 0 && speed > 0) {
          DateTime date = data['start_date'].toDate();

          chartData
              .add(HeartRateSpeedData(date, heartRate, speed, activityName));
        }
      }

      chartData.sort((a, b) => a.date.compareTo(b.date));

      return chartData;
    } catch (e) {
      print("Error fetching heart rate and speed data: $e");
      return [];
    }
  }

  Widget _buildHeartRateSpeedGraph() {
    return FutureBuilder<List<HeartRateSpeedData>>(
      future: _fetchHeartRateSpeedData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGraph();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildEmptyGraph("Error loading heart rate and speed data");
        }

        List<HeartRateSpeedData> data = snapshot.data!;

        if (data.isEmpty) {
          return _buildEmptyGraph("No activities with heart rate data found");
        }

        double correlationValue = 0.0;
        String correlationText = "Insufficient data for correlation analysis";

        if (data.length >= 3) {
          List<double> heartRates = data.map((e) => e.heartRate).toList();
          List<double> speeds = data.map((e) => e.speed).toList();

          correlationValue = _calculatePearsonCorrelation(heartRates, speeds);

          if (correlationValue > 0.7) {
            correlationText =
                "Strong positive correlation (${correlationValue.toStringAsFixed(2)}). Higher heart rates consistently increase your speed.";
          } else if (correlationValue > 0.4) {
            correlationText =
                "Moderate positive correlation (${correlationValue.toStringAsFixed(2)}). Your speed tends to increase with heart rate.";
          } else if (correlationValue > 0.2) {
            correlationText =
                "Weak positive correlation (${correlationValue.toStringAsFixed(2)}). Your speed is somewhat affected by heart rate.";
          } else if (correlationValue > -0.2) {
            correlationText =
                "No significant correlation (${correlationValue.toStringAsFixed(2)}). Your speed varies independently of your heart rate.";
          } else if (correlationValue > -0.4) {
            correlationText =
                "Weak negative correlation (${correlationValue.toStringAsFixed(2)}). Lower heart rates sometimes relate to higher speeds.";
          } else if (correlationValue > -0.7) {
            correlationText =
                "Moderate negative correlation (${correlationValue.toStringAsFixed(2)}). Unusual pattern - your speed decreases with higher heart rates.";
          } else {
            correlationText =
                "Strong negative correlation (${correlationValue.toStringAsFixed(2)}). Unusual pattern - your speed significantly decreases with higher heart rates.";
          }
        }

        double minSpeed = data.map((e) => e.speed).reduce(math.min);
        double maxSpeed = data.map((e) => e.speed).reduce(math.max);

        double speedRange = maxSpeed - minSpeed;
        double speedMin = math.max(0, minSpeed - (speedRange * 0.1));
        double speedMax = maxSpeed + (speedRange * 0.1);

        List<HeartRateZoneData> zoneData = [];

        if (age > 0) {
          List<HeartRateSpeedData> zone1Points = [];
          List<HeartRateSpeedData> zone2Points = [];
          List<HeartRateSpeedData> zone3Points = [];
          List<HeartRateSpeedData> zone4Points = [];
          List<HeartRateSpeedData> zone5Points = [];

          for (var point in data) {
            if (point.heartRate < zone2HeartRate) {
              zone1Points.add(point);
            } else if (point.heartRate < zone3HeartRate) {
              zone2Points.add(point);
            } else if (point.heartRate < zone4HeartRate) {
              zone3Points.add(point);
            } else if (point.heartRate < zone5HeartRate) {
              zone4Points.add(point);
            } else {
              zone5Points.add(point);
            }
          }

          if (zone1Points.isNotEmpty) {
            double avgSpeed =
                zone1Points.map((e) => e.speed).reduce((a, b) => a + b) /
                    zone1Points.length;
            zoneData.add(HeartRateZoneData(
                'Zone 1', avgSpeed, zone1Points.length, Colors.green[700]!));
          } else {
            zoneData.add(HeartRateZoneData('Zone 1', 0, 0, Colors.green[700]!));
          }

          if (zone2Points.isNotEmpty) {
            double avgSpeed =
                zone2Points.map((e) => e.speed).reduce((a, b) => a + b) /
                    zone2Points.length;
            zoneData.add(HeartRateZoneData(
                'Zone 2', avgSpeed, zone2Points.length, Colors.green[400]!));
          } else {
            zoneData.add(HeartRateZoneData('Zone 2', 0, 0, Colors.green[400]!));
          }

          if (zone3Points.isNotEmpty) {
            double avgSpeed =
                zone3Points.map((e) => e.speed).reduce((a, b) => a + b) /
                    zone3Points.length;
            zoneData.add(HeartRateZoneData(
                'Zone 3', avgSpeed, zone3Points.length, Colors.orange[400]!));
          } else {
            zoneData
                .add(HeartRateZoneData('Zone 3', 0, 0, Colors.orange[400]!));
          }

          if (zone4Points.isNotEmpty) {
            double avgSpeed =
                zone4Points.map((e) => e.speed).reduce((a, b) => a + b) /
                    zone4Points.length;
            zoneData.add(HeartRateZoneData(
                'Zone 4', avgSpeed, zone4Points.length, Colors.red[400]!));
          } else {
            zoneData.add(HeartRateZoneData('Zone 4', 0, 0, Colors.red[400]!));
          }

          if (zone5Points.isNotEmpty) {
            double avgSpeed =
                zone5Points.map((e) => e.speed).reduce((a, b) => a + b) /
                    zone5Points.length;
            zoneData.add(HeartRateZoneData(
                'Zone 5', avgSpeed, zone5Points.length, Colors.red[700]!));
          } else {
            zoneData.add(HeartRateZoneData('Zone 5', 0, 0, Colors.red[700]!));
          }
        }

        if (zoneData.isEmpty) {
          return _buildEmptyGraph(
              "Heart rate zones not available - enter your age in profile");
        }

        return _buildGraphContainer(
          title: "Speed by\nHeart Rate Zone",
          subtitle: "Training Zone Analysis",
          height: 340,
          child: Column(
            children: [
              // Main chart
              Expanded(
                child: SfCartesianChart(
                  margin: EdgeInsets.all(10),
                  plotAreaBorderWidth: 0,
                  primaryXAxis: CategoryAxis(
                    title: AxisTitle(
                      text: 'Heart Rate Zones',
                      textStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                    majorGridLines: MajorGridLines(
                      width: 0,
                    ),
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: Colors.grey[700],
                    ),
                  ),
                  primaryYAxis: NumericAxis(
                    title: AxisTitle(
                      text: 'Average Speed (km/h)',
                      textStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                    minimum: speedMin,
                    maximum: speedMax,
                    interval: 2,
                    majorGridLines: MajorGridLines(
                      width: 0.5,
                      color: Colors.grey[200],
                      dashArray: <double>[3, 3],
                    ),
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: Colors.grey[700],
                    ),
                    labelFormat: '{value} km/h',
                  ),
                  series: <ChartSeries>[
                    LineSeries<HeartRateZoneData, String>(
                      name: 'Average Speed',
                      dataSource: zoneData,
                      xValueMapper: (HeartRateZoneData zone, _) =>
                          zone.zoneName,
                      yValueMapper: (HeartRateZoneData zone, _) =>
                          zone.averageSpeed,
                      color: Colors.blue[600],
                      width: 2.5,
                      markerSettings: MarkerSettings(
                        isVisible: true,
                        shape: DataMarkerType.circle,
                        height: 8,
                        width: 8,
                        borderWidth: 2,
                        borderColor: Colors.white,
                      ),
                      pointColorMapper: (HeartRateZoneData zone, _) =>
                          zone.zoneColor,
                      enableTooltip: true,
                    ),
                  ],
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    builder: (dynamic data, dynamic point, dynamic series,
                        int pointIndex, int seriesIndex) {
                      HeartRateZoneData zoneData = data;
                      return Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              zoneData.zoneName,
                              style: TextStyle(
                                color: zoneData.zoneColor,
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Speed: ${zoneData.averageSpeed.toStringAsFixed(1)} km/h",
                              style: TextStyle(
                                color: Colors.blue[300],
                                fontFamily: 'Inter',
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              "Activities: ${zoneData.activityCount}",
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Inter',
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  legend: Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    overflowMode: LegendItemOverflowMode.wrap,
                  ),
                ),
              ),

              // Zone description
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildZoneIndicator(
                          "Zone 1", "50-60%", Colors.green[700]!),
                      SizedBox(width: 8),
                      _buildZoneIndicator(
                          "Zone 2", "60-70%", Colors.green[400]!),
                      SizedBox(width: 8),
                      _buildZoneIndicator(
                          "Zone 3", "70-80%", Colors.orange[400]!),
                      SizedBox(width: 8),
                      _buildZoneIndicator("Zone 4", "80-90%", Colors.red[400]!),
                      SizedBox(width: 8),
                      _buildZoneIndicator(
                          "Zone 5", "90-100%", Colors.red[700]!),
                    ],
                  ),
                ),
              ),

              // Correlation insight box
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
                      size: 18,
                    ),
                    SizedBox(width: 5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            correlationText,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Colors.grey[800],
                              height: 1.2,
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

  Widget _buildRecommendationCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Color> gradientColors,
    List<String> recommendations, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      // InkWell provides better touch response than GestureDetector
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // List view (scrollable)
            Expanded(
              child: NotificationListener<OverscrollIndicatorNotification>(
                onNotification: (overscroll) {
                  overscroll.disallowIndicator();
                  return true;
                },
                child: ListView.builder(
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  itemCount:
                      recommendations.length > 3 ? 3 : recommendations.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: color.withOpacity(0.1), width: 1),
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
            ),

            // Tap indicator
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(color: color.withOpacity(0.1), width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 16,
                    color: color,
                  ),
                  SizedBox(width: 6),
                  Text(
                    recommendations.length > 3
                        ? "Tap to view all ${recommendations.length} tips"
                        : "Tap to expand",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullscreenOverlay(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Color> gradientColors,
    List<String> recommendations,
  ) {
    // Declare the overlayEntry as late - it will be initialized before use
    late OverlayEntry overlayEntry;

    // Define the builder function separately
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        child: _AnimatedAutoSizingOverlay(
          onDismiss: () {
            overlayEntry.remove();
          },
          title: title,
          icon: icon,
          color: color,
          gradientColors: gradientColors,
          recommendations: recommendations,
        ),
      ),
    );

    // Show the overlay
    Overlay.of(context).insert(overlayEntry);
  }

// Helper widget for zone indicators
  Widget _buildZoneIndicator(String zoneName, String zoneRange, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            height: 10,
            width: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 4),
          Text(
            "$zoneName ($zoneRange)",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<List<NutritionActivityData>> _fetchNutritionActivityData() async {
    if (userId == null) return [];

    try {
      // Fetch food entries data
      QuerySnapshot foodSnapshot = await FirebaseFirestore.instance
          .collection('food_entries')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(30)
          .get();

      // Fetch activity data
      QuerySnapshot activitySnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .where('uid', isEqualTo: userId)
          .orderBy('start_date', descending: true)
          .limit(30)
          .get();

      // Map food entries by date
      Map<String, Map<String, dynamic>> foodByDate = {};
      for (var doc in foodSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        if (data['date'] != null) {
          DateTime date = data['date'].toDate();
          String dateKey = DateFormat('yyyy-MM-dd').format(date);

          foodByDate[dateKey] = {
            'totalCalories': safeParseDouble(data['total_calories']),
            'totalCarbs': safeParseDouble(data['total_carbs']),
            'totalFat': safeParseDouble(data['total_fat']),
            'totalProtein': safeParseDouble(data['total_protein']),
            'date': date,
          };
        }
      }

      // Map activities by date
      Map<String, Map<String, dynamic>> activitiesByDate = {};
      for (var doc in activitySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        if (data['start_date'] != null) {
          DateTime date = data['start_date'].toDate();
          String dateKey = DateFormat('yyyy-MM-dd').format(date);

          if (activitiesByDate.containsKey(dateKey)) {
            double existingDistance =
                safeParseDouble(activitiesByDate[dateKey]!['distance']);
            double newDistance = safeParseDouble(data['distance']);

            if (newDistance > existingDistance) {
              activitiesByDate[dateKey] = {
                'elapsedTime': safeParseDouble(data['elapsed_time']) / 60,
                'distance': safeParseDouble(data['distance']),
                'averageSpeed': safeParseDouble(data['average_speed']),
                'date': date,
              };
            }
          } else {
            activitiesByDate[dateKey] = {
              'elapsedTime': safeParseDouble(data['elapsed_time']) /
                  60, // Convert to minutes
              'distance': safeParseDouble(data['distance']),
              'averageSpeed': safeParseDouble(data['average_speed']),
              'date': date,
            };
          }
        }
      }

      List<NutritionActivityData> combinedData = [];

      Set<String> allDates = {...foodByDate.keys, ...activitiesByDate.keys};

      for (String dateKey in allDates) {
        var foodData = foodByDate[dateKey];
        var activityData = activitiesByDate[dateKey];

        if (foodData != null && activityData != null) {
          combinedData.add(NutritionActivityData(
            date: foodData['date'],
            totalCalories: foodData['totalCalories'],
            totalCarbs: foodData['totalCarbs'],
            totalFat: foodData['totalFat'],
            totalProtein: foodData['totalProtein'],
            elapsedTime: activityData['elapsedTime'],
            distance: activityData['distance'],
            averageSpeed: activityData['averageSpeed'],
          ));
        }
      }

      // Sort by date (oldest to newest)
      combinedData.sort((a, b) => a.date.compareTo(b.date));

      return combinedData;
    } catch (e) {
      print("Error fetching nutrition and activity data: $e");
      return [];
    }
  }

  Widget _buildNutritionActivityGraph() {
    return FutureBuilder<List<NutritionActivityData>>(
      future: _fetchNutritionActivityData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGraph();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildEmptyGraph("Error loading nutrition and activity data");
        }

        List<NutritionActivityData> data = snapshot.data!;

        if (data.isEmpty) {
          return _buildEmptyGraph(
              "No matching nutrition and activity data found");
        }

        // Default selections
        String selectedNutritionMetric = 'totalCalories';
        String selectedActivityMetric = 'averageSpeed';

        return StatefulBuilder(
          builder: (context, setState) {
            return _buildGraphContainer(
              title: "Nutrition &\nPerformance",
              subtitle: "Correlation Analysis",
              height: 340, // Match other graphs
              child: Column(
                children: [
                  // Main chart section
                  Expanded(
                    child: SfCartesianChart(
                      margin: EdgeInsets.all(10),
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
                      ),
                      primaryYAxis: NumericAxis(
                        name: 'Nutrition',
                        majorGridLines: MajorGridLines(
                          width: 0.5,
                          color: Colors.grey[200],
                          dashArray: <double>[3, 3],
                        ),
                        axisLine: AxisLine(width: 0),
                        labelFormat:
                            _getNutritionYAxisFormat(selectedNutritionMetric),
                        labelStyle: TextStyle(
                          color: _getNutritionColor(selectedNutritionMetric),
                          fontFamily: 'Inter',
                          fontSize: 10,
                        ),
                      ),
                      axes: <ChartAxis>[
                        NumericAxis(
                          name: 'Activity',
                          opposedPosition: true,
                          majorGridLines: MajorGridLines(width: 0),
                          axisLine: AxisLine(width: 0),
                          labelFormat:
                              _getActivityYAxisFormat(selectedActivityMetric),
                          labelStyle: TextStyle(
                            color: _getActivityColor(selectedActivityMetric),
                            fontFamily: 'Inter',
                            fontSize: 10,
                          ),
                        ),
                      ],
                      series: <ChartSeries>[
                        // Nutrition series
                        SplineSeries<NutritionActivityData, DateTime>(
                          name:
                              _getNutritionSeriesName(selectedNutritionMetric),
                          dataSource: data,
                          xValueMapper: (NutritionActivityData data, _) =>
                              data.date,
                          yValueMapper: (NutritionActivityData data, _) =>
                              _getNutritionValue(data, selectedNutritionMetric),
                          color: _getNutritionColor(selectedNutritionMetric),
                          width: 2.5,
                          markerSettings: MarkerSettings(
                            isVisible: true,
                            shape: DataMarkerType.circle,
                            height: 6,
                            width: 6,
                            color: _getNutritionColor(selectedNutritionMetric),
                            borderColor: Colors.white,
                            borderWidth: 2,
                          ),
                        ),

                        // Activity series
                        SplineSeries<NutritionActivityData, DateTime>(
                          name: _getActivitySeriesName(selectedActivityMetric),
                          dataSource: data,
                          xValueMapper: (NutritionActivityData data, _) =>
                              data.date,
                          yValueMapper: (NutritionActivityData data, _) =>
                              _getActivityValue(data, selectedActivityMetric),
                          yAxisName: 'Activity',
                          color: _getActivityColor(selectedActivityMetric),
                          width: 2.5,
                          markerSettings: MarkerSettings(
                            isVisible: true,
                            shape: DataMarkerType.diamond,
                            height: 6,
                            width: 6,
                            color: _getActivityColor(selectedActivityMetric),
                            borderColor: Colors.white,
                            borderWidth: 2,
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

                  // Toggle buttons row
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Nutrition toggle buttons
                        _buildMetricToggleButton(
                          'Calories',
                          selectedNutritionMetric == 'totalCalories',
                          Colors.orange[700]!,
                          () => setState(
                              () => selectedNutritionMetric = 'totalCalories'),
                        ),
                        SizedBox(width: 4),
                        _buildMetricToggleButton(
                          'Carbs',
                          selectedNutritionMetric == 'totalCarbs',
                          Colors.green[700]!,
                          () => setState(
                              () => selectedNutritionMetric = 'totalCarbs'),
                        ),
                        SizedBox(width: 4),
                        _buildMetricToggleButton(
                          'Fat',
                          selectedNutritionMetric == 'totalFat',
                          Colors.yellow[700]!,
                          () => setState(
                              () => selectedNutritionMetric = 'totalFat'),
                        ),
                        SizedBox(width: 4),
                        _buildMetricToggleButton(
                          'Protein',
                          selectedNutritionMetric == 'totalProtein',
                          Colors.purple[700]!,
                          () => setState(
                              () => selectedNutritionMetric = 'totalProtein'),
                        ),
                      ],
                    ),
                  ),

                  // Activity toggle buttons
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMetricToggleButton(
                          'Time',
                          selectedActivityMetric == 'elapsedTime',
                          Colors.blue[700]!,
                          () => setState(
                              () => selectedActivityMetric = 'elapsedTime'),
                        ),
                        SizedBox(width: 4),
                        _buildMetricToggleButton(
                          'Distance',
                          selectedActivityMetric == 'distance',
                          Colors.indigo[700]!,
                          () => setState(
                              () => selectedActivityMetric = 'distance'),
                        ),
                        SizedBox(width: 4),
                        _buildMetricToggleButton(
                          'Speed',
                          selectedActivityMetric == 'averageSpeed',
                          Colors.teal[700]!,
                          () => setState(
                              () => selectedActivityMetric = 'averageSpeed'),
                        ),
                      ],
                    ),
                  ),

                  // Insight section
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
                                _getInsightText(data, selectedNutritionMetric,
                                    selectedActivityMetric),
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
      },
    );
  }

// Update the metric toggle button for a more compact design
  Widget _buildMetricToggleButton(
      String label, bool isSelected, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : Colors.grey[600],
          ),
        ),
      ),
    );
  }

// Helper methods for nutrition metrics
  String _getNutritionSeriesName(String metric) {
    switch (metric) {
      case 'totalCalories':
        return 'Calories';
      case 'totalCarbs':
        return 'Carbs (g)';
      case 'totalFat':
        return 'Fat (g)';
      case 'totalProtein':
        return 'Protein (g)';
      default:
        return 'Calories';
    }
  }

  Color _getNutritionColor(String metric) {
    switch (metric) {
      case 'totalCalories':
        return Colors.orange[700]!;
      case 'totalCarbs':
        return Colors.green[700]!;
      case 'totalFat':
        return Colors.yellow[700]!;
      case 'totalProtein':
        return Colors.purple[700]!;
      default:
        return Colors.orange[700]!;
    }
  }

  String _getNutritionYAxisFormat(String metric) {
    switch (metric) {
      case 'totalCalories':
        return '{value} kcal';
      case 'totalCarbs':
        return '{value} g';
      case 'totalFat':
        return '{value} g';
      case 'totalProtein':
        return '{value} g';
      default:
        return '{value} kcal';
    }
  }

  double? _getNutritionValue(NutritionActivityData data, String metric) {
    switch (metric) {
      case 'totalCalories':
        return data.totalCalories;
      case 'totalCarbs':
        return data.totalCarbs;
      case 'totalFat':
        return data.totalFat;
      case 'totalProtein':
        return data.totalProtein;
      default:
        return data.totalCalories;
    }
  }

// Helper methods for activity metrics
  String _getActivitySeriesName(String metric) {
    switch (metric) {
      case 'elapsedTime':
        return 'Time (min)';
      case 'distance':
        return 'Distance (km)';
      case 'averageSpeed':
        return 'Speed (km/h)';
      default:
        return 'Speed (km/h)';
    }
  }

  Color _getActivityColor(String metric) {
    switch (metric) {
      case 'elapsedTime':
        return Colors.blue[700]!;
      case 'distance':
        return Colors.indigo[700]!;
      case 'averageSpeed':
        return Colors.teal[700]!;
      default:
        return Colors.teal[700]!;
    }
  }

  String _getActivityYAxisFormat(String metric) {
    switch (metric) {
      case 'elapsedTime':
        return '{value} min';
      case 'distance':
        return '{value} km';
      case 'averageSpeed':
        return '{value} km/h';
      default:
        return '{value} km/h';
    }
  }

  double? _getActivityValue(NutritionActivityData data, String metric) {
    switch (metric) {
      case 'elapsedTime':
        return data.elapsedTime;
      case 'distance':
        return data.distance;
      case 'averageSpeed':
        return data.averageSpeed;
      default:
        return data.averageSpeed;
    }
  }

// Generate insight text based on selected metrics
  String _getInsightText(List<NutritionActivityData> data,
      String nutritionMetric, String activityMetric) {
    if (data.length < 3) {
      return "Track more nutrition and activity data to see correlation insights.";
    }

    List<double> nutritionValues = [];
    List<double> activityValues = [];

    for (var point in data) {
      double? nutritionValue = _getNutritionValue(point, nutritionMetric);
      double? activityValue = _getActivityValue(point, activityMetric);

      if (nutritionValue != null && activityValue != null) {
        nutritionValues.add(nutritionValue);
        activityValues.add(activityValue);
      }
    }

    if (nutritionValues.length < 3 || activityValues.length < 3) {
      return "Need more complete data points to analyze correlation.";
    }

    // Calculate correlation
    double correlation =
        _calculatePearsonCorrelation(nutritionValues, activityValues);

    String nutritionName = _getNutritionSeriesName(nutritionMetric);
    String activityName = _getActivitySeriesName(activityMetric);

    if (correlation > 0.6) {
      return "Strong positive correlation detected. Higher $nutritionName appears to relate to higher $activityName.";
    } else if (correlation > 0.3) {
      return "Moderate positive correlation. $nutritionName may have a positive effect on your $activityName.";
    } else if (correlation > -0.3) {
      return "No significant correlation between $nutritionName and $activityName detected in your data.";
    } else if (correlation > -0.6) {
      return "Moderate negative correlation. Lower $nutritionName appears to relate to higher $activityName.";
    } else {
      return "Strong negative correlation detected. Lower $nutritionName strongly relates to higher $activityName.";
    }
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
    if (userId == null)
      return {
        'correlationData': <WeightCalorieData>[],
        'correlationCoefficient': 0.0
      };

    try {
      // Fetch weight data
      QuerySnapshot weightSnapshot = await FirebaseFirestore.instance
          .collection('userData')
          .where('uid', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(14)
          .get();

      // Fetch food entries for calorie consumed data
      QuerySnapshot foodSnapshot = await FirebaseFirestore.instance
          .collection('food_entries')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(14)
          .get();

      // Fetch activity data for calories burned
      QuerySnapshot activitySnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .where('uid', isEqualTo: userId)
          .orderBy('start_date', descending: true)
          .limit(30)
          .get();

      // Process weight data
      Map<String, double> weightByDate = {};
      for (var doc in weightSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        double weight = safeParseDouble(data['weight']);

        if (weight > 0 && data['timestamp'] != null) {
          DateTime date = data['timestamp'].toDate();
          String dateKey = DateFormat('yyyy-MM-dd').format(date);
          weightByDate[dateKey] = weight;
        }
      }

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

      Map<String, double> caloriesBurnedByDate = {};
      for (var doc in activitySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        double calories = safeParseDouble(data['calories_burned']);

        if (calories > 0 && data['start_date'] != null) {
          DateTime date = data['start_date'].toDate();
          String dateKey = DateFormat('yyyy-MM-dd').format(date);
          caloriesBurnedByDate[dateKey] =
              (caloriesBurnedByDate[dateKey] ?? 0) + calories;
        }
      }

      List<WeightCalorieData> correlationData = [];
      Set<String> allDates = {
        ...weightByDate.keys,
        ...caloriesConsumedByDate.keys,
        ...caloriesBurnedByDate.keys
      };

      List<String> sortedDates = allDates.toList()..sort();

      for (String dateKey in sortedDates) {
        if (weightByDate.containsKey(dateKey)) {
          double weight = weightByDate[dateKey]!;
          double caloriesConsumed = caloriesConsumedByDate[dateKey] ?? 0;
          double caloriesBurned = caloriesBurnedByDate[dateKey] ?? 0;
          double netCalories = caloriesConsumed - caloriesBurned;

          DateTime date = DateFormat('yyyy-MM-dd').parse(dateKey);
          correlationData.add(WeightCalorieData(date, weight, netCalories));
        }
      }

      double correlationCoefficient = 0.0;

      if (correlationData.length >= 3) {
        List<double> weights = correlationData.map((e) => e.weight).toList();
        List<double> netCalories =
            correlationData.map((e) => e.netCalories).toList();

        correlationCoefficient =
            _calculatePearsonCorrelation(weights, netCalories);
      }

      return {
        'correlationData': correlationData,
        'correlationCoefficient': correlationCoefficient,
      };
    } catch (e) {
      print("Error fetching correlation data: $e");
      return {
        'correlationData': <WeightCalorieData>[],
        'correlationCoefficient': 0.0
      };
    }
  }

// Helper method to calculate Pearson correlation coefficient
  double _calculatePearsonCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) return 0.0;

    double xMean = x.reduce((a, b) => a + b) / x.length;
    double yMean = y.reduce((a, b) => a + b) / y.length;

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

    if (xDenominator == 0 || yDenominator == 0) return 0.0;

    return numerator / (math.sqrt(xDenominator) * math.sqrt(yDenominator));
  }

  double _calculateWeeklyCaloriesBurned() {
    if (activityData.isEmpty) return 0.0;

    double weeklyCalories = 0.0;
    DateTime oneWeekAgo = DateTime.now().subtract(Duration(days: 7));

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
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      QuerySnapshot subgoalQuery = await FirebaseFirestore.instance
          .collection('cycling_subgoals')
          .where('userId', isEqualTo: uid)
          .where('endDate', isGreaterThan: DateTime.now())
          .orderBy('endDate', descending: false)
          .limit(1)
          .get();

      print("SubGoal Query is Empty?: ");
      print(subgoalQuery.docs.isNotEmpty);
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

        // Now check for the most recently completed subgoal
        // to use as reference for new subgoal suggestions
        try {
          QuerySnapshot completedSubgoalQuery = await FirebaseFirestore.instance
              .collection('cycling_subgoals')
              .where('userId', isEqualTo: uid)
              .where('endDate', isLessThan: DateTime.now())
              .orderBy('endDate', descending: true)
              .limit(1)
              .get();

          if (completedSubgoalQuery.docs.isNotEmpty) {
            DocumentSnapshot subgoalDoc = completedSubgoalQuery.docs.first;
            var data = subgoalDoc.data() as Map<String, dynamic>;

            // First ensure we have baseline data
            if (baselineDistance == 0.0) {
              _calculateBaselines();
            }

            // Get the subgoal date range to fetch relevant activities
            DateTime startDate = data['startDate'].toDate();
            DateTime endDate = data['endDate'].toDate();
            String completedType = data['subgoalType'];

            // Fetch activities within the previous subgoal's time period
            QuerySnapshot activitiesSnapshot = await FirebaseFirestore.instance
                .collection('activities')
                .where('uid', isEqualTo: uid)
                .where('start_date',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
                .where('start_date',
                    isLessThanOrEqualTo: Timestamp.fromDate(endDate))
                .get();

            // Calculate actual performance metrics from these activities
            double actualTotalDistance = 0.0;
            double actualTotalDuration = 0.0; // in minutes
            List<double> paces = [];

            for (var doc in activitiesSnapshot.docs) {
              var activityData = doc.data() as Map<String, dynamic>;

              double distance = safeParseDouble(activityData['distance']);
              double durationSeconds =
                  safeParseDouble(activityData['elapsed_time']);
              double durationMinutes = durationSeconds / 60.0;

              if (distance > 0) actualTotalDistance += distance;
              if (durationMinutes > 0) actualTotalDuration += durationMinutes;

              // Calculate pace (minutes per km) for this activity
              if (distance > 0 && durationMinutes > 0) {
                double pace = durationMinutes / distance;
                paces.add(pace);
              }
            }

            // Calculate averages if there were activities
            int activityCount = activitiesSnapshot.docs.length;
            double actualAvgDistance =
                activityCount > 0 ? actualTotalDistance / activityCount : 0.0;
            double actualAvgDuration =
                activityCount > 0 ? actualTotalDuration / activityCount : 0.0;
            double actualAvgPace = 0.0;

            if (paces.isNotEmpty) {
              actualAvgPace = paces.reduce((a, b) => a + b) / paces.length;
            }

            // Then update our reference values based on completed subgoal
            setState(() {
              if (activityCount > 0) {
                // Use actual performance metrics if we have activities
                referenceDistance = actualAvgDistance;
                referencePace = actualAvgPace;
                referenceDuration = actualAvgDuration;
                usingPreviousGoal = false;
              } else {
                // If no activities found, fall back to previous subgoal target values
                if (completedType == "distance") {
                  referenceDistance = data['targetValue'];
                  referencePace = baselinePace;
                  referenceDuration = baselineDuration;
                } else if (completedType == "pace") {
                  referenceDistance = baselineDistance;
                  referencePace = data['targetValue'];
                  referenceDuration = baselineDuration;
                } else if (completedType == "duration") {
                  referenceDistance = baselineDistance;
                  referencePace = baselinePace;
                  referenceDuration = data['targetValue'];
                } else if (completedType == "maintain") {
                  // For maintain goals, use the baseline values
                  referenceDistance = baselineDistance;
                  referencePace = baselinePace;
                  referenceDuration = baselineDuration;
                }
                usingPreviousGoal = true;
              }
            });

            print(
                "Using performance data from previous subgoal period: Distance=${actualAvgDistance.toStringAsFixed(2)}km, Pace=${actualAvgPace.toStringAsFixed(2)}min/km, Duration=${actualAvgDuration.toStringAsFixed(0)}min");
          } else {
            // No completed subgoal found, use baseline values
            setState(() {
              referenceDistance = baselineDistance;
              referencePace = baselinePace;
              referenceDuration = baselineDuration;
              usingPreviousGoal = false;
            });
            print("No completed subgoal found. Using baseline values.");
          }
        } catch (e) {
          print("Error fetching completed subgoal: $e");
          setState(() {
            referenceDistance = baselineDistance;
            referencePace = baselinePace;
            referenceDuration = baselineDuration;
            usingPreviousGoal = false;
          });
        }
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
    String dataSource = usingPreviousGoal
        ? "previous goal target"
        : "your actual cycling performance";

    switch (type) {
      case "distance":
        title =
            "Increase cycling distance to ${targetValue.toStringAsFixed(1)} km";

        // Generate suggestions
        suggestions.add(
            "Start with a proper warm-up to prepare for the longer distance");
        suggestions.add("Increase your hydration for longer rides");
        suggestions.add("Plan a route with the target distance in advance");

        if (targetValue > referenceDistance * 1.3 && referenceDistance > 0) {
          warnings.add(
              "This is a ${((targetValue / referenceDistance - 1) * 100).toStringAsFixed(0)}% increase from your ${usingPreviousGoal ? "previous goal" : "average performance"}. Consider a more gradual progression.");
        }

        if (respiratoryCondition == "Yes" &&
            targetValue > referenceDistance * 1.2) {
          warnings.add(
              "With your respiratory condition, consider a more moderate increase in distance.");
        }
        break;

      case "pace":
        double currentPaceMinPerKm = referencePace;
        title =
            "Improve cycling pace to ${targetValue.toStringAsFixed(1)} min/km";

        suggestions.add("Include interval training in your routine");
        suggestions.add("Focus on consistent pedaling cadence");
        suggestions.add(
            "Make sure your bike is properly maintained for optimal efficiency");

        if (currentPaceMinPerKm > 0 &&
            targetValue < currentPaceMinPerKm * 0.8) {
          warnings.add(
              "This is a ${((1 - targetValue / currentPaceMinPerKm) * 100).toStringAsFixed(0)}% speed increase based on your ${usingPreviousGoal ? "previous goal" : "current pace"}, which may be challenging. Consider a gradual approach.");
        }

        if (cardiovascularCondition == "Yes") {
          warnings.add(
              "With your cardiovascular condition, consult a healthcare provider before significantly increasing intensity.");
        }
        break;

      case "duration":
        title =
            "Extend cycling duration to ${targetValue.toStringAsFixed(0)} minutes";

        suggestions.add("Build endurance with a steady pace");
        suggestions.add("Ensure proper nutrition before longer sessions");
        suggestions.add("Take small breaks if needed during the extended ride");

        if (targetValue > referenceDuration * 1.5 && referenceDuration > 0) {
          warnings.add(
              "This is a ${((targetValue / referenceDuration - 1) * 100).toStringAsFixed(0)}% increase in duration from your ${usingPreviousGoal ? "previous goal" : "average rides"}, which may lead to fatigue. Consider a more gradual approach.");
        }

        break;

      case "maintain":
        title = "Maintain current cycling performance";

        suggestions.add("Focus on consistency in your current routine");
        suggestions.add("Work on technique refinement");
        suggestions.add("Use this period to establish a sustainable rhythm");
        break;
    }

    // Add a note about the data source to the suggestions
    suggestions.add(
        "This goal is based on $dataSource from your previous training period.");

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
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final oneWeekAgo = today.subtract(Duration(days: 7));

      QuerySnapshot foodEntrySnapshot = await FirebaseFirestore.instance
          .collection('food_entries')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(oneWeekAgo))
          .orderBy('date', descending: true)
          .limit(7)
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

        setState(() {
          nutritionData = newNutritionData;
          if (nutritionData.isNotEmpty) {
            foodIntake =
                "${nutritionData[0]['breakfast']}, ${nutritionData[0]['lunch']}, ${nutritionData[0]['dinner']}";
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
      nutritionRecommendations.add(
          "Complete your food diary to get personalized nutrition recommendations.");
      return;
    }

    var latestFoodEntry = nutritionData[0];
    double totalCalories =
        safeParseDouble(latestFoodEntry['total_calories'].toString());
    double breakfastCalories =
        safeParseDouble(latestFoodEntry['breakfast_calories'].toString());
    double lunchCalories =
        safeParseDouble(latestFoodEntry['lunch_calories'].toString());
    double dinnerCalories =
        safeParseDouble(latestFoodEntry['dinner_calories'].toString());
    double totalCarbs =
        safeParseDouble(latestFoodEntry['total_carbs'].toString());
    double totalFat = safeParseDouble(latestFoodEntry['total_fat'].toString());
    double totalProtein =
        safeParseDouble(latestFoodEntry['total_protein'].toString());
    double breakfastCarbs =
        safeParseDouble(latestFoodEntry['breakfast_carbs'].toString());
    double lunchCarbs =
        safeParseDouble(latestFoodEntry['lunch_carbs'].toString());
    double dinnerCarbs =
        safeParseDouble(latestFoodEntry['dinner_carbs'].toString());
    double breakfastFat =
        safeParseDouble(latestFoodEntry['breakfast_fat'].toString());
    double lunchFat = safeParseDouble(latestFoodEntry['lunch_fat'].toString());
    double dinnerFat =
        safeParseDouble(latestFoodEntry['dinner_fat'].toString());
    double breakfastProtein =
        safeParseDouble(latestFoodEntry['breakfast_protein'].toString());
    double lunchProtein =
        safeParseDouble(latestFoodEntry['lunch_protein'].toString());
    double dinnerProtein =
        safeParseDouble(latestFoodEntry['dinner_protein'].toString());

    // Calculate macronutrient percentages if calories > 0
    double carbPercent =
        totalCalories > 0 ? (totalCarbs * 4 / totalCalories) * 100 : 0;
    double fatPercent =
        totalCalories > 0 ? (totalFat * 9 / totalCalories) * 100 : 0;
    // Get BMR directly from user input
    double bmr = safeParseDouble(basalMetabolicRate);
    double weeklyCaloriesBurned = _calculateWeeklyCaloriesBurned();
    double dailyCaloriesBurned = weeklyCaloriesBurned / 7.0;

    // Calculate total daily calorie needs based on BMR and actual calories burned
    double dailyCalorieNeeds = bmr + dailyCaloriesBurned;
    double weightInKg = safeParseDouble(weight);
    double bodyFatPercentage = safeParseDouble(bodyFat);

    // Calculate recommended protein needs based on weight, body fat and training type
    double leanBodyMass = weightInKg * (1 - (bodyFatPercentage / 100));
    double recommendedProteinGrams = 0;

    if (goalType == "Leisure") {
      recommendedProteinGrams =
          leanBodyMass * 1.6; // 1.6g per kg LBM for recreational
    } else if (goalType == "Endurance") {
      recommendedProteinGrams =
          leanBodyMass * 1.8; // 1.8g per kg LBM for endurance
    } else if (goalType == "High Intensity Cycling") {
      recommendedProteinGrams =
          leanBodyMass * 2.0; // 2.0g per kg LBM for high intensity
    } else {
      recommendedProteinGrams = leanBodyMass * 1.6; // Default
    }

    // If body fat percentage is unavailable, fall back to total body weight
    if (bodyFatPercentage <= 0) {
      if (goalType == "Leisure") {
        recommendedProteinGrams =
            weightInKg * 1.2; // 1.2g per kg for recreational
      } else if (goalType == "Endurance") {
        recommendedProteinGrams = weightInKg * 1.4; // 1.4g per kg for endurance
      } else if (goalType == "High Intensity Cycling") {
        recommendedProteinGrams =
            weightInKg * 1.6; // 1.6g per kg for high intensity
      } else {
        recommendedProteinGrams = weightInKg * 1.2; // Default
      }
    }

    // Determine recommended carbs based on training volume and intensity
    double recommendedCarbPercent = 0;
    if (goalType == "Leisure") {
      recommendedCarbPercent = 45; // 45% for recreational
    } else if (goalType == "Endurance") {
      // Scale carb needs based on actual cycling volume
      if (weeklyDistanceTotal > 100) {
        recommendedCarbPercent = 65; // 65% for high volume endurance
      } else if (weeklyDistanceTotal > 50) {
        recommendedCarbPercent = 60; // 60% for moderate volume endurance
      } else {
        recommendedCarbPercent = 55; // 55% for lower volume endurance
      }
    } else if (goalType == "High Intensity Cycling") {
      recommendedCarbPercent = 55; // 55% for high intensity
    } else {
      recommendedCarbPercent = 50; // Default
    }

    // Calculate recommended carb grams based on percentage of calories
    double recommendedCarbGrams =
        (recommendedCarbPercent / 100) * dailyCalorieNeeds / 4;

    // Determine recommended fat based on the remaining calories
    double recommendedFatPercent = 100 -
        recommendedCarbPercent -
        (recommendedProteinGrams * 4 * 100 / dailyCalorieNeeds);
    // Ensure fat doesn't go below 20% for hormonal health
    recommendedFatPercent = math.max(20, recommendedFatPercent);
    double recommendedFatGrams =
        (recommendedFatPercent / 100) * dailyCalorieNeeds / 9;

    // Calorie recommendations based on actual cycling data and body composition
    if (totalCalories < dailyCalorieNeeds * 0.8) {
      nutritionRecommendations.add(
          "Based on your ${bmr.toInt()} kcal BMR and ${dailyCaloriesBurned.toInt()} kcal average daily burn from cycling, your intake of ${totalCalories.toInt()} kcal is too low. Consider increasing to ${dailyCalorieNeeds.toInt()} kcal for optimal recovery and performance.");
    } else if (totalCalories > dailyCalorieNeeds * 1.2 &&
        goalType == "High Intensity Cycling") {
      nutritionRecommendations.add(
          "Your intake of ${totalCalories.toInt()} kcal exceeds your needs (${dailyCalorieNeeds.toInt()} kcal based on your BMR and cycling data) by ${(totalCalories - dailyCalorieNeeds).toInt()} kcal. Adjust portions to align with your weight goals while maintaining performance.");
    }

    // Meal timing recommendations
    double breakfastPercent =
        totalCalories > 0 ? (breakfastCalories / totalCalories) * 100 : 0;
    double lunchPercent =
        totalCalories > 0 ? (lunchCalories / totalCalories) * 100 : 0;
    double dinnerPercent =
        totalCalories > 0 ? (dinnerCalories / totalCalories) * 100 : 0;

    if (breakfastPercent < 20 && totalCalories > 0) {
      nutritionRecommendations.add(
          "Your breakfast (${breakfastPercent.toInt()}% of daily calories) is smaller than optimal for cyclists. Aim for 20-25% of daily calories at breakfast to fuel morning training and jumpstart metabolism.");
    }

    // Check lunch meal balance
    if (lunchPercent < 25 && totalCalories > 0) {
      nutritionRecommendations.add(
          "Your lunch (${lunchPercent.toInt()}% of daily calories) could be increased to provide better midday fueling. Aim for 25-30% of daily calories at lunch to sustain energy throughout the day, especially if you ride in the afternoon.");
    }

    // Check dinner meal balance
    if (dinnerPercent > 45 && totalCalories > 0) {
      nutritionRecommendations.add(
          "Your dinner (${dinnerPercent.toInt()}% of daily calories) represents a large portion of your daily intake. Consider redistributing some calories to earlier meals to support activity during the day and improve recovery.");
    }

    // Macronutrient distribution recommendations based on actual training data
    if (totalCalories > 0) {
      // Protein recommendations based on lean body mass or weight
      if (totalProtein < recommendedProteinGrams * 0.8) {
        nutritionRecommendations.add(
            "Your protein intake (${totalProtein.toInt()}g) is below the recommended ${recommendedProteinGrams.toInt()}g for your ${bodyFatPercentage > 0 ? "lean body mass" : "body weight"} and training intensity. Increase protein through foods like chicken, fish, eggs, dairy, tofu, or legumes for better recovery after your ${weeklyActivityCount} weekly rides.");
      } else if (totalProtein > recommendedProteinGrams * 1.5) {
        nutritionRecommendations.add(
            "Your protein intake (${totalProtein.toInt()}g) significantly exceeds your needs. While generally safe, consider balancing your diet with more complex carbs to fuel your ${weeklyDistanceTotal.toInt()} km of weekly cycling.");
      } else {
        nutritionRecommendations.add(
            "Your protein intake (${totalProtein.toInt()}g) aligns well with your needs. Continue consuming protein across all meals for optimal recovery from your ${weeklyActivityCount} weekly cycling sessions.");
      }

      // Carbohydrate recommendations based on actual training volume
      if (carbPercent < (recommendedCarbPercent - 10)) {
        nutritionRecommendations.add(
            "Your carbohydrate intake (${carbPercent.toInt()}% of calories) is lower than optimal for your ${weeklyDistanceTotal.toInt()} km weekly cycling volume. Increase to ${recommendedCarbPercent.toInt()}% of calories (approximately ${recommendedCarbGrams.toInt()}g) to properly fuel rides and speed recovery.");
      } else if (carbPercent > (recommendedCarbPercent + 10)) {
        nutritionRecommendations.add(
            "Your carbohydrate intake (${carbPercent.toInt()}% of calories) exceeds recommendations for your current training load. Focus on timing carbs around your rides and choosing complex carbs like whole grains, fruits, and vegetables for better energy management.");
      } else {
        nutritionRecommendations.add(
            "Your carbohydrate intake (${carbPercent.toInt()}% of calories) is well-matched to your weekly cycling volume. Continue to time carbs before and during longer rides for optimal performance.");
      }

      // Fat recommendations
      if (fatPercent < 20) {
        nutritionRecommendations.add(
            "Your fat intake (${fatPercent.toInt()}% of calories) is below the 20% minimum for hormone production and fat-soluble vitamin absorption. Include healthy fats like avocados, nuts, olive oil, and fatty fish even when focusing on weight management. Aim for ${recommendedFatGrams.toInt()}g of fat daily.");
      } else if (fatPercent > 35 && goalType != "Leisure") {
        nutritionRecommendations.add(
            "Your fat intake (${fatPercent.toInt()}% of calories) is higher than optimal for your ${goalType} cycling. Consider shifting some calories to carbohydrates to better fuel your high-intensity or endurance sessions. Target around ${recommendedFatGrams.toInt()}g of fat daily.");
      } else {
        nutritionRecommendations.add(
            "Your fat intake (${fatPercent.toInt()}% of calories) is appropriate at approximately ${totalFat.toInt()}g, close to the recommended ${recommendedFatGrams.toInt()}g. Focus on unsaturated fats from plant sources and omega-3s from fish to support recovery and reduce inflammation from training.");
      }
    }

    // Meal-specific macronutrient recommendations tied to training data
    if (totalCalories > 0) {
      // Breakfast macronutrient recommendations
      if (breakfastProtein < (recommendedProteinGrams * 0.25) &&
          breakfastCalories > 0) {
        nutritionRecommendations.add(
            "With only ${breakfastProtein.toInt()}g protein at breakfast, you're missing an opportunity for recovery. Aim for ${(recommendedProteinGrams * 0.25).toInt()}-${(recommendedProteinGrams * 0.33).toInt()}g protein at breakfast, especially important after morning rides.");
      }

      if (breakfastCarbs < 30 &&
          goalType == "Endurance" &&
          breakfastCalories > 0) {
        nutritionRecommendations.add(
            "Your breakfast carbohydrate intake (${breakfastCarbs.toInt()}g) is insufficient for your endurance training. Morning carbs replenish glycogen depleted overnight and prepare you for ${weeklyDistanceTotal / weeklyActivityCount} km average rides.");
      }

      // Lunch macronutrient recommendations
      if (lunchCarbs < (recommendedCarbGrams * 0.3) && lunchCalories > 0) {
        nutritionRecommendations.add(
            "Your lunch carbohydrate intake (${lunchCarbs.toInt()}g) is lower than optimal. Aim for ${(recommendedCarbGrams * 0.3).toInt()}-${(recommendedCarbGrams * 0.35).toInt()}g of carbs at lunch to fuel afternoon activities and support recovery.");
      }

      if (lunchProtein < (recommendedProteinGrams * 0.25) &&
          lunchCalories > 0) {
        nutritionRecommendations.add(
            "Your lunch protein intake (${lunchProtein.toInt()}g) could be increased to better support muscle recovery throughout the day. Target ${(recommendedProteinGrams * 0.25).toInt()}-${(recommendedProteinGrams * 0.3).toInt()}g at lunch.");
      }

      // Dinner macronutrient recommendations
      if (dinnerProtein < (recommendedProteinGrams * 0.3) &&
          dinnerCalories > 0) {
        nutritionRecommendations.add(
            "Your dinner protein intake (${dinnerProtein.toInt()}g) is lower than recommended. Aim for ${(recommendedProteinGrams * 0.3).toInt()}-${(recommendedProteinGrams * 0.4).toInt()}g at dinner to optimize overnight muscle repair.");
      }

      if (dinnerCarbs > (recommendedCarbGrams * 0.5) &&
          goalType == "High Intensity Cycling" &&
          dinnerCalories > 0) {
        nutritionRecommendations.add(
            "Your dinner carbohydrate intake (${dinnerCarbs.toInt()}g) is relatively high. For weight management goals, consider shifting some carbs to earlier meals, especially if you don't typically ride in the evening.");
      }

      // Fat balance in meals
      if (breakfastFat < 5 && breakfastCalories > 0) {
        nutritionRecommendations.add(
            "Your breakfast contains very little fat (${breakfastFat.toInt()}g). Including some healthy fats at breakfast improves satiety and absorption of fat-soluble vitamins.");
      }

      if (lunchFat > (recommendedFatGrams * 0.5) && lunchCalories > 0) {
        nutritionRecommendations.add(
            "Your lunch contains ${lunchFat.toInt()}g of fat, which may be higher than optimal for midday fueling. Consider reducing heavy fats at lunch if you typically ride in the afternoon.");
      }

      if (dinnerFat > (recommendedFatGrams * 0.6) && dinnerCalories > 0) {
        nutritionRecommendations.add(
            "Your dinner fat intake (${dinnerFat.toInt()}g) represents a large portion of your daily fat intake. High-fat evening meals can affect sleep quality and recovery. Consider a more balanced distribution across meals.");
      }
    }

    // Training-specific nutrition guidance based on recorded activity data
    if (goalType == "Endurance") {
      nutritionRecommendations.add(
          "For your endurance training (${weeklyDistanceTotal.toInt()} km weekly), prioritize nutrient timing: consume high-carb meals (60-100g) 2-3 hours before rides and recovery nutrition within 30 minutes after.");

      // Specific recommendations for longer rides
      double longestRide = 0;
      for (var activity in activityData) {
        double distance = safeParseDouble(activity['distance']);
        if (distance > longestRide) longestRide = distance;
      }

      if (longestRide > 40) {
        nutritionRecommendations.add(
            "For your long rides (${longestRide.toInt()} km), consume 60-90g carbs/hour from multiple sources (sports drinks, gels, bananas) after the first hour to maintain performance and prevent bonking.");
      }
    } else if (goalType == "High Intensity Cycling") {
      nutritionRecommendations.add(
          "For high-intensity cycling, your protein needs are higher (${recommendedProteinGrams.toInt()}g daily based on your body composition). This supports recovery from your ${weeklyActivityCount} high-intensity sessions.");

      // Calculate average intensity from heart rate data
      double avgHeartRate = 0;
      int hrDataPoints = 0;
      for (var activity in activityData) {
        double hr = safeParseDouble(activity['average_heartrate']);
        if (hr > 0) {
          avgHeartRate += hr;
          hrDataPoints++;
        }
      }
      if (hrDataPoints > 0) {
        avgHeartRate /= hrDataPoints;
        nutritionRecommendations.add(
            "Your average heart rate of ${avgHeartRate.toInt()} bpm during rides indicates high-intensity work. Prioritize recovery nutrition with a 3:1 carb-to-protein ratio within 30 minutes post-ride to replenish glycogen and initiate muscle repair.");
      }
    }

    // Weight management recommendations based on body composition data
    if (latestWeight > 0 && previousWeight > 0) {
      double weightChange = latestWeight - previousWeight;
      if (goalType == "High Intensity Cycling" && weightChange > 0.5) {
        nutritionRecommendations.add(
            "Your recent ${weightChange.toStringAsFixed(1)} kg weight increase may impact power-to-weight ratio. Consider adjusting portion sizes while maintaining nutrient quality to support your high-intensity training goals.");
      } else if (goalType == "Endurance" && weightChange < -1.0) {
        nutritionRecommendations.add(
            "Your ${(-weightChange).toStringAsFixed(1)} kg weight loss, if continued, may compromise endurance performance. Ensure adequate fueling with ${recommendedCarbGrams.toInt()}g carbs daily to sustain your ${weeklyDistanceTotal.toInt()} km weekly training load.");
      }
    }

    // Hydration advice based on actual training data
    double avgRideTime = 0;
    int timeDataPoints = 0;
    for (var activity in activityData) {
      double time =
          safeParseDouble(activity['elapsed_time']) / 60; // convert to minutes
      if (time > 0) {
        avgRideTime += time;
        timeDataPoints++;
      }
    }
    if (timeDataPoints > 0) {
      avgRideTime /= timeDataPoints;
      double recommendedFluidPerRide =
          (avgRideTime / 60) * 750; // 750ml per hour
      nutritionRecommendations.add(
          "For your average ${avgRideTime.toInt()}-minute rides, consume approximately ${recommendedFluidPerRide.toInt()} ml of fluid. Stay hydrated with 2-3 liters of water daily plus electrolytes when training in hot conditions.");
    } else {
      nutritionRecommendations.add(
          "Stay well-hydrated with 2-3 liters of water daily, plus additional 500-750ml per hour of cycling.");
    }
  }

  void _saveCyclingSubgoalToFirestore(String type, double targetValue,
      List<String> suggestions, List<String> warnings) {
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
        'completedSuccessfully': false,
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
          return _buildEmptyGraph(
              "Error loading temperature and activity data");
        }

        var correlationData = snapshot.data!;
        List<TemperatureActivityData> data =
            correlationData['temperatureActivityData'] ?? [];

        if (data.isEmpty) {
          return _buildEmptyGraph(
              "No matching temperature and activity data found");
        }

        if (data.length > 7) {
          data = data.sublist(data.length - 7);
        }

        List<String> sessionDates = [];

        for (var item in data) {
          sessionDates.add(DateFormat('MM/dd').format(item.date));
        }

        List<DateTime> parsedDates = sessionDates
            .map((date) => DateFormat('MM/dd').parse(date))
            .toList();

        parsedDates.sort((a, b) => a.compareTo(b));

        sessionDates = parsedDates
            .map((date) => DateFormat('MM/dd').format(date))
            .toList();
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
          tempDistanceCorrelation =
              _calculatePearsonCorrelation(temps, distances);
          tempDurationCorrelation =
              _calculatePearsonCorrelation(temps, durations);
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
          height: 650,
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
                      xValueMapper: (TemperatureActivityData data, index) =>
                          sessionDates[index],
                      yValueMapper: (TemperatureActivityData data, _) =>
                          data.temperature,
                      width: 0.6,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(4)),
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
                      xValueMapper: (TemperatureActivityData data, index) =>
                          sessionDates[index],
                      yValueMapper: (TemperatureActivityData data, _) =>
                          data.speed,
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
                      xValueMapper: (TemperatureActivityData data, index) =>
                          sessionDates[index],
                      yValueMapper: (TemperatureActivityData data, _) =>
                          data.distance,
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
                      xValueMapper: (TemperatureActivityData data, index) =>
                          sessionDates[index],
                      yValueMapper: (TemperatureActivityData data, _) =>
                          data.duration,
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
                            _getTemperatureInsightText(
                                tempSpeedCorrelation,
                                tempDistanceCorrelation,
                                tempDurationCorrelation),
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

  String _getTemperatureInsightText(
      double speedCorr, double distanceCorr, double durationCorr) {
    String insight = "";

    if (speedCorr.abs() >= distanceCorr.abs() &&
        speedCorr.abs() >= durationCorr.abs() &&
        speedCorr.abs() > 0.3) {
      insight = speedCorr > 0
          ? "Your cycling speed tends to increase in warmer weather."
          : "Your cycling speed tends to be faster in cooler weather.";
    } else if (distanceCorr.abs() >= speedCorr.abs() &&
        distanceCorr.abs() >= durationCorr.abs() &&
        distanceCorr.abs() > 0.3) {
      insight = distanceCorr > 0
          ? "You tend to ride longer distances in warmer weather."
          : "You tend to ride longer distances in cooler weather.";
    } else if (durationCorr.abs() > 0.3) {
      insight = durationCorr > 0
          ? "Your rides tend to last longer in warmer weather."
          : "Your rides tend to be shorter in warmer weather.";
    } else {
      insight = "Temperature has minimal effect on your cycling performance.";
    }

    return insight;
  }

// Method to fetch temperature and activity data
  Future<Map<String, dynamic>> _fetchTemperatureCyclingData() async {
    if (userId == null) return {'temperatureActivityData': []};

    try {
      QuerySnapshot activitySnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .where('uid', isEqualTo: userId)
          .orderBy('start_date', descending: true)
          .limit(20)
          .get();

      QuerySnapshot weatherSnapshot = await FirebaseFirestore.instance
          .collection('weatherData')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

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
              temperatureActivityData.add(TemperatureActivityData(
                  temperature, speed, distance, durationMinutes, activityDate));
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

  Widget _buildSubgoalSelectionCard() {
    if (hasActiveSubgoal || goalType != "High Intensity Cycling")
      return SizedBox.shrink();

    int targetDaysPerWeek = int.tryParse(daysPerWeek) ?? 0;

    bool hasCompletedWeeklyCommitment =
        weeklyActivityCount >= targetDaysPerWeek;

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
                  child: Icon(Icons.directions_bike_outlined,
                      color: Colors.blue[700], size: 24),
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
                          ? MediaQuery.of(context).size.width *
                              0.8 *
                              (weeklyActivityCount / targetDaysPerWeek)
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
                  Icon(Icons.lightbulb_outline,
                      size: 20, color: Colors.orange[700]),
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

      // Update reference values if we're not yet using previous goals
      if (!usingPreviousGoal) {
        referenceDistance = baselineDistance;
        referencePace = baselinePace;
        referenceDuration = baselineDuration;
      }
    }

    double distanceOption1 = math
        .max(referenceDistance * 1.1, referenceDistance + 1)
        .roundToDouble();
    double distanceOption2 = math
        .max(referenceDistance * 1.2, referenceDistance + 2)
        .roundToDouble();

    double paceOption1 = referencePace > 0
        ? math.max(referencePace * 0.95, referencePace - 0.5)
        : 0;
    double paceOption2 = referencePace > 0
        ? math.max(referencePace * 0.9, referencePace - 1)
        : 0;

    double durationOption1 = math
        .max(referenceDuration * 1.1, referenceDuration + 10)
        .roundToDouble();
    double durationOption2 = math
        .max(referenceDuration * 1.2, referenceDuration + 15)
        .roundToDouble();

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
                  child: Icon(Icons.check_circle_outline,
                      color: Colors.green[700], size: 24),
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

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: usingPreviousGoal ? Colors.purple[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: usingPreviousGoal ? Colors.purple[200]! : Colors.blue[100]!,
            width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                usingPreviousGoal
                    ? Icons
                        .emoji_events_outlined // Trophy icon for previous goals
                    : Icons
                        .analytics_outlined, // Analytics icon for performance data
                size: 16,
                color:
                    usingPreviousGoal ? Colors.purple[800] : Colors.blue[800],
              ),
              SizedBox(width: 6),
              Text(
                usingPreviousGoal
                    ? "Your Previous Goal Target:"
                    : "Your Actual Performance:",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: usingPreviousGoal
                        ? Colors.purple[800]
                        : Colors.blue[800]),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    "${referenceDistance.toStringAsFixed(1)} km",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  Text(
                    "Distance",
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    "${referencePace > 0 ? referencePace.toStringAsFixed(1) : '-'} min/km",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  Text(
                    "Pace",
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    "${referenceDuration.toStringAsFixed(0)} min",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  Text(
                    "Duration",
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 6),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: usingPreviousGoal
                    ? Colors.purple[100]!.withOpacity(0.4)
                    : Colors.blue[100]!.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                usingPreviousGoal
                    ? "Based on previous goal target value"
                    : "Based on your actual cycling performance",
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color:
                      usingPreviousGoal ? Colors.purple[900] : Colors.blue[900],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          _buildSubgoalOptionTitle(
              "Weekly Average Distance", Icons.straighten_outlined),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSubgoalOptionButton(
                    "Moderate",
                    "${distanceOption1.toStringAsFixed(1)} km/ride",
                    "From ${referenceDistance.toStringAsFixed(1)} km ${usingPreviousGoal ? 'previous goal' : 'avg'}",
                    Colors.blue[700]!,
                    "distance",
                    distanceOption1),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildSubgoalOptionButton(
                    "Challenging",
                    "${distanceOption2.toStringAsFixed(1)} km/ride",
                    "From ${referenceDistance.toStringAsFixed(1)} km ${usingPreviousGoal ? 'previous goal' : 'avg'}",
                    Colors.blue[900]!,
                    "distance",
                    distanceOption2),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (baselinePace > 0) ...[
            _buildSubgoalOptionTitle(
                "Weekly Average Pace", Icons.speed_outlined),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSubgoalOptionButton(
                      "Moderate",
                      "${paceOption1.toStringAsFixed(1)} min/km",
                      "From ${referencePace.toStringAsFixed(1)} min/km ${usingPreviousGoal ? 'previous goal' : 'avg'}",
                      Colors.orange[700]!,
                      "pace",
                      paceOption1),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildSubgoalOptionButton(
                      "Challenging",
                      "${paceOption2.toStringAsFixed(1)} min/km",
                      "From ${referencePace.toStringAsFixed(1)} min/km ${usingPreviousGoal ? 'previous goal' : 'avg'}",
                      Colors.orange[900]!,
                      "pace",
                      paceOption2),
                ),
              ],
            ),
          ],
          SizedBox(height: 16),
          _buildSubgoalOptionTitle(
              "Weekly Average Duration", Icons.timer_outlined),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSubgoalOptionButton(
                    "Moderate",
                    "${durationOption1.toStringAsFixed(0)} min/ride",
                    "From ${referenceDuration.toStringAsFixed(0)} min ${usingPreviousGoal ? 'previous goal' : 'avg'}",
                    Colors.green[700]!,
                    "duration",
                    durationOption1),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildSubgoalOptionButton(
                    "Challenging",
                    "${durationOption2.toStringAsFixed(0)} min/ride",
                    "From ${referenceDuration.toStringAsFixed(0)} min ${usingPreviousGoal ? 'previous goal' : 'avg'}",
                    Colors.green[900]!,
                    "duration",
                    durationOption2),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildSubgoalOptionTitle(
              "Maintain Current Level", Icons.equalizer_outlined),
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
                  Icon(Icons.check_circle_outline,
                      color: Colors.grey[700], size: 20),
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
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
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
    String goalText = "";
    switch (type) {
      case "distance":
        goalText =
            "increase your weekly average distance to ${targetValue.toStringAsFixed(1)} km";
        break;
      case "pace":
        goalText =
            "improve your weekly average pace to ${targetValue.toStringAsFixed(1)} min/km";
        break;
      case "duration":
        goalText =
            "extend your weekly average duration to ${targetValue.toStringAsFixed(0)} minutes";
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

  Widget _buildSubgoalOptionButton(String title, String value, String baseline,
      Color color, String type, double targetValue) {
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
            baselineStartDate = goalsDoc['baseline_StartDate']?.toDate();
            baselineEndDate = goalsDoc['baseline_EndDate']?.toDate();
          } else if (goalType == 'Endurance') {
            targetDistance = goalsDoc['targetDistance']?.toString() ?? "0";
            targetDuration = goalsDoc['targetDuration']?.toString() ?? "0";
          }
        });
      }
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
        // await _fetchActiveSubgoal();

        setState(() {
          activityData = newActivityData;
          totalActivities = activityData.length;

          weeklyActivityCount = 0;
          weeklyDistanceTotal = 0.0;

          print("what: $hasActiveSubgoal");

          if (hasActiveSubgoal == true) {
            for (var activity in activityData) {
              if (activity['start_date'] != null) {
                print(activity);
                DateTime activityDate = activity['start_date'].toDate();
                if (activityDate.isAfter(subgoalStartDate)) {
                  weeklyActivityCount++;
                  weeklyDistanceTotal += safeParseDouble(activity['distance']);
                }
              }
            }
          } else {
            DateTime now = DateTime.now();
            if (now.isBefore(baselineEndDate) &&
                now.isAfter(
                    baselineEndDate.subtract(const Duration(days: 6)))) {
              for (var activity in activityData) {
                if (activity['start_date'] != null) {
                  print(activity);
                  DateTime activityDate = activity['start_date'].toDate();
                  if (activityDate.isBefore(baselineEndDate) &&
                      activityDate.isAfter(
                          baselineEndDate.subtract(const Duration(days: 6)))) {
                    weeklyActivityCount++;
                    weeklyDistanceTotal +=
                        safeParseDouble(activity['distance']);
                  }
                }
              }
            } else if (now.isBefore(
                    baselineEndDate.subtract(const Duration(days: 6))) &&
                now.isAfter(
                    baselineEndDate.subtract(const Duration(days: 13)))) {
              for (var activity in activityData) {
                if (activity['start_date'] != null) {
                  print(activity);
                  DateTime activityDate = activity['start_date'].toDate();
                  if (activityDate.isBefore(
                          baselineEndDate.subtract(const Duration(days: 6))) &&
                      activityDate.isAfter(
                          baselineEndDate.subtract(const Duration(days: 13)))) {
                    weeklyActivityCount++;
                    weeklyDistanceTotal +=
                        safeParseDouble(activity['distance']);
                  }
                }
              }
            } else if (now.isBefore(
                    baselineEndDate.subtract(const Duration(days: 13))) &&
                now.isAfter(
                    baselineEndDate.subtract(const Duration(days: 20)))) {
              for (var activity in activityData) {
                if (activity['start_date'] != null) {
                  print(activity);
                  DateTime activityDate = activity['start_date'].toDate();
                  if (activityDate.isBefore(
                          baselineEndDate.subtract(const Duration(days: 13))) &&
                      activityDate.isAfter(
                          baselineEndDate.subtract(const Duration(days: 20)))) {
                    weeklyActivityCount++;
                    weeklyDistanceTotal +=
                        safeParseDouble(activity['distance']);
                  }
                }
              }
            } else if (now.isBefore(
                    baselineEndDate.subtract(const Duration(days: 20))) &&
                now.isAfter(
                    baselineEndDate.subtract(const Duration(days: 27)))) {
              for (var activity in activityData) {
                if (activity['start_date'] != null) {
                  print(activity);
                  DateTime activityDate = activity['start_date'].toDate();
                  if (activityDate.isBefore(
                          baselineEndDate.subtract(const Duration(days: 20))) &&
                      activityDate.isAfter(
                          baselineEndDate.subtract(const Duration(days: 27)))) {
                    weeklyActivityCount++;
                    weeklyDistanceTotal +=
                        safeParseDouble(activity['distance']);
                  }
                }
              }
            }
          }
          if (activityData.isNotEmpty) {
            if (activityData[0]['start_date'] != null) {
              lastActivityDate = activityData[0]['start_date'].toDate();
              daysSinceLastActivity =
                  DateTime.now().difference(lastActivityDate).inDays;
            }
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
        // Add gender to the fetched data
        gender = data['gender'] ?? "Male"; // Default to Male if not specified

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
        zone1HeartRate = (maxHeartRateCalculated * 0.6).round();
        zone2HeartRate = (maxHeartRateCalculated * 0.7).round();
        zone3HeartRate = (maxHeartRateCalculated * 0.8).round();
        zone4HeartRate = (maxHeartRateCalculated * 0.9).round();
        zone5HeartRate = (maxHeartRateCalculated * 0.95).round();
        recommendedHeartRate = maxHeartRateCalculated;
      });
    }

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
              "basalMetabolicRate":
                  data['basalMetabolicRate'] ?? basalMetabolicRate,
            });
          }

          setState(() {
            recentData = newRecentData;
          });
          print("Recent data updated: ${recentData.length} entries");

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
            .limit(7)
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
      _generateRecommendation();
      if (goalType == "High Intensity Cycling") {
        _calculateBaselines();
        await _fetchActiveSubgoal();
        print('huh: $hasActiveSubgoal');
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

    int maxFrequency = 0;
    dayFrequency.forEach((day, frequency) {
      if (frequency > maxFrequency) {
        maxFrequency = frequency;
        mostFrequentDay = day;
      }
    });

    hasRegularSchedule = maxFrequency > (activityData.length / 3);

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
      heartrateProgression = heartRates.reversed.toList();
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

    isImprovingOverTime = _checkImprovementTrend();

    isConsistent = dayGaps.isNotEmpty &&
        _calculateCoeffOfVariation(dayGaps.map((g) => g.toDouble()).toList()) <
            0.5;

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

      levelOfExertion = latestData['levelOfExertion']?.toString() ?? "0";
    } else if (recentData.length == 1) {
      var latestData = recentData[0];

      latestWeight = safeParseDouble(latestData['weight']);
      latestBodyFat = safeParseDouble(latestData['bodyFat']);

      levelOfExertion = latestData['levelOfExertion']?.toString() ?? "0";
    }
  }

  // Generate seasonal advice based on current weather
  void _generateSeasonalAdvice() {
    double temp = safeParseDouble(temperature);
    double humid = safeParseDouble(humidity);

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
      } else if (airQuality == "Poor" ||
          airQuality == "Very Poor" ||
          airQuality == "Extremely Poor") {
        seasonalAdvice =
            "Poor air quality: Consider indoor training to protect respiratory health.";
      } else if (humid > 85) {
        seasonalAdvice =
            "High humidity: Consider indoor training or early morning rides. Stay hydrated!";
      }
    } else {
      if (temp >= 15 && temp <= 25 && airQuality == "Good" && humid < 70) {
        seasonalAdvice = "Perfect cycling conditions! Enjoy your outdoor ride.";
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

    // Updated heart rate zones based on research (Fletcher, 2023)
    double maxHeartRate = 220 - age.toDouble();
    // Updated fat burning zone based on research (50-70% of max HR)
    double fatBurningZoneLower = maxHeartRate * 0.5;
    double fatBurningZoneUpper = maxHeartRate * 0.7;
    double zone2HeartRate = maxHeartRate * 0.6;

    double latestHeartRate = safeParseDouble(averageHeartrate);

    // Weight and body fat progress tracking
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
        // Updated based on Weegu et al. (2023) findings
        feedback =
            "Losing weight but not body fat. Add more HIIT with short work intervals (<60s) and active recovery periods (<90s) for better body composition.";
      });
    } else if (latestWeight > previousWeight &&
        latestBodyFat < previousBodyFat &&
        latestWeight > 0 &&
        previousWeight > 0 &&
        latestBodyFat > 0 &&
        previousBodyFat > 0) {
      setState(() {
        recommendation = "✅ Gaining Muscle";
        // Updated based on cycling HIIT research (Weegu et al., 2023)
        feedback =
            "Gaining weight while reducing body fat suggests muscle building. Cycling HIIT is effective for recruiting lower body muscles.";
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
        // Updated based on HIIT research (Weegu et al., 2023)
        feedback =
            "Adjust your training and nutrition. HIIT sessions 3x weekly for 8+ weeks are most effective for body composition changes.";
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
          // Updated based on Myles C's recommendations
          feedback =
              "Your current metrics: ${latestWeight.toStringAsFixed(1)} kg weight and ${latestBodyFat.toStringAsFixed(1)}% body fat. For results, aim for 30 minutes daily (180 minutes/week).";
        });
      } else if (safeParseDouble(weight) > 0) {
        setState(() {
          recommendation = "ℹ️ Starting Point Established";
          // Updated based on Adam K's recommendations
          feedback =
              "Your weight: ${weight} kg. Record post-workout data to track progress. Aim for 3x weekly cycling for at least 20 minutes each session.";
        });
      } else {
        setState(() {
          recommendation = "ℹ️ Building Baseline";
          // Based on Adam K's input about monitoring distance
          feedback =
              "Track metrics consistently for personalized recommendations. Focus on distance and heart rate for progress monitoring.";
        });
      }
    }

    // Calorie deficit recommendations
    if (totalCaloriesBurned > 0) {
      double dailyDeficitNeeded = (3500 * 2) / 30; // 2kg/month

      if (totalCaloriesBurned < dailyDeficitNeeded / 2 &&
          activityData.isNotEmpty) {
        trainingRecommendations.add(
            "Increase session duration by 15-20 minutes or add HIIT with short intervals (<60s) and active recovery (<90s) for better results.");
      } else if (totalCaloriesBurned > dailyDeficitNeeded) {
        // Updated based on recovery science (Dupuy et al.)
        trainingRecommendations.add(
            "Great calorie burn! Focus on recovery with compression garments and possibly cold therapy after sessions to reduce muscle damage and inflammation.");
      }
    }

    
    // Body fat percentage recommendations
    if (bodyFatPercentage > 0) {
       String bodyFatCategory = "";
    
    if (gender == "Female") {
      // Female body fat categories according to American Council on Exercise
      if (bodyFatPercentage < 10) {
        bodyFatCategory = "below essential fat";
      } else if (bodyFatPercentage <= 12) {
        bodyFatCategory = "essential fat";
      } else if (bodyFatPercentage <= 20) {
        bodyFatCategory = "athletic";
      } else if (bodyFatPercentage <= 24) {
        bodyFatCategory = "fitness";
      } else if (bodyFatPercentage <= 31) {
        bodyFatCategory = "acceptable";
      } else {
        bodyFatCategory = "obesity";
      }
    } else {
      // Male body fat categories according to American Council on Exercise
      if (bodyFatPercentage < 2) {
        bodyFatCategory = "below essential fat";
      } else if (bodyFatPercentage <= 4) {
        bodyFatCategory = "essential fat";
      } else if (bodyFatPercentage <= 13) {
        bodyFatCategory = "athletic";
      } else if (bodyFatPercentage <= 17) {
        bodyFatCategory = "fitness";
      } else if (bodyFatPercentage <= 25) {
        bodyFatCategory = "acceptable";
      } else {
        bodyFatCategory = "obesity";
      }
    }

    healthRecommendations.add(
        "Your body fat (${bodyFatPercentage.toStringAsFixed(1)}%) is in the '$bodyFatCategory' range for ${gender}.");

    // Gender-specific recommendations based on body fat category
    if (bodyFatCategory == "below essential fat") {
      healthRecommendations.add(
          "Your body fat percentage is below essential levels. This can be dangerous for health. Consider consulting a healthcare professional about healthy body composition.");
    } else if (bodyFatCategory == "obesity") {
      int recommendedSessions = weeklyActivityCount < 2 ? 3 : 4;
      // Updated based on Weegu et al. (2023) research
      healthRecommendations.add(
          "Aim for ${recommendedSessions} sessions/week for 8+ weeks. Cycling-based HIIT helps preserve muscle while reducing fat, with less joint impact than running.");
    } else if (bodyFatCategory == "acceptable") {
      // Updated based on HIIT research
      healthRecommendations.add(
          "Use 2:1 ratio of high-intensity to steady-state cardio with active recovery periods for optimal body composition changes.");
    } else if (bodyFatCategory == "fitness") {
      // Updated based on nutrition timing research
      healthRecommendations.add(
          "Focus on nutrition timing with pre-workout carbs (banana or eggs 1 hour before) and post-workout protein for better results.");
    } else if (bodyFatCategory == "athletic") {
      // Updated based on carbohydrate research
      healthRecommendations.add(
          "Shift to performance goals. For rides >2.5 hours, consume 90g carbs/hour from multiple sources. Mix glucose and fructose for better absorption.");
    } else if (bodyFatCategory == "essential fat") {
      healthRecommendations.add(
          "Maintain current level through consistent performance rather than further reduction.");
    }
  } else {
    // Updated based on Myles C's advice on BMI vs body fat
    healthRecommendations.add(
        "Measure your body fat percentage to receive more tailored recommendations - it's a better indicator of fitness than BMI. Focus on consistency rather than intensity initially.");
  }

    // BMR-based recommendations
    if (bmr > 0) {
      double activityFactor = weeklyActivityCount <= 2
          ? 1.375
          : weeklyActivityCount <= 4
              ? 1.55
              : 1.725;
      double weightLossTarget = bmr * activityFactor - 500;

      // Updated based on nutrition research
      trainingRecommendations.add(
          "Aim for ${weightLossTarget.toInt()} kcal daily intake for sustainable weight loss. Never start your workout on an empty stomach - eat something light 30-60 minutes before.");

      if (bmr > 1800) {
        trainingRecommendations.add(
            "Add 1-2 longer steady-state rides (60+ min) weekly to maximize fat utilization.");
      } else if (bmr < 1400) {
        trainingRecommendations.add(
            "Add resistance training 2x weekly to boost your metabolic rate alongside cycling.");
      }
    }

    // Heart rate recommendations - updated based on fat burning zone research
    if (latestHeartRate > 0) {
      if (latestHeartRate < fatBurningZoneLower) {
        trainingRecommendations.add(
            "Increase intensity to ${fatBurningZoneLower.toInt()}-${fatBurningZoneUpper.toInt()} bpm for optimal fat burning. This zone varies by individual fitness level.");
      } else if (latestHeartRate > fatBurningZoneUpper) {
        trainingRecommendations.add(
            "Use intervals: high intensity and active recovery (${zone2HeartRate.toInt()} bpm) for better lactate clearance and fat oxidation.");
      } else {
        trainingRecommendations.add(
            "Perfect fat-burning zone! Maintain this intensity for optimal results, but remember fat can be burned at various heart rates.");
      }
    }

    // HIIT session analysis - updated based on Weegu et al. (2023)
    int totalHighIntensitySessions = 0;
    List<int> lastFiveHeartRates = [];

    for (int i = 0; i < math.min(activityData.length, 20); i++) {
      double hr = safeParseDouble(activityData[i]['average_heartrate']);
      if (hr > fatBurningZoneLower) totalHighIntensitySessions++;
      if (i < 5 && hr > 0) lastFiveHeartRates.add(hr.toInt());
    }

    if (totalHighIntensitySessions < 12 && activityData.length >= 15) {
      trainingRecommendations.add(
          "Aim for at least 12 high-intensity sessions monthly (3x weekly) for optimal body composition changes.");
    }

    // Frequency recommendations - updated based on Adam K and Myles C's feedback
    if (weeklyActivityCount < 3) {
      trainingRecommendations.add(
          "Gradually build to 3 sessions weekly (minimum 20-30 minutes each), aiming for 12+ monthly sessions for effective results.");
    }

    // Weather recommendations - updated based on research
    if (weatherData.isNotEmpty) {
      double currentTemp = safeParseDouble(temperature);
      if (currentTemp > 28) {
        // Updated based on temperature impact research
        trainingRecommendations.add(
            "For hot weather (${currentTemp.toStringAsFixed(1)}°C), ride in early morning to avoid heat stress and increase hydration by 100-200ml per 20 minutes to prevent dehydration.");
      } else if (currentTemp < 10) {
        trainingRecommendations.add(
            "For cold weather, ensure proper 10-15 minute warm-up before high-intensity work.");
      }

      // Recovery recommendations - updated based on Dupuy et al.
      trainingRecommendations.add(
          "For optimal recovery: 1) active recovery with light cycling, 2) compression garments to reduce fatigue, 3) cold therapy or contrast water therapy to reduce DOMS and inflammation.");

      // Health condition recommendations - updated based on chronic disease management research
      if (respiratoryCondition == "Yes") {
        healthRecommendations.add(
            "With respiratory conditions, use shorter intervals (30s-1min) with longer recovery (2-3min). Avoid highly polluted areas as they can reduce lung function and performance.");
      }

      if (cardiovascularCondition == "Yes") {
        // Updated based on AHA recommendations
        healthRecommendations.add(
            "With cardiovascular conditions, maintain moderate intensity (${(maxHeartRate * 0.6).toInt()}-${(maxHeartRate * 0.7).toInt()} bpm) and aim for 150 minutes weekly. Always get checked by a doctor first.");
      }

      // Training structure - based on Weegu et al. (2023)
      if (weeklyActivityCount >= 3) {
        trainingRecommendations.add(
            "Structure weekly rides: ${math.min(3, weeklyActivityCount - 1)} HIIT sessions (with short work intervals <60s and active recovery <90s) plus ${math.max(1, weeklyActivityCount - 3)} moderate rides for recovery.");
      }
    }
  }

  void _generateCyclingEnduranceRecommendations() {
    // Basic data
    double targetDistanceValue = safeParseDouble(targetDistance);
    double currentDistanceValue = safeParseDouble(distance);
    double targetDurationValue = safeParseDouble(targetDuration);
    double currentDurationValue = safeParseDouble(sessionDuration) / 60;

    // Heart rate zones - updated based on the research
    double maxHeartRate = 220 - age.toDouble();
    double enduranceZoneLower = maxHeartRate * 0.65; // 65% of max HR
    double enduranceZoneUpper = maxHeartRate * 0.75; // 75% of max HR
    double thresholdZoneLower = maxHeartRate * 0.76; // 76% of max HR
    double thresholdZoneUpper = maxHeartRate * 0.90; // 90% of max HR

    // Zone 2 training for recovery and base building (60-70% of max HR)
    double zone2HeartRateLower = maxHeartRate * 0.6;
    double zone2HeartRateUpper = maxHeartRate * 0.7;
    double zone2HeartRate = (zone2HeartRateLower + zone2HeartRateUpper) / 2;
   
    double latestHeartRate = safeParseDouble(averageHeartrate);

    // Tracking progress and providing feedback
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
        // Updated based on Myles C's advice on tapering
        feedback =
            "Recent ride was shorter than previous. Focus on recovery before next endurance effort. Remember to taper workouts rather than stopping abruptly.";
      });
    } else if (latestAverageSpeed < previousAverageSpeed &&
        latestAverageSpeed > 0 &&
        previousAverageSpeed > 0) {
      setState(() {
        recommendation = "⚠️ Speed Decreasing";
        // Updated based on Myles C's advice on pacing
        feedback =
            "Average speed dropped. Work on consistent pacing during long rides. Adjusting pace is more effective than stopping and starting.";
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
        // Updated based on Adam K's advice on distance tracking
        feedback =
            "Track rides consistently for personalized endurance recommendations. Focus on distance as your primary metric.";
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

        // Updated based on Myles C's advice on progress expectations
        if (improvementPercent > 10) {
          trainingRecommendations.add(
              "Your endurance has improved ${improvementPercent.toStringAsFixed(0)}% compared to earlier rides. Excellent progression! Remember progress varies by individual - some see changes in 2 weeks, others in 3 months.");
        } else if (improvementPercent < -10) {
          trainingRecommendations.add(
              "Recent distances are ${(-improvementPercent).toStringAsFixed(0)}% shorter than earlier rides. Adjust training and ensure proper recovery. Progress isn't always linear.");
        } else {
          trainingRecommendations.add(
              "Your distance progression is stable. Continue improving by gradually increasing your longest ride each week (no more than 10% increase).");
        }
      }

      // Find longest ride ever
      double longestRide = distanceProgression.reduce(math.max);
      if (longestRide > 0 && targetDistanceValue > 0) {
        // Updated based on recommendations for recreational cycling
        double percentOfTarget = (longestRide / targetDistanceValue) * 100;
        trainingRecommendations.add(
            "Your longest ride (${longestRide.toStringAsFixed(1)} km) is ${percentOfTarget.toStringAsFixed(0)}% of your target. For recreational cycling, aim for at least 30 minutes per day (180 minutes/week).");
      }
    }

    // Heart rate zone analysis from historical data - updated with HRM research
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

      // Updated based on heart rate monitoring research
      if (endurancePercent < 60 && thresholdPercent > 30) {
        trainingRecommendations.add(
            "${thresholdPercent.toStringAsFixed(0)}% of your rides are above threshold zone. For endurance, focus more on Zone 2 (${enduranceZoneLower.toInt()}-${enduranceZoneUpper.toInt()} bpm). Heart rate monitoring helps measure exercise intensity and prevent overtraining.");
      }
    }

    // Recovery and overtraining prevention based on heart rate - updated based on HRM research
    if (heartrateProgression.length >= 10) {
      List<double> recentHRs = heartrateProgression.sublist(0, 5);
      List<double> earlierHRs = heartrateProgression.sublist(
          5, math.min(10, heartrateProgression.length));

      double recentAvg = recentHRs.reduce((a, b) => a + b) / recentHRs.length;
      double earlierAvg =
          earlierHRs.reduce((a, b) => a + b) / earlierHRs.length;

      double hrChangePercent = ((recentAvg - earlierAvg) / earlierAvg) * 100;

      // Updated based on HRM research for overtraining detection
      if (hrChangePercent > 5 && weeklyActivityCount > 3) {
        trainingRecommendations.add(
            "Your heart rate has increased by ${hrChangePercent.toStringAsFixed(1)}% recently. This may indicate fatigue or overtraining. Use HRM data to detect changes in max heart rate, a potential indicator of high training loads. Add an additional recovery day with light cycling at ${zone2HeartRate.toInt()} bpm.");
      } else if (hrChangePercent < -5) {
        trainingRecommendations.add(
            "Your heart rate has decreased by ${(-hrChangePercent).toStringAsFixed(1)}% recently, suggesting improved cardiovascular efficiency. Great progress!");
      }
    }

    // Current heart rate recommendations - updated based on Myles C's advice
    if (latestHeartRate > 0) {
      if (latestHeartRate > thresholdZoneUpper) {
        trainingRecommendations.add(
            "Heart rate too high for endurance. For recreational cycling, don't aim to reach your threshold. Stay within ${enduranceZoneLower.toInt()}-${enduranceZoneUpper.toInt()} bpm range for longer rides.");
      } else if (latestHeartRate < enduranceZoneLower) {
        trainingRecommendations.add(
            "Increase intensity to ${enduranceZoneLower.toInt()}-${enduranceZoneUpper.toInt()} bpm for better aerobic development.");
      } else if (latestHeartRate >= enduranceZoneLower &&
          latestHeartRate <= enduranceZoneUpper) {
        trainingRecommendations.add(
            "Perfect endurance zone! This heart rate range is optimal for building aerobic capacity.");
      } else {
        trainingRecommendations.add(
            "You're in threshold zone - good for tempo sessions but not longer endurance rides.");
      }
    }

    // Training structure based on research
    trainingRecommendations.add(
        "Follow 80/20 rule: 80% low intensity, 20% higher intensity rides. Heart rate monitors effectively measure exercise intensity and can help prevent overtraining.");

    // Distance progression
    if (currentDistanceValue > 0 &&
        targetDistanceValue > 0 &&
        currentDistanceValue < targetDistanceValue) {
      double percentComplete =
          (currentDistanceValue / targetDistanceValue) * 100;
      // Limit to 10% increase per week based on research
      double weeklyIncrease =
          math.min(targetDistanceValue * 0.1, currentDistanceValue * 0.1);

      trainingRecommendations.add(
          "You're ${percentComplete.toStringAsFixed(0)}% to goal. For safe progression, increase your long ride by no more than ${weeklyIncrease.toStringAsFixed(1)} km/week.");
    }

    // Frequency recommendations - updated based on Adam K & Myles C
    if (weeklyActivityCount < 3) {
      trainingRecommendations.add(
          "For optimal endurance benefits, aim for 3 rides/week (minimum 20 minutes each): one long ride, 2 shorter recovery rides.");
    }

    // Recovery strategies based on research - updated with Dupuy et al. research
    trainingRecommendations.add(
        "For optimal recovery: (1) active recovery with low-intensity cycling to enhance blood flow and remove metabolic waste, (2) compression garments to reduce perceived fatigue, and (3) cold therapy or contrast water therapy to reduce DOMS and inflammation.");

    // Weather and temperature considerations - updated based on research
    if (weatherData.isNotEmpty) {
      double currentTemp = safeParseDouble(temperature);
      double currentHumidity = safeParseDouble(humidity);

      // Updated based on temperature impact research
      if (currentTemp > 28) {
        trainingRecommendations.add(
            "At ${currentTemp.toStringAsFixed(1)}°C: Lower heart rate target by 5-10%, increase hydration frequency to prevent dehydration, and consider riding earlier in the morning to avoid heat stress.");

        // Updated based on humidity research
        if (currentHumidity > 70) {
          trainingRecommendations.add(
              "High humidity (${currentHumidity.toStringAsFixed(0)}%) restricts evaporative cooling and increases thermal stress. Reduce intensity and increase hydration further in these conditions. Acclimatization is important when training in humid areas.");
        }
      } else if (currentTemp < 10) {
        trainingRecommendations.add(
            "Cold weather (${currentTemp.toStringAsFixed(1)}°C): Extend your warm-up to 15-20 minutes and use layered clothing for optimal temperature regulation.");
      }

      // Health condition recommendations - updated based on research
      if (respiratoryCondition == "Yes") {
        // Updated based on air quality research
        healthRecommendations.add(
            "With your respiratory condition, build endurance gradually and monitor symptoms during exercise. Controlled aerobic exercise can increase respiratory stamina.");
        healthRecommendations.add(
            "Only ride outdoors when air quality is good, as pollution can exacerbate respiratory issues, reduce lung function, and decrease performance. Consider training in lower-pollution environments.");
      }

      if (cardiovascularCondition == "Yes") {
        // Updated based on AHA research and Myles C's advice
        healthRecommendations.add(
            "Focus on Zone 2 training (${zone2HeartRateLower.toInt()}-${zone2HeartRateUpper.toInt()} bpm) for cardiovascular health. The AHA recommends 150 minutes of moderate-intensity exercise weekly. Always get checked by a doctor first.");
        healthRecommendations.add(
            "Monitor heart rate carefully with a device like an Apple Watch or Fitbit, and increase intensity very gradually to avoid strain.");
      }

      // Nutrition recommendations - updated based on research and Myles C's advice
      healthRecommendations.add(
          "Pre-ride nutrition: Eat a light meal (like a banana or boiled eggs) 30-60 minutes before riding. Never start on an empty stomach. Post-ride: consume a 3:1 carb:protein ratio within 30 minutes.");

      // Updated based on Holland et al. (2017) hydration research
      if (currentDistanceValue > 30) {
        double rideHours = currentDurationValue / 60;
        double weightInKg = safeParseDouble(weight);

        if (rideHours >= 1 && rideHours <= 2) {
          // For 1-2 hour moderate-intensity rides
          double recommendedFluidRate = 0.175; // midpoint of 0.15-0.20 range
          double totalFluidRecommendation =
              recommendedFluidRate * weightInKg * rideHours * 60;

          healthRecommendations.add(
              "For your ${rideHours.toStringAsFixed(1)}-hour moderate rides, consume approximately ${totalFluidRecommendation.toInt()} ml of fluid (${(recommendedFluidRate * weightInKg).toStringAsFixed(1)} ml/min) for optimal performance.");
        } else if (rideHours > 2) {
          // For rides longer than 2 hours
          double recommendedFluidRate = 0.205; // midpoint of 0.14-0.27 range
          double totalFluidRecommendation =
              recommendedFluidRate * weightInKg * rideHours * 60;

          healthRecommendations.add(
              "For your ${rideHours.toStringAsFixed(1)}-hour rides, consume approximately ${totalFluidRecommendation.toInt()} ml of fluid total and 60-90g of carbohydrates per hour from multiple sources to maintain energy levels.");
        } else if (rideHours < 1 &&
            latestAverageHeartrate > thresholdZoneLower) {
          // For high-intensity rides under 1 hour
          healthRecommendations.add(
              "For high-intensity rides under 1 hour, excessive hydration can be counterproductive. Focus on pre-ride hydration instead of drinking large amounts during the ride.");
        }
      }

      // Recovery recommendations
      if (daysSinceLastActivity < 1 && weeklyActivityCount > 5) {
        healthRecommendations.add(
            "Add dedicated recovery days to prevent overtraining syndrome and reduce injury risk.");
      }

      // Equipment recommendations - added HRM based on research
      equipmentRecommendations.add(
          "Proper bike fit is crucial for endurance - small discomforts may become major issues on long rides.");
      equipmentRecommendations.add(
          "Especially for longer rides,  use a heart rate monitor to maintain proper intensity and track recovery.");
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
                      child: _buildSectionTitle("Personalized Insights",
                          Icons.lightbulb_outline_rounded),
                    ),
                    SizedBox(height: 12),
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
                      child: _buildSectionTitle("Your Analytics",
                          Icons.insert_chart_outlined_rounded),
                    ),
                    SizedBox(height: 50),
                    _buildWeeklySummary(),
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
        border:
            Border.all(color: Color(0xffFFA500).withOpacity(0.3), width: 1.5),
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
                Icon(Icons.access_time_rounded,
                    size: 14, color: Color(0xffFFA500)),
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

  Widget _buildExpandedPopup(BuildContext context, String title, IconData icon,
      Color color, List<Color> gradientColors, List<String> recommendations,
      {required VoidCallback onClose}) {
    return GestureDetector(
      onTap: () {}, // Prevent taps from closing the popup
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        tween: Tween<double>(begin: 0.8, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 15,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with close button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: Colors.white, size: 22),
                          ),
                          SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Fredoka-SemiBold',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Recommendations list
              Expanded(
                child: NotificationListener<OverscrollIndicatorNotification>(
                  onNotification: (overscroll) {
                    overscroll.disallowIndicator();
                    return true;
                  },
                  child: ListView.builder(
                    physics: BouncingScrollPhysics(),
                    padding: EdgeInsets.all(16),
                    itemCount: recommendations.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: EdgeInsets.only(bottom: 14),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: color.withOpacity(0.2), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.05),
                              spreadRadius: 0,
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                                color: color,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                recommendations[index],
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
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
              ),
            ],
          ),
        ),
      ),
    );
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

    if (progressRecommendations.isNotEmpty) {
      recommendationCategories.add({
        "title": "Progress Insights",
        "icon": Icons.insights_rounded,
        "color": Color(0xFF8E24AA),
        "gradientColors": [Color(0xFF8E24AA), Color(0xFF5E35B1)],
        "recommendations": progressRecommendations,
      });
    }

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

    // Reference to store the current overlay entry
    OverlayEntry? overlayEntry;

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
                    context,
                    category["title"],
                    category["icon"],
                    category["color"],
                    category["gradientColors"],
                    category["recommendations"],
                    onTap: () {
                      // Show fullscreen overlay when card is tapped
                      _showFullscreenOverlay(
                        context,
                        category["title"],
                        category["icon"],
                        category["color"],
                        category["gradientColors"],
                        category["recommendations"],
                      );
                    },
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

              // Pass null for weight as the fifth parameter
              chartData.add(PaceCaloriesData(
                  date, paceMinPerKm, calories, activityName, null));
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

            // Pass null for weight as the fifth parameter
            chartData.add(PaceCaloriesData(
                date, paceMinPerKm, calories, activityName, null));
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

        // Sort data by date (oldest first)
        chartData.sort((a, b) => a.date.compareTo(b.date));

        // Get the date range - first day to first day + 28 days
        DateTime startDate = chartData.first.date;
        DateTime endDate = startDate.add(Duration(days: 28));

        // Filter data to only include points within the 28-day range
        chartData = chartData
            .where((data) =>
                data.date.isAfter(startDate.subtract(Duration(days: 1))) &&
                data.date.isBefore(endDate.add(Duration(days: 1))))
            .toList();

        if (chartData.isEmpty) {
          return _buildEmptyGraph("No activities found in the 28-day period");
        }

        double avgPace = chartData.map((e) => e.pace).reduce((a, b) => a + b) /
            chartData.length;
        double avgCalories =
            chartData.map((e) => e.calories).reduce((a, b) => a + b) /
                chartData.length;

        PaceCaloriesData fastestSession =
            chartData.reduce((a, b) => a.pace < b.pace ? a : b);
        PaceCaloriesData highestCalorieSession =
            chartData.reduce((a, b) => a.calories > b.calories ? a : b);

        // For weight data, create data points
        double userWeight = safeParseDouble(weight);
        double previousUserWeight =
            previousWeight > 0 ? previousWeight : userWeight * 0.98;

        // Create weight data points at the start and end of the range
        List<Map<String, dynamic>> weightDataPoints = [];
        if (userWeight > 0) {
          weightDataPoints
              .add({'date': startDate, 'weight': previousUserWeight});
          weightDataPoints.add({'date': endDate, 'weight': userWeight});
        }

        // Set min/max weight values with some padding
        double minWeight = userWeight > 0
            ? math.min(userWeight, previousUserWeight) * 0.95
            : 50;
        double maxWeight = userWeight > 0
            ? math.max(userWeight, previousUserWeight) * 1.05
            : 100;

        return _buildGraphContainer(
          title: "Pace & Calories\nAnalysis",
          subtitle: "28-Day Period",
          height: 650,
          child: Column(
            children: [
              Expanded(
                child: SfCartesianChart(
                  margin: EdgeInsets.all(10),
                  primaryXAxis: DateTimeAxis(
                    minimum: startDate,
                    maximum: endDate,
                    majorGridLines: MajorGridLines(width: 0),
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: Colors.grey[700],
                    ),
                    dateFormat: DateFormat('MM/dd'),
                    intervalType: DateTimeIntervalType.days,
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
                    if (userWeight > 0)
                      NumericAxis(
                        name: 'Weight',
                        opposedPosition: true,
                        labelStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: Colors.green[700],
                        ),
                        minimum: minWeight,
                        maximum: maxWeight,
                        majorGridLines: MajorGridLines(width: 0),
                        axisLine: AxisLine(width: 0),
                      ),
                  ],
                  series: <ChartSeries>[
                    ColumnSeries<PaceCaloriesData, DateTime>(
                      name: 'Calories',
                      dataSource: chartData,
                      xValueMapper: (PaceCaloriesData data, _) => data.date,
                      yValueMapper: (PaceCaloriesData data, _) => data.calories,
                      width: 0.6,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(4)),
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
                          data == highestCalorieSession
                              ? Colors.orange[700]
                              : null,
                    ),
                    SplineSeries<PaceCaloriesData, DateTime>(
                      name: 'Pace',
                      dataSource: chartData,
                      xValueMapper: (PaceCaloriesData data, _) => data.date,
                      yValueMapper: (PaceCaloriesData data, _) => data.pace,
                      yAxisName: 'Pace',
                      color: Colors.blue[600],
                      width: 2.5,
                      markerSettings: MarkerSettings(
                        isVisible: true,
                        shape: DataMarkerType.circle,
                        width: 8,
                        height: 8,
                        borderWidth: 2,
                        borderColor: Colors.white,
                      ),
                      pointColorMapper: (PaceCaloriesData data, _) =>
                          data == fastestSession
                              ? Colors.green[600]
                              : Colors.blue[600],
                    ),
                    // Weight series
                    if (weightDataPoints.isNotEmpty)
                      ScatterSeries<Map<String, dynamic>, DateTime>(
                        name: 'Weight',
                        dataSource: weightDataPoints,
                        xValueMapper: (Map<String, dynamic> data, _) =>
                            data['date'],
                        yValueMapper: (Map<String, dynamic> data, _) =>
                            data['weight'],
                        yAxisName: 'Weight',
                        color: Colors.green[700],
                        markerSettings: MarkerSettings(
                          height: 10,
                          width: 10,
                          shape: DataMarkerType.diamond,
                          borderWidth: 2,
                          borderColor: Colors.white,
                        ),
                        dataLabelSettings: DataLabelSettings(
                          isVisible: true,
                          textStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                          builder: (dynamic data, dynamic point, dynamic series,
                              int pointIndex, int seriesIndex) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: Colors.green[700]!, width: 1),
                              ),
                              child: Text(
                                '${data['weight'].toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _generateEnhancedInsightText(chartData, avgPace,
                            avgCalories, fastestSession, highestCalorieSession),
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

  String _generateEnhancedInsightText(
      List<PaceCaloriesData> data,
      double avgPace,
      double avgCalories,
      PaceCaloriesData fastestSession,
      PaceCaloriesData highestCalorieSession) {
    List<PaceCaloriesData> recentSessions =
        data.length >= 3 ? data.sublist(data.length - 3) : data;
    bool improvingPace = true;
    bool increasingCalories = true;

    for (int i = 1; i < recentSessions.length; i++) {
      if (recentSessions[i].pace <= recentSessions[i - 1].pace) {
        improvingPace = false;
      }
      if (recentSessions[i].calories <= recentSessions[i - 1].calories) {
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
        String correlationExplanation =
            "Need more data points to determine correlation.";

        bool isInSurplus = false;
        double latestNetCalories = 0;

        if (chartData.isNotEmpty) {
          chartData.sort((a, b) => b.date.compareTo(a.date));
          latestNetCalories = chartData[0].netCalories;
          isInSurplus = latestNetCalories >= 0;
        }

        chartData.sort((a, b) => a.date.compareTo(b.date));

        DateTime startDate = chartData.first.date;
        DateTime endDate = startDate.add(Duration(days: 28));

        chartData = chartData
            .where((data) =>
                data.date.isAfter(startDate.subtract(Duration(days: 1))) &&
                data.date.isBefore(endDate.add(Duration(days: 1))))
            .toList();

        if (chartData.length >= 3) {
          double correlationCoefficient = data['correlationCoefficient'];

          if (correlationCoefficient < -0.7) {
            correlationStrength = "Strong negative";
            correlationExplanation = isInSurplus
                ? "Warning: Your caloric surplus is strongly associated with weight gain. Consider reducing calorie intake for better results."
                : "Great job! Your caloric deficit is strongly associated with weight loss. Continue your current approach.";
          } else if (correlationCoefficient < -0.3) {
            correlationStrength = "Moderate negative";
            correlationExplanation = isInSurplus
                ? "Note: Your caloric surplus shows moderate association with weight changes. Aim for a deficit to improve results."
                : "Good progress! Your caloric deficit is showing moderate association with weight loss. Maintain consistency for better results.";
          } else if (correlationCoefficient < 0.3) {
            correlationStrength = "Weak/No correlation";
            correlationExplanation = isInSurplus
                ? "Your caloric surplus doesn't yet show a clear relationship with weight changes. Consider tracking more consistently."
                : "Your caloric deficit hasn't yet shown a clear relationship with weight. Ensure you're tracking accurately and consistently.";
          } else if (correlationCoefficient < 0.7) {
            correlationStrength = "Moderate positive";
            correlationExplanation = isInSurplus
                ? "Caution: Your caloric surplus is moderately associated with weight gain, which may conflict with your goals."
                : "Unusual pattern: Despite caloric deficits, you're showing moderate weight gain. Consider reviewing tracking accuracy or consulting a professional.";
          } else {
            correlationStrength = "Strong positive";
            correlationExplanation = isInSurplus
                ? "Warning: Your caloric surplus is strongly driving weight gain, which may hinder your cycling performance goals."
                : "Unexpected trend: Despite tracking deficits, weight is increasing. Consider reviewing measurement accuracy or consulting a nutritionist.";
          }
        } else {
          correlationExplanation = isInSurplus
              ? "You're currently in a caloric surplus, which may slow weight loss progress. Track more data for better insights."
              : "You're currently in a caloric deficit, which supports weight loss goals. Track more data for personalized insights.";
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
          title: "Calories and\nWeight Correlation",
          subtitle: isInSurplus ? "Caloric Surplus" : "Caloric Deficit",
          height: 650,
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
                    minimum: startDate,
                    maximum: endDate,
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
                        color:
                            isInSurplus ? Colors.red[700] : Colors.green[700],
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
                        yValueMapper: (WeightCalorieData data, _) =>
                            data.netCalories,
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
                        yValueMapper: (WeightCalorieData data, _) =>
                            data.netCalories,
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(5),
                          border:
                              Border.all(color: Colors.green[200]!, width: 1),
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                padding: const EdgeInsets.only(
                    top: 20, bottom: 4, left: 16, right: 16),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isInSurplus ? Colors.red[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            isInSurplus ? Colors.red[200]! : Colors.green[200]!,
                        width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          isInSurplus
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          size: 16,
                          color: isInSurplus
                              ? Colors.red[700]
                              : Colors.green[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          correlationExplanation,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: isInSurplus
                                ? Colors.red[900]
                                : Colors.green[900],
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
        goalGraphs.add(_buildNutritionActivityGraph());
        goalGraphs.add(_buildHeartRateSpeedGraph());
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
        height: 650,
        child: goalGraphs.first,
      );
    }

    return Column(
      children: [
        Container(
          height: 450,
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
    double height = 650,
  }) {
    return Container(
      height: height,
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

    if (baselineComparison.containsKey('activity') &&
        baselineComparison['activity'].containsKey('baselineAvgDistance') &&
        baselineComparison['activity'].containsKey('currentAvgDistance')) {
      double baseline = baselineComparison['activity']['baselineAvgDistance'];
      double current = baselineComparison['activity']['currentAvgDistance'];
      double change = baselineComparison['activity']['distanceChange'];
      chartData
          .add(BaselineComparisonData("Distance", baseline, current, change));
    }

    if (baselineComparison.containsKey('activity') &&
        baselineComparison['activity'].containsKey('baselineAvgSpeed') &&
        baselineComparison['activity'].containsKey('currentAvgSpeed')) {
      double baseline = baselineComparison['activity']['baselineAvgSpeed'];
      double current = baselineComparison['activity']['currentAvgSpeed'];
      double change = baselineComparison['activity']['speedChange'];
      chartData.add(BaselineComparisonData("Speed", baseline, current, change));
    }

    if (baselineComparison.containsKey('activity') &&
        baselineComparison['activity'].containsKey('baselineAvgHeartRate') &&
        baselineComparison['activity'].containsKey('currentAvgHeartRate')) {
      double baseline = baselineComparison['activity']['baselineAvgHeartRate'];
      double current = baselineComparison['activity']['currentAvgHeartRate'];
      double change = baselineComparison['activity']['heartRateChange'];
      chartData
          .add(BaselineComparisonData("Heart Rate", baseline, current, change));
    }

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

    // Make sure flex values are at least 1 to avoid divide by zero errors
    int burnedFlex = math.max(1, weeklyCaloriesBurned.toInt());
    int consumedFlex = math.max(1, weeklyCaloriesConsumed.toInt());

    // Scale down if values are too large to prevent UI overflow
    if (burnedFlex > 10000 || consumedFlex > 10000) {
      int divisor = math.max(burnedFlex, consumedFlex) ~/ 1000;
      burnedFlex = burnedFlex ~/ divisor;
      consumedFlex = consumedFlex ~/ divisor;
    }

    // Calculate a fixed card height that will be safe for all cards
    double cardHeight = math.min(media.width * 0.45, 180);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
        Row(
          children: [
            Expanded(
              child: Container(
                height: cardHeight,
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
                    children: [
                      // Header
                      Row(
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

                      // Value display
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                          colors: [
                                        Color(0xffFFA500),
                                        Color(0xffFF8C00)
                                      ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight)
                                      .createShader(Rect.fromLTRB(
                                          0, 0, bounds.width, bounds.height));
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
                            ],
                          ),
                        ),
                      ),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: weeklyActivityCount /
                              math.max(1, (int.tryParse(daysPerWeek) ?? 7)),
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xffFFA500)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: cardHeight,
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
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

                      // Value display
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                          colors: [
                                        Color(0xffFF7E00),
                                        Color(0xffFF5900)
                                      ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight)
                                      .createShader(Rect.fromLTRB(
                                          0, 0, bounds.width, bounds.height));
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
            ),
          ],
        ),

        SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Container(
                height: cardHeight,
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
                    children: [
                      // Header
                      Row(
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

                      // Value display
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                          colors: [
                                        Color(0xffFF5900),
                                        Color(0xffFF3800)
                                      ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight)
                                      .createShader(Rect.fromLTRB(
                                          0, 0, bounds.width, bounds.height));
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
                            ],
                          ),
                        ),
                      ),

                      // Zone indicators
                      Container(
                        height: 30,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
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
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Weight Card
            Expanded(
              child: Container(
                height: cardHeight,
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
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

                      // Value display
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                          colors: [
                                        Color(0xffFF3800),
                                        Color(0xffE62200)
                                      ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight)
                                      .createShader(Rect.fromLTRB(
                                          0, 0, bounds.width, bounds.height));
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

                      // Change indicator
                      if (previousWeight > 0 && latestWeight > 0)
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(
                            color: latestWeight < previousWeight
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                latestWeight < previousWeight
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                size: 14,
                                color: latestWeight < previousWeight
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              SizedBox(width: 5),
                              Text(
                                "${(latestWeight - previousWeight).abs().toStringAsFixed(1)} kg",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: latestWeight < previousWeight
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
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
                                    colors: [
                                      Color(0xffFFA500),
                                      Color(0xffFF8C00)
                                    ],
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
                                    colors: [
                                      Color(0xff4CAF50),
                                      Color(0xff388E3C)
                                    ],
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
                      // Balance bar with safe flex values
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          children: [
                            Flexible(
                              flex: burnedFlex,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xffFFA500),
                                      Color(0xffFF8C00)
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(5),
                                    bottomLeft: Radius.circular(5),
                                    topRight: weeklyCaloriesConsumed == 0
                                        ? Radius.circular(5)
                                        : Radius.zero,
                                    bottomRight: weeklyCaloriesConsumed == 0
                                        ? Radius.circular(5)
                                        : Radius.zero,
                                  ),
                                ),
                              ),
                            ),
                            Flexible(
                              flex: consumedFlex,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xff4CAF50),
                                      Color(0xff388E3C)
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(5),
                                    bottomRight: Radius.circular(5),
                                    topLeft: weeklyCaloriesBurned == 0
                                        ? Radius.circular(5)
                                        : Radius.zero,
                                    bottomLeft: weeklyCaloriesBurned == 0
                                        ? Radius.circular(5)
                                        : Radius.zero,
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
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: weeklyCaloriesBurned > weeklyCaloriesConsumed
                            ? [Color(0xffFFA500), Color(0xffFF8C00)]
                            : [Color(0xff4CAF50), Color(0xff388E3C)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: weeklyCaloriesBurned > weeklyCaloriesConsumed
                              ? Color(0xffFFA500).withOpacity(0.3)
                              : Color(0xff4CAF50).withOpacity(0.3),
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
                          weeklyCaloriesBurned > weeklyCaloriesConsumed
                              ? Icons.trending_down_rounded
                              : Icons.trending_up_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Net: ${(weeklyCaloriesBurned - weeklyCaloriesConsumed).abs().toInt()} kcal ${weeklyCaloriesBurned > weeklyCaloriesConsumed ? 'deficit' : 'surplus'}",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
    );
  }

  Widget _buildHRZone(String zone, bool isActive, Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? color : Colors.grey[200],
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          zone,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
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

class _AnimatedFullscreenOverlayState extends State<_AnimatedFullscreenOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Create animation controller
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    // Create animations
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    // Start the animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    // Reverse the animation and then dismiss
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Material(
          color: Colors.black.withOpacity(0.7 * _opacityAnimation.value),
          child: InkWell(
            onTap: _dismiss,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: SafeArea(
              child: Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // Header with close button
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: widget.gradientColors,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          padding: EdgeInsets.fromLTRB(20, 16, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(widget.icon,
                                          color: Colors.white, size: 24),
                                    ),
                                    SizedBox(width: 14),
                                    Flexible(
                                      child: Text(
                                        widget.title,
                                        style: TextStyle(
                                          fontFamily: 'Fredoka-SemiBold',
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: _dismiss,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Content area - takes all available space
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              // Prevent taps inside content from closing
                            },
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              child: ListView.builder(
                                physics: BouncingScrollPhysics(),
                                padding: EdgeInsets.all(16),
                                itemCount: widget.recommendations.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 14),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: widget.color.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: widget.color.withOpacity(0.2),
                                          width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: widget.color.withOpacity(0.05),
                                          spreadRadius: 0,
                                          blurRadius: 5,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: EdgeInsets.only(top: 2),
                                          child: Icon(
                                            Icons.check_circle_rounded,
                                            size: 22,
                                            color: widget.color,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            widget.recommendations[index],
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 16,
                                              color: Colors.black87,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedAutoSizingOverlayState extends State<_AnimatedAutoSizingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Create animation controller
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    // Create animations
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    // Start the animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    // Reverse the animation and then dismiss
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  // Calculate font size based on recommendation count
  double _calculateFontSize() {
    int count = widget.recommendations.length;

    // Base font size that decreases as recommendation count increases
    if (count <= 3) return 16.0;
    if (count <= 5) return 15.0;
    if (count <= 8) return 14.0;
    if (count <= 12) return 13.0;
    if (count <= 16) return 12.0;
    return 11.0; // Minimum font size for readability
  }

  // Calculate icon size based on recommendation count
  double _calculateIconSize() {
    int count = widget.recommendations.length;

    if (count <= 3) return 22.0;
    if (count <= 5) return 20.0;
    if (count <= 8) return 18.0;
    if (count <= 12) return 16.0;
    return 14.0;
  }

  // Calculate item padding based on recommendation count
  EdgeInsets _calculateItemPadding() {
    int count = widget.recommendations.length;

    if (count <= 3) return EdgeInsets.all(16.0);
    if (count <= 5) return EdgeInsets.all(14.0);
    if (count <= 8) return EdgeInsets.all(12.0);
    if (count <= 12) return EdgeInsets.all(10.0);
    if (count <= 16) return EdgeInsets.all(8.0);
    return EdgeInsets.all(6.0);
  }

  // Calculate item margin based on recommendation count
  double _calculateItemMargin() {
    int count = widget.recommendations.length;

    if (count <= 3) return 14.0;
    if (count <= 5) return 12.0;
    if (count <= 8) return 10.0;
    if (count <= 12) return 8.0;
    if (count <= 16) return 6.0;
    return 4.0;
  }

  @override
  Widget build(BuildContext context) {
    // Auto-size calculations
    final fontSize = _calculateFontSize();
    final iconSize = _calculateIconSize();
    final itemPadding = _calculateItemPadding();
    final itemMargin = _calculateItemMargin();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Material(
          color: Colors.black.withOpacity(0.7 * _opacityAnimation.value),
          child: InkWell(
            onTap: _dismiss,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: SafeArea(
              child: Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // Header with close button
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: widget.gradientColors,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          padding: EdgeInsets.fromLTRB(20, 16, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(widget.icon,
                                          color: Colors.white, size: 24),
                                    ),
                                    SizedBox(width: 14),
                                    Flexible(
                                      child: Text(
                                        widget.title,
                                        style: TextStyle(
                                          fontFamily: 'Fredoka-SemiBold',
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: _dismiss,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: InkWell(
                            onTap: () {},
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              child: SingleChildScrollView(
                                physics: BouncingScrollPhysics(),
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: widget.recommendations
                                        .map((recommendation) {
                                      return Container(
                                        margin:
                                            EdgeInsets.only(bottom: itemMargin),
                                        padding: itemPadding,
                                        decoration: BoxDecoration(
                                          color: widget.color.withOpacity(0.05),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color:
                                                  widget.color.withOpacity(0.2),
                                              width: 1),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              margin: EdgeInsets.only(top: 2),
                                              child: Icon(
                                                Icons.check_circle_rounded,
                                                size: iconSize,
                                                color: widget.color,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                recommendation,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: fontSize,
                                                  color: Colors.black87,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
