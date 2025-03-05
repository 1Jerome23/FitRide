import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class FoodQuestionnairePage extends StatefulWidget {
  const FoodQuestionnairePage({Key? key}) : super(key: key);

  @override
  State<FoodQuestionnairePage> createState() => _FoodQuestionnairePageState();
}

class _FoodQuestionnairePageState extends State<FoodQuestionnairePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _breakfastController = TextEditingController();
  final TextEditingController _lunchController = TextEditingController();
  final TextEditingController _dinnerController = TextEditingController();
  
  double _breakfastCalories = 0;
  double _lunchCalories = 0;
  double _dinnerCalories = 0;
  
  bool _isCalculatingBreakfast = false;
  bool _isCalculatingLunch = false;
  bool _isCalculatingDinner = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _breakfastController.dispose();
    _lunchController.dispose();
    _dinnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Daily Food Diary'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What did you eat today?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),
              SizedBox(height: 24),
              
              // Breakfast Section
              _buildMealSection(
                mealTitle: 'Breakfast',
                controller: _breakfastController,
                calories: _breakfastCalories,
                isCalculating: _isCalculatingBreakfast,
                onCalculate: () async {
                  if (_breakfastController.text.isEmpty) return;
                  
                  setState(() {
                    _isCalculatingBreakfast = true;
                  });
                  
                  final calories = await _getCaloriesFromUSDA(_breakfastController.text);
                  
                  setState(() {
                    _breakfastCalories = calories;
                    _isCalculatingBreakfast = false;
                  });
                },
              ),
              SizedBox(height: 16),
              
              // Lunch Section
              _buildMealSection(
                mealTitle: 'Lunch',
                controller: _lunchController,
                calories: _lunchCalories,
                isCalculating: _isCalculatingLunch,
                onCalculate: () async {
                  if (_lunchController.text.isEmpty) return;
                  
                  setState(() {
                    _isCalculatingLunch = true;
                  });
                  
                  final calories = await _getCaloriesFromUSDA(_lunchController.text);
                  
                  setState(() {
                    _lunchCalories = calories;
                    _isCalculatingLunch = false;
                  });
                },
              ),
              SizedBox(height: 16),
              
              // Dinner Section
              _buildMealSection(
                mealTitle: 'Dinner',
                controller: _dinnerController,
                calories: _dinnerCalories,
                isCalculating: _isCalculatingDinner,
                onCalculate: () async {
                  if (_dinnerController.text.isEmpty) return;
                  
                  setState(() {
                    _isCalculatingDinner = true;
                  });
                  
                  final calories = await _getCaloriesFromUSDA(_dinnerController.text);
                  
                  setState(() {
                    _dinnerCalories = calories;
                    _isCalculatingDinner = false;
                  });
                },
              ),
              SizedBox(height: 24),
              
              // Total Calories
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Calories:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${(_breakfastCalories + _lunchCalories + _dinnerCalories).toStringAsFixed(0)} kcal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isCalculatingBreakfast || 
                             _isCalculatingLunch || 
                             _isCalculatingDinner || 
                             _isSubmitting) ? null : _saveToFirestore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: _isSubmitting
                      ? CircularProgressIndicator(color: Colors.black)
                      : Text(
                          'Save Food Diary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMealSection({
    required String mealTitle,
    required TextEditingController controller,
    required double calories,
    required bool isCalculating,
    required VoidCallback onCalculate,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mealTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'What did you eat?',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    filled: true,
                    fillColor: Colors.grey[800],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter what you ate';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: 8),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: isCalculating ? null : onCalculate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isCalculating
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.calculate),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Calories: ',
                style: TextStyle(
                  color: Colors.grey[400],
                ),
              ),
              Text(
                '${calories.toStringAsFixed(0)} kcal',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  Future<void> _saveToFirestore() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in to save food data')),
      );
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    try {
      // Get the current date (without time)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Create data entry
      final foodEntry = {
        'userId': user.uid,
        'date': Timestamp.fromDate(today),
        'breakfast_calories': _breakfastCalories,
        'lunch_calories': _lunchCalories,
        'dinner_calories': _dinnerCalories,
        'total_calories': _breakfastCalories + _lunchCalories + _dinnerCalories,
        'breakfast': _breakfastController.text,
        'lunch': _lunchController.text,
        'dinner': _dinnerController.text,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Check if an entry already exists for today
      final querySnapshot = await FirebaseFirestore.instance
        .collection('food_entries')
        .where('userId', isEqualTo: user.uid)
        .where('date', isEqualTo: Timestamp.fromDate(today))
        .limit(1)
        .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Update existing entry
        await FirebaseFirestore.instance
          .collection('food_entries')
          .doc(querySnapshot.docs.first.id)
          .update(foodEntry);
      } else {
        // Create new entry
        await FirebaseFirestore.instance
          .collection('food_entries')
          .add(foodEntry);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Food diary saved successfully!')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      print('Error saving food data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving food data: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}