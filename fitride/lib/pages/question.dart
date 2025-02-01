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
  final TextEditingController _ageController = TextEditingController();

  String? _selectedActivityLevel;
  String? _experiencedHeartRateIssues;
  String? _difficultyBreathing;

  final List<String> _activityLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  final List<String> _yesNoOptions = [
    'Yes',
    'No',
  ];

  int _currentStep = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _bodyWaterController.dispose();
    _ageController.dispose(); 
    super.dispose();
  }

 Future<void> _submitForm() async {
  if (_formKey.currentState!.validate()) {
    final name = _nameController.text;
    final weight = _weightController.text.isNotEmpty
        ? double.tryParse(_weightController.text) 
        : null;
    final height = _heightController.text.isNotEmpty ? _heightController.text : null;
    final bodyWater = _bodyWaterController.text.isNotEmpty ? _bodyWaterController.text : null;
    final activityLevel = _selectedActivityLevel;

    // Convert age to int
    final age = _ageController.text.isNotEmpty
        ? int.tryParse(_ageController.text) 
        : null; 

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User is not authenticated! Please log in.')),
      );
      return;
    }

    String uid = user.uid;

    try {
      await FirebaseFirestore.instance
          .collection('User Questionnaires')
          .doc(uid)
          .set({
        'name': name,
        'weight': weight,  // Save as double (or null if empty)
        'height': height,
        'age': age, // Save as int (or null if empty)
        'bodyWater': bodyWater,
        'activityLevel': activityLevel,
        'experiencedHeartRateIssues': _experiencedHeartRateIssues,
        'difficultyBreathing': _difficultyBreathing,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Form submitted successfully!')),
      );

      _formKey.currentState!.reset();
      setState(() {
        _selectedActivityLevel = null;
        _experiencedHeartRateIssues = null;
        _difficultyBreathing = null;
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
    body: Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_currentStep == 0) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                      ),
                      style: TextStyle(color: Colors.black),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                      ),
                      style: TextStyle(color: Colors.black),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your age';
                        }
                        final age = int.tryParse(value);
                        if (age == null || age <= 0) {
                          return 'Please enter a valid age';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedActivityLevel,
                    decoration: InputDecoration(
                      labelText: 'Current Fitness Level',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                    ),
                    style: TextStyle(color: Colors.black),
                    items: _activityLevels
                        .map((level) => DropdownMenuItem(
                              value: level,
                              child: Text(level,
                                  style: TextStyle(color: Colors.black)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedActivityLevel = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your fitness level';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState?.validate() ?? false) {
                            setState(() {
                              _currentStep++;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: Text('Next'),
                      ),
                    ],
                  ),
                ],
                if (_currentStep == 1) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _weightController,
                      decoration: InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                      ),
                      style: TextStyle(color: Colors.black),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your weight';
                        }
                        final double? weight = double.tryParse(value);
                        if (weight == null || weight <= 0) {
                          return 'Enter a valid weight';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _heightController,
                    decoration: InputDecoration(
                      labelText: 'Height (cm)',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                    ),
                    style: TextStyle(color: Colors.black),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your height';
                      }
                      final double? height = double.tryParse(value);
                      if (height == null || height <= 0) {
                        return 'Enter a valid height';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _currentStep--;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: Text('Back'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState?.validate() ?? false) {
                            setState(() {
                              _currentStep++;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: Text('Next'),
                      ),
                    ],
                  ),
                ],
                if (_currentStep == 2) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Have you experienced any heart rate issues?',
                      style: TextStyle(fontSize: 12, color: Colors.black),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _experiencedHeartRateIssues,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                    ),
                    style: TextStyle(color: Colors.black),
                    items: _yesNoOptions
                        .map((option) => DropdownMenuItem<String>(
                              value: option,
                              child: Text(option,
                                  style: TextStyle(color: Colors.black)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _experiencedHeartRateIssues = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select an option';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _currentStep--;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: Text('Back'),
                      ),
                      ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: Text('Submit'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}