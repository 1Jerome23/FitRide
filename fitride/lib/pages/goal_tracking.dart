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

class _GoalTrackingPageState extends State<GoalTrackingPage> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  bool showQuestionnaire = false;
  bool showGoalList = false;
  String? selectedGoal;
  Map<String, dynamic> answers = {};
  List<Map<String, dynamic>> goals = [];
  int _currentPage = 0;
  int _selectedIndex = 2;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    
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

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
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
        if (goals.isNotEmpty) {
          _animationController.reset();
          _animationController.forward();
        }
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

      if (selectedGoal == "Cycling Endurance") {
        goalData.addAll({
          'targetDistance': double.parse(answers["What's your target cycling distance per session?"] ?? '0'),
          'frequency': answers["How often do you want to achieve this goal?"],
          'currentLevel': answers["What's your current cycling level?"],
          'progress': 0.0,
          'target': double.parse(answers["What's your target cycling distance per session?"] ?? '0'),
        });
      } else {
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
          goals.insert(0, goalData);
          showQuestionnaire = false;
          showGoalList = true;
          selectedGoal = null;
          answers.clear();
        });

        _animationController.reset();
        _animationController.forward();

      } catch (e) {
        print('Error saving goal: $e');
      }
    }
  }

  Widget _buildGoalCard(Map<String, dynamic> goal, {bool animate = false}) {
    double progress = goal['progress'] ?? 0.0;
    double target = goal['target'] ?? 0.0;
    String goalType = goal['goalType'] ?? '';
    String unit = goalType == 'Cycling Endurance' ? 'km' : 'kg';
    
    Widget card = Container(
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
                    _loadGoals();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress / target,
              backgroundColor: Colors.grey[300],
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
          ],
        ),
      ),
    );

    if (animate) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOut,
          )),
          child: card,
        ),
      );
    }

    return card;
  }

  Widget _buildGoalPage(Map<String, dynamic> goalType, bool isActive) {
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(isActive ? 0 : 0.1),
      alignment: isActive ? Alignment.center : Alignment.centerLeft,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isActive ? 1.0 : 0.7,
        child: GestureDetector(
          onTap: () {
            setState(() {
              selectedGoal = goalType['title'];
              showQuestionnaire = true;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
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
                  offset: const Offset(0, 4),
                ),
                if (!isActive) BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: -5,
                  offset: const Offset(-10, 0),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(
                      goalType['image'],
                      height: 200,
                      width: 200,
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
                      fontSize: 15,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Your Goals",
                        style: TextStyle(
                          fontFamily: 'Fredoka-SemiBold',
                          fontSize: 29,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Every ride is a step toward your best self. Stay on track! 🚴🔥",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ],

                  ), const SizedBox(height: 24),
                  ...goals.asMap().entries.map((entry) {
                    return _buildGoalCard(
                      entry.value,
                      animate: entry.key == 0,
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        showGoalList = false;
                        showQuestionnaire = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffFFA500),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Add New Goal",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              )
            : showQuestionnaire
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              setState(() {
                                showQuestionnaire = false;
                                answers.clear();
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedGoal ?? "",
                            style: const TextStyle(
                              fontFamily: 'Fredoka-SemiBold',
                              fontSize: 24,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (selectedGoal != null)
                        ...questions[selectedGoal]!.map((question) {
                          if (question['type'] == 'number') {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    question['question'],
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                TextFormField(
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontFamily: 'Inter',
                                  ),
                                  decoration: InputDecoration(
                                    hintText: question['hint'],
                                    hintStyle: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 15,
                                      fontFamily: 'Inter',
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[200],
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      answers[question['question']] = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    question['question'],
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Column(
                                  children: (question['options'] as List<String>).map((option) {
                                    bool isSelected = answers[question['question']] == option;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          answers[question['question']] = option;
                                        });
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: isSelected
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xffFFA500),
                                                    Color(0xffFFCC70),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: isSelected ? null : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          option,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: isSelected ? Colors.black : Colors.grey[700],
                                            fontFamily: 'Inter',
                                            fontSize: 16,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),

                                const SizedBox(height: 24),
                              ],
                            );
                          }
                        }).toList(),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saveGoal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffFFA500),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Save Goal",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      const SizedBox(height: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Text(
                            "Set Your Cycling Goals",
                            style: TextStyle(
                              fontFamily: 'Fredoka-Bold',
                              fontSize: 25,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Choose a goal and start making progress!",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: goalTypes.length,
                          itemBuilder: (context, index) {
                            return _buildGoalPage(
                              goalTypes[index],
                              index == _currentPage,
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: SmoothPageIndicator(
                          controller: _pageController,
                          count: goalTypes.length,
                          effect: const WormEffect(
                            dotHeight: 8,
                            dotWidth: 8,
                            spacing: 8,
                            dotColor: Colors.grey,
                            activeDotColor: Color(0xffFFA500),
                          ),
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