import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'home_page.dart';
import 'recommendation.dart';
import 'profile.dart';
import 'login_register.dart';
import 'dart:math' as math;

class GoalTrackingPage extends StatefulWidget {
  const GoalTrackingPage({super.key});

  @override
  _GoalTrackingPageState createState() => _GoalTrackingPageState();
}

class _GoalTrackingPageState extends State<GoalTrackingPage> {
  final PageController _pageController = PageController(viewportFraction: 0.8);
  bool showQuestionnaire = false;
  bool showGoalList = false;
  String? selectedGoal;
  Map<String, dynamic> answers = {};
  List<Map<String, dynamic>> goals = [];
  int _currentPage = 0;
  int _selectedIndex = 2;

  final List<Map<String, dynamic>> goalTypes = [
    {
      'title': 'Cycling Endurance',
      'description': 'Set distance goals for your cycling sessions',
      'image': 'assets/endurance-goal.png',
    },
    {
      'title': 'Weight Management',
      'description': 'Track your weight loss or gain progress',
      'image': 'assets/weight-goal.png',
    },
  ];

  final Map<String, List<Map<String, dynamic>>> questions = {
    'Cycling Endurance': [
      {
        'question': "What's your target cycling distance per session?",
        'type': 'number',
        'hint': 'Enter distance in kilometers',
      },
      {
        'question': "How often do you want to achieve this goal?",
        'type': 'choice',
        'options': ['Daily', 'Weekly', 'Monthly'],
      },
      {
        'question': "What's your current cycling level?",
        'type': 'choice',
        'options': ['Beginner', 'Intermediate', 'Advanced'],
      },
    ],
    'Weight Management': [
      {
        'question': "What's your current weight (kg)?",
        'type': 'number',
        'hint': 'Enter weight in kilograms',
      },
      {
        'question': "What's your target weight (kg)?",
        'type': 'number',
        'hint': 'Enter target weight in kilograms',
      },
      {
        'question': "What's your desired timeframe?",
        'type': 'choice',
        'options': ['1 month', '3 months', '6 months'],
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _pageController.addListener(() {
      int next = _pageController.page!.round();
      if (_currentPage != next) {
        setState(() {
          _currentPage = next;
          selectedGoal = goalTypes[next]['title'];
        });
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RecommendationPage()),
        );
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ProfilePage()),
        );
        break;
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  void _loadGoals() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final goalsSnapshot = await FirebaseFirestore.instance
          .collection('goals')
          .where('uid', isEqualTo: uid)
          .get();

      setState(() {
        goals = goalsSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        showGoalList = goals.isNotEmpty;
      });
    }
  }

