import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HealthSummary extends StatefulWidget {
  @override
  _HealthSummaryState createState() => _HealthSummaryState();
}

class _HealthSummaryState extends State<HealthSummary> {
  late String userId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    userId = user?.uid ?? '';
  }

  Future<Map<String, dynamic>> _fetchData() async {
    if (userId.isEmpty) {
      throw Exception("User not logged in");
    }
    
    try {
      final userDoc = await FirebaseFirestore.instance.collection('userData').doc(userId).get();
      final activitiesSnapshot = await FirebaseFirestore.instance.collection('activities').where('user_id', isEqualTo: userId).get();
      final athleteDoc = await FirebaseFirestore.instance.collection('athletes').doc(userId).get();

      final userData = userDoc.data() ?? {};
      final athleteData = athleteDoc.data() ?? {};
      final activities = activitiesSnapshot.docs.map((doc) => doc.data()).toList();

      double height = (double.tryParse(userData['height']?.toString() ?? '0') ?? 0) / 100;
      double weight = double.tryParse(userData['weight']?.toString() ?? '0') ?? 0;
      double bmi = (height > 0) ? weight / (height * height) : 0;
      double metabolicRate = double.tryParse(userData['metabolic_rate']?.toString() ?? '0') ?? 0;
      double bodyFatPercentage = double.tryParse(userData['body_fat_percentage']?.toString() ?? '0') ?? 0;

      double totalHeartRate = 0, maxHeartRate = 0, totalDistance = 0, totalCalories = 0;
      int heartRateCount = 0;

      for (var activity in activities) {
        double heartRate = double.tryParse(activity['average_heartrate']?.toString() ?? '0') ?? 0;
        if (heartRate > 0) {
          totalHeartRate += heartRate;
          heartRateCount++;
          if (heartRate > maxHeartRate) maxHeartRate = heartRate;
        }
        totalDistance += double.tryParse(activity['distance']?.toString() ?? '0') ?? 0;
        totalCalories += double.tryParse(activity['calories_burned']?.toString() ?? '0') ?? 0;
      }

      return {
        'athlete_name': athleteData['athlete_name'] ?? 'N/A',
        'age': userData['age']?.toString() ?? 'N/A',
        'height': userData['height']?.toString() ?? 'N/A',
        'weight': userData['weight']?.toString() ?? 'N/A',
        'bmi': bmi.toStringAsFixed(2),
        'metabolic_rate': metabolicRate.toStringAsFixed(2),
        'body_fat_percentage': bodyFatPercentage.toStringAsFixed(2),
        'average_heart_rate': heartRateCount > 0 ? (totalHeartRate / heartRateCount).toStringAsFixed(2) : 'N/A',
        'max_heart_rate': maxHeartRate.toStringAsFixed(2),
        'total_distance': totalDistance.toStringAsFixed(2),
        'total_calories': totalCalories.toStringAsFixed(2),
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
              ...data.entries.map((entry) => pw.Text("${entry.key}: ${entry.value}")),
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
      appBar: AppBar(
        title: Text("Health Summary", style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final data = await _fetchData();
              _generatePdf(data);
            },
          ),
        ],
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
          return ListView(
            padding: EdgeInsets.all(16),
            children: data.entries.map((entry) => _buildCard(entry.key, entry.value)).toList(),
          );
        },
      ),
    );
  }

  Widget _buildCard(String label, dynamic value) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("$label:", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black)),
            Text(value.toString(), style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w400, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
