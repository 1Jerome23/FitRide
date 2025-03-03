import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HealthSummary extends StatefulWidget {
  @override
  _HealthSummaryState createState() => _HealthSummaryState();
}

class _HealthSummaryState extends State<HealthSummary> {
  late String userId;
  String goalType = "-";
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    userId = user?.uid ?? '';
    if (userId.isNotEmpty) {
    fetchGoalType();
  }
  }
  Future<void> fetchGoalType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("❌ No authenticated user.");
      return;
    }

    print("🔍 Fetching goalType for userId: ${user.uid}");

    try {
      QuerySnapshot goalsQuery = await FirebaseFirestore.instance
          .collection('goals')
          .where('uid', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (goalsQuery.docs.isNotEmpty) {
        DocumentSnapshot goalsDoc = goalsQuery.docs.first;
        print("🏆 Goal Data: ${goalsDoc.data()}");

        setState(() {
          goalType = goalsDoc['goalType'] ?? "-"; // ✅ Update goalType properly
        });

        print("✅ Updated goalType: $goalType");
      } else {
        print("⚠️ No goal found for user ID: ${user.uid}");

        setState(() {
          goalType = "Leisure"; // ✅ Set default fallback
        });
      }
    } catch (e) {
      print("❌ Error fetching goalType: $e");
    }
  }

  Future<Map<String, dynamic>> _fetchData() async {
    if (userId.isEmpty) {
      throw Exception("User not logged in");
    }
    
    try {
      final userDoc = await FirebaseFirestore.instance.collection('userData').doc(userId).get();
      final activitiesSnapshot = await FirebaseFirestore.instance.collection('activities').where('uid', isEqualTo: userId).get();
      final athleteDoc = await FirebaseFirestore.instance.collection('athletes').doc(userId).get();

      final userData = userDoc.data() ?? {};
      final athleteData = athleteDoc.data() ?? {};
      final activities = activitiesSnapshot.docs.map((doc) => doc.data()).toList();

      double height = (double.tryParse(userData['height']?.toString() ?? '0') ?? 0) / 100;
      double weight = double.tryParse(userData['weight']?.toString() ?? '0') ?? 0;
      double bmi = (height > 0) ? weight / (height * height) : 0;
      double metabolicRate = double.tryParse(userData['metabolic_rate']?.toString() ?? '0') ?? 0;
      double bodyFatPercentage = double.tryParse(userData['bodyFat']?.toString() ?? '0') ?? 0;

      double totalDistance = 0, totalCalories = 0;
      double latestHeartRate = 0;
      Timestamp? latestTimestamp;

      for (var activity in activities) {
        // Convert distance and calories directly
        totalDistance += double.tryParse(activity['distance']?.toString() ?? '0') ?? 0;
        totalCalories += double.tryParse(activity['calories_burned']?.toString() ?? '0') ?? 0;

        // Ensure heart rate is valid
        double heartRate = double.tryParse(activity['average_heartrate']?.toString() ?? '0') ?? 0;
        Timestamp? activityTimestamp = activity['start_date']; // Assuming timestamp is stored

        if (heartRate > 0 && activityTimestamp != null) {
          if (latestTimestamp == null || activityTimestamp.millisecondsSinceEpoch > latestTimestamp.millisecondsSinceEpoch) {
            latestTimestamp = activityTimestamp;
            latestHeartRate = heartRate;
          }
        }
      }
      print("🔥 Heart Rate: $latestHeartRate");
      print("🔥 Total Distance: $totalDistance");
      print("🔥 Total Calories: $totalCalories");
    return {
      'Athlete Name': athleteData['athlete_name'] ?? 'N/A',
      'Age': userData['age']?.toString() ?? 'N/A',
      'Height (cm)': userData['height']?.toString() ?? 'N/A',
      'Weight (kg)': userData['weight']?.toString() ?? 'N/A',
      'BMI': bmi > 0 ? bmi.toStringAsFixed(2) : 'N/A',
      'Metabolic Rate': metabolicRate > 0 ? metabolicRate.toStringAsFixed(2) : 'N/A',
      'Body Fat %': bodyFatPercentage > 0 ? bodyFatPercentage.toStringAsFixed(2) : 'N/A',
      'Avg. Heart Rate': latestHeartRate > 0 ? latestHeartRate.toStringAsFixed(2) : 'N/A', // ✅ Uses latest heart rate
      'Total Distance (km)': totalDistance > 0 ? totalDistance.toStringAsFixed(2) : 'N/A',
      'Total Calories': totalCalories > 0 ? totalCalories.toStringAsFixed(2) : 'N/A',

    };
    
    } catch (e) {
      throw Exception("Error fetching data: $e");
    }
  }

  Future<void> _generatePdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Health Summary", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...data.entries.map((entry) => pw.Padding(
                padding: pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("${entry.key}:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(entry.value)
                  ]
                )
              )),
            ],
          );
        },
      ),
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'health_summary.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        title: Text(
          "Health Summary",
          style: TextStyle(
            fontFamily: 'Fredoka-SemiBold',
            color: Color(0xffFFA500),
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Color(0xffFFA500)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: Icon(Icons.picture_as_pdf, color: Color(0xffFFA500)),
              onPressed: () async {
                final data = await _fetchData();
                _generatePdf(data);
              },
              tooltip: "Export as PDF",
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: Color(0xffFFA500),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red[400],
                    size: 60,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Error loading data',
                    style: TextStyle(
                      fontFamily: 'Fredoka-SemiBold',
                      fontSize: 18,
                      color: Colors.red[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey[400],
                    size: 60,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No health data available',
                    style: TextStyle(
                      fontFamily: 'Fredoka-SemiBold',
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            );
          }
          
          final data = snapshot.data!;
          return SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xffFFA500).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.health_and_safety,
                          color: Color(0xffFFA500),
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Your Health Profile",
                            style: TextStyle(
                              fontFamily: 'Fredoka-SemiBold',
                              fontSize: 20,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Based on your activity data",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
                  
                  SizedBox(height: 24),

                  // Physical Metrics Section
                  _buildSectionHeader("Physical Metrics", Icons.monitor_weight),
                  SizedBox(height: 12),
                  _buildMetricCard("Height", data['Height (cm)'] + " cm", Icons.height, Colors.blue),

                  // Show Weight and Body Fat only if goalType is "High Intensity Cycling"
                  if (goalType == "High Intensity Cycling") ...[
                    _buildMetricCard("Weight", data['Weight (kg)'] + " kg", Icons.fitness_center, Colors.green),
                    _buildMetricCard("BMI", data['BMI'], Icons.speed, _getBMIColor(double.tryParse(data['BMI']) ?? 0)),
                    _buildMetricCard("Body Fat", data['Body Fat %'] + "%", Icons.pie_chart, Colors.purple),
                  ],

                  SizedBox(height: 24),

                  // Performance Metrics Section
                  _buildSectionHeader("Performance Metrics", Icons.trending_up),
                  SizedBox(height: 12),
                  _buildMetricCard("Average Heart Rate", data['Avg. Heart Rate'] + " bpm", Icons.favorite, Colors.red),
                  _buildMetricCard("Total Distance", data['Total Distance (km)'] + " km", Icons.directions_bike, Color(0xffFFA500)),

                  // Show Total Calories and Metabolic Rate only if goalType is "High Intensity Cycling"
                  if (goalType == "High Intensity Cycling") ...[
                    _buildMetricCard("Total Calories", data['Total Calories'] + " kcal", Icons.local_fire_department, Colors.amber),
                    _buildMetricCard("Metabolic Rate", data['Metabolic Rate'] + " kcal", Icons.bolt, Colors.teal),
                  ],

                  SizedBox(height: 30),
                  
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Export as PDF to share",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
                  
                  SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 8, top: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Color(0xffFFA500),
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Fredoka-SemiBold',
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color iconColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Color _getBMIColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }
}