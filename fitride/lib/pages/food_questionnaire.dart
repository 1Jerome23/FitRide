import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitride/globals.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FoodQuestionnairePage extends StatefulWidget {
  const FoodQuestionnairePage({Key? key}) : super(key: key);

  @override
  State<FoodQuestionnairePage> createState() => _FoodQuestionnairePageState();
}

class _FoodQuestionnairePageState extends State<FoodQuestionnairePage> {
  final _formKey = GlobalKey<FormState>();
  final user = FirebaseAuth.instance.currentUser;
  final firestore = FirebaseFirestore.instance;
  
  // Form fields
  final TextEditingController _breakfastController = TextEditingController();
  final TextEditingController _lunchController = TextEditingController();
  final TextEditingController _dinnerController = TextEditingController();
  
  // Calorie values
  double _breakfastCalories = 0;
  double _lunchCalories = 0;
  double _dinnerCalories = 0;
  
  // Loading states
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
      appBar: AppBar(
        title: const Text('Daily Food Diary'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        color: Colors.black,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What did you eat today?',
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Breakfast Section
                  _buildMealSection(
                    'Breakfast',
                    _breakfastController,
                    _breakfastCalories,
                    _isCalculatingBreakfast,
                    () async {
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
                  const SizedBox(height: 24),
                  
                  // Lunch Section
                  _buildMealSection(
                    'Lunch',
                    _lunchController,
                    _lunchCalories,
                    _isCalculatingLunch,
                    () async {
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
                  const SizedBox(height: 24),
                  
                  // Dinner Section
                  _buildMealSection(
                    'Dinner',
                    _dinnerController,
                    _dinnerCalories,
                    _isCalculatingDinner,
                    () async {
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
                  const SizedBox(height: 32),
                  
                  // Total Calories Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Daily Calories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_breakfastCalories + _lunchCalories + _dinnerCalories).toStringAsFixed(0)} kcal',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isCalculatingBreakfast || 
                                 _isCalculatingLunch || 
                                 _isCalculatingDinner || 
                                 _isSubmitting) ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
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
        ),
      ),
    );
  }
  
  Widget _buildMealSection(
    String mealTitle, 
    TextEditingController controller, 
    double calories, 
    bool isCalculating,
    VoidCallback onCalculate,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'E.g., 1 apple, 2 eggs, oatmeal',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: isCalculating 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calculate, color: Colors.white),
                onPressed: isCalculating ? null : onCalculate,
                tooltip: 'Calculate calories',
              ),
            ),
            style: const TextStyle(color: Colors.white),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter what you ate for $mealTitle';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Estimated calories:',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Text(
                '${calories.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Start submission
      setState(() {
        _isSubmitting = true;
      });

      try {
        if (user != null) {
          // Get the current date (without time)
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          
          // Create data entry
          final foodEntry = {
            'userId': user!.uid,
            'date': Timestamp.fromDate(today),
            'breakfast_calories': _breakfastCalories,
            'lunch_calories': _lunchCalories,
            'dinner_calories': _dinnerCalories,
            'total_calories': _breakfastCalories + _lunchCalories + _dinnerCalories,
            'breakfast_description': _breakfastController.text,
            'lunch_description': _lunchController.text,
            'dinner_description': _dinnerController.text,
            'created_at': Timestamp.now(),
          };

          // Check if an entry already exists for today
          final querySnapshot = await firestore
              .collection('food_entries')
              .where('userId', isEqualTo: user!.uid)
              .where('date', isEqualTo: Timestamp.fromDate(today))
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            // Update existing entry
            await firestore
                .collection('food_entries')
                .doc(querySnapshot.docs.first.id)
                .update(foodEntry);
          } else {
            // Create new entry
            await firestore.collection('food_entries').add(foodEntry);
          }

          // Show success message
          if (mounted) {
            Globals.scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Food diary saved successfully!'),
                backgroundColor: Colors.green,
              ),
            );

            // Return to previous screen
            Navigator.of(context).pop();
          }
        } else {
          // User not logged in
          if (mounted) {
            Globals.scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Error: You must be logged in to save entries.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          Globals.scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Error saving food entry: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        // End submission state if still mounted
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }
}