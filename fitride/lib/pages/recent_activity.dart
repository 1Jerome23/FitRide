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

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (userId == null) return;

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('testAfterCycle')
          .doc(userId)
          .collection('dailyData')
          .orderBy('timestamp', descending: true)
          .limit(3) // Fetch the latest 3 entries
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          recentData = snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
          _generateRecommendation();
        });
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
        double.tryParse(latestData['weight'].toString()) ?? 0.0;
    double latestBodyFat =
        double.tryParse(latestData['body_fat'].toString()) ?? 0.0;
    double previousWeight =
        double.tryParse(previousData['weight'].toString()) ?? 0.0;
    double previousBodyFat =
        double.tryParse(previousData['body_fat'].toString()) ?? 0.0;

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
            Text(
              "Condition-Based Recommendations",
              style: GoogleFonts.roboto(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16),
            if (recentData.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Current Weight: ${recentData[0]['weight'].toString()} kg",
                    style: GoogleFonts.lato(fontSize: 16, color: Colors.black),
                  ),
                  Text(
                    "Current Body Fat: ${recentData[0]['body_fat'].toString()}%",
                    style: GoogleFonts.lato(fontSize: 16, color: Colors.black),
                  ),
                ],
              ),
            SizedBox(height: 20),
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
            Text(
              "Recent Activity Logs",
              style: GoogleFonts.roboto(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: recentData.length,
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
                      Text(
                        "Weight: ${data['weight'].toString()} kg",
                        style:
                            GoogleFonts.lato(fontSize: 16, color: Colors.black),
                      ),
                      Text(
                        "Body Fat: ${data['body_fat'].toString()}%",
                        style:
                            GoogleFonts.lato(fontSize: 16, color: Colors.black),
                      ),
                      Text(
                        "Exertion Level: ${data['exertion_level'].toString()}/10",
                        style:
                            GoogleFonts.lato(fontSize: 16, color: Colors.black),
                      ),
                      Text(
                        "Sleep: ${data['sleep'].toString()} hours",
                        style:
                            GoogleFonts.lato(fontSize: 16, color: Colors.black),
                      ),
                      Text(
                        "Water: ${data['water'].toString()} liters",
                        style:
                            GoogleFonts.lato(fontSize: 16, color: Colors.black),
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
