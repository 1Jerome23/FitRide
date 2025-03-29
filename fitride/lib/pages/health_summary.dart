import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class HealthSummary extends StatefulWidget {
  @override
  _HealthSummaryState createState() => _HealthSummaryState();
}

// Utility classes for chart data
class WeightData {
  final DateTime date;
  final double weight;

  WeightData({required this.date, required this.weight});
}

class BodyFatData {
  final DateTime date;
  final double bodyFat;

  BodyFatData({required this.date, required this.bodyFat});
}

class BMRData {
  final DateTime date;
  final double bmr;

  BMRData({required this.date, required this.bmr});
}

class HeartRateData {
  final DateTime date;
  final double heartRate;

  HeartRateData({required this.date, required this.heartRate});
}

class CaloriesBurnedData {
  final DateTime date;
  final double calories;

  CaloriesBurnedData({required this.date, required this.calories});
}

class _HealthSummaryState extends State<HealthSummary> {
  late String userId;
  String goalType = "-";
  // Initialize expandable state for all metric cards
  late Map<String, bool> expandedState;
  
  @override
  void initState() {
    super.initState();
    // Initialize all expandable states to false
    expandedState = {
      'weight': false,
      'bodyFat': false,
      'bmi': false,
      'height': false,
      'bmr': false,
      'heartRate': false,
      'calories': false,
      'distance': false,
      'dailyCalories': false,
    };
    
    final user = FirebaseAuth.instance.currentUser;
    userId = user?.uid ?? '';
    if (userId.isNotEmpty) {
      fetchGoalType();
    }
  }

  // Removed old initState as it's now included in the expandedState declaration above

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
          .where('userId',
              isEqualTo: userId) // Using userId field instead of uid
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
        final calories =
            double.tryParse(data['total_calories']?.toString() ?? '0') ?? 0;
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
      print(
          "🍎 Average daily calories: $averageCalories (over ${dailyCalories.length} day(s))");

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

        if (timestamp != null &&
            (latestTimestamp == null ||
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
      final bmr =
          double.tryParse(data['basalMetabolicRate']?.toString() ?? '0') ?? 0;

      print("🔥 Latest Basal Metabolic Rate: $bmr");
      return bmr;
    } catch (e) {
      print("❌ Error fetching basal metabolic rate: $e");
      print(
          "⚠️ You may need to create a composite index - check the error message for details");
      return 0;
    }
  }

