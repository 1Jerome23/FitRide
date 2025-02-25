import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HealthSummary extends StatefulWidget {
  @override
  _HealthSummaryState createState() => _HealthSummaryState();
}

class _HealthSummaryState extends State<HealthSummary> {
Future<Map<String, dynamic>> _fetchData(String userId) async {
  try {
    final userDataSnapshot = await FirebaseFirestore.instance.collection('userData').doc(userId).get();
    final activitiesSnapshot = await FirebaseFirestore.instance.collection('activities').where('user_id', isEqualTo: userId).get();
    
    final athleteSnapshot = await FirebaseFirestore.instance.collection('athletes').doc(userId).get();
    final athleteData = athleteSnapshot.data() ?? {};

    final userData = userDataSnapshot.data() ?? {};
    final activities = activitiesSnapshot.docs.map((doc) => doc.data()).toList();
    
    double weight = double.tryParse(userData['weight']?.toString() ?? '0') ?? 0;
    double height = double.tryParse(userData['height']?.toString() ?? '0') ?? 0;
    double heightInMeters = height / 100;
    double bmi = (heightInMeters > 0) ? weight / (heightInMeters * heightInMeters) : 0;
    double metabolicRate = double.tryParse(userData['metabolic_rate']?.toString() ?? '0') ?? 0;
    double bodyFatPercentage = double.tryParse(userData['body_fat_percentage']?.toString() ?? '0') ?? 0;

    double totalHeartRate = 0;
    double maxHeartRate = 0;
    double totalDistance = 0;
    double totalCalories = 0;
    int heartRateCount = 0;
    
    for (var activity in activities) {
      double heartRate = double.tryParse(activity['average_heartrate']?.toString() ?? '0') ?? 0;
      double distance = double.tryParse(activity['distance']?.toString() ?? '0') ?? 0;
      double calories = double.tryParse(activity['calories_burned']?.toString() ?? '0') ?? 0;
      
      if (heartRate > 0) {
        totalHeartRate += heartRate;
        heartRateCount++;
      }
      if (heartRate > maxHeartRate) {
        maxHeartRate = heartRate;
      }
      totalDistance += distance;
      totalCalories += calories;
    }
    
    double averageHeartRate = (heartRateCount > 0) ? totalHeartRate / heartRateCount : 0;
    
    return {
      'athlete_name': athleteData['athlete_name'] ?? 'N/A',  // ✅ Fetch correctly
      'age': userData['age']?.toString() ?? 'N/A',
      'height': height.toString(),
      'weight': weight.toString(),
      'bmi': bmi.toStringAsFixed(2),
      'metabolic_rate': metabolicRate.toStringAsFixed(2),
      'body_fat_percentage': bodyFatPercentage.toStringAsFixed(2),
      'average_heart_rate': averageHeartRate.toStringAsFixed(2),
      'max_heart_rate': maxHeartRate.toStringAsFixed(2),
      'total_distance': totalDistance.toStringAsFixed(2),
      'total_calories': totalCalories.toStringAsFixed(2),
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
        title: Text("Health Summary", style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
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

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCard("Athlete Name", data['athlete_name']),
                _buildCard("Age", data['age']),
                _buildCard("Height (cm)", data['height']),
                _buildCard("Weight (kg)", data['weight']),
                _buildCard("BMI", data['bmi']),
                _buildCard("Metabolic Rate", data['metabolic_rate']),
                _buildCard("Body Fat Percentage", data['body_fat_percentage']),
                _buildCard("Average Heart Rate", data['average_heart_rate']),
                _buildCard("Max Heart Rate", data['max_heart_rate']),
                _buildCard("Total Distance Cycled (km)", data['total_distance']),
                _buildCard("Total Calories Burned", data['total_calories']),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(String label, String value) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "$label:",
              style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
            ),
            Text(
              value,
              style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w400, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
