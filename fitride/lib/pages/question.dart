import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestionPage extends StatefulWidget {
  const QuestionPage({Key? key}) : super(key: key);

  @override
  _QuestionPageState createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  final LiquidController _controller = LiquidController();
  int _currentPage = 0;
  
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String? _healthCondition;

  final List<String> _healthConditions = [
    'None',
    'Cardiovascular condition',
    'Respiratory condition',
    'Both'
  ];

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void onPageChangedCallback(int activePageIndex) {
    setState(() {
      _currentPage = activePageIndex;
    });
  }

  Future<void> submitQuestionnaire() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to submit your answers')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('User Questionnaires')
          .doc(user.uid)
          .set({
        'age': _ageController.text,
        'height': _heightController.text,
        'weight': _weightController.text,
        'healthCondition': _healthCondition,
        'timestamp': FieldValue.serverTimestamp(),
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userAge', _ageController.text);
      
      Navigator.pushReplacementNamed(context, '/homepage');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit questionnaire: $e')),
      );
    }
  }

  Widget buildInputPage(String question, Widget input, Size size, List<Color> colors) {
    return Container(
      color: colors.first,
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: "Fredoka-SemiBold",
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 40),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: input,
          ),
          SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget buildNumberInput(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(color: Colors.white, fontSize: 20, fontFamily: "Inter"),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white70),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  Widget buildHealthConditionDropdown() {
    return DropdownButtonFormField<String>(
      value: _healthCondition,
      dropdownColor: Colors.grey[800],
      style: TextStyle(color: Colors.white, fontSize: 20),
      decoration: InputDecoration(
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
      ),
      items: _healthConditions.map((String condition) {
        return DropdownMenuItem(
          value: condition,
          child: Text(condition),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _healthCondition = newValue;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    final pages = [
      buildInputPage(
        "How old are you?",
        buildNumberInput(_ageController, "Enter your age"),
        size,
        [Color(0xff676767)],
      ),
      buildInputPage(
        "What is your height?",
        buildNumberInput(_heightController, "Enter your height in cm"),
        size,
        [Color(0xffff8b3d)],
      ),
      buildInputPage(
        "What is your weight?",
        buildNumberInput(_weightController, "Enter your weight in kg"),
        size,
        [Color(0xff676767)],
      ),
      buildInputPage(
        "Do you have any pre-existing condition?",
        buildHealthConditionDropdown(),
        size,
        [Color(0xffff8b3d)],
      ),
    ];

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          LiquidSwipe(
            pages: pages,
            liquidController: _controller,
            onPageChangeCallback: onPageChangedCallback,
            //slideIconWidget: _currentPage == pages.length - 1 ? null : Icon(Icons.arrow_back_ios, color: Colors.white),
            enableSideReveal: false,
          ),
          Positioned(
            bottom: 60.0,
            child: OutlinedButton(
              onPressed: _currentPage == pages.length - 1 ? submitQuestionnaire : () {
                _controller.animateToPage(
                  page: _currentPage + 1,
                  duration: 600,
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white30),
                shape: CircleBorder(),
                padding: EdgeInsets.all(20),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _currentPage == pages.length - 1 ? Icons.check : Icons.arrow_forward_ios,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            child: AnimatedSmoothIndicator(
              activeIndex: _currentPage,
              count: pages.length,
              effect: WormEffect(
                activeDotColor: Colors.white,
                dotColor: Colors.white54,
                dotHeight: 5.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}