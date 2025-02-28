import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PostExercise extends StatefulWidget {
  @override
  _PostExerciseState createState() => _PostExerciseState();
}

class _PostExerciseState extends State<PostExercise> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _exertionController = TextEditingController();
  final TextEditingController _foodController = TextEditingController();
  final TextEditingController _hydrationController = TextEditingController();
  final TextEditingController _currentLevelController = TextEditingController();
  String goalType = "-";

  bool _isSubmitting = false;

Future<int> _getDaysPerWeek(String userId) async {
  try {
    DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
        .collection('goals')
        .doc(userId)
        .get();
     DocumentSnapshot goalsDoc = await FirebaseFirestore.instance
          .collection('goals')
          .doc(userId)
          .get();
    if (snapshot.exists && snapshot.data() != null) {
      return snapshot.data()!['daysPerWeek'] ?? 0; // Default to 0 if not set
    }
  } catch (e) {
    print('Error fetching daysPerWeek: $e');
  }
  return 0; // Default to 0 if an error occurs or data is missing
}
  Future<void> _updateStreakCount(String userId) async {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfWeek = startOfDay.add(Duration(days: 7 - startOfDay.weekday));

  // Fetch the required days per week for the user
  int daysPerWeek = await _getDaysPerWeek(userId);

  // Check if there is an existing streak document for this week
  DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
      .collection('Streak')
      .doc(userId)
      .get();

  bool isNewWeek = !snapshot.exists || (snapshot.data()!['endOfWeek'] as Timestamp).toDate().isBefore(startOfDay);

  if (isNewWeek) {
    // Create a new streak document for the current week
    await FirebaseFirestore.instance.collection('Streak').doc(userId).set({
      'userId': userId,
      'activityCount': 1,
      'streak': snapshot.exists ? snapshot.data()!['streak'] + 1 : 1,
      'startOfWeek': FieldValue.serverTimestamp(),
      'endOfWeek': endOfWeek,
    });
  } else {
    // Update the existing streak document
    int currentActivityCount = snapshot.data()!['activityCount'] ?? 0;
    int updatedActivityCount = currentActivityCount + 1;

    if (updatedActivityCount >= daysPerWeek) {
      // User has completed the required activities for the week
      await FirebaseFirestore.instance.collection('Streak').doc(userId).update({
        'activityCount': updatedActivityCount,
        'streak': FieldValue.increment(1), // Increment streak
      });
    } else {
      // User has not yet completed the required activities for the week
      await FirebaseFirestore.instance.collection('Streak').doc(userId).update({
        'activityCount': updatedActivityCount,
      });
    }
  }
}

  Future<void> _saveToFirestore() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    FocusScope.of(context).unfocus();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User not logged in!");
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    try {
      double estimatedCalories = await _getCaloriesFromUSDA(_foodController.text);

      await FirebaseFirestore.instance.collection('after_exercise').add({
        'userId': user.uid,
        'levelOfExertion': int.tryParse(_exertionController.text) ?? 0,
        'foodTaken': _foodController.text,
        'estimatedCalories': estimatedCalories,
        'hydration': int.tryParse(_hydrationController.text) ?? 0,
        'currentLevel': _currentLevelController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await fetchWeatherData(user.uid);
      await _updateStreakCount(user.uid);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Data saved successfully!")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } catch (e) {
      print("Error saving data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save data! Please try again.")),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }


  }
  Future<double> _getCaloriesFromUSDA(String foodInput) async {
    if (foodInput.isEmpty) return 0.0;

    final apiKey = dotenv.env['API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      print("API key is missing!");
      return 0.0;
    }

    final RegExp regex = RegExp(r'(\d+)\s*(.*)');
    int quantity = 1;
    String food = foodInput.trim();

    final match = regex.firstMatch(foodInput);
    if (match != null) {
      quantity = int.parse(match.group(1)!);
      food = match.group(2)!.trim();
    }

    final url = Uri.parse("https://api.nal.usda.gov/fdc/v1/foods/search?query=$food&api_key=$apiKey");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data["foods"] != null && data["foods"].isNotEmpty) {
          final firstFood = data["foods"][0];

          for (var nutrient in firstFood["foodNutrients"]) {
            if (nutrient["nutrientName"] == "Energy" && nutrient["unitName"] == "KCAL") {
              double caloriesPerUnit = nutrient["value"].toDouble();
              return caloriesPerUnit * quantity;
            }
          }
        }
        print("No calorie data found for '$food'.");
        return 0.0;
      } else {
        print("USDA API Error: ${response.body}");
        return 0.0;
      }
    } catch (e) {
      print("Error fetching calorie data: $e");
      return 0.0;
    }
  }


  Future<void> fetchWeatherData(String userId) async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final latitude = position.latitude;
      final longitude = position.longitude;

      final weatherResponse = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true&hourly=relative_humidity_2m'));

      if (weatherResponse.statusCode == 200) {
        final data = json.decode(weatherResponse.body);
        double temperature = (data['current_weather']['temperature'] as num).toDouble();
        double humidity = data['hourly']['relative_humidity_2m'][0]?.toDouble() ?? 0.0;

        FirebaseFirestore.instance.collection('weatherData').add({
          'userId': userId,
          'temperature': temperature,
          'humidity': humidity,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error fetching weather data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          "Post Exercise Form",
          style: GoogleFonts.roboto(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
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
                validator: (value) => value == null || value.isEmpty ? "Required" : null,
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
              if (goalType == "Leisure")
              _buildTextInput(
                label: "How do you feel after your exercise (1-10)",
                controller: _hydrationController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return "Required";
                  final numValue = int.tryParse(value);
                  if (numValue == null || numValue < 1 || numValue > 10) {
                    return "Enter a number between 1-10";
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _saveToFirestore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: _isSubmitting
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Submit", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
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
}