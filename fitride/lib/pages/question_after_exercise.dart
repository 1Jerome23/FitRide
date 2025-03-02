import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  @override
  void initState() {
    super.initState();
    print("🔄 Initializing PostExercise widget");
    // Call getUserGoal immediately and add a callback for when it completes
    getUserGoal().then((_) {
      print("✅ getUserGoal completed, goalType is now: $goalType");
      // Force a rebuild of the widget after goal is fetched
      if (mounted) setState(() {});
    });
  }


  Future<int> _getDaysPerWeek(String userId) async {
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
        return goalsDoc['daysPerWeek'] ?? 0; // Default to 0 if not set
    }
    return 0; // Default to 0 if an error occurs or data is missing
  }

  Future<void> getUserGoal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("❌ No authenticated user.");
      return;
    }

    print("🔍 Fetching goal for userId: ${user.uid}");

    try {
      // Fetch the most recent document from goals collection where uid matches userId
      QuerySnapshot goalsQuery = await FirebaseFirestore.instance
          .collection('goals')
          .where('uid', isEqualTo: user.uid)
          .orderBy('timestamp',
          descending: true) // Sort by timestamp in descending order
          .limit(1) // Limit to the most recent document
          .get();

      if (goalsQuery.docs.isNotEmpty) {
        DocumentSnapshot goalsDoc =
            goalsQuery.docs.first; // Get the first (most recent) document
        print("🏆 Goal Data: $goalsDoc");

        setState(() {
          goalType = goalsDoc['goalType'] ?? "-"; // Update state
        });

        print("✅ Updated goalType: $goalType");
      } else {
        print("⚠️ No goal found for user ID: ${user.uid}");
        
        // Optionally set a default if you want this field to show anyway
        setState(() {
          goalType = "Leisure"; // Set default to make the field appear
        });
      }
    } catch (e) {
      print("❌ Error fetching user goal: $e");
    }
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
        SnackBar(
          content: Text("Data saved successfully!"),
          backgroundColor: Color(0xffFFA500),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } catch (e) {
      print("Error saving data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save data! Please try again."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
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
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        title: Text(
          "Post Exercise Summary",
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
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "How was your ride?",
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 24,
                    color: Colors.black87,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: -0.1, end: 0),
                
                SizedBox(height: 6),
                
                Text(
                  "Let us know about your cycling experience today",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: -0.1, end: 0),
                
                SizedBox(height: 30),
                
                _buildInputField(
                  label: "Level of Exertion",
                  hintText: "Rate from 1-10 how hard you worked",
                  controller: _exertionController,
                  icon: Icons.fitness_center,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Please enter your exertion level";
                    final numValue = int.tryParse(value);
                    if (numValue == null || numValue < 1 || numValue > 10) 
                      return "Enter a number between 1-10";
                    return null;
                  },
                  delay: 300,
                ),
                
                SizedBox(height: 20),
                
                _buildInputField(
                  label: "Food Intake",
                  hintText: "What did you eat today?",
                  controller: _foodController,
                  icon: Icons.restaurant_menu,
                  validator: (value) => value == null || value.isEmpty 
                      ? "Please enter what you ate" 
                      : null,
                  delay: 400,
                ),
                
                SizedBox(height: 20),
                
                Builder(builder: (context) {
                  print("🔍 Checking condition: goalType == 'Leisure' (${goalType == 'Leisure'})");
                  if (goalType == "Leisure") {
                    print("✅ Condition matched, should show the field");
                    return _buildInputField(
                      label: "Post-Ride Feeling",
                      hintText: "Rate from 1-10 how you feel now",
                      controller: _hydrationController,
                      icon: Icons.mood,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Please rate how you feel";
                        final numValue = int.tryParse(value);
                        if (numValue == null || numValue < 1 || numValue > 10) {
                          return "Enter a number between 1-10";
                        }
                        return null;
                      },
                      delay: 500,
                    );
                  } else {
                    print("❌ Condition not matched, field should be hidden");
                    return SizedBox.shrink(); // Return an empty widget if not Leisure
                  }
                }),
                
                SizedBox(height: 40),
                
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _saveToFirestore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xffFFA500),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              "Submit",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 600.ms).scale(begin: Offset(0.95, 0.95)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int delay = 0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Fredoka-SemiBold',
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Container(
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
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: Colors.black87,
            ),
            validator: validator,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.grey[400],
              ),
              prefixIcon: Icon(
                icon,
                color: Color(0xffFFA500),
                size: 22,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              filled: true,
              fillColor: Colors.white,
              errorStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Colors.red[700],
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: delay.ms).slideY(begin: 0.1, end: 0);
  }
}