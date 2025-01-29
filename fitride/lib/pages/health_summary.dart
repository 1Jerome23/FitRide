import 'package:fitride/pages/goal_tracking.dart';
import 'package:fitride/pages/home_page.dart';
import 'package:fitride/pages/profile.dart';
import 'package:fitride/pages/recommendation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HealthSummary extends StatefulWidget {
  @override
  _HealthSummaryState createState() => _HealthSummaryState();
}

class _HealthSummaryState extends State<HealthSummary> {

  Future<Map<String, dynamic>> _fetchData(String userId) async {
    try {
      final userQuestionnaireDoc = FirebaseFirestore.instance
          .collection('User Questionnaires')
          .doc(userId); 
      final activitiesDoc = FirebaseFirestore.instance
          .collection('activities')
          .doc(userId); 
      final afterExerciseFormDoc = FirebaseFirestore.instance
          .collection('After Exercise Form')
          .doc(userId); 

      final userQuestionnaireSnapshot = await userQuestionnaireDoc.get();
      final activitiesSnapshot = await activitiesDoc.get();
      final afterExerciseFormSnapshot = await afterExerciseFormDoc.get();

      print("User Questionnaire Data: ${userQuestionnaireSnapshot.data()}");
      print("Activities Data: ${activitiesSnapshot.data()}");
      print("After Exercise Form Data: ${afterExerciseFormSnapshot.data()}");

      return {
        'User Questionnaires': userQuestionnaireSnapshot.data(),
        'activities': activitiesSnapshot.data(),
        'afterExerciseForm': afterExerciseFormSnapshot.data(),
      };
    } catch (e) {
      throw Exception("Error fetching data: $e");
    }
  }

 @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? ''; 

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          "FitRide",
          style: GoogleFonts.roboto(
            color: Colors.orange,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              'assets/logobike.png',
              height: 40,
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchData(userId), 
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

          double weight = double.tryParse(data['User Questionnaires']?['weight']?.toString() ?? '0') ?? 0;
          double height = double.tryParse(data['User Questionnaires']?['height']?.toString() ?? '0') ?? 0;

          double heightInMeters = height / 100;

          double bmi = (heightInMeters > 0) ? weight / (heightInMeters * heightInMeters) : 0;


          var activities = data['activities']?['activities'] ?? [];
          double totalHeartRate = 0;
          int count = 0;

          for (var activity in activities) {
            double heartRate = double.tryParse(activity['average_heartrate']?.toString() ?? '0') ?? 0;
            if (heartRate > 0) {
              totalHeartRate += heartRate;
              count++;
            }
          }
          double averageHeartRate = (count > 0) ? totalHeartRate / count : 0;  

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Personal"),
                  _buildInfoRow("Name", data['User Questionnaires']?['name']?.toString() ?? 'N/A'),
                  _buildInfoRow("Weight", data['User Questionnaires']?['weight']?.toString() ?? 'N/A'),
                  _buildInfoRow("Height", data['User Questionnaires']?['height']?.toString() ?? 'N/A'),
                  _buildInfoRow("BMI", bmi > 0 ? bmi.toStringAsFixed(2) : 'Invalid data'),

                  _buildSectionTitle("Heart Health"),
                  _buildInfoRow("Consistent Heart Rate", averageHeartRate > 0 ? averageHeartRate.toStringAsFixed(2) : '0'),
                  _buildInfoRow("Have you experienced heart issues?", data['User Questionnaires']?['experiencedHeartRateIssues'] ?? 'N/A'),

                  _buildSectionTitle("Respiratory Health"),
                  _buildInfoRow("Respiratory Health Issues", data['User Questionnaires']?['difficultyBreathing'] ?? 'N/A'),

                  _buildSectionTitle("Fitness Goals"),
                  _buildInfoRow("Goals", data['User Questionnaires']?['goals'] ?? 'N/A'),
                  _buildInfoRow("Current Fitness Level", data['User Questionnaires']?['activityLevel'] ?? 'N/A'),
                  _buildInfoRow("Interested in improving cardiovascular endurance?", data['User Questionnaires']?['interestedInCardioEndurance'] ?? 'N/A'),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,  
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
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
    padding: const EdgeInsets.symmetric(vertical: 12.0),
    child: Row(
      children: [
        Icon(
          Icons.info_outline,
          color: Theme.of(context).primaryColor,
          size: 24,
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.roboto(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ],
    ),
  );
}

Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 15.0),
    child: Row(
      children: [
        Container(
          width: 180,
          child: Text(
            "$label: ",
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.roboto(
              fontSize: 18,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis, 
            softWrap: true,
          ),
        ),
      ],
    ),
  );
}

}
