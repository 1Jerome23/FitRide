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
  
  // Define the orange color from profile page
  final Color orangeColor = const Color(0xffFFA500);
  final Color darkGrey = const Color(0xFF303030);

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        title: const Text(
          "Daily Food Diary",
          style: TextStyle(
            fontFamily: 'Fredoka-SemiBold',
            color: Color(0xffFFA500),
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: orangeColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'What did you eat today?',
                    style: TextStyle(
                      fontFamily: 'Fredoka-SemiBold',
                      color: Colors.black,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              SizedBox(height: 20),
              
              // Breakfast Section
              _buildMealSection(
                mealTitle: 'Breakfast',
                controller: _breakfastController,
                calories: _breakfastCalories,
                isCalculating: _isCalculatingBreakfast,
                icon: Icons.breakfast_dining,
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
                icon: Icons.lunch_dining,
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
                icon: Icons.dinner_dining,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: orangeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.local_fire_department,
                            color: orangeColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Total Calories:',
                          style: TextStyle(
                            fontFamily: 'Fredoka-SemiBold',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${(_breakfastCalories + _lunchCalories + _dinnerCalories).toStringAsFixed(0)} kcal',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: orangeColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),
              
              // Submit Button
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [orangeColor.withOpacity(0.8), orangeColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: orangeColor.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: (_isCalculatingBreakfast || 
                          _isCalculatingLunch || 
                          _isCalculatingDinner || 
                          _isSubmitting) ? null : _saveToFirestore,
                    child: Center(
                      child: _isSubmitting
                          ? CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.save_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  "SAVE FOOD DIARY",
                                  style: TextStyle(
                                    fontFamily: 'Fredoka-SemiBold',
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
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
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: orangeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: orangeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                mealTitle,
                style: TextStyle(
                  fontFamily: 'Fredoka-SemiBold',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: TextFormField(
                    controller: controller,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'What did you eat?',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter what you ate';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCalculating 
                        ? [Colors.grey.withOpacity(0.8), Colors.grey] 
                        : [orangeColor.withOpacity(0.8), orangeColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: orangeColor.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: isCalculating ? null : onCalculate,
                    child: Center(
                      child: isCalculating
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.calculate,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
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
                  fontFamily: 'Inter',
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                '${calories.toStringAsFixed(0)} kcal',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: orangeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
        SnackBar(
          content: Text('You must be logged in to save food data'),
          backgroundColor: Colors.red,
        ),
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
        SnackBar(
          content: Text('Food diary saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      print('Error saving food data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving food data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}