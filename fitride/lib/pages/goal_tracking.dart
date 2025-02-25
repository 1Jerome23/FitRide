import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'recommendation.dart';
import 'profile.dart';
import 'login_register.dart';
import 'package:intl/intl.dart';

class GoalTrackingPage extends StatefulWidget {
  const GoalTrackingPage({super.key});

  @override
  _GoalTrackingPageState createState() => _GoalTrackingPageState();
}

class _GoalTrackingPageState extends State<GoalTrackingPage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 2;
  Map<String, dynamic>? userGoal;
  bool _isLoading = true;
  bool _hasActivityAfterGoal = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const Color primaryOrange = Color(0xFFFF8B3D);
  static const Color primaryBlack = Color(0xFF1A1A1A);
  static const Color primaryGray = Color(0xFF676767);

  @override
  void initState() {
    super.initState();
    _loadUserGoal();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
        // Current page
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

  Future<void> _loadUserGoal() async {
    setState(() {
      _isLoading = true;
    });
    
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        // 1. Get the goal data
        final goalDoc = await FirebaseFirestore.instance
            .collection('goals')
            .doc(uid)
            .get();
            
        if (goalDoc.exists) {
          final goalData = goalDoc.data();
          
          // Query athletes collection
          final athleteQuerySnapshot = await FirebaseFirestore.instance
              .collection('athletes')
              .where('app_id', isEqualTo: uid)
              .limit(1)
              .get();
          
          bool hasActivity = false;
          
          if (athleteQuerySnapshot.docs.isNotEmpty) {
            final athleteDoc = athleteQuerySnapshot.docs.first;
            final athleteId = athleteDoc.id;
            
            // Important: Convert the document ID to a number if that's what user_id expects
            final userIdNumber = int.tryParse(athleteId);
            
            print("Athlete Document ID: $athleteId");
            print("Converted User ID Number: $userIdNumber");
            
            if (userIdNumber != null) {
              // Query activities using the number
              final activitiesSnapshot = await FirebaseFirestore.instance
                  .collection('activities')
                  .where('user_id', isEqualTo: userIdNumber)
                  .get();
              
              // Check if any activities were found
              hasActivity = activitiesSnapshot.docs.isNotEmpty;
              
              print("Activities found: $hasActivity");
              if (hasActivity) {
                activitiesSnapshot.docs.forEach((doc) {
                  print("Activity Document: ${doc.id}");
                  print("Activity Data: ${doc.data()}");
                });
              }
            } else {
              print("Could not convert athlete ID to number");
            }
          } else {
            print("No matching athlete found");
          }
          
          setState(() {
            userGoal = goalData;
            _hasActivityAfterGoal = hasActivity;
            _isLoading = false;
          });
        } else {
          setState(() {
            userGoal = null;
            _hasActivityAfterGoal = false;
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading goal: $e');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showChangeGoalConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Change Your Goal?",
            style: TextStyle(
              fontFamily: 'Fredoka-SemiBold',
              fontSize: 22,
              color: primaryBlack,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Are you sure you want to change your current goal?",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: primaryBlack,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Your current progress will be reset, and you'll need to set up a new goal.",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: primaryGray,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetUserGoal();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                "Change Goal",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetUserGoal() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        // Delete current goal
        await FirebaseFirestore.instance
            .collection('goals')
            .doc(uid)
            .delete();
            
        // Navigate to question page to set a new goal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()), // Replace with your question/onboarding page
        );
      } catch (e) {
        print('Error resetting goal: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reset goal. Please try again.'))
        );
      }
    }
  }

  String _getIconForGoalType(String goalType) {
    switch (goalType) {
      case 'Leisure':
        return 'assets/leisure.png';
      case 'High Intensity Cycling':
        return 'assets/weight_loss.png';
      case 'Endurance':
        return 'assets/endurance.png';
      default:
        return 'assets/leisure.png';
    }
  }
  
  Widget _buildFirstActivityPrompt() {
    final goalType = userGoal!['goalType'] ?? 'Cycling';
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: primaryOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.directions_bike_rounded,
                    size: 50,
                    color: primaryOrange,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Start Your $goalType Journey",
                style: const TextStyle(
                  fontFamily: 'Fredoka-SemiBold',
                  fontSize: 22,
                  color: primaryBlack,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "Complete your first cycling activity to establish a baseline for your $goalType goal. This will help us track your progress and provide personalized recommendations.",
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: primaryGray,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Log your cycling activity using Strava. Your progress will automatically update after your first ride.",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(String title, double progress, double target, String unit, Color color, IconData icon) {
    final percentage = (progress / target).clamp(0.0, 1.0);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Fredoka-SemiBold',
                      fontSize: 16,
                      color: primaryBlack,
                    ),
                  ),
                ),
                Text(
                  "${(percentage * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Container(
                  height: 8,
                  width: MediaQuery.of(context).size.width * percentage * 0.7, // Adjusted for padding
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Current: ${progress.toStringAsFixed(1)} $unit",
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: primaryGray,
                  ),
                ),
                Text(
                  "Target: ${target.toStringAsFixed(1)} $unit",
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: primaryGray,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard() {
    if (userGoal == null) {
      return const Center(
        child: Text(
          "No goal found. Please set up a goal first.",
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            color: primaryGray,
          ),
        ),
      );
    }
    
    // Check if there are no activities after the goal was created
    if (!_hasActivityAfterGoal) {
      return _buildFirstActivityPrompt();
    }

    final goalType = userGoal!['goalType'] ?? '';
    final createdAt = userGoal!['timestamp'] != null 
        ? (userGoal!['timestamp'] as Timestamp).toDate()
        : DateTime.now();
    
    // Progress data
    double daysProgress = 0;
    double daysTarget = userGoal!['daysPerWeek']?.toDouble() ?? 7.0;
    
    double durationProgress = 0;
    double durationTarget = userGoal!['sessionDuration']?.toDouble() ?? 30.0;
    
    // For weight management
    double? currentWeight;
    double? targetWeight;
    if (goalType == 'High Intensity Cycling') {
      currentWeight = double.tryParse(userGoal!['weight'] ?? '0') ?? 0;
      targetWeight = double.tryParse(userGoal!['targetWeight'] ?? '0') ?? 0;
    }
    
    // For endurance
    double? currentDistance;
    double? targetDistance;
    if (goalType == 'Endurance') {
      targetDistance = double.tryParse(userGoal!['targetDistance'] ?? '0') ?? 0;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryOrange.withOpacity(0.2),
              primaryOrange.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primaryOrange.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Image.asset(
                        _getIconForGoalType(goalType),
                      ),
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
                            color: primaryBlack,
                          ),
                        ),
                        Text(
                          "Started on ${DateFormat('MMM d, yyyy').format(createdAt)}",
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: primaryGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Progress metrics based on goal type
              if (goalType == 'Leisure') ...[
                _buildProgressCard(
                  "Weekly Cycling Days",
                  daysProgress,
                  daysTarget,
                  "days",
                  primaryOrange,
                  Icons.calendar_today_rounded,
                ),
                _buildProgressCard(
                  "Session Duration",
                  durationProgress,
                  durationTarget,
                  "mins",
                  Colors.blue,
                  Icons.timer,
                ),
              ] else if (goalType == 'High Intensity Cycling') ...[
                _buildProgressCard(
                  "Weight Progress",
                  currentWeight ?? 0,
                  targetWeight ?? 0,
                  "kg",
                  primaryOrange,
                  Icons.monitor_weight_outlined,
                ),
                _buildProgressCard(
                  "Weekly Cycling Days",
                  daysProgress,
                  daysTarget,
                  "days",
                  Colors.green,
                  Icons.calendar_today_rounded,
                ),
                _buildProgressCard(
                  "Session Duration",
                  durationProgress,
                  durationTarget,
                  "mins",
                  Colors.blue,
                  Icons.timer,
                ),
              ] else if (goalType == 'Endurance') ...[
                _buildProgressCard(
                  "Distance Target",
                  currentDistance ?? 0,
                  targetDistance ?? 0,
                  "km",
                  primaryOrange,
                  Icons.straighten_rounded,
                ),
                _buildProgressCard(
                  "Session Duration",
                  durationProgress,
                  durationTarget,
                  "mins",
                  Colors.blue,
                  Icons.timer,
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Tips based on goal type
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: primaryOrange,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Cycling Tips",
                          style: TextStyle(
                            fontFamily: 'Fredoka-SemiBold',
                            fontSize: 16,
                            color: primaryBlack,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (goalType == 'Leisure')
                      const Text(
                        "Try to maintain a consistent cycling schedule. Even short rides can be beneficial for your health and enjoyment!",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: primaryGray,
                        ),
                      )
                    else if (goalType == 'High Intensity Cycling')
                      const Text(
                        "For maximum calorie burn, incorporate interval training into your rides. Alternate between high intensity sprints and recovery periods.",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: primaryGray,
                        ),
                      )
                    else
                      const Text(
                        "Gradually increase your distance over time. Focus on proper nutrition and recovery to build endurance.",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: primaryGray,
                        ),
                      ),
                  ],
                ),
              ),
            ],
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
            fontSize: 22,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: _logout,
              child: Image.asset(
                'assets/logobike.png',
                height: 25,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading 
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryOrange),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Goal Tracking",
                    style: TextStyle(
                      fontFamily: 'Fredoka-SemiBold',
                      fontSize: 28,
                      color: primaryBlack,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Track your cycling progress and stay motivated to achieve your fitness goals!",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      color: primaryGray,
                    ),
                  ),
                  userGoal == null
                      ? Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 50),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.track_changes_rounded,
                                  size: 70,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  "No goal found",
                                  style: TextStyle(
                                    fontFamily: 'Fredoka-SemiBold',
                                    fontSize: 20,
                                    color: primaryBlack,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  "Set up your cycling goal to start tracking your progress",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    color: primaryGray,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () {
                                    // Navigate to goal setting page
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (context) => HomePage()), // Replace with your goal setting page
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryOrange,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    "Set Up Goal",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : !_hasActivityAfterGoal
                          ? _buildFirstActivityPrompt()
                          : _buildGoalCard(),
                  
                  if (userGoal != null && _hasActivityAfterGoal) ...[
                    const SizedBox(height: 20),
                  ],
                  
                  if (userGoal != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _showChangeGoalConfirmation,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: primaryOrange),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Change Goal",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: primaryOrange,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.grey[900],
            currentIndex: _selectedIndex,
            selectedItemColor: Color(0xffFFA500),
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              fontFamily: "Inter",
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 12,
              fontFamily: "Inter",
            ),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
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
      ),
    );
  }
}