import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestionPage extends StatefulWidget {
  @override
  _QuestionPageState createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _bodyWaterController = TextEditingController();
  
  String? _selectedGoal;
  String? _selectedHealthIssue;
  String? _selectedActivityLevel;
  String? _experiencedHeartRateIssues;
  String? _difficultyBreathing;
  String? _interestedInCardioEndurance;

  final List<String> _goals = [
    'Weight loss',
    'Muscle building',
    'Improving endurance',
    'Stress reduction',
  ];

  final List<String> _activityLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  final List<String> _yesNoOptions = [
    'Yes',
    'No',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _bodyWaterController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final weight = _weightController.text.isNotEmpty ? _weightController.text : null;
      final height = _heightController.text.isNotEmpty ? _heightController.text : null;
      final bodyWater = _bodyWaterController.text.isNotEmpty ? _bodyWaterController.text : null;
      final goals = _selectedGoal;
      final healthIssues = _selectedHealthIssue;
      final activityLevel = _selectedActivityLevel;

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User is not authenticated! Please log in.')),
        );
        return;
      }

      String uid = user.uid;

      // Save to Firestore
      try {
        await FirebaseFirestore.instance
            .collection('User Questionnaires') // Collection name
            .doc(uid) // Use UID as the document ID
            .set({
          'name': name,
          'weight': weight,
          'height': height,
          'bodyWater': bodyWater,
          'goals': goals,
          'healthIssues': healthIssues,
          'activityLevel': activityLevel,
          'experiencedHeartRateIssues': _experiencedHeartRateIssues,
          'difficultyBreathing': _difficultyBreathing,
          'interestedInCardioEndurance': _interestedInCardioEndurance,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Form submitted successfully!')),
        );

        _formKey.currentState!.reset();
        setState(() {
          _selectedActivityLevel = null;
          _selectedGoal = null;
          _selectedHealthIssue = null;
          _experiencedHeartRateIssues = null;
          _difficultyBreathing = null;
          _interestedInCardioEndurance = null;
        });
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userName', name);
        Navigator.pushReplacementNamed(context, '/homepage');
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit form: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,  
          children: [
            Text('User Questionnaire'),  
            Image.asset(
              'assets/logobike.png',  
              height: 40,  
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Name input field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: TextStyle(color: Colors.black, fontSize: 14),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _weightController,
                  decoration: InputDecoration(
                    labelText: 'Weight (kg)',
                    labelStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: TextStyle(color: Colors.black, fontSize: 14),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your weight';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8),
                // Height input field (required)
                TextFormField(
                  controller: _heightController,
                  decoration: InputDecoration(
                    labelText: 'Height (cm)',
                    labelStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: TextStyle(color: Colors.black, fontSize: 14),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your height';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8),

                // Body Water input field (optional)
                TextFormField(
                  controller: _bodyWaterController,
                  decoration: InputDecoration(
                    labelText: 'Body Water (%) (Optional)',
                    labelStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: TextStyle(color: Colors.black, fontSize: 14),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 8),

                // Goal dropdown field
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownButtonFormField<String>(
                    value: _selectedGoal,
                    decoration: InputDecoration(
                      labelText: 'Goals',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: TextStyle(color: Colors.black, fontSize: 14),
                    items: _goals
                        .map((goal) => DropdownMenuItem(
                              value: goal,
                              child: Text(goal),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGoal = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a goal';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 8),

                // Activity Level dropdown field
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownButtonFormField<String>(
                    value: _selectedActivityLevel,
                    decoration: InputDecoration(
                      labelText: 'Current Fitness Level',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: TextStyle(color: Colors.black, fontSize: 14),
                    items: _activityLevels
                        .map((level) => DropdownMenuItem(
                              value: level,
                              child: Text(level),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedActivityLevel = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select an activity level';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 8),

                // Heart Rate Issues dropdown field
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownButtonFormField<String>(
                    value: _experiencedHeartRateIssues,
                    decoration: InputDecoration(
                      labelText: 'Have you experienced any issues with your\nheart during or after exercise?',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: TextStyle(color: Colors.black, fontSize: 14),
                    items: _yesNoOptions
                        .map((option) => DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _experiencedHeartRateIssues = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please answer if you have heart rate issues';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 8),

                // Breathing Difficulty dropdown field
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownButtonFormField<String>(
                    value: _difficultyBreathing,
                    decoration: InputDecoration(
                      labelText: 'Do you experience shortness of breath\nor any difficulty breathing during or after cycling?',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: TextStyle(color: Colors.black, fontSize: 14),
                    items: _yesNoOptions
                        .map((option) => DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _difficultyBreathing = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please answer if you have difficulty breathing';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 8),

                // Cardio Endurance dropdown field
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownButtonFormField<String>(
                    value: _interestedInCardioEndurance,
                    decoration: InputDecoration(
                      labelText: 'Are you interested in improving your\ncardiovascular endurance through cycling?',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: TextStyle(color: Colors.black, fontSize: 14),
                    items: _yesNoOptions
                        .map((option) => DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _interestedInCardioEndurance = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please answer if you are interested in cardio endurance';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 16),

                ElevatedButton(
                  onPressed: _submitForm,
                  child: Text('Submit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
