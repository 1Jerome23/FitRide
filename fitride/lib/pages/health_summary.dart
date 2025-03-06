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

  Future<double> fetchWeeklyAverageCalories() async {
    if (userId.isEmpty) {
      return 0;
    }
    
    try {
      // Get all entries for this user
      QuerySnapshot foodEntries = await FirebaseFirestore.instance
          .collection('food_entries')
          .where('userId', isEqualTo: userId)  // Using userId field instead of uid
          .get();
      
      print("🍎 Found ${foodEntries.docs.length} total food entries");
      
      if (foodEntries.docs.isEmpty) {
        print("⚠️ No food entries found");
        return 0;
      }
      
      // Calculate dates for the past week
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(Duration(days: 7));
      
      // Group entries by day
      Map<String, double> dailyCalories = {};
      
      for (var doc in foodEntries.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        print("🍎 Processing entry: ${doc.id}");
        print("🍎 Entry data: $data");
        
        // Check for timestamp fields
        Timestamp? entryTimestamp;
        
        // Try both 'timestamp' and 'date' fields
        if (data['timestamp'] != null) {
          entryTimestamp = data['timestamp'] as Timestamp;
        } else if (data['date'] != null) {
          entryTimestamp = data['date'] as Timestamp;
        }
        
        if (entryTimestamp == null) {
          print("⚠️ No timestamp/date found in entry ${doc.id}");
          continue;
        }
        
        final date = entryTimestamp.toDate();
        print("🍎 Entry date: $date");
        
        // Only include entries from the past week
        if (date.isBefore(oneWeekAgo)) {
          print("🍎 Entry is older than one week, skipping");
          continue;
        }
        
        // Create a key for the day
        final dayKey = "${date.year}-${date.month}-${date.day}";
        
        // Get calories from the entry
        final calories = double.tryParse(data['total_calories']?.toString() ?? '0') ?? 0;
        print("🍎 Entry calories: $calories");
        
        // Add calories to the daily total
        if (dailyCalories.containsKey(dayKey)) {
          dailyCalories[dayKey] = dailyCalories[dayKey]! + calories;
        } else {
          dailyCalories[dayKey] = calories;
        }
      }
      
      print("🍎 Daily calories by date: $dailyCalories");
      
      // If no entries from past week, return 0
      if (dailyCalories.isEmpty) {
        print("⚠️ No entries found in the past week");
        return 0;
      }
      
      // Calculate the average daily calories
      double totalCalories = 0;
      dailyCalories.forEach((day, calories) {
        totalCalories += calories;
      });
      
      double averageCalories = totalCalories / dailyCalories.length;
      print("🍎 Average daily calories: $averageCalories (over ${dailyCalories.length} day(s))");
      
      return averageCalories;
    } catch (e) {
      print("❌ Error fetching food entries: $e");
      return 0;
    }
  }
  
  Future<double> fetchLatestBasalMetabolicRate() async {
    if (userId.isEmpty) {
      return 0;
    }
    
    try {
      // Simplifying to avoid composite index issues
      // First try the direct document approach
      final userDoc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final bmr = double.tryParse(data['basalMetabolicRate']?.toString() ?? '0') ?? 0;
        
        if (bmr > 0) {
          print("🔥 Basal Metabolic Rate from direct document: $bmr");
          return bmr;
        }
      }
      
      // If that doesn't work, get all documents for this user without ordering
      QuerySnapshot userDataQuery = await FirebaseFirestore.instance
          .collection('userData')
          .where('uid', isEqualTo: userId)
          .get();
      
      if (userDataQuery.docs.isEmpty) {
        print("⚠️ No user data found for basal metabolic rate");
        return 0;
      }
      
      // Find the document with the most recent timestamp manually
      DocumentSnapshot? latestDoc;
      Timestamp? latestTimestamp;
      
      for (var doc in userDataQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        
        if (timestamp != null && (latestTimestamp == null || 
            timestamp.compareTo(latestTimestamp) > 0)) {
          latestTimestamp = timestamp;
          latestDoc = doc;
        }
      }
      
      if (latestDoc == null) {
        print("⚠️ No user data with timestamp found for basal metabolic rate");
        // Fall back to first document if no timestamps found
        latestDoc = userDataQuery.docs.first;
      }
      
      final data = latestDoc.data() as Map<String, dynamic>;
      final bmr = double.tryParse(data['basalMetabolicRate']?.toString() ?? '0') ?? 0;
      
      print("🔥 Latest Basal Metabolic Rate: $bmr");
      return bmr;
    } catch (e) {
      print("❌ Error fetching basal metabolic rate: $e");
      print("⚠️ You may need to create a composite index - check the error message for details");
      return 0;
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
      
      // Fetch the weekly average calories and latest BMR
      final averageCalories = await fetchWeeklyAverageCalories();
      final basalMetabolicRate = await fetchLatestBasalMetabolicRate();

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
      print("🔥 Average Daily Calories: $averageCalories");
      print("🔥 Basal Metabolic Rate: $basalMetabolicRate");
      
    return {
      'Athlete Name': athleteData['athlete_name'] ?? 'N/A',
      'Age': userData['age']?.toString() ?? 'N/A',
      'Height (cm)': userData['height']?.toString() ?? 'N/A',
      'Weight (kg)': userData['weight']?.toString() ?? 'N/A',
      'BMI': bmi > 0 ? bmi.toStringAsFixed(2) : 'N/A',
      'Metabolic Rate': metabolicRate > 0 ? metabolicRate.toStringAsFixed(2) : 'N/A',
      'Basal Metabolic Rate': basalMetabolicRate > 0 ? basalMetabolicRate.toStringAsFixed(2) : 'N/A',
      'Body Fat %': bodyFatPercentage > 0 ? bodyFatPercentage.toStringAsFixed(2) : 'N/A',
      'Avg. Heart Rate': latestHeartRate > 0 ? latestHeartRate.toStringAsFixed(2) : 'N/A', // ✅ Uses latest heart rate
      'Total Distance (km)': totalDistance > 0 ? totalDistance.toStringAsFixed(2) : 'N/A',
      'Total Calories': totalCalories > 0 ? totalCalories.toStringAsFixed(2) : 'N/A',
      'Avg. Daily Calories': averageCalories > 0 ? averageCalories.toStringAsFixed(2) : 'N/A',
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

                  // Show Average calories and basal metabolic rate only if goalType is "High Intensity Cycling"
                  if (goalType == "High Intensity Cycling") ...[
                    _buildMetricCard(
                      "Average Daily Calories", 
                      data['Avg. Daily Calories'] + " kcal", 
                      Icons.food_bank, 
                      Colors.orange,
                      note: "Based on food entries this week"
                    ),
                    _buildMetricCard(
                      "Basal Metabolic Rate", 
                      data['Basal Metabolic Rate'] + " kcal", 
                      Icons.whatshot, 
                      Colors.deepOrange
                    ),
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

  Widget _buildMetricCard(String label, String value, IconData icon, Color iconColor, {String? note}) {
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
                if (note != null) ...[
                  SizedBox(height: 4),
                  Text(
                    note,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
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