  Future<void> _saveGoal() async {
  String? uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null && selectedGoal != null) {
    String goalId = DateTime.now().millisecondsSinceEpoch.toString();
    
    Map<String, dynamic> goalData = {
      'uid': uid,
      'goalId': goalId,
      'goalType': selectedGoal,
      'createdAt': Timestamp.now(),
    };

    // Add specific fields based on goal type
    if (selectedGoal == "Cycling Endurance") {
      goalData.addAll({
        'targetDistance': double.parse(answers["What's your target cycling distance per session?"] ?? '0'),
        'frequency': answers["How often do you want to achieve this goal?"],
        'currentLevel': answers["What's your current cycling level?"],
        'progress': 0.0,
        'target': double.parse(answers["What's your target cycling distance per session?"] ?? '0'),
      });
    } else {
      // For Weight Management
      double currentWeight = double.parse(answers["What's your current weight (kg)?"] ?? '0');
      double targetWeight = double.parse(answers["What's your target weight (kg)?"] ?? '0');
      
      goalData.addAll({
        'currentWeight': currentWeight,
        'targetWeight': targetWeight,
        'timeframe': answers["What's your desired timeframe?"],
        'progress': 0.0,
        'target': (currentWeight - targetWeight).abs(),
      });
    }

    try {
      await FirebaseFirestore.instance
          .collection('goals')
          .doc(goalId)
          .set(goalData);

      setState(() {
        goals.add(goalData);
        showQuestionnaire = false;
        showGoalList = true;
        selectedGoal = null;
        answers.clear();
      });
    } catch (e) {
      print('Error saving goal: $e');
    }
  }
}

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    double progress = goal['progress'] ?? 0.0;
    double target = goal['target'] ?? 0.0;
    String goalType = goal['goalType'] ?? '';
    String unit = goalType == 'Cycling Endurance' ? 'km' : 'kg';
    Map<String, dynamic> answers = goal['answers'] ?? {};
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xffFFA500).withOpacity(0.2),
            const Color(0xffFFCC70).withOpacity(0.1)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xffFFA500).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffFFA500).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    goalType == 'Cycling Endurance' 
                        ? Icons.directions_bike
                        : Icons.fitness_center,
                    color: const Color(0xffFFA500),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goalType,
                        style: const TextStyle(
                          fontFamily: 'Fredoka-SemiBold',
                          fontSize: 20,
                          color: Colors.black,
                        ),
                      ),
                      if (goalType == 'Cycling Endurance')
                        Text(
                          "Frequency: ${answers['How often do you want to achieve this goal?'] ?? 'Not set'}",
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      Text(
                        "Target: $target $unit",
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xffFFA500),
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('goals')
                        .doc(goal['goalId'])
                        .delete();
                    
                    // Refresh the goals list
                    if (mounted) {
                      context.findAncestorStateOfType<_GoalTrackingPageState>()!._loadGoals();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress / target,
              backgroundColor: Colors.grey[700],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xffFFA500)),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              "Progress: $progress/$target $unit",
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Created: ${(goal['createdAt'] as Timestamp).toDate().toString().split(' ')[0]}",
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalPage(Map<String, dynamic> goalType) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedGoal = goalType['title'];
          showQuestionnaire = true;
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate minimum height needed for content
          final minHeight = 450.0;
          // Use the larger of minHeight or available height
          final cardHeight = math.max(constraints.maxHeight, minHeight);
          final imageSize = 150.0; // Fixed image size
          
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            height: cardHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color.fromARGB(255, 250, 157, 34).withOpacity(0.8),
                  const Color.fromARGB(255, 238, 168, 78).withOpacity(0.7)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Image.asset(
                        goalType['image'],
                        height: imageSize,
                        width: imageSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      goalType['title'],
                      style: const TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 24,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      goalType['description'],
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Tap to set goal",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey[900],
        elevation: 0,
        title: const Text(
          "FitRide",
          style: TextStyle(
            fontFamily: 'Fredoka-SemiBold',
            color: Color(0xffFFA500),
            fontSize: 28,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: _logout,
              child: Image.asset(
                'assets/logobike.png',
                height: 40,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: showGoalList 
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    "Your Goals",
                    style: TextStyle(
                      fontFamily: 'Fredoka-SemiBold',
                      fontSize: 32,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Track your progress today! View your goals below.",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: Color.fromARGB(255, 59, 57, 57),
                    ),
                  ),
                  SizedBox(height: media.width * 0.05),
                  ...goals.map(_buildGoalCard).toList(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffFFA500),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        showGoalList = false;
                        showQuestionnaire = false;
                      });
                    },
                    child: const Text(
                      "Set Another Goal",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              )
            : showQuestionnaire
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Set Your $selectedGoal Goal",
                          style: const TextStyle(
                            fontFamily: 'Fredoka-SemiBold',
                            fontSize: 24,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ...questions[selectedGoal]!.map((question) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                question['question'],
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (question['type'] == 'choice')
                                ...question['options'].map<Widget>((option) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: answers[question['question']] == option
                                            ? const Color(0xffFFA500)  // Orange when selected
                                            : const Color(0xFF2C2C2C), // Dark grey when not selected
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          answers[question['question']] = option;
                                        });
                                      },
                                      child: Text(
                                        option,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          color: answers[question['question']] == option
                                              ? Colors.black   // Black text when selected (orange background)
                                              : Colors.white,  // White text when not selected (grey background)
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList()
                              else
                                TextField(
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setState(() {
                                      answers[question['question']] = value;
                                    });
                                  },
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: question['hint'],
                                    hintStyle: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.white70,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF2C2C2C), // Darker background
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                ),
                              const SizedBox(height: 24),
                            ],
                          );
                        }).toList(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xffFFA500),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _saveGoal,
                            child: const Text(
                              "Set Goal",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      const SizedBox(height: 60),
                      const Text(
                        "What is your goal?",
                        style: TextStyle(
                          fontFamily: 'Fredoka-SemiBold',
                          fontSize: 30,
                          color: Colors.black,
                        ),
                      ),
                      const Text(
                        "Choose a goal to get started",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 400,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: goalTypes.length,
                          itemBuilder: (context, index) {
                            return _buildGoalPage(goalTypes[index]);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: goalTypes.length,
                        effect: WormEffect(
                          dotColor: Colors.grey.shade700,
                          activeDotColor: const Color(0xffFFA500),
                          dotHeight: 10,
                          dotWidth: 10,
                        ),
                      ),
                    ],
                  ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xffFFA500),
          unselectedItemColor: Colors.grey[600],
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_rounded),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.track_changes_rounded),
              label: 'Goals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}