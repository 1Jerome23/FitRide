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
  String averageSpeed = "-";
  String caloriesBurned = "-";
  String distance = "-";
  String hydration = "-";
  String foodTaken = "-";
  String weightTraining = "-";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (userId == null) return;

    try {
      // Fetch data from User Questionnaire collection
      DocumentSnapshot userQuestionnaireDoc = await FirebaseFirestore.instance
          .collection('User Questionnaire')
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
            averageSpeed = latestActivity['average_speed']?.toString() ?? "-";
            caloriesBurned =
                latestActivity['calories_burned']?.toString() ?? "-";
            distance = latestActivity['distance']?.toString() ?? "-";
            weightTraining =
                latestActivity['WeightTraining']?.toString() ?? "-";
          });
        }

        if (afterExerciseSnapshot.docs.isNotEmpty) {
          var latestExercise =
              afterExerciseSnapshot.docs.first.data() as Map<String, dynamic>;
          setState(() {
            hydration = latestExercise['hydration']?.toString() ?? "-";
            foodTaken = latestExercise['foodTaken']?.toString() ?? "-";
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

    double latestWeight =
        double.tryParse(latestData['weight']?.toString() ?? "0.0") ?? 0.0;
    double latestBodyFat =
        double.tryParse(latestData['bodyFat']?.toString() ?? "0.0") ?? 0.0;
    double previousWeight =
        double.tryParse(previousData['weight']?.toString() ?? "0.0") ?? 0.0;
    double previousBodyFat =
        double.tryParse(previousData['bodyFat']?.toString() ?? "0.0") ?? 0.0;

    String weightTrend = _getTrend(latestWeight, previousWeight);
    String bodyFatTrend = _getTrend(latestBodyFat, previousBodyFat);

    setState(() {
      if (weightTrend == "↓" && bodyFatTrend == "↓") {
        recommendation = "✅ Good";
        feedback =
            "You're losing weight & fat! Keep it up by maintaining your routine.";
      } else if (weightTrend == "↓" && bodyFatTrend == "↑") {
        recommendation = "⚠️ Warning";
        feedback =
            "You're losing weight but gaining fat. Try increasing protein intake & strength training.";
      } else if (weightTrend == "↑" && bodyFatTrend == "↓") {
        recommendation = "✅ Good";
        feedback = "You're gaining muscle and losing fat. Great progress!";
      } else if (weightTrend == "=" && bodyFatTrend == "↓") {
        recommendation = "✅ Good";
        feedback =
            "You're maintaining weight but reducing fat. Keep up the balance!";
      } else if (weightTrend == "=" && bodyFatTrend == "↑") {
        recommendation = "❌ Bad";
        feedback =
            "You might be gaining fat. Consider adjusting nutrition & workouts.";
      } else {
        recommendation = "No clear trend detected.";
        feedback = "Ensure consistent tracking for better insights.";
      }
    });
  }

  String _getTrend(double current, double previous) {
    if (current > previous) return "↑";
    if (current < previous) return "↓";
    return "=";
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
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Recommendation: $recommendation",
                    style: GoogleFonts.lato(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getRecommendationColor(recommendation),
                    ),
                  ),
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
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (averageSpeed != "-")
                    _buildGoalRecommendation(
                      "✅ Increase Average Speed by X%",
                      "Try increasing your cadence to improve speed by 0.5 km/h next week.",
                    ),
                  if (caloriesBurned != "-")
                    _buildGoalRecommendation(
                      "✅ Increase Calories Burned per Ride",
                      "Try extending your ride by 10 minutes to burn an extra 50 kcal.",
                    ),
                  if (distance != "-")
                    _buildGoalRecommendation(
                      "✅ Improve Distance per Week",
                      "Aim to ride 5 km more this week compared to last week.",
                    ),
                  if (hydration != "-" &&
                      double.tryParse(hydration) != null &&
                      double.parse(hydration) < 1.5)
                    _buildGoalRecommendation(
                      "✅ Stay Hydrated (Hydration Goal)",
                      "You drank only $hydration L today. Aim for at least 1.5-2L daily to improve recovery.",
                    ),
                  if (foodTaken != "-" && foodTaken.isEmpty)
                    _buildGoalRecommendation(
                      "✅ Maintain Energy Levels (Food & Nutrition)",
                      "Your last ride was at high exertion with no food intake. Consider a pre-ride snack for energy.",
                    ),
                  if (weightTraining != "-" && weightTraining.isNotEmpty)
                    _buildGoalRecommendation(
                      "✅ Balance Weight Training & Cardio",
                      "Strength training helps! Try 1-2 weight sessions per week to boost cycling power.",
                    ),
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
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['exertion_level'] != null)
                          Text(
                            "Exertion Level: ${data['exertion_level'].toString()}/10",
                            style: GoogleFonts.lato(
                                fontSize: 16, color: Colors.black),
                          ),
                        if (data['sleep'] != null)
                          Text(
                            "Sleep: ${data['sleep'].toString()} hours",
                            style: GoogleFonts.lato(
                                fontSize: 16, color: Colors.black),
                          ),
                        if (data['water'] != null)
                          Text(
                            "Water: ${data['water'].toString()} liters",
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
                        if (data['WeightTraining'] != null)
                          Text(
                            "Weight Training: ${data['WeightTraining'].toString()}",
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
              color: Colors.green,
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
