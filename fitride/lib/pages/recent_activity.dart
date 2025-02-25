import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class RecentActivityPage extends StatefulWidget {
  @override
  _RecentActivityPageState createState() => _RecentActivityPageState();
}

class _RecentActivityPageState extends State<RecentActivityPage> {
  String? userId = FirebaseAuth.instance.currentUser?.uid;
  List<Map<String, dynamic>> recentData = [];
  String recommendation = "Loading...";
  String feedback = "";
  bool showAllLogs = false;
  String goalType = "-";
  String currentLevel = "-";
  String weight = "-";
  String bodyFat = "-";
  String bodyWater = "-";
  String hydration = "-";
  String levelOfExertion = "-";
  String averageHeartrate = "-";
  String averageSpeed = "-";
  String caloriesBurned = "-";
  String distance = "-";
  String sessionDuration = "-";
  String daysPerWeek = "-";
  String targetDistance = "-";
  String targetWeight = "-";

  // Variables for comparison
  double latestWeight = 0.0;
  double previousWeight = 0.0;
  double latestBodyFat = 0.0;
  double previousBodyFat = 0.0;
  double latestDistance = 0.0;
  double previousDistance = 0.0;
  double latestHydration = 0.0;
  double previousHydration = 0.0;
  double latestCaloriesBurned = 0.0;
  double previousCaloriesBurned = 0.0;
  double latestAverageSpeed = 0.0;
  double previousAverageSpeed = 0.0;
  double latestAverageHeartrate = 0.0;
  double previousAverageHeartrate = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (userId == null) return;

