import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart'; 

class PostExercise extends StatefulWidget {
  @override
  _PostExerciseState createState() => _PostExerciseState();
}

class _PostExerciseState extends State<PostExercise> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _exertionController = TextEditingController();
  final TextEditingController _foodController = TextEditingController();
  final TextEditingController _hydrationController = TextEditingController();

  Future<void> _saveToFirestore() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('after_exercise').doc(user.uid).set({
          'levelOfExertion': int.parse(_exertionController.text),
          'foodTaken': _foodController.text,
          'hydration': int.parse(_hydrationController.text),
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Data saved successfully!")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()), 
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Post Exercise Form",
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                validator: (value) {
                  if (value == null || value.isEmpty) return "Required";
                  return null;
                },
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
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _saveToFirestore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: Text("Submit", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
