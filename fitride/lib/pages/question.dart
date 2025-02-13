import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
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
  
  String? _selectedAgeRange;
  String? _selectedHeightRange;
  String? _selectedWeightRange;
  String? _healthCondition;

  static const Color primaryBlack = Color(0xFF1A1A1A);
  static const Color primaryGray = Color(0xFF676767);
  static const Color primaryOrange = Color(0xFFFF8B3D);
  
  final List<Map<String, String>> _ageGroups = [
    {'image': 'assets/male-young.png', 'label': '18-30'},
    {'image': 'assets/male-adult.png', 'label': '31-45'},
    {'image': 'assets/male-middle.png', 'label': '46-60'},
    {'image': 'assets/male-senior.png', 'label': '60+'},
  ];

  final List<Map<String, String>> _heightGroups = [
    {'image': 'assets/height_short.png', 'label': '150-165cm'},
    {'image': 'assets/height_medium.png', 'label': '166-180cm'},
    {'image': 'assets/height_tall.png', 'label': '181-195cm'},
    {'image': 'assets/height_very_tall.png', 'label': '196cm+'},
  ];

  final List<Map<String, String>> _weightGroups = [
    {'image': 'assets/weight_light.png', 'label': '45-60kg'},
    {'image': 'assets/weight_medium.png', 'label': '61-75kg'},
    {'image': 'assets/weight_heavy.png', 'label': '76-90kg'},
    {'image': 'assets/weight_very_heavy.png', 'label': '91kg+'},
  ];

  final List<Map<String, dynamic>> _healthConditions = [
    {
      'image': 'assets/none.png',
      'label': 'None',
      'description': 'No pre-existing conditions'
    },
    {
      'image': 'assets/heart.png',
      'label': 'Cardiovascular',
      'description': 'Heart-related conditions'
    },
    {
      'image': 'assets/lungs.png',
      'label': 'Respiratory',
      'description': 'Breathing-related conditions'
    },
    {
      'image': 'assets/both.png',
      'label': 'Both',
      'description': 'Both cardiovascular and respiratory conditions'
    },
  ];

  void onPageChangedCallback(int activePageIndex) {
    setState(() {
      _currentPage = activePageIndex;
    });
  }

  Future<void> submitQuestionnaire() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit your answers')),
      );
      return;
    }

    if (_selectedAgeRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an age range')),
      );
      return;
    }
    if (_selectedHeightRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a height range')),
      );
      return;
    }
    if (_selectedWeightRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a weight range')),
      );
      return;
    }
    if (_healthCondition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a health condition')),
      );
      return;
    }

    try {
      Map<String, dynamic> userData = {
        'timestamp': FieldValue.serverTimestamp(),
        'ageRange': _selectedAgeRange,
        'heightRange': _selectedHeightRange,
        'weightRange': _selectedWeightRange,
        'healthCondition': _healthCondition,
      };

      await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid)
          .set(userData);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userAgeRange', _selectedAgeRange!);
      
      Navigator.pushReplacementNamed(context, '/homepage');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit questionnaire: $e')),
      );
    }
  }

  List<LinearGradient> gradients = [
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF000000), Color(0xFF222222)], // Diagonal Black Gradient
    ),
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF111111), Color(0xFF000000)], // Fade from Dark Gray to Black
    ),
    LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFF000000), Color(0xFF333333)], // Horizontal Black Gradient
    ),
    LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [Color(0xFF000000), Color(0xFF1A1A1A)], // Reverse Diagonal Gradient
    ),
  ];

  Widget buildInputPage(String title, String subtitle, Widget input, int index) {
    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
        gradient: gradients[index % gradients.length],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 32),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: "Fredoka-SemiBold",
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontFamily: "Inter",
                  ),
                ),
                SizedBox(height: 40),
                Expanded(
                  child: SingleChildScrollView(
                    physics: ClampingScrollPhysics(),
                    child: Column(
                      children: [
                        input,
                        SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildImageSelector(List<Map<String, String>> items, String? selectedValue, Function(String?) onSelect) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double itemWidth = (constraints.maxWidth - 16) / 2;
        double itemHeight = itemWidth * 1.2;
        
        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: itemWidth / itemHeight,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isSelected = selectedValue == item['label'];
            
            return GestureDetector(
              onTap: () => onSelect(item['label']),
              child: Container(
                width: itemWidth,
                height: itemHeight,
                decoration: BoxDecoration(
                  color: isSelected ? primaryOrange.withOpacity(0.1) : primaryGray.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? primaryOrange : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      item['image']!,
                      height: 150,
                      width: 150,
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        item['label']!,
                        style: TextStyle(
                          color: isSelected ? primaryOrange : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildHealthConditionSelector() {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _healthConditions.length,
      itemBuilder: (context, index) {
        final condition = _healthConditions[index];
        final isSelected = _healthCondition == condition['label'];
        
        return GestureDetector(
          onTap: () => setState(() => _healthCondition = condition['label']),
          child: Container(
            margin: EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? primaryOrange.withOpacity(0.1) : primaryGray.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? primaryOrange : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Image.asset(
                  condition['image'],
                  height: 100,
                  width: 100,
                  //color: isSelected ? primaryOrange : Colors.white,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        condition['label'],
                        style: TextStyle(
                          color: isSelected ? primaryOrange : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        condition['description'],
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildInputPage(
        "What's your age?",
        "Select an age group that best represents you.",
        buildImageSelector(
          _ageGroups,
          _selectedAgeRange,
          (value) => setState(() => _selectedAgeRange = value),
        ),
        0,
      ),
      buildInputPage(
        "What's your height?",
        "Select a height range that matches you best.",
        buildImageSelector(
          _heightGroups,
          _selectedHeightRange,
          (value) => setState(() => _selectedHeightRange = value),
        ),
        1,
      ),
      buildInputPage(
        "What's your weight?",
        "Select a weight range that matches you best.",
        buildImageSelector(
          _weightGroups,
          _selectedWeightRange,
          (value) => setState(() => _selectedWeightRange = value),
        ),
        2,
      ),
      buildInputPage(
        "Health Conditions",
        "Please select any pre-existing conditions that apply to you.",
        buildHealthConditionSelector(),
        3,
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: LiquidSwipe(
              pages: pages,
              liquidController: _controller,
              onPageChangeCallback: onPageChangedCallback,
              enableSideReveal: false,
              fullTransitionValue: 880,
              enableLoop: false,
              waveType: WaveType.liquidReveal,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryOrange.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _currentPage == pages.length - 1 
                      ? submitQuestionnaire 
                      : () {
                          _controller.animateToPage(
                            page: _currentPage + 1,
                            duration: 600,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(20),
                    elevation: 0,
                  ),
                  child: Icon(
                    _currentPage == pages.length - 1 
                        ? Icons.check 
                        : Icons.arrow_forward,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}