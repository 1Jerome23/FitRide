import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuestionAfterExercisePage extends StatefulWidget {
  @override
  _QuestionAfterExercisePageState createState() =>
      _QuestionAfterExercisePageState();
}

class _QuestionAfterExercisePageState extends State<QuestionAfterExercisePage> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedSleepHours;
  int? _selectedWaterIntake;
  int? _selectedEnergyLevel;
  final TextEditingController _cyclingGoalController = TextEditingController();

  final List<int> _sleepHoursOptions = List.generate(13, (index) => index); // 0–12 hours
  final List<int> _waterIntakeOptions = List.generate(21, (index) => index); // 0–20 glasses
  final List<int> _energyLevelOptions = List.generate(10, (index) => index + 1); // 1–10

  @override
  void dispose() {
    _cyclingGoalController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final sleepHours = _selectedSleepHours;
      final waterIntake = _selectedWaterIntake;
      final energyLevel = _selectedEnergyLevel;
      final cyclingGoal = _cyclingGoalController.text;

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
            .collection('After Exercise Form')
            .doc(uid)
            .set({
          'sleepHours': sleepHours,
          'waterIntake': waterIntake,
          'energyLevel': energyLevel,
          'cyclingGoal': cyclingGoal,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Form submitted successfully!')),
        );

        _formKey.currentState!.reset();
        setState(() {
          _selectedSleepHours = null;
          _selectedWaterIntake = null;
          _selectedEnergyLevel = null;
        });
        _cyclingGoalController.clear();
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
            Text('Questionnaire After Exercise'),
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
                // Sleep Hours Dropdown
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownButtonFormField<int>(
                    value: _selectedSleepHours,
                    decoration: InputDecoration(
                      labelText: 'How many hours of sleep did you have last night?',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: TextStyle(color: Colors.black, fontSize: 14),
                    items: _sleepHoursOptions
                        .map((hours) => DropdownMenuItem(
                      value: hours,
                      child: Text('$hours hours'),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSleepHours = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select the number of hours';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 8),

                // Water Intake Dropdown
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownButtonFormField<int>(
                    value: _selectedWaterIntake,
                    decoration: InputDecoration(
                      labelText: 'How much water did you drink during your ride?',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: TextStyle(color: Colors.black, fontSize: 14),
                    items: _waterIntakeOptions
                        .map((glasses) => DropdownMenuItem(
                      value: glasses,
                      child: Text('$glasses glasses'),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedWaterIntake = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select the number of glasses';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 8),

                // Energy Level Dropdown
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownButtonFormField<int>(
                    value: _selectedEnergyLevel,
                    decoration: InputDecoration(
                      labelText: 'How energized did you feel during your ride? (1–10)',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: TextStyle(color: Colors.black, fontSize: 14),
                    items: _energyLevelOptions
                        .map((level) => DropdownMenuItem(
                      value: level,
                      child: Text(level.toString()),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedEnergyLevel = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select an energy level';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 8),

                // Cycling Goal Input
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: TextFormField(
                    controller: _cyclingGoalController,
                    decoration: InputDecoration(
                      labelText: 'What do you want to achieve with your cycling journey?',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 3,
                    style: TextStyle(color: Colors.black, fontSize: 14),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your goal';
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