  Future<Map<String, dynamic>> _fetchData() async {
    if (userId.isEmpty) {
      throw Exception("User not logged in");
    }

    try {
      // Modified to get the most recent userData document for this userId
      final userDataQuery = await FirebaseFirestore.instance
          .collection('userData')
          .where('uid', isEqualTo: userId)
          .orderBy('timestamp',
              descending: true) // Assuming 'timestamp' is your timestamp field
          .limit(1)
          .get();

      // Get the first (most recent) document or null if empty
      final userDoc =
          userDataQuery.docs.isNotEmpty ? userDataQuery.docs.first : null;

      final activitiesSnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .where('uid', isEqualTo: userId)
          .get();

      final athleteDoc = await FirebaseFirestore.instance
          .collection('athletes')
          .doc(userId)
          .get();

      // Fetch the weekly average calories and latest BMR
      final averageCalories = await fetchWeeklyAverageCalories();
      final basalMetabolicRate = await fetchLatestBasalMetabolicRate();

      final userData = userDoc?.data() ?? {};
      final athleteData = athleteDoc.data() ?? {};
      final activities =
          activitiesSnapshot.docs.map((doc) => doc.data()).toList();

      // Rest of the code remains the same
      double height =
          (double.tryParse(userData['height']?.toString() ?? '0') ?? 0) / 100;
      double weight =
          double.tryParse(userData['weight']?.toString() ?? '0') ?? 0;
      double bmi = (height > 0) ? weight / (height * height) : 0;
      double metabolicRate =
          double.tryParse(userData['metabolic_rate']?.toString() ?? '0') ?? 0;
      double bodyFatPercentage =
          double.tryParse(userData['bodyFat']?.toString() ?? '0') ?? 0;

      double totalDistance = 0, totalCalories = 0;
      double latestHeartRate = 0;
      Timestamp? latestTimestamp;

      for (var activity in activities) {
        // Convert distance and calories directly
        totalDistance +=
            double.tryParse(activity['distance']?.toString() ?? '0') ?? 0;
        totalCalories +=
            double.tryParse(activity['calories_burned']?.toString() ?? '0') ??
                0;

        // Ensure heart rate is valid
        double heartRate =
            double.tryParse(activity['average_heartrate']?.toString() ?? '0') ??
                0;
        Timestamp? activityTimestamp =
            activity['start_date']; // Assuming timestamp is stored

        if (heartRate > 0 && activityTimestamp != null) {
          if (latestTimestamp == null ||
              activityTimestamp.millisecondsSinceEpoch >
                  latestTimestamp.millisecondsSinceEpoch) {
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
        'Metabolic Rate':
            metabolicRate > 0 ? metabolicRate.toStringAsFixed(2) : 'N/A',
        'Basal Metabolic Rate': basalMetabolicRate > 0
            ? basalMetabolicRate.toStringAsFixed(2)
            : 'N/A',
        'Body Fat %': bodyFatPercentage > 0
            ? bodyFatPercentage.toStringAsFixed(2)
            : 'N/A',
        'Avg. Heart Rate': latestHeartRate > 0
            ? latestHeartRate.toStringAsFixed(2)
            : 'N/A', // ✅ Uses latest heart rate
        'Total Distance (km)':
            totalDistance > 0 ? totalDistance.toStringAsFixed(2) : 'N/A',
        'Total Calories':
            totalCalories > 0 ? totalCalories.toStringAsFixed(2) : 'N/A',
        'Avg. Daily Calories':
            averageCalories > 0 ? averageCalories.toStringAsFixed(2) : 'N/A',
      };
    } catch (e) {
      throw Exception("Error fetching data: $e");
    }
  }

  // Fetch weight data for chart
  Future<List<WeightData>> _fetchWeightData() async {
    try {
      QuerySnapshot weightQuery = await FirebaseFirestore.instance
          .collection('userData')
          .where('uid', isEqualTo: userId)
          .orderBy('timestamp', descending: false)
          .get();

      List<WeightData> weightData = weightQuery.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final weight = double.tryParse(data['weight']?.toString() ?? '0') ?? 0;

            return timestamp != null && weight > 0
                ? WeightData(date: timestamp.toDate(), weight: weight)
                : null;
          })
          .whereType<WeightData>()
          .toList();

      return weightData;
    } catch (e) {
      print("❌ Error fetching weight data: $e");
      return [];
    }
  }

  // Fetch body fat data for chart
  Future<List<BodyFatData>> _fetchBodyFatData() async {
    try {
      QuerySnapshot bodyFatQuery = await FirebaseFirestore.instance
          .collection('userData')
          .where('uid', isEqualTo: userId)
          .orderBy('timestamp', descending: false)
          .get();

      List<BodyFatData> bodyFatData = bodyFatQuery.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final bodyFat = double.tryParse(data['bodyFat']?.toString() ?? '0') ?? 0;

            return timestamp != null && bodyFat > 0
                ? BodyFatData(date: timestamp.toDate(), bodyFat: bodyFat)
                : null;
          })
          .whereType<BodyFatData>()
          .toList();

