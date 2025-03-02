import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'goal_tracking.dart';
import 'login_register.dart';
import 'profile.dart';
import 'dart:async';

class RecommendationPage extends StatefulWidget {
  @override
  _RecommendationPageState createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  int _selectedIndex = 1;

  String? userId = FirebaseAuth.instance.currentUser?.uid;
  List<Map<String, dynamic>> recentData = [];
  List<Map<String, dynamic>> activityData = [];
  String recommendation = "Loading...";
  String feedback = "";
  bool showAllLogs = false;
  String goalType = "-";
  String currentLevel = "0";
  String weight = "0";
  String bodyFat = "0";
  String bodyWater = "0";
  String hydration = "0";
  String levelOfExertion = "0";
  String averageHeartrate = "0";
  String averageSpeed = "0";
  String caloriesBurned = "0";
  String distance = "0";
  String sessionDuration = "0";
  String daysPerWeek = "0";
  String targetDistance = "0";
  String targetWeight = "0";
  String targetDuration = "0";
  int age = 0;
  int recommendedHeartRate = 0;
  String healthCondition = "-";
  String height = "0";

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
      // Fetch the most recent document from goals collection where uid matches userId
      QuerySnapshot goalsQuery = await FirebaseFirestore.instance
          .collection('goals')
          .where('uid', isEqualTo: userId)
          .orderBy('timestamp',
              descending: true) // Sort by timestamp in descending order
          .limit(1) // Limit to the most recent document
          .get();

