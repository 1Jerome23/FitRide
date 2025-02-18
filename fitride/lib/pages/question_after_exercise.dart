import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class PostExercise extends StatefulWidget {
  @override
  _PostExerciseState createState() => _PostExerciseState();
}

class _PostExerciseState extends State<PostExercise> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _exertionController = TextEditingController();
  final TextEditingController _foodController = TextEditingController();
  final TextEditingController _hydrationController = TextEditingController();

  Future<void> _saveToFirestore() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        
        await FirebaseFirestore.instance.collection('after_exercise').doc(user.uid).set({
          'levelOfExertion': int.parse(_exertionController.text),
          'foodTaken': _foodController.text,
          'hydration': int.parse(_hydrationController.text),
          'timestamp': FieldValue.serverTimestamp(),
        });

        await fetchWeatherData(user.uid);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Data saved successfully!")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      }
    }
  }

  Future<void> fetchWeatherData(String userId) async {
    Position position;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        print("Location permission is denied permanently.");
        return;
      }

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permission is denied.");
        return;
      }
      position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print('Error fetching location: $e');
      return;
    }

    final latitude = position.latitude;
    final longitude = position.longitude;

    try {
      final weatherResponse = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true&hourly=relative_humidity_2m'));

      if (weatherResponse.statusCode == 200) {
        final data = json.decode(weatherResponse.body);
        final currentWeather = data['current_weather'];
        final hourly = data['hourly'];

        double temperature = (currentWeather['temperature'] as num).toDouble();
        double humidity = (hourly['relative_humidity_2m'] != null &&
                hourly['relative_humidity_2m'].isNotEmpty)
            ? (hourly['relative_humidity_2m'][0] as num).toDouble()
            : 0.0;

        // Air quality data
        final airQualityResponse = await http.get(Uri.parse(
            'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$latitude&longitude=$longitude&hourly=pm2_5'));

        double pm2_5 = 0.0;
        String airQualityStatus = "Unknown";
        if (airQualityResponse.statusCode == 200) {
          final airData = json.decode(airQualityResponse.body);
          final hourlyData = airData['hourly'];

          pm2_5 =
              (hourlyData['pm2_5'] != null && hourlyData['pm2_5'].isNotEmpty)
                  ? (hourlyData['pm2_5'][0] as num).toDouble()
                  : 0.0;

          airQualityStatus = _evaluateAirQuality(pm2_5);
        }

        // Store weather data in Firestore
        FirebaseFirestore.instance.collection('weatherData').add({
          'userId': userId,
          'temperature': temperature,
          'humidity': humidity,
          'pm2_5': pm2_5,
          'airQualityStatus': airQualityStatus,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        print('Failed to fetch weather data.');
      }
    } catch (e) {
      print('Error fetching weather data: $e');
    }
  }

  String _evaluateAirQuality(double? pm2_5) {
    if (pm2_5 == null) return "Unknown";
    if (pm2_5 <= 25) return "Good";
    if (pm2_5 <= 50) return "Moderate";
    return "Poor";
  }

  Widget _buildTextInput({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: Colors.black),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Post Exercise Form",
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextInput(
                label: "Level of exertion (1-10)",
                controller: _exertionController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return "Required";
                  final numValue = int.tryParse(value);
                  if (numValue == null || numValue < 1 || numValue > 10) return "Enter a number between 1-10";
                  return null;
                },
              ),
              _buildTextInput(
                label: "Food taken today",
                controller: _foodController,
                validator: (value) {
                  if (value == null || value.isEmpty) return "Required";
                  return null;
                },
              ),
              _buildTextInput(
                label: "Hydration (bottles of water 1-10)",
                controller: _hydrationController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return "Required";
                  final numValue = int.tryParse(value);
                  if (numValue == null || numValue < 1 || numValue > 10) return "Enter a number between 1-10";
                  return null;
                },
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _saveToFirestore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: Text("Submit", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