      return bodyFatData;
    } catch (e) {
      print("❌ Error fetching body fat data: $e");
      return [];
    }
  }

  // Fetch BMR data for chart
  Future<List<BMRData>> _fetchBMRData() async {
    try {
      QuerySnapshot bmrQuery = await FirebaseFirestore.instance
          .collection('userData')
          .where('uid', isEqualTo: userId)
          .orderBy('timestamp', descending: false)
          .get();

      List<BMRData> bmrData = bmrQuery.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final bmr = double.tryParse(data['basalMetabolicRate']?.toString() ?? '0') ?? 0;

            return timestamp != null && bmr > 0
                ? BMRData(date: timestamp.toDate(), bmr: bmr)
                : null;
          })
          .whereType<BMRData>()
          .toList();

      return bmrData;
    } catch (e) {
      print("❌ Error fetching BMR data: $e");
      return [];
    }
  }

  // Fetch heart rate data for chart
  Future<List<HeartRateData>> _fetchHeartRateData() async {
    try {
      QuerySnapshot heartRateQuery = await FirebaseFirestore.instance
          .collection('activities')
          .where('uid', isEqualTo: userId)
          .orderBy('start_date', descending: false)
          .get();

      List<HeartRateData> heartRateData = heartRateQuery.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['start_date'] as Timestamp?;
            final heartRate = double.tryParse(data['average_heartrate']?.toString() ?? '0') ?? 0;

            return timestamp != null && heartRate > 0
                ? HeartRateData(date: timestamp.toDate(), heartRate: heartRate)
                : null;
          })
          .whereType<HeartRateData>()
          .toList();

      return heartRateData;
    } catch (e) {
      print("❌ Error fetching heart rate data: $e");
      return [];
    }
  }

  // Fetch calories burned data for chart
  Future<List<CaloriesBurnedData>> _fetchCaloriesBurnedData() async {
    try {
      QuerySnapshot caloriesQuery = await FirebaseFirestore.instance
          .collection('activities')
          .where('uid', isEqualTo: userId)
          .orderBy('start_date', descending: false)
          .get();

      List<CaloriesBurnedData> caloriesData = caloriesQuery.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['start_date'] as Timestamp?;
            final calories = double.tryParse(data['calories_burned']?.toString() ?? '0') ?? 0;

            return timestamp != null && calories > 0
                ? CaloriesBurnedData(date: timestamp.toDate(), calories: calories)
                : null;
          })
          .whereType<CaloriesBurnedData>()
          .toList();

      return caloriesData;
    } catch (e) {
      print("❌ Error fetching calories burned data: $e");
      return [];
    }
  }

  // Function to build the weight chart
  Widget _buildWeightTrackingChart() {
    return FutureBuilder<List<WeightData>>(
      future: _fetchWeightData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGraph();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyGraph("No weight tracking data available");
        }

        List<WeightData> weightData = snapshot.data!;
        
        // Sort data by date
        weightData.sort((a, b) => a.date.compareTo(b.date));

        // Determine date range
        DateTime startDate = weightData.first.date;
        DateTime endDate = weightData.last.date;

        return _buildGraphContainer(
          title: "Weight Tracking",
          subtitle: "Your Weight Journey",
          height: 400,
          child: SfCartesianChart(
            margin: EdgeInsets.fromLTRB(10, 10, 16, 5),
            zoomPanBehavior: ZoomPanBehavior(
              enablePinching: true,
              enablePanning: true,
              zoomMode: ZoomMode.x,
            ),
            primaryXAxis: DateTimeAxis(
              minimum: startDate,
              maximum: endDate,
              majorGridLines: MajorGridLines(width: 0),
              minorGridLines: MinorGridLines(width: 0),
              axisLine: AxisLine(width: 1, color: Colors.grey[200]),
              labelStyle: TextStyle(
                color: Colors.grey[700],
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              dateFormat: DateFormat('MM/dd'),
              intervalType: DateTimeIntervalType.days,
              labelRotation: 0,
            ),
            primaryYAxis: NumericAxis(
              majorGridLines: MajorGridLines(
                width: 0.5,
                color: Colors.grey[200],
                dashArray: <double>[3, 3],
              ),
              axisLine: AxisLine(width: 0),
              labelFormat: '{value} kg',
              labelStyle: TextStyle(
                color: Colors.blue[700],
                fontFamily: 'Inter',
                fontSize: 10,
              ),
            ),
            series: <ChartSeries>[
              SplineSeries<WeightData, DateTime>(
                dataSource: weightData,
                xValueMapper: (WeightData data, _) => data.date,
                yValueMapper: (WeightData data, _) => data.weight,
                color: Colors.blue[700],
                width: 2.5,
                markerSettings: MarkerSettings(
                  isVisible: true,
                  shape: DataMarkerType.circle,
                  color: Colors.blue[700],
                  borderColor: Colors.white,
                  borderWidth: 2,
                  height: 8,
                  width: 8,
                ),
              ),
            ],
            tooltipBehavior: TooltipBehavior(
              enable: true,
              color: Colors.grey[800],
              textStyle: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  // Function to build the body fat chart
  Widget _buildBodyFatChart() {
    return FutureBuilder<List<BodyFatData>>(
      future: _fetchBodyFatData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGraph();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyGraph("No body fat data available");
        }

        List<BodyFatData> bodyFatData = snapshot.data!;
        
        // Sort data by date
        bodyFatData.sort((a, b) => a.date.compareTo(b.date));

        // Determine date range
        DateTime startDate = bodyFatData.first.date;
        DateTime endDate = bodyFatData.last.date;

        return _buildGraphContainer(
          title: "Body Fat Tracking",
          subtitle: "Your Body Fat Journey",
          height: 400,
          child: SfCartesianChart(
            margin: EdgeInsets.fromLTRB(10, 10, 16, 5),
            zoomPanBehavior: ZoomPanBehavior(
              enablePinching: true,
              enablePanning: true,
              zoomMode: ZoomMode.x,
            ),
            primaryXAxis: DateTimeAxis(
              minimum: startDate,
              maximum: endDate,
              majorGridLines: MajorGridLines(width: 0),
              minorGridLines: MinorGridLines(width: 0),
              axisLine: AxisLine(width: 1, color: Colors.grey[200]),
              labelStyle: TextStyle(
                color: Colors.grey[700],
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              dateFormat: DateFormat('MM/dd'),
              intervalType: DateTimeIntervalType.days,
              labelRotation: 0,
            ),
            primaryYAxis: NumericAxis(
              majorGridLines: MajorGridLines(
                width: 0.5,
                color: Colors.grey[200],
                dashArray: <double>[3, 3],
              ),
              axisLine: AxisLine(width: 0),
              labelFormat: '{value} %',
              labelStyle: TextStyle(
                color: Colors.purple[700],
                fontFamily: 'Inter',
                fontSize: 10,
              ),
            ),
            series: <ChartSeries>[
              SplineSeries<BodyFatData, DateTime>(
                dataSource: bodyFatData,
                xValueMapper: (BodyFatData data, _) => data.date,
                yValueMapper: (BodyFatData data, _) => data.bodyFat,
                color: Colors.purple[700],
                width: 2.5,
                markerSettings: MarkerSettings(
                  isVisible: true,
                  shape: DataMarkerType.circle,
                  color: Colors.purple[700],
                  borderColor: Colors.white,
                  borderWidth: 2,
                  height: 8,
                  width: 8,
                ),
              ),
            ],
            tooltipBehavior: TooltipBehavior(
              enable: true,
              color: Colors.grey[800],
              textStyle: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  // Function to build the BMR chart
  Widget _buildBMRChart() {
    return FutureBuilder<List<BMRData>>(
      future: _fetchBMRData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGraph();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyGraph("No basal metabolic rate data available");
        }

        List<BMRData> bmrData = snapshot.data!;
        
        // Sort data by date
        bmrData.sort((a, b) => a.date.compareTo(b.date));

        // Determine date range
        DateTime startDate = bmrData.first.date;
        DateTime endDate = bmrData.last.date;

        return _buildGraphContainer(
          title: "Basal Metabolic Rate Tracking",
          subtitle: "Your BMR Journey",
          height: 400,
          child: SfCartesianChart(
            margin: EdgeInsets.fromLTRB(10, 10, 16, 5),
            zoomPanBehavior: ZoomPanBehavior(
              enablePinching: true,
              enablePanning: true,
              zoomMode: ZoomMode.x,
            ),
            primaryXAxis: DateTimeAxis(
              minimum: startDate,
              maximum: endDate,
              majorGridLines: MajorGridLines(width: 0),
              minorGridLines: MinorGridLines(width: 0),
              axisLine: AxisLine(width: 1, color: Colors.grey[200]),
              labelStyle: TextStyle(
                color: Colors.grey[700],
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              dateFormat: DateFormat('MM/dd'),
              intervalType: DateTimeIntervalType.days,
              labelRotation: 0,
            ),
            primaryYAxis: NumericAxis(
              majorGridLines: MajorGridLines(
                width: 0.5,
                color: Colors.grey[200],
                dashArray: <double>[3, 3],
              ),
              axisLine: AxisLine(width: 0),
              labelFormat: '{value} kcal',
              labelStyle: TextStyle(
                color: Colors.deepOrange[700],
                fontFamily: 'Inter',
                fontSize: 10,
              ),
            ),
            series: <ChartSeries>[
              SplineSeries<BMRData, DateTime>(
                dataSource: bmrData,
                xValueMapper: (BMRData data, _) => data.date,
                yValueMapper: (BMRData data, _) => data.bmr,
                color: Colors.deepOrange[700],
                width: 2.5,
                markerSettings: MarkerSettings(
                  isVisible: true,
                  shape: DataMarkerType.circle,
                  color: Colors.deepOrange[700],
                  borderColor: Colors.white,
                  borderWidth: 2,
                  height: 8,
                  width: 8,
                ),
              ),
            ],
            tooltipBehavior: TooltipBehavior(
              enable: true,
              color: Colors.grey[800],
              textStyle: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  // Function to build the heart rate chart
  Widget _buildHeartRateChart() {
    return FutureBuilder<List<HeartRateData>>(
      future: _fetchHeartRateData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGraph();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyGraph("No heart rate data available");
        }

        List<HeartRateData> heartRateData = snapshot.data!;
        
        // Sort data by date
        heartRateData.sort((a, b) => a.date.compareTo(b.date));

        // Determine date range
        DateTime startDate = heartRateData.first.date;
        DateTime endDate = heartRateData.last.date;

        return _buildGraphContainer(
          title: "Heart Rate Tracking",
          subtitle: "Your Heart Rate History",
          height: 400,
          child: SfCartesianChart(
            margin: EdgeInsets.fromLTRB(10, 10, 16, 5),
            zoomPanBehavior: ZoomPanBehavior(
              enablePinching: true,
              enablePanning: true,
              zoomMode: ZoomMode.x,
            ),
            primaryXAxis: DateTimeAxis(
              minimum: startDate,
              maximum: endDate,
              majorGridLines: MajorGridLines(width: 0),
              minorGridLines: MinorGridLines(width: 0),
              axisLine: AxisLine(width: 1, color: Colors.grey[200]),
              labelStyle: TextStyle(
                color: Colors.grey[700],
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              dateFormat: DateFormat('MM/dd'),
              intervalType: DateTimeIntervalType.days,
              labelRotation: 0,
            ),
            primaryYAxis: NumericAxis(
              majorGridLines: MajorGridLines(
                width: 0.5,
                color: Colors.grey[200],
                dashArray: <double>[3, 3],
              ),
              axisLine: AxisLine(width: 0),
              labelFormat: '{value} bpm',
              labelStyle: TextStyle(
                color: Colors.red[700],
                fontFamily: 'Inter',
                fontSize: 10,
              ),
            ),
            series: <ChartSeries>[
              SplineSeries<HeartRateData, DateTime>(
                dataSource: heartRateData,
                xValueMapper: (HeartRateData data, _) => data.date,
                yValueMapper: (HeartRateData data, _) => data.heartRate,
                color: Colors.red[700],
                width: 2.5,
                markerSettings: MarkerSettings(
                  isVisible: true,
                  shape: DataMarkerType.circle,
                  color: Colors.red[700],
                  borderColor: Colors.white,
                  borderWidth: 2,
                  height: 8,
                  width: 8,
                ),
              ),
            ],
            tooltipBehavior: TooltipBehavior(
              enable: true,
              color: Colors.grey[800],
              textStyle: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  // Function to build the calories burned chart
  Widget _buildCaloriesBurnedChart() {
    return FutureBuilder<List<CaloriesBurnedData>>(
      future: _fetchCaloriesBurnedData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGraph();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyGraph("No calories burned data available");
        }

        List<CaloriesBurnedData> caloriesData = snapshot.data!;
        
        // Sort data by date
        caloriesData.sort((a, b) => a.date.compareTo(b.date));

        // Determine date range
        DateTime startDate = caloriesData.first.date;
        DateTime endDate = caloriesData.last.date;

        return _buildGraphContainer(
          title: "Calories Burned Tracking",
          subtitle: "Your Calories Burned History",
          height: 400,
          child: SfCartesianChart(
            margin: EdgeInsets.fromLTRB(10, 10, 16, 5),
            zoomPanBehavior: ZoomPanBehavior(
              enablePinching: true,
              enablePanning: true,
              zoomMode: ZoomMode.x,
            ),
            primaryXAxis: DateTimeAxis(
              minimum: startDate,
              maximum: endDate,
              majorGridLines: MajorGridLines(width: 0),
              minorGridLines: MinorGridLines(width: 0),
              axisLine: AxisLine(width: 1, color: Colors.grey[200]),
              labelStyle: TextStyle(
                color: Colors.grey[700],
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              dateFormat: DateFormat('MM/dd'),
              intervalType: DateTimeIntervalType.days,
              labelRotation: 0,
            ),
            primaryYAxis: NumericAxis(
              majorGridLines: MajorGridLines(
                width: 0.5,
                color: Colors.grey[200],
                dashArray: <double>[3, 3],
              ),
              axisLine: AxisLine(width: 0),
              labelFormat: '{value} kcal',
              labelStyle: TextStyle(
                color: Colors.orange[700],
                fontFamily: 'Inter',
                fontSize: 10,
              ),
            ),
            series: <ChartSeries>[
              SplineSeries<CaloriesBurnedData, DateTime>(
                dataSource: caloriesData,
                xValueMapper: (CaloriesBurnedData data, _) => data.date,
                yValueMapper: (CaloriesBurnedData data, _) => data.calories,
                color: Colors.orange[700],
                width: 2.5,
                markerSettings: MarkerSettings(
                  isVisible: true,
                  shape: DataMarkerType.circle,
                  color: Colors.orange[700],
                  borderColor: Colors.white,
                  borderWidth: 2,
                  height: 8,
                  width: 8,
                ),
              ),
            ],
            tooltipBehavior: TooltipBehavior(
              enable: true,
              color: Colors.grey[800],
              textStyle: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  // Function for expandable metric card
  Widget _buildExpandableMetricCard(
      String label, String value, IconData icon, Color iconColor, String metricKey,
      {String? note, Widget? chart}) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          children: [
            // The metric card itself
            Container(
              margin: EdgeInsets.only(bottom: (expandedState[metricKey] ?? false) ? 0 : 12),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: (expandedState[metricKey] ?? false) ? Radius.zero : Radius.circular(12),
                  bottomRight: (expandedState[metricKey] ?? false) ? Radius.zero : Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: chart == null ? null : () {
                  setState(() {
                    expandedState[metricKey] = !expandedState[metricKey]!;
                  });
                },
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
                    if (chart != null) ...[
                      Icon(
                        expandedState[metricKey]! ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey[600],
                        size: 24,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // The expandable chart section
            if (chart != null) ...[
              AnimatedCrossFade(
                duration: Duration(milliseconds: 300),
                firstChild: Container(
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: chart,
                  ),
                ),
                secondChild: SizedBox.shrink(),
                crossFadeState: (expandedState[metricKey] ?? false) ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLoadingGraph() {
    return Container(
      height: 280,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: Color(0xffFFA500),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              "Loading your data...",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyGraph(String message) {
    return Container(
      height: 280,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_chart_outlined_rounded,
              color: Colors.grey[300],
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to create a graph container
  Widget _buildGraphContainer({
    required String title,
    required String subtitle,
    required double height,
    required Widget child,
  }) {
    return Container(
      height: height,
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Future<void> _generatePdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Health Summary",
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...data.entries.map((entry) => pw.Padding(
                  padding: pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("${entry.key}:",
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(entry.value)
                      ]))),
            ],
          );
        },
      ),
    );
    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'health_summary.pdf');
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
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.1, end: 0),

                  SizedBox(height: 24),

                  // Physical Metrics Section
                  _buildSectionHeader("Physical Metrics", Icons.monitor_weight),
                  SizedBox(height: 12),
                  _buildExpandableMetricCard(
                    "Height", 
                    data['Height (cm)'] + " cm",
                    Icons.height, 
                    Colors.blue, 
                    "height"
                  ),

                  // Show Weight and Body Fat only if goalType is "High Intensity Cycling"
                  if (goalType == "High Intensity Cycling") ...[
                    _buildExpandableMetricCard(
                      "Weight", 
                      data['Weight (kg)'] + " kg",
                      Icons.fitness_center, 
                      Colors.green, 
                      "weight",
                      chart: _buildWeightTrackingChart()
                    ),
                    _buildExpandableMetricCard(
                      "BMI", 
                      data['BMI'], 
                      Icons.speed,
                      _getBMIColor(double.tryParse(data['BMI']) ?? 0), 
                      "bmi"
                    ),
                    _buildExpandableMetricCard(
                      "Body Fat", 
                      data['Body Fat %'] + "%",
                      Icons.pie_chart, 
                      Colors.purple, 
                      "bodyFat",
                      chart: _buildBodyFatChart()
                    ),
                  ],

                  SizedBox(height: 24),

                  // Performance Metrics Section
                  _buildSectionHeader("Performance Metrics", Icons.trending_up),
                  SizedBox(height: 12),
                  _buildExpandableMetricCard(
                    "Average Heart Rate",
                    data['Avg. Heart Rate'] + " bpm",
                    Icons.favorite,
                    Colors.red,
                    "heartRate",
                    chart: _buildHeartRateChart()
                  ),
                  _buildExpandableMetricCard(
                    "Total Distance",
                    data['Total Distance (km)'] + " km",
                    Icons.directions_bike,
                    Color(0xffFFA500),
                    "distance"
                  ),

                  // Show Average calories and basal metabolic rate only if goalType is "High Intensity Cycling"
                  if (goalType == "High Intensity Cycling") ...[
                    _buildExpandableMetricCard(
                      "Average Daily Calories",
                      data['Avg. Daily Calories'] + " kcal",
                      Icons.food_bank,
                      Colors.orange,
                      "dailyCalories",
                      note: "Based on food entries this week"
                    ),
                    _buildExpandableMetricCard(
                      "Basal Metabolic Rate",
                      data['Basal Metabolic Rate'] + " kcal",
                      Icons.whatshot,
                      Colors.deepOrange,
                      "bmr",
                      chart: _buildBMRChart()
                    ),
                    _buildExpandableMetricCard(
                      "Total Calories Burned",
                      data['Total Calories'] + " kcal",
                      Icons.local_fire_department,
                      Colors.orange,
                      "calories",
                      chart: _buildCaloriesBurnedChart()
                    ),
                  ],

                  SizedBox(height: 30),

                  Center(
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  // Original metric card (left for reference)
  Widget _buildMetricCard(
      String label, String value, IconData icon, Color iconColor,
      {String? note}) {
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
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 300.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Color _getBMIColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }
}