      if (goalsQuery.docs.isNotEmpty) {
        DocumentSnapshot goalsDoc =
            goalsQuery.docs.first; // Get the first (most recent) document

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

      QuerySnapshot activitiesQuery = await FirebaseFirestore.instance
          .collection('activities')
          .where('uid', isEqualTo: userId)
          .orderBy('start_date', descending: true)
          .limit(10)
          .get();
      if (activitiesQuery.docs.isNotEmpty) {
        for (var doc in activitiesQuery.docs) {
          var data = doc.data() as Map<String, dynamic>;

          // Add data to the recentData list
          activityData.add({
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
      } else {
        print("No documents found in activities for user $userId");
      }

      // Fetch the most recent document from userData collection where uid matches userId
      QuerySnapshot userDataQuery = await FirebaseFirestore.instance
          .collection('userData')
          .where('uid', isEqualTo: userId)
          .orderBy('timestamp',
              descending: true) // Sort by timestamp in descending order
          .limit(1) // Limit to the most recent document
          .get();

      if (userDataQuery.docs.isNotEmpty) {
        DocumentSnapshot userDataDoc =
            userDataQuery.docs.first; // Get the first (most recent) document
        setState(() {
          age = int.tryParse(userDataDoc['age']?.toString() ?? '30') ?? 30;
          healthCondition = userDataDoc['healthCondition'] ?? "-";
          height = userDataDoc['height']?.toString() ?? "0";
          weight = userDataDoc.data().toString().contains('weight')
              ? userDataDoc['weight']?.toString() ?? "0"
              : "0";
          bodyFat = userDataDoc.data().toString().contains('bodyFat')
              ? userDataDoc['bodyFat']?.toString() ?? "0"
              : "0";
          bodyWater = userDataDoc.data().toString().contains('bodyWater')
              ? userDataDoc['bodyWater']?.toString() ?? "0"
              : "0";
          recommendedHeartRate = 220 - age; // Calculate recommended heart rate
        });
      }

      // Fetch data from after_exercise collection (only if goal is not Leisure)
      print("User ID: $userId");
      print("Goal type from fetch: $goalType");
      if (goalType != "Leisure") {
        print("Attempting to fetch after_exercise data...");
        QuerySnapshot goalSnapshot = await FirebaseFirestore.instance
            .collection('after_exercise')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get();

        print("Query completed. Document count: ${goalSnapshot.docs.length}");

        if (goalSnapshot.docs.isNotEmpty) {
          for (var doc in goalSnapshot.docs) {
            var data = doc.data() as Map<String, dynamic>;

            // Add data to the recentData list
            recentData.add({
              "documentId": doc.id,
              "currentLevel": data['currentLevel'],
              "estimatedCalories": data['estimatedCalories'],
              "foodTaken": data['foodTaken'],
              "hydration": data['hydration'],
              "levelOfExertion": data['levelOfExertion'],
              "timestamp": data['timestamp'],
              "userId": data['userId'],
            });
          }
          print("Print recent data, $recentData");
        } else {
          print("No documents found in after_exercise for user $userId");
        }
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

  void _generateRecommendation() {
    print("Starting recommendation generation");
    print("Goal type: $goalType");
    print("Recent data count: ${recentData.length}");
    if (recentData.isEmpty && activityData.isEmpty) {
      setState(() {
        recommendation = "No data available.";
      });
      return;
    }

    // Only check for comparison if the goal is not "Leisure"
    if (goalType != "Leisure" && recentData.length < 2) {
      setState(() {
        recommendation = "Insufficient data for comparison.";
        feedback = "Please add more data to generate recommendations.";
      });
      return;
    } else if (goalType != "Leisure"){
      // Get the most recent and previous data
      var latestData = recentData[0];
      var previousData = recentData.length > 1 ? recentData[1] : null;
      var latestActivityData = activityData[0];
      var previousActivityData = activityData.length > 1 ? activityData[1] : null;
      // Update class-level variables
      setState(() {
        latestWeight = safeParseDouble(latestData['weight']);
        previousWeight =
        previousData != null ? safeParseDouble(previousData['weight']) : 0.0;

        latestBodyFat = safeParseDouble(latestData['bodyFat']);
        previousBodyFat =
        previousData != null ? safeParseDouble(previousData['bodyFat']) : 0.0;

        latestDistance = safeParseDouble(latestActivityData['distance']);
        previousDistance = previousActivityData != null
            ? safeParseDouble(previousActivityData['distance'])
            : 0.0;

        latestCaloriesBurned =
            safeParseDouble(latestActivityData['calories_burned']);
        previousCaloriesBurned = previousActivityData != null
            ? safeParseDouble(previousActivityData['calories_burned'])
            : 0.0;

        latestAverageSpeed = safeParseDouble(latestActivityData['average_speed']);
        previousAverageSpeed = previousActivityData != null
            ? safeParseDouble(previousActivityData['average_speed'])
            : 0.0;

        latestAverageHeartrate =
            safeParseDouble(latestActivityData['average_heartrate']);
        print(latestAverageHeartrate);
        previousAverageHeartrate = previousActivityData != null
            ? safeParseDouble(previousActivityData['average_heartrate'])
            : 0.0;
      });
    } else {
      // Get the most recent and previous data
      var latestActivityData = activityData[0];
      // Update class-level variables
      setState(() {
        latestDistance = safeParseDouble(latestActivityData['distance']);
        latestCaloriesBurned =
            safeParseDouble(latestActivityData['calories_burned']);
        latestAverageSpeed = safeParseDouble(latestActivityData['average_speed']);
        latestAverageHeartrate =
            safeParseDouble(latestActivityData['average_heartrate']);
        print(latestAverageHeartrate);

      });
    }


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
  }

  void _generateLeisureRecommendations() {
    int maxHeartRate = 220 - age;
    double targetHeartRate =
        maxHeartRate * 0.6; // 60% of max heart rate for leisure

    double latestHeartRate = safeParseDouble(latestAverageHeartrate);
    print(latestHeartRate);
    double latestExertion = safeParseDouble(levelOfExertion);

    if (latestHeartRate > targetHeartRate && latestHeartRate > 0) {
      setState(() {
        recommendation = "⚠️ Warning";
        feedback =
            "Your heart rate was higher than the recommended range for a recovery ride. Aim for a heart rate below ${targetHeartRate.toStringAsFixed(0)} bpm.";
      });
    } else if (latestHeartRate <= targetHeartRate &&
        latestExertion <= 5 &&
        latestHeartRate > 0 &&
        latestExertion > 0) {
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
    if (latestWeight < previousWeight &&
        latestBodyFat < previousBodyFat &&
        latestWeight > 0 &&
        previousWeight > 0 &&
        latestBodyFat > 0 &&
        previousBodyFat > 0) {
      setState(() {
        recommendation = "✅ Good";
        feedback =
            "Great job! You're losing both weight and body fat. Keep up the consistency with your cycling sessions and nutrition.";
      });
    } else if (latestWeight < previousWeight &&
        latestBodyFat >= previousBodyFat &&
        latestWeight > 0 &&
        previousWeight > 0 &&
        latestBodyFat > 0 &&
        previousBodyFat > 0) {
      setState(() {
        recommendation = "⚠️ Warning";
        feedback =
            "You're losing weight, but your body fat % isn’t dropping. Consider adding some strength training such as inclined cycling.";
      });
    } else if (latestWeight > previousWeight &&
        latestBodyFat < previousBodyFat &&
        latestWeight > 0 &&
        previousWeight > 0 &&
        latestBodyFat > 0 &&
        previousBodyFat > 0) {
      setState(() {
        recommendation = "✅ Good";
        feedback =
            "You're building muscle while burning fat! This is a great sign of improved fitness.";
      });
    } else if (latestWeight == previousWeight &&
        latestBodyFat < previousBodyFat &&
        latestWeight > 0 &&
        previousWeight > 0 &&
        latestBodyFat > 0 &&
        previousBodyFat > 0) {
      setState(() {
        recommendation = "✅ Good";
        feedback =
            "Your body fat % is going down while maintaining weight—this suggests you're replacing fat with muscle. Keep going!";
      });
    } else if (latestWeight == previousWeight &&
        latestBodyFat > previousBodyFat &&
        latestWeight > 0 &&
        previousWeight > 0 &&
        latestBodyFat > 0 &&
        previousBodyFat > 0) {
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
    print("Generating cycling endurance recommendations...");
    print("Latest distance: $latestDistance");
    print("Previous distance: $previousDistance");
    print("Latest speed: $latestAverageSpeed");

    if (latestDistance > previousDistance &&
        latestDistance > 0 &&
        previousDistance > 0) {
      setState(() {
        recommendation = "✅ Good";
        feedback =
            "Impressive ride today! Your endurance is improving—keep building on this momentum.";
      });
    } else if (latestAverageSpeed < previousAverageSpeed &&
        latestAverageSpeed > 0 &&
        previousAverageSpeed > 0) {
      setState(() {
        recommendation = "⚠️ Warning";
        feedback =
            "Your pace was lower today. Try to maintain a steady rhythm to improve endurance.";
      });
    } else if (latestAverageHeartrate > previousAverageHeartrate &&
        latestAverageHeartrate > 0 &&
        previousAverageHeartrate > 0) {
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
            // Recommendations Container
            Text(
              "Recommendations",
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
                  SizedBox(height: 12),
                  Text(
                    feedback,
                    style: GoogleFonts.lato(fontSize: 16, color: Colors.black),
                  ),
                  SizedBox(height: 20),

                  if (goalType == "Leisure") ...[
                    if (latestAverageHeartrate > recommendedHeartRate)
                      _buildGoalRecommendation(
                        "⚠️ Warning",
                        "Your heart rate was higher than the recommended range for a recovery ride. Aim for a heart rate below ${recommendedHeartRate.toStringAsFixed(0)} bpm.",
                      ),
                    if (latestAverageHeartrate <= recommendedHeartRate &&
                        double.parse(levelOfExertion) <= 5)
                      _buildGoalRecommendation(
                        "✅ Good",
                        "Great job keeping your session light! Your recovery rides are staying within the ideal range.",
                      ),
                  ],
                  if (goalType == "High Intensity Cycling") ...[
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
                        "You're losing weight, but your body fat % isnt dropping. Consider adding some strength training such as inclined cycling.",
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
                  if (goalType == "Endurance") ...[
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
                  SizedBox(height: 20),

                  // Target Distance Recommendations
                  if (goalType == "High Intensity Cycling") ...[
                    SizedBox(height: 12),
                    if (double.parse(distance) > double.parse(targetDistance))
                      _buildGoalRecommendation(
                        "✅ Good",
                        "Great job! You've exceeded your target distance of $targetDistance km. Keep pushing your limits'!!",
                      ),
                    if (double.parse(distance) < double.parse(targetDistance))
                      _buildGoalRecommendation(
                        "⚠️ Warning",
                        "You're below your target distance of $targetDistance km. Try to increase your distance gradually.",
                      ),
                    if (double.parse(distance) ==
                            double.parse(targetDistance) &&
                        double.parse(distance) != 0)
                      _buildGoalRecommendation(
                        "✅ Good",
                        "You've met your target distance of $targetDistance km. Well done!",
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
                    color: Colors.black,
                  ),
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
