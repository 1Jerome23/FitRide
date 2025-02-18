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

    // Extract values for comparison
    double latestDistance =
        double.tryParse(latestData['distance']?.toString() ?? "0.0") ?? 0.0;
    double previousDistance =
        double.tryParse(previousData['distance']?.toString() ?? "0.0") ?? 0.0;

    double latestHydration =
        double.tryParse(latestData['hydration']?.toString() ?? "0.0") ?? 0.0;
    double previousHydration =
        double.tryParse(previousData['hydration']?.toString() ?? "0.0") ?? 0.0;

    double latestCaloriesBurned =
        double.tryParse(latestData['calories_burned']?.toString() ?? "0.0") ??
            0.0;
    double previousCaloriesBurned =
        double.tryParse(previousData['calories_burned']?.toString() ?? "0.0") ??
            0.0;

    double latestAverageSpeed =
        double.tryParse(latestData['average_speed']?.toString() ?? "0.0") ??
            0.0;
    double previousAverageSpeed =
        double.tryParse(previousData['average_speed']?.toString() ?? "0.0") ??
            0.0;

    // Compare historical data and generate recommendations
    String recommendationMessage = "";
    String feedbackMessage = "";

    if (latestDistance < previousDistance &&
        latestHydration < previousHydration) {
      recommendationMessage = "⚠️ Warning";
      feedbackMessage =
          "Your distance and hydration have decreased. Try drinking more water and increasing your workout intensity!";
    } else if (latestDistance < previousDistance) {
      recommendationMessage = "⚠️ Warning";
      feedbackMessage =
          "Your distance has decreased. Consider pushing yourself a bit more next time!";
    } else if (latestHydration < previousHydration) {
      recommendationMessage = "⚠️ Warning";
      feedbackMessage =
          "Your hydration has decreased. Make sure to drink enough water before and after your workout!";
    } else if (latestCaloriesBurned < previousCaloriesBurned) {
      recommendationMessage = "⚠️ Warning";
      feedbackMessage =
          "You burned fewer calories this time. Try increasing the duration or intensity of your workout!";
    } else if (latestAverageSpeed < previousAverageSpeed) {
      recommendationMessage = "⚠️ Warning";
      feedbackMessage =
          "Your average speed has decreased. Focus on maintaining a consistent pace!";
    } else {
      recommendationMessage = "✅ Good";
      feedbackMessage = "You're making progress! Keep up the good work!";
    }

    setState(() {
      recommendation = recommendationMessage;
      feedback = feedbackMessage;
    });
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
                  )
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