    try {
      // Fetch data from goals collection
      DocumentSnapshot goalsDoc = await FirebaseFirestore.instance
          .collection('goals')
          .doc(userId)
          .get();

      // Fetch data from after_exercise collection
      QuerySnapshot afterExerciseSnapshot = await FirebaseFirestore.instance
          .collection('after_exercise')
          .doc(userId)
          .collection('dailyData')
          .orderBy('timestamp', descending: true)
          .limit(10) // Limit to 10 entries
          .get();

      // Fetch data from activities collection
      QuerySnapshot activitiesSnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .doc(userId)
          .collection('dailyData')
          .orderBy('start_date', descending: true)
          .limit(10) // Limit to 10 entries
          .get();

      if (goalsDoc.exists) {
        setState(() {
          goalType = goalsDoc['goalType'] ?? "-";
          currentLevel = goalsDoc['currentLevel'] ?? "-";
          weight = goalsDoc['weight']?.toString() ?? "-";
          bodyFat = goalsDoc['bodyFat']?.toString() ?? "-";
          bodyWater = goalsDoc['bodyWater']?.toString() ?? "-";
          sessionDuration = goalsDoc['sessionDuration']?.toString() ?? "-";
          daysPerWeek = goalsDoc['daysPerWeek']?.toString() ?? "-";
          targetDistance = goalsDoc['targetDistance']?.toString() ?? "-";
          targetWeight = goalsDoc['targetWeight']?.toString() ?? "-";
        });
      }

      if (afterExerciseSnapshot.docs.isNotEmpty ||
          activitiesSnapshot.docs.isNotEmpty) {
        setState(() {
          recentData = [
            ...afterExerciseSnapshot.docs
                .map((doc) => doc.data() as Map<String, dynamic>),
            ...activitiesSnapshot.docs
                .map((doc) => doc.data() as Map<String, dynamic>),
          ];
        });

        // Fetch specific fields for recommendations
        if (activitiesSnapshot.docs.isNotEmpty) {
          var latestActivity =
              activitiesSnapshot.docs.first.data() as Map<String, dynamic>;
          setState(() {
            averageHeartrate =
                latestActivity['average_heartrate']?.toString() ?? "-";
            averageSpeed = latestActivity['average_speed']?.toString() ?? "-";
            caloriesBurned =
                latestActivity['calories_burned']?.toString() ?? "-";
            distance = latestActivity['distance']?.toString() ?? "-";
          });
        }

        if (afterExerciseSnapshot.docs.isNotEmpty) {
          var latestExercise =
              afterExerciseSnapshot.docs.first.data() as Map<String, dynamic>;
          setState(() {
            hydration = latestExercise['Hydration']?.toString() ?? "-";
            levelOfExertion =
                latestExercise['levelOfExertion']?.toString() ?? "-";
          });
        }

        _generateRecommendation();
      } else {
        setState(() {
          recommendation = "No data available.";
        });
      }
    } catch (e) {
      setState(() {
        recommendation = "Error fetching data.";
      });
      print("Error fetching user data: $e");
    }
  }

  void _generateRecommendation() {
    if (recentData.isEmpty) {
      setState(() {
        recommendation = "No data available.";
      });
      return;
    }

    // Ensure there are at least 2 entries to compare
    if (recentData.length < 2) {
      setState(() {
        recommendation = "Insufficient data for comparison.";
        feedback = "Please add more data to generate recommendations.";
      });
      return;
    }

    // Get the most recent and previous data
    var latestData = recentData[0];
    var previousData = recentData[1];

    // Update class-level variables
    setState(() {
      latestWeight =
          double.tryParse(latestData['weight']?.toString() ?? "0.0") ?? 0.0;
      previousWeight =
          double.tryParse(previousData['weight']?.toString() ?? "0.0") ?? 0.0;

      latestBodyFat =
          double.tryParse(latestData['bodyFat']?.toString() ?? "0.0") ?? 0.0;
      previousBodyFat =
          double.tryParse(previousData['bodyFat']?.toString() ?? "0.0") ?? 0.0;

      latestDistance =
          double.tryParse(latestData['distance']?.toString() ?? "0.0") ?? 0.0;
      previousDistance =
          double.tryParse(previousData['distance']?.toString() ?? "0.0") ?? 0.0;

      latestHydration =
          double.tryParse(latestData['Hydration']?.toString() ?? "0.0") ?? 0.0;
      previousHydration =
          double.tryParse(previousData['Hydration']?.toString() ?? "0.0") ??
              0.0;

      latestCaloriesBurned =
          double.tryParse(latestData['calories_burned']?.toString() ?? "0.0") ??
              0.0;
      previousCaloriesBurned = double.tryParse(
              previousData['calories_burned']?.toString() ?? "0.0") ??
          0.0;

      latestAverageSpeed =
          double.tryParse(latestData['average_speed']?.toString() ?? "0.0") ??
              0.0;
      previousAverageSpeed =
          double.tryParse(previousData['average_speed']?.toString() ?? "0.0") ??
              0.0;

      latestAverageHeartrate = double.tryParse(
              latestData['average_heartrate']?.toString() ?? "0.0") ??
          0.0;
      previousAverageHeartrate = double.tryParse(
              previousData['average_heartrate']?.toString() ?? "0.0") ??
          0.0;
    });

    // Generate recommendations based on goal type
    switch (goalType) {
      case "Leisure":
        _generateLeisureRecommendations();
        break;
      case "Weight Management":
        _generateWeightManagementRecommendations();
        break;
      case "Cycling Endurance":
        _generateCyclingEnduranceRecommendations();
        break;
      default:
        setState(() {
          recommendation = "No goal type selected.";
          feedback = "Please set a goal in the app.";
        });
    }
  }

  void _generateLeisureRecommendations() {
    if (latestAverageHeartrate > previousAverageHeartrate &&
        double.parse(levelOfExertion) > 5) {
      setState(() {
        recommendation = "⚠️ Warning";
        feedback =
            "Your effort today was higher than usual for a recovery ride. Try slowing down your pace next time to stay in a relaxed zone.";
      });
    } else if (latestAverageHeartrate <= previousAverageHeartrate &&
        double.parse(levelOfExertion) <= 5) {
      setState(() {
        recommendation = "✅ Good";
        feedback =
            "Great job keeping your session light! Your recovery rides are staying within the ideal range.";
      });
    } else {
      setState(() {
        recommendation = "No clear trend detected.";
        feedback = "Ensure consistent tracking for better insights.";
      });
    }
  }

  void _generateWeightManagementRecommendations() {
    if (latestWeight < previousWeight && latestBodyFat < previousBodyFat) {
      setState(() {
        recommendation = "✅ Good";
        feedback =
            "Great job! You're losing both weight and body fat. Keep up the consistency with your cycling sessions and nutrition.";
      });
    } else if (latestWeight < previousWeight &&
        latestBodyFat >= previousBodyFat) {
      setState(() {
        recommendation = "⚠️ Warning";
        feedback =
            "You're losing weight, but your body fat % isn’t dropping. Consider adding some strength training such as inclined cycling.";
      });
    } else if (latestWeight > previousWeight &&
        latestBodyFat < previousBodyFat) {
      setState(() {
        recommendation = "✅ Good";
        feedback =
            "You're building muscle while burning fat! This is a great sign of improved fitness.";
      });
    } else if (latestWeight == previousWeight &&
        latestBodyFat < previousBodyFat) {
      setState(() {
        recommendation = "✅ Good";
        feedback =
            "Your body fat % is going down while maintaining weight—this suggests you're replacing fat with muscle. Keep going!";
      });
    } else if (latestWeight == previousWeight &&
        latestBodyFat > previousBodyFat) {
      setState(() {
        recommendation = "⚠️ Warning";
        feedback =
            "Your weight is stable, but body fat % is rising. Review your nutrition—ensure you're burning more than you consume.";
      });
    } else {
      setState(() {
        recommendation = "No clear trend detected.";
        feedback = "Ensure consistent tracking for better insights.";
      });
    }
  }

  void _generateCyclingEnduranceRecommendations() {
    if (latestDistance > previousDistance) {
      setState(() {
        recommendation = "✅ Good";
        feedback =
            "Impressive ride today! Your endurance is improving—keep building on this momentum.";
      });
    } else if (latestAverageSpeed < previousAverageSpeed) {
      setState(() {
        recommendation = "⚠️ Warning";
        feedback =
            "Your pace was lower today. Try to maintain a steady rhythm to improve endurance.";
      });
    } else if (latestAverageHeartrate > previousAverageHeartrate) {
      setState(() {
        recommendation = "⚠️ Warning";
        feedback =
            "Your heart rate was higher than usual. Ensure you’re pacing yourself to sustain longer rides.";
      });
    } else {
      setState(() {
        recommendation = "No clear trend detected.";
        feedback = "Ensure consistent tracking for better insights.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Recent Activity",
          style: GoogleFonts.roboto(
            color: Colors.orange,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Condition-Based Recommendations
            Text(
              "Condition-Based Recommendations",
              style: GoogleFonts.roboto(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16),
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
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Recommendation: $recommendation",
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getRecommendationColor(recommendation),
                      )),
                  SizedBox(height: 12),
                  Text(
                    feedback,
                    style: GoogleFonts.lato(fontSize: 16, color: Colors.black),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Goal-Based Recommendations
            Text(
              "Goal-Based Recommendations",
              style: GoogleFonts.roboto(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            SizedBox(height: 16),
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
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (goalType == "Leisure") ...[
                    if (latestAverageHeartrate > previousAverageHeartrate &&
                        double.parse(levelOfExertion) > 5)
                      _buildGoalRecommendation(
                        "⚠️ Warning",
                        "Your effort today was higher than usual for a recovery ride. Try slowing down your pace next time to stay in a relaxed zone.",
                      ),
                    if (latestAverageHeartrate <= previousAverageHeartrate &&
                        double.parse(levelOfExertion) <= 5)
                      _buildGoalRecommendation(
                        "✅ Good",
                        "Great job keeping your session light! Your recovery rides are staying within the ideal range.",
                      ),
                  ],
                  if (goalType == "Weight Management") ...[
                    if (latestWeight < previousWeight &&
                        latestBodyFat < previousBodyFat)
                      _buildGoalRecommendation(
                        "✅ Good",
                        "Great job! You're losing both weight and body fat. Keep up the consistency with your cycling sessions and nutrition.",
                      ),
                    if (latestWeight < previousWeight &&
                        latestBodyFat >= previousBodyFat)
                      _buildGoalRecommendation(
                        "⚠️ Warning",
                        "You're losing weight, but your body fat % isn’t dropping. Consider adding some strength training such as inclined cycling.",
                      ),
                    if (latestWeight > previousWeight &&
                        latestBodyFat < previousBodyFat)
                      _buildGoalRecommendation(
                        "✅ Good",
                        "You're building muscle while burning fat! This is a great sign of improved fitness.",
                      ),
                    if (latestWeight == previousWeight &&
                        latestBodyFat < previousBodyFat)
                      _buildGoalRecommendation(
                        "✅ Good",
                        "Your body fat % is going down while maintaining weight—this suggests you're replacing fat with muscle. Keep going!",
                      ),
                    if (latestWeight == previousWeight &&
                        latestBodyFat > previousBodyFat)
                      _buildGoalRecommendation(
                        "⚠️ Warning",
                        "Your weight is stable, but body fat % is rising. Review your nutrition—ensure you're burning more than you consume.",
                      ),
                  ],
                  if (goalType == "Cycling Endurance") ...[
                    if (latestDistance > previousDistance)
                      _buildGoalRecommendation(
                        "✅ Good",
                        "Impressive ride today! Your endurance is improving—keep building on this momentum.",
                      ),
                    if (latestAverageSpeed < previousAverageSpeed)
                      _buildGoalRecommendation(
                        "⚠️ Warning",
                        "Your pace was lower today. Try to maintain a steady rhythm to improve endurance.",
                      ),
                    if (latestAverageHeartrate > previousAverageHeartrate)
                      _buildGoalRecommendation(
                        "⚠️ Warning",
                        "Your heart rate was higher than usual. Ensure you’re pacing yourself to sustain longer rides.",
                      ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 20),

            // Recent Activity Logs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent Activity Logs",
                  style: GoogleFonts.roboto(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                if (recentData.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showAllLogs = !showAllLogs;
                      });
                    },
                    child: Text(
                      showAllLogs ? "Hide All" : "View All",
                      style:
                          GoogleFonts.lato(fontSize: 16, color: Colors.orange),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            if (recentData.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: showAllLogs ? recentData.length : 1,
                itemBuilder: (context, index) {
                  var data = recentData[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
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
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['levelOfExertion'] != null)
                          Text(
                            "Level of Exertion: ${data['levelOfExertion'].toString()}/10",
                            style: GoogleFonts.lato(
                                fontSize: 16, color: Colors.black),
                          ),
                        if (data['Hydration'] != null)
                          Text(
                            "Hydration: ${data['Hydration'].toString()} liters",
                            style: GoogleFonts.lato(
                                fontSize: 16, color: Colors.black),
                          ),
                        if (data['average_heartrate'] != null)
                          Text(
                            "Average Heartrate: ${data['average_heartrate'].toString()} bpm",
                            style: GoogleFonts.lato(
                                fontSize: 16, color: Colors.black),
                          ),
                        if (data['average_speed'] != null)
                          Text(
                            "Average Speed: ${data['average_speed'].toString()} km/h",
                            style: GoogleFonts.lato(
                                fontSize: 16, color: Colors.black),
                          ),
                        if (data['calories_burned'] != null)
                          Text(
                            "Calories Burned: ${data['calories_burned'].toString()} kcal",
                            style: GoogleFonts.lato(
                                fontSize: 16, color: Colors.black),
                          ),
                        if (data['distance'] != null)
                          Text(
                            "Distance: ${data['distance'].toString()} km",
                            style: GoogleFonts.lato(
                                fontSize: 16, color: Colors.black),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalRecommendation(String title, String feedback) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _getRecommendationColor(title),
            ),
          ),
          SizedBox(height: 4),
          Text(
            feedback,
            style: GoogleFonts.lato(fontSize: 14, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Color _getRecommendationColor(String recommendation) {
    switch (recommendation) {
      case "✅ Good":
        return Colors.green;
      case "⚠️ Warning":
        return Colors.orange;
      case "❌ Bad":
        return Colors.red;
      default:
        return Colors.black;
    }
  }
}
