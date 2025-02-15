import 'package:fitride/pages/goal_tracking.dart';
import 'package:fitride/pages/home_page.dart';
import 'package:fitride/pages/profile.dart';
import 'package:fitride/pages/recommendation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostExercise extends StatefulWidget {
  @override
  _PostExercise createState() => _PostExercise();
}

class _PostExercise extends State<PostExercise> {
  Future<Map<String, dynamic>> _fetchData() async {
    try {
      // Fetch data from all four collections in parallel
      final userQuestionnaireDoc = FirebaseFirestore.instance.collection('UserQuestionnaires').doc('userID');
      final weatherDataDoc = FirebaseFirestore.instance.collection('weatherData').doc('userID');
      final activitiesDoc = FirebaseFirestore.instance.collection('activities').doc('userID');
      final afterExerciseFormDoc = FirebaseFirestore.instance.collection('AfterExerciseForm').doc('userID');

      // Get documents from Firestore
      final userQuestionnaireSnapshot = await userQuestionnaireDoc.get();
      final weatherDataSnapshot = await weatherDataDoc.get();
      final activitiesSnapshot = await activitiesDoc.get();
      final afterExerciseFormSnapshot = await afterExerciseFormDoc.get();

      // Combine all data into a map
      return {
        'userQuestionnaire': userQuestionnaireSnapshot.data(),
        'weatherData': weatherDataSnapshot.data(),
        'activities': activitiesSnapshot.data(),
        'afterExerciseForm': afterExerciseFormSnapshot.data(),
      };
    } catch (e) {
      throw Exception("Error fetching data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          "Health Summary",
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return Center(child: Text('No data available.'));
          }

          final data = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heart Rate Section
                  _buildSectionTitle("Heart Health"),
                  _buildInfoRow("Heart Rate", data['userQuestionnaire']?['heartRate'] ?? 'N/A'),
                  _buildInfoRow("Cardiovascular Health", data['userQuestionnaire']?['cardiovascularHealth'] ?? 'N/A'),
                  _buildInfoRow("Have you experienced heart issues?", data['userQuestionnaire']?['heartIssues'] ?? 'N/A'),
                  
                  // Respiratory Health Section
                  _buildSectionTitle("Respiratory Health"),
                  _buildInfoRow("Respiratory Health", data['userQuestionnaire']?['respiratoryHealth'] ?? 'N/A'),
                  _buildInfoRow("Shortness of Breath", data['userQuestionnaire']?['shortnessOfBreath'] ?? 'N/A'),

                  // Fitness Goals Section
                  _buildSectionTitle("Fitness Goals"),
                  _buildInfoRow("Goals", (data['userQuestionnaire']?['goals'] as List).join(", ") ?? 'N/A'),
                  _buildInfoRow("Current Fitness Level", data['userQuestionnaire']?['fitnessLevel'] ?? 'N/A'),
                  _buildInfoRow("Interested in improving cardiovascular endurance?", data['userQuestionnaire']?['improveCardioEndurance'] ?? 'N/A'),

                  // Environmental Data Section
                  _buildSectionTitle("Environmental Data"),
                  _buildInfoRow("Weather Temperature", data['weatherData']?['weatherTemperature'] ?? 'N/A'),
                  _buildInfoRow("Humidity", data['weatherData']?['humidity'] ?? 'N/A'),
                  _buildInfoRow("Precipitation", data['weatherData']?['precipitation'] ?? 'N/A'),
                  _buildInfoRow("Air Quality", data['weatherData']?['airQuality'] ?? 'N/A'),

                  // Hydration and Sleep Section
                  _buildSectionTitle("Hydration and Sleep"),
                  _buildInfoRow("Hydration Level", data['afterExerciseForm']?['hydrationLevel'] ?? 'N/A'),
                  _buildInfoRow("Hydration", data['afterExerciseForm']?['hydration'] ?? 'N/A'),
                  _buildInfoRow("Sleep Quality", data['afterExerciseForm']?['sleep'] ?? 'N/A'),

                  // Food Intake & Energy Level Section
                  _buildSectionTitle("Food & Energy"),
                  _buildInfoRow("Food Intake", data['afterExerciseForm']?['foodIntake'] ?? 'N/A'),
                  _buildInfoRow("Energy Level", data['afterExerciseForm']?['energyLevel'] ?? 'N/A'),

                  // Physical Health Section
                  _buildSectionTitle("Physical Health"),
                  _buildInfoRow("BMI", data['activities']?['bmi'] ?? 'N/A'),
                  _buildInfoRow("Weight", data['activities']?['weight'] ?? 'N/A'),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,  // Adjust based on your app's navigation
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          // Handle navigation
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
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.data_usage),
            label: 'Goal/Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.roboto(
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
