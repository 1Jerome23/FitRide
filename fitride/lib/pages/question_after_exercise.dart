import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  
  // Nutrient tracking for each meal
  double _breakfastCarbs = 0;
  double _lunchCarbs = 0;
  double _dinnerCarbs = 0;
  
  double _breakfastProtein = 0;
  double _lunchProtein = 0;
  double _dinnerProtein = 0;
  
  double _breakfastFat = 0;
  double _lunchFat = 0;
  double _dinnerFat = 0;

  bool _isCalculatingBreakfast = false;
  bool _isCalculatingLunch = false;
  bool _isCalculatingDinner = false;
  bool _isSubmitting = false;
  bool _showGuidelines = true;

  // Define the orange color from profile page
  final Color orangeColor = const Color(0xffFFA500);
  final Color darkGrey = const Color(0xFF303030);

  // CaloriesNinja API Key
  final String _apiKey = 'vRBy09Rf/CSLlSJO0iK3Vw==m5ujHrsqBMljyyFP';

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
        actions: [
          // Help button that toggles guidelines
          IconButton(
            icon: Icon(_showGuidelines ? Icons.visibility_off : Icons.help_outline, color: orangeColor),
            onPressed: () {
              setState(() {
                _showGuidelines = !_showGuidelines;
              });
            },
            tooltip: _showGuidelines ? "Hide Guidelines" : "Show Guidelines",
          ),
        ],
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
              SizedBox(height: 16),

              // Guidelines section (collapsible)
              if (_showGuidelines) _buildGuidelines(),

              // Breakfast Section
              _buildMealSection(
                mealTitle: 'Breakfast',
                controller: _breakfastController,
                calories: _breakfastCalories,
                isCalculating: _isCalculatingBreakfast,
                icon: Icons.breakfast_dining,
                hintText: 'E.g., "2 eggs, 1 slice toast with butter, 1 cup coffee with milk"',
                onCalculate: () async {
                  if (_breakfastController.text.isEmpty) return;

                  setState(() {
                    _isCalculatingBreakfast = true;
                  });

                  final nutritionData =
                      await _getNutritionFromCaloriesNinja(_breakfastController.text);

                  setState(() {
                    _breakfastCalories = nutritionData['calories'] ?? 0.0;
                    _breakfastCarbs = nutritionData['carbs'] ?? 0.0;
                    _breakfastProtein = nutritionData['protein'] ?? 0.0;
                    _breakfastFat = nutritionData['fat'] ?? 0.0;
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
                hintText: 'E.g., "Chicken sandwich with lettuce, tomato and mayo, apple, water"',
                onCalculate: () async {
                  if (_lunchController.text.isEmpty) return;

                  setState(() {
                    _isCalculatingLunch = true;
                  });

                  final nutritionData =
                      await _getNutritionFromCaloriesNinja(_lunchController.text);

                  setState(() {
                    _lunchCalories = nutritionData['calories'] ?? 0.0;
                    _lunchCarbs = nutritionData['carbs'] ?? 0.0;
                    _lunchProtein = nutritionData['protein'] ?? 0.0;
                    _lunchFat = nutritionData['fat'] ?? 0.0;
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
                hintText: 'E.g., "1 cup rice, 5oz salmon, 1 cup steamed broccoli, 1 tbsp olive oil"',
                onCalculate: () async {
                  if (_dinnerController.text.isEmpty) return;

                  setState(() {
                    _isCalculatingDinner = true;
                  });

                  final nutritionData =
                      await _getNutritionFromCaloriesNinja(_dinnerController.text);

                  setState(() {
                    _dinnerCalories = nutritionData['calories'] ?? 0.0;
                    _dinnerCarbs = nutritionData['carbs'] ?? 0.0;
                    _dinnerProtein = nutritionData['protein'] ?? 0.0;
                    _dinnerFat = nutritionData['fat'] ?? 0.0;
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(_breakfastCalories + _lunchCalories + _dinnerCalories).toStringAsFixed(0)} kcal',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: orangeColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Carbs: ${(_breakfastCarbs + _lunchCarbs + _dinnerCarbs).toStringAsFixed(1)}g',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Protein: ${(_breakfastProtein + _lunchProtein + _dinnerProtein).toStringAsFixed(1)}g',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Fat: ${(_breakfastFat + _lunchFat + _dinnerFat).toStringAsFixed(1)}g',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Pre-save validation reminder
              if (_breakfastCalories == 0 && _lunchCalories == 0 && _dinnerCalories == 0)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Please enter and calculate all meals before saving your food diary",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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
                            _isSubmitting)
                        ? null
                        : _saveToFirestore,
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

  Widget _buildGuidelines() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "How to Use the Food Diary",
                    style: TextStyle(
                      fontFamily: 'Fredoka-SemiBold',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _showGuidelines = false;
                  });
                },
                child: Icon(
                  Icons.close,
                  color: Colors.blue[700],
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGuidelineItem(
            icon: Icons.format_list_bulleted,
            text: "Be as specific as possible with your food entries (e.g., \"2 scrambled eggs with 1 tbsp butter, 1 slice whole wheat toast\")",
          ),
          _buildGuidelineItem(
            icon: Icons.calculate_outlined,
            text: "Click the calculate button after entering each meal to analyze its nutritional content",
          ),
          _buildGuidelineItem(
            icon: Icons.restaurant,
            text: "Include portion sizes when possible (e.g., \"1 cup rice\" instead of just \"rice\")",
          ),
          _buildGuidelineItem(
            icon: Icons.local_drink_outlined,
            text: "Don't forget to include beverages, condiments, and cooking oils",
          ),
          _buildGuidelineItem(
            icon: Icons.tips_and_updates_outlined,
            text: "For mixed dishes, list major ingredients (e.g., \"chicken sandwich with lettuce, mayo, and tomato\")",
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(
              "Tips for Better Results",
              style: TextStyle(
                fontFamily: 'Fredoka-SemiBold',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.blue[700],
              ),
            ),
            children: [
              _buildGuidelineItem(
                icon: Icons.text_fields,
                text: "Use brand names when relevant (e.g., \"Chobani Greek yogurt\" vs \"yogurt\")",
              ),
              _buildGuidelineItem(
                icon: Icons.lightbulb_outline,
                text: "Specify cooking methods (e.g., \"grilled chicken\" vs \"fried chicken\")",
              ),
              _buildGuidelineItem(
                icon: Icons.no_meals_outlined,
                text: "If you skipped a meal, enter \"none\" and calculate (will show 0 calories)",
              ),
              _buildGuidelineItem(
                icon: Icons.watch_later_outlined,
                text: "Complete your diary daily for the most accurate nutrition recommendations",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.blue[400],
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
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
    required String hintText,
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
              if (calories == 0) 
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.amber[700],
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        "Needs calculation",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.amber[700],
                        ),
                      )
                    ],
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
                      hintText: hintText,
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter what you ate';
                      }
                      return null;
                    },
                    maxLines: 3,
                    minLines: 1,
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
                          : Tooltip(
                              message: "Calculate nutrition",
                              child: Icon(
                                Icons.calculate,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
              SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'C: ${mealTitle == 'Breakfast' ? _breakfastCarbs.toStringAsFixed(1) : 
                        mealTitle == 'Lunch' ? _lunchCarbs.toStringAsFixed(1) : 
                        _dinnerCarbs.toStringAsFixed(1)}g',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'P: ${mealTitle == 'Breakfast' ? _breakfastProtein.toStringAsFixed(1) : 
                        mealTitle == 'Lunch' ? _lunchProtein.toStringAsFixed(1) : 
                        _dinnerProtein.toStringAsFixed(1)}g',
                        style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'F: ${mealTitle == 'Breakfast' ? _breakfastFat.toStringAsFixed(1) : 
                        mealTitle == 'Lunch' ? _lunchFat.toStringAsFixed(1) : 
                        _dinnerFat.toStringAsFixed(1)}g',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Map<String, double>> _getNutritionFromCaloriesNinja(String foodInput) async {
    // Initialize result map with default values
    Map<String, double> nutritionData = {
      'calories': 0.0,
      'carbs': 0.0,
      'protein': 0.0,
      'fat': 0.0,
    };
    
    if (foodInput.isEmpty) return nutritionData;
    
    // Handle "none" or "skipped" entries
    if (foodInput.toLowerCase().trim() == "none" || 
        foodInput.toLowerCase().trim() == "skipped" ||
        foodInput.toLowerCase().trim() == "skip") {
      return nutritionData; // Return all zeros
    }

    final url = Uri.parse('https://api.calorieninjas.com/v1/nutrition?query=$foodInput');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'X-Api-Key': _apiKey,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['items'] != null && data['items'].isNotEmpty) {
          // Sum up nutritional values from all items in the response
          for (var item in data['items']) {
            if (item['calories'] != null) {
              nutritionData['calories'] = nutritionData['calories']! + item['calories'].toDouble();
            }
            
            if (item['carbohydrates_total_g'] != null) {
              nutritionData['carbs'] = nutritionData['carbs']! + item['carbohydrates_total_g'].toDouble();
            }
            
            if (item['protein_g'] != null) {
              nutritionData['protein'] = nutritionData['protein']! + item['protein_g'].toDouble();
            }
            
            if (item['fat_total_g'] != null) {
              nutritionData['fat'] = nutritionData['fat']! + item['fat_total_g'].toDouble();
            }
          }
        } else {
          print("No food items found for '$foodInput'");
          // Show a warning to the user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No nutrition data found for '$foodInput'. Try being more specific or check spelling."),
              backgroundColor: Colors.amber[700],
              duration: Duration(seconds: 4),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      } else {
        print("CaloriesNinja API Error: ${response.statusCode} - ${response.body}");
        // Show an error message to the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error calculating nutrition data. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error fetching nutrition data: $e");
      // Show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connection error. Please check your internet and try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    return nutritionData;
  }

  Future<void> _saveToFirestore() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Check if all meals have been calculated
    if (_breakfastController.text.isNotEmpty && _breakfastCalories == 0 ||
        _lunchController.text.isNotEmpty && _lunchCalories == 0 ||
        _dinnerController.text.isNotEmpty && _dinnerCalories == 0) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please calculate nutrition for all meals before saving'),
          backgroundColor: Colors.amber[700],
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
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

      // Check if an entry for today already exists
      final existingEntries = await FirebaseFirestore.instance
          .collection('food_entries')
          .where('userId', isEqualTo: user.uid)
          .where('date', isEqualTo: Timestamp.fromDate(today))
          .get();

      if (existingEntries.docs.isNotEmpty) {
        // Show confirmation dialog for overwriting
        bool shouldOverwrite = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Entry Already Exists"),
              content: Text("You already have a food diary entry for today. Do you want to replace it?", style: TextStyle(color: Colors.black),),
              actions: [
                TextButton(
                  child: Text("Cancel", style: TextStyle(color: Colors.grey[700])),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: orangeColor),
                  child: Text("Replace", style: TextStyle(color: Colors.white)),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ?? false;

        if (!shouldOverwrite) {
          setState(() {
            _isSubmitting = false;
          });
          return;
        }

        // Delete the existing entry
        await FirebaseFirestore.instance
            .collection('food_entries')
            .doc(existingEntries.docs.first.id)
            .delete();
      }

      // Calculate totals
      final totalCalories = _breakfastCalories + _lunchCalories + _dinnerCalories;
      final totalCarbs = _breakfastCarbs + _lunchCarbs + _dinnerCarbs;
      final totalProtein = _breakfastProtein + _lunchProtein + _dinnerProtein;
      final totalFat = _breakfastFat + _lunchFat + _dinnerFat;
      
      // Create data entry
      final foodEntry = {
        'userId': user.uid,
        'date': Timestamp.fromDate(today),
        // Calories
        'breakfast_calories': _breakfastCalories,
        'lunch_calories': _lunchCalories,
        'dinner_calories': _dinnerCalories,
        'total_calories': totalCalories,
        // Carbs
        'breakfast_carbs': _breakfastCarbs,
        'lunch_carbs': _lunchCarbs,
        'dinner_carbs': _dinnerCarbs,
        'total_carbs': totalCarbs,
        // Protein
        'breakfast_protein': _breakfastProtein,
        'lunch_protein': _lunchProtein,
        'dinner_protein': _dinnerProtein,
        'total_protein': totalProtein,
        // Fat
        'breakfast_fat': _breakfastFat,
        'lunch_fat': _lunchFat,
        'dinner_fat': _dinnerFat,
        'total_fat': totalFat,
        // Food descriptions
        'breakfast': _breakfastController.text,
        'lunch': _lunchController.text,
        'dinner': _dinnerController.text,
        'timestamp': FieldValue.serverTimestamp(),
      };
      // Create new entry
      await FirebaseFirestore.instance
          .collection('food_entries')
          .add(foodEntry);

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