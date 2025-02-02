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

  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _bodyFatController = TextEditingController();
  final TextEditingController _bodyWaterController = TextEditingController();
  final TextEditingController _exertionController =
      TextEditingController(); // New controller for exertion level

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _bodyFatController.dispose();
    _bodyWaterController.dispose();
    _exertionController.dispose(); // Dispose the new controller
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final age = _ageController.text.isNotEmpty
          ? int.tryParse(_ageController.text)
          : null;
      final weight = _weightController.text.isNotEmpty
          ? double.tryParse(_weightController.text)
          : null;
      final bodyFat = _bodyFatController.text.isNotEmpty
          ? double.tryParse(_bodyFatController.text)
          : null;
      final bodyWater = _bodyWaterController.text.isNotEmpty
          ? double.tryParse(_bodyWaterController.text)
          : null;
      final exertionLevel = _exertionController.text.isNotEmpty
          ? int.tryParse(_exertionController.text)
          : null; // Parse exertion level

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
          'age': age,
          'weight': weight,
          'bodyFat': bodyFat,
          'bodyWater': bodyWater,
          'exertionLevel': exertionLevel, // Add exertion level to Firestore
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Form submitted successfully!')),
        );

        _formKey.currentState!.reset();
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
                  // Age Input
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

                  // Weight Input
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                      ),
                      style: TextStyle(color: Colors.black),
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

                  // Body Fat Input
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _bodyFatController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Body Fat (%)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                      ),
                      style: TextStyle(color: Colors.black),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your body fat percentage';
                        }
                        final double? bodyFat = double.tryParse(value);
                        if (bodyFat == null || bodyFat <= 0 || bodyFat > 100) {
                          return 'Enter a valid body fat percentage (0-100)';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 16),

                  // Body Water Input
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _bodyWaterController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Body Water (%)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                      ),
                      style: TextStyle(color: Colors.black),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your body water percentage';
                        }
                        final double? bodyWater = double.tryParse(value);
                        if (bodyWater == null ||
                            bodyWater <= 0 ||
                            bodyWater > 100) {
                          return 'Enter a valid body water percentage (0-100)';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 16),

                  // Exertion Level Input
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _exertionController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Level of Exertion in Cycling (1-10)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                      ),
                      style: TextStyle(color: Colors.black),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your exertion level';
                        }
                        final int? exertionLevel = int.tryParse(value);
                        if (exertionLevel == null ||
                            exertionLevel < 1 ||
                            exertionLevel > 10) {
                          return 'Enter a valid exertion level (1-10)';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 16),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding:
                          EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                    child: Text(
                      'Submit',
                      style: TextStyle(color: Colors.black),
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
}
