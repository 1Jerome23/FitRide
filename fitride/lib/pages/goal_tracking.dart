import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'recommendation.dart';
import 'profile.dart';
import 'login_register.dart';
import 'package:intl/intl.dart';
import 'question.dart';

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

  DateTime _weekStartDate = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  DateTime _weekEndDate = DateTime.now().add(Duration(days: 7 - DateTime.now().weekday));

  // FOR TESTING - change ito if gusto ma test kung gumagana yung dates
  //DateTime _weekStartDate = DateTime(2024, 1, 15); // Jan 15, 2024 year, month, day
  //DateTime _weekEndDate = DateTime(2024, 1, 21);   // Jan 21, 2024

  List<Map<String, dynamic>> _weeklyActivities = [];
  double _weeklyDaysProgress = 0;
  double _averageSessionDuration = 0;
  double _totalWeeklyDuration = 0; 
  double _totalWeeklyDistance = 0;
  Set<String> _uniqueDays = {};
  
  double _currentUserWeight = 0;
  double targetWeight = 0; 

  Map<String, dynamic>? _bestDistanceActivity;
  double _bestDistance = 0;
  DateTime? _bestDistanceDate;
  Map<String, dynamic>? _latestActivity;
  DateTime? _latestActivityDate;
  double _latestDistance = 0;

  static const Color primaryOrange = Color(0xFFFF8B3D);
  static const Color primaryBlack = Color(0xFF1A1A1A);
  static const Color primaryGray = Color(0xFF676767);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 500), () {
      _loadUserGoalAndActivities();
    });
    
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

  Future<void> _loadUserGoalAndActivities() async {
    setState(() {
      _isLoading = true;
    });

    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        print("Current user UID: $uid");

        // Query all goals for the current user and order by timestamp in descending order
        QuerySnapshot goalsSnapshot = await FirebaseFirestore.instance
            .collection('goals')
            .where('userId', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .get();

        print("Goals found: ${goalsSnapshot.docs.length}");

        if (goalsSnapshot.docs.isNotEmpty) {
          // Get the most recent goal (first document in the sorted list)
          DocumentSnapshot mostRecentGoalDoc = goalsSnapshot.docs.first;
          Map<String, dynamic>? goalData = mostRecentGoalDoc.data() as Map<String, dynamic>?;

          print("Most recent goal data: $goalData");
          if (goalData!['goalType'] == 'High Intensity Cycling') {
            try {
              final userDataDoc = await FirebaseFirestore.instance
                  .collection('userData')
                  .doc(uid)
                  .get();

              if (userDataDoc.exists) {
                final userData = userDataDoc.data();
                print("User data found: $userData");

                var weightValue = userData!['weight'];
                if (weightValue != null) {
                  if (weightValue is int) {
                    _currentUserWeight = weightValue.toDouble();
                  } else if (weightValue is double) {
                    _currentUserWeight = weightValue;
                  } else if (weightValue is String) {
                    _currentUserWeight = double.tryParse(weightValue) ?? 0.0;
                  }
                }
                print("Current user weight: $_currentUserWeight");
              } else {
                print("No userData document found for current weight");
              }
            } catch (e) {
              print("Error fetching user data: $e");
            }
          }

          final athleteQuerySnapshot = await FirebaseFirestore.instance
              .collection('athletes')
              .where('app_id', isEqualTo: uid)
              .limit(1)
              .get();

          bool hasActivity = false;
          _uniqueDays.clear();

          print("Athlete documents found: ${athleteQuerySnapshot.docs.length}");

          if (athleteQuerySnapshot.docs.isNotEmpty) {
            final athleteDoc = athleteQuerySnapshot.docs.first;
            final athleteId = athleteDoc.id;

            int? userIdNumber;

            userIdNumber = int.tryParse(athleteId);

            if (userIdNumber == null && athleteDoc.data().containsKey('user_id')) {
              userIdNumber = athleteDoc.data()['user_id'] as int?;
            }

            if (userIdNumber == null) {
              final numericPart = RegExp(r'(\d+)').firstMatch(athleteId)?.group(1);
              userIdNumber = numericPart != null ? int.tryParse(numericPart) : null;
            }

            print("Athlete Document ID: $athleteId");
            print("Converted User ID Number: $userIdNumber");

            if (userIdNumber != null) {
              final allActivitiesSnapshot = await FirebaseFirestore.instance
                  .collection('activities')
                  .where('user_id', isEqualTo: userIdNumber)
                  .get();

              print("Activities found: ${allActivitiesSnapshot.docs.length}");

              hasActivity = allActivitiesSnapshot.docs.isNotEmpty;

              if (hasActivity) {
                if (goalData['goalType'] == 'Endurance') {
                  print("Processing activities for Endurance goal");

                  _bestDistance = 0;
                  _bestDistanceDate = null;
                  _bestDistanceActivity = null;
                  _latestActivity = null;
                  _latestActivityDate = null;
                  _latestDistance = 0;

                  // Sort activities by date (newest first)
                  final sortedActivities = allActivitiesSnapshot.docs.map((doc) => doc.data()).toList()
                    ..sort((a, b) {
                      final dateA = (a['start_date'] as Timestamp).toDate();
                      final dateB = (b['start_date'] as Timestamp).toDate();
                      return dateB.compareTo(dateA); // Newest first
                    });

                  if (sortedActivities.isNotEmpty) {
                    _latestActivity = sortedActivities.first;
                    _latestActivityDate = (_latestActivity!['start_date'] as Timestamp).toDate();

                    var latestDistanceValue = _latestActivity!['distance'];
                    if (latestDistanceValue is int) {
                      _latestDistance = latestDistanceValue.toDouble();
                    } else if (latestDistanceValue is double) {
                      _latestDistance = latestDistanceValue;
                    } else if (latestDistanceValue is String) {
                      _latestDistance = double.tryParse(latestDistanceValue) ?? 0.0;
                    }

                    print("Latest activity date: ${_latestActivityDate}");
                    print("Latest distance: $_latestDistance");
                  }

                  for (final activityData in allActivitiesSnapshot.docs) {
                    final data = activityData.data();

                    double distance = 0.0;
                    if (data['distance'] != null) {
                      var distanceValue = data['distance'];
                      if (distanceValue is int) {
                        distance = distanceValue.toDouble();
                      } else if (distanceValue is double) {
                        distance = distanceValue;
                      } else if (distanceValue is String) {
                        distance = double.tryParse(distanceValue) ?? 0.0;
                      }
                    }

                    // If this activity has a better distance, save it as the best
                    if (distance > _bestDistance) {
                      _bestDistance = distance;
                      _bestDistanceDate = (data['start_date'] as Timestamp).toDate();
                      _bestDistanceActivity = data;
                      print("New best distance: $_bestDistance on ${_bestDistanceDate}");
                    }
                  }
                }

                final weeklyActivitiesSnapshot = await FirebaseFirestore.instance
                    .collection('activities')
                    .where('user_id', isEqualTo: userIdNumber)
                    .where('start_date', isGreaterThanOrEqualTo: Timestamp.fromDate(_weekStartDate))
                    .where('start_date', isLessThanOrEqualTo: Timestamp.fromDate(_weekEndDate))
                    .get();

                print("Weekly activities found: ${weeklyActivitiesSnapshot.docs.length}");

                double totalDuration = 0;
                double totalDistance = 0;

                _weeklyActivities = weeklyActivitiesSnapshot.docs.map((doc) {
                  final data = doc.data();

                  DateTime activityDate = (data['start_date'] as Timestamp).toDate();
                  String dayKey = DateFormat('yyyy-MM-dd').format(activityDate);
                  _uniqueDays.add(dayKey);

                  double duration = 0.0;
                  var timeValue = data['elapsed_time'];
                  if (timeValue is int) {
                    duration = timeValue.toDouble();
                  } else if (timeValue is double) {
                    duration = timeValue;
                  } else if (timeValue is String) {
                    duration = double.tryParse(timeValue) ?? 0.0;
                  }

                  duration = duration / 60.0;
                  totalDuration += duration;


                  if (data['distance'] != null) {
                    double distance = 0.0;
                    var distanceValue = data['distance'];
                    if (distanceValue is int) {
                      distance = distanceValue.toDouble();
                    } else if (distanceValue is double) {
                      distance = distanceValue;
                    } else if (distanceValue is String) {
                      distance = double.tryParse(distanceValue) ?? 0.0;
                    }
                    totalDistance += distance;
                  }

                  return data;
                }).toList();

                _weeklyDaysProgress = _uniqueDays.length.toDouble();
                _totalWeeklyDuration = totalDuration;
                _averageSessionDuration = _weeklyActivities.isEmpty ? 0 : totalDuration / _weeklyActivities.length;
                _totalWeeklyDistance = totalDistance;
              }
            }
          } else {
            print("No matching athlete found, but goal exists");
          }

          setState(() {
            userGoal = goalData;
            _hasActivityAfterGoal = hasActivity;
            _isLoading = false;
          });
        } else {
          print("No goal found in the goals collection");
          setState(() {
            userGoal = null;
            _hasActivityAfterGoal = false;
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading goal and activities: $e');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      print("No user is currently signed in");
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
        await FirebaseFirestore.instance //delete goal
            .collection('goals')
            .doc(uid)
            .delete();
            
        // Navigate directly to the goals page (index 2)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => QuestionPage(initialPage: 2)),
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

  String _getWeightHelperText(double targetWeight) {
    if (_currentUserWeight <= 0) {
      return "Update your current weight in your profile to track progress.";
    }
    
    if (_currentUserWeight > targetWeight) {
      double remaining = _currentUserWeight - targetWeight;
      return "You have ${remaining.toStringAsFixed(1)} kg left to reach your target weight.";
    } else {
      return "Congratulations! You've reached your target weight.";
    }
  }

  String _getDurationHelperText(double weeklyTarget) {
    if (_totalWeeklyDuration < weeklyTarget) {
      double remaining = weeklyTarget - _totalWeeklyDuration;
      return "You need ${remaining.round()} more minutes of cycling this week to reach your goal.";
    } else {
      return "Great job! You've reached your weekly cycling duration goal.";
    }
  }

  String _getEnduranceHelperText(double targetDistance) {
    if (_bestDistance <= 0) {
      return "Complete your first cycling activity to establish your baseline.";
    }
    
    String bestDateStr = _bestDistanceDate != null ? 
      DateFormat('MMM d, yyyy').format(_bestDistanceDate!) : "your first ride";
    
    if (_bestDistance < targetDistance) {
      double remaining = targetDistance - _bestDistance;
      String progressText = "Your best performance was ${_bestDistance.toStringAsFixed(1)} km on $bestDateStr.";
      
      if (_latestActivityDate != null && _latestActivityDate != _bestDistanceDate) {
        if (_latestDistance < _bestDistance) {
          String latestDateStr = DateFormat('MMM d, yyyy').format(_latestActivityDate!);
          progressText += " Your latest ride on $latestDateStr was ${_latestDistance.toStringAsFixed(1)} km. Keep training to beat your personal best!";
        }
      }
      
      return progressText + " You need ${remaining.toStringAsFixed(1)} more km to reach your target.";
    } else {
      return "Congratulations! You've reached your distance target of ${targetDistance.toStringAsFixed(1)} km on $bestDateStr.";
    }
  }

  double _getBestActivityDuration() {
    if (_bestDistanceActivity == null) return 0;
    
    double duration = 0.0;
    var timeValue = _bestDistanceActivity!['elapsed_time'];
    if (timeValue is int) {
      duration = timeValue.toDouble();
    } else if (timeValue is double) {
      duration = timeValue;
    } else if (timeValue is String) {
      duration = double.tryParse(timeValue) ?? 0.0;
    }
    
    // Convert from seconds to minutes
    return duration / 60.0;
  }
  
  String _getBestDurationHelperText(double targetDuration) {
    if (_bestDistanceActivity == null) return "";
    
    double bestDuration = _getBestActivityDuration();
    String bestDateStr = _bestDistanceDate != null ? 
      DateFormat('MMM d, yyyy').format(_bestDistanceDate!) : "your first ride";
    
    if (bestDuration > targetDuration) {
      return "Your best distance ride took longer than your target duration. Try to improve your speed while maintaining distance.";
    } else {
      return "Great job! You completed your best distance ride in ${bestDuration.toStringAsFixed(1)} minutes on $bestDateStr, which is within your target duration.";
    }
  }

  Widget _buildProgressCard(String title, double progress, double target, String unit, Color color, IconData icon, {String? helpText}) {
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
                  width: MediaQuery.of(context).size.width * percentage * 0.7,
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
            unit != "%" ? Row(
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
            ) : title == "Weight Progress" ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Current: ${_currentUserWeight.toStringAsFixed(1)} kg",
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: primaryGray,
                  ),
                ),
                Text(
                  "Target: ${targetWeight.toStringAsFixed(1)} kg",
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: primaryGray,
                  ),
                ),
              ],
            ) : Container(),
            if (helpText != null) ...[
              const SizedBox(height: 8),
              Text(
                helpText,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: primaryGray,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard() {
    if (userGoal == null) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              "No goal found. Please set up a goal first.",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                color: primaryGray,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                _loadUserGoalAndActivities();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Retry Loading Goal",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    if (!_hasActivityAfterGoal) {
      return _buildFirstActivityPrompt();
    }

    final goalType = userGoal!['goalType'] ?? '';
    final createdAt = userGoal!['timestamp'] != null 
        ? (userGoal!['timestamp'] as Timestamp).toDate()
        : DateTime.now();
    
    // Format week range for display
    final weekRangeStr = "${DateFormat('MMM d').format(_weekStartDate)} - ${DateFormat('MMM d').format(_weekEndDate)}";
    
    // Get target values from user goal - safely convert to double from any type
    double daysTarget = 7.0; // Default value
    double durationTarget = 30.0; // Default value
    
    // Parse daysPerWeek safely
    if (userGoal!.containsKey('daysPerWeek')) {
      var daysValue = userGoal!['daysPerWeek'];
      if (daysValue is int) {
        daysTarget = daysValue.toDouble();
      } else if (daysValue is double) {
        daysTarget = daysValue;
      } else if (daysValue is String) {
        daysTarget = double.tryParse(daysValue) ?? 7.0;
      }
      print("Days target parsed as: $daysTarget from ${userGoal!['daysPerWeek']}");
    }
    
    if (userGoal!.containsKey('sessionDuration')) {
      var durationValue = userGoal!['sessionDuration'];
      if (durationValue is int) {
        durationTarget = durationValue.toDouble();
      } else if (durationValue is double) {
        durationTarget = durationValue;
      } else if (durationValue is String) {
        durationTarget = double.tryParse(durationValue) ?? 30.0;
      }
      print("Duration target parsed as: $durationTarget from ${userGoal!['sessionDuration']}");
    }
    
    // For weight management
    if (goalType == 'High Intensity Cycling') {
      var targetWeightValue = userGoal!['targetWeight'];
      if (targetWeightValue is int) {
        targetWeight = targetWeightValue.toDouble();
      } else if (targetWeightValue is double) {
        targetWeight = targetWeightValue;
      } else if (targetWeightValue is String) {
        targetWeight = double.tryParse(targetWeightValue) ?? 0;
      }
      print("Target weight: $targetWeight, Current weight: $_currentUserWeight");
    }
    
    // For endurance
    double targetDistance = 0;
    if (goalType == 'Endurance') {
      var distanceValue = userGoal!['targetDistance'];
      if (distanceValue is int) {
        targetDistance = distanceValue.toDouble();
      } else if (distanceValue is double) {
        targetDistance = distanceValue;
      } else if (distanceValue is String) {
        targetDistance = double.tryParse(distanceValue) ?? 0;
      }
    }

    // Helper text based on progress
    String daysHelperText = '';
    if (_weeklyDaysProgress < daysTarget) {
      int remaining = (daysTarget - _weeklyDaysProgress).round();
      daysHelperText = "You need $remaining more day${remaining > 1 ? 's' : ''} this week to reach your goal.";
    } else {
      daysHelperText = "Great job! You've reached your weekly cycling goal.";
    }
    
    String durationHelperText = '';
    if (_averageSessionDuration < durationTarget) {
      double needed = durationTarget - _averageSessionDuration;
      durationHelperText = "Try to increase your session duration by about ${needed.round()} mins.";
    } else {
      durationHelperText = "Excellent! You're meeting your duration targets.";
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
              const SizedBox(height: 16),
              
              // Current Week Display based on goal type
              if (goalType != 'Endurance')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryOrange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.date_range,
                        size: 16,
                        color: primaryOrange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Current Week: $weekRangeStr",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: primaryBlack,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_bestDistanceDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryOrange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 16,
                        color: primaryOrange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Best Performance: ${DateFormat('MMM d, yyyy').format(_bestDistanceDate!)}",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: primaryBlack,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Progress metrics based on goal type
              if (goalType == 'Leisure') ...[
                _buildProgressCard(
                  "Weekly Cycling Days",
                  _weeklyDaysProgress,
                  daysTarget,
                  "days",
                  primaryOrange,
                  Icons.calendar_today_rounded,
                  helpText: daysHelperText,
                ),
                _buildProgressCard(
                  "Weekly Cycling Duration",
                  _totalWeeklyDuration,
                  durationTarget, // Total weekly target is the session duration
                  "mins",
                  Colors.blue,
                  Icons.timer,
                  helpText: _getDurationHelperText(durationTarget),
                ),
                // Weekly reset info
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
                        Icons.refresh_rounded,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Leisure goals reset every Monday. Your weekly target is the total duration you should cycle this week.",
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
              ] else if (goalType == 'High Intensity Cycling') ...[
                // Weight Progress Card
                _buildProgressCard(
                  "Weight Progress",
                  _currentUserWeight <= 0 ? 0 : targetWeight / _currentUserWeight * 100, // Invert the progress since we want to lose weight
                  100, // Target is 100% (reaching target weight)
                  "%",
                  primaryOrange,
                  Icons.monitor_weight_outlined,
                  helpText: _getWeightHelperText(targetWeight),
                ),
                _buildProgressCard(
                  "Weekly Cycling Days",
                  _weeklyDaysProgress,
                  daysTarget,
                  "days",
                  Colors.green,
                  Icons.calendar_today_rounded,
                  helpText: daysHelperText,
                ),
                _buildProgressCard(
                  "Weekly Cycling Duration",
                  _totalWeeklyDuration,
                  durationTarget, // Weekly target cycling duration
                  "mins",
                  Colors.blue,
                  Icons.timer,
                  helpText: _getDurationHelperText(durationTarget),
                ),
                // Information Card about High Intensity Goals
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.green.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "High intensity cycling helps burn more calories. Your daily target is to cycle with elevated heart rate to maximize weight loss results. Update your weight in your profile to track progress.",
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
              ] else if (goalType == 'Endurance') ...[
                // Best Distance Card
                _buildProgressCard(
                  "Best Distance",
                  _bestDistance,
                  targetDistance,
                  "km",
                  primaryOrange,
                  Icons.straighten_rounded,
                  helpText: _getEnduranceHelperText(targetDistance),
                ),
                
                // Best Duration Card
                if (_bestDistanceActivity != null) ...[
                  _buildProgressCard(
                    "Duration",
                    _getBestActivityDuration(),
                    durationTarget,
                    "mins",
                    Colors.blue,
                    Icons.timer,
                    helpText: _getBestDurationHelperText(durationTarget),
                  ),
                ],
                
                // Endurance Goals Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.purple.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.purple.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Endurance goals track your best performance. Each time you beat your distance record, your progress will update. Focus on gradually increasing your distance while maintaining a good pace.",
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
              
              const SizedBox(height: 16),
              
              // Weekly Activities Summary - only for non-endurance goals
              if (_weeklyActivities.isNotEmpty && goalType != 'Endurance') ...[
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
                      Row(
                        children: [
                          Icon(
                            Icons.directions_bike,
                            color: primaryOrange,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Week's Activities",
                            style: TextStyle(
                              fontFamily: 'Fredoka-SemiBold',
                              fontSize: 16,
                              color: primaryBlack,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        "You've completed ${_weeklyActivities.length} cycling ${_weeklyActivities.length == 1 ? 'activity' : 'activities'} this week.",
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
              
              // Latest activity summary for endurance goals
              if (goalType == 'Endurance' && _latestActivityDate != null && _latestActivityDate != _bestDistanceDate) ...[
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
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: primaryOrange,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Latest Activity",
                            style: TextStyle(
                              fontFamily: 'Fredoka-SemiBold',
                              fontSize: 16,
                              color: primaryBlack,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        "Your latest activity on ${DateFormat('MMM d, yyyy').format(_latestActivityDate!)} was ${_latestDistance.toStringAsFixed(1)} km.",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: primaryGray,
                        ),
                      ),
                      _latestDistance < _bestDistance 
                        ? Text(
                            "Keep pushing! You're ${(_bestDistance - _latestDistance).toStringAsFixed(1)} km away from your personal best.",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: primaryOrange,
                            ),
                          )
                        : Container(),
                    ],
                  ),
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
                                    // Navigate directly to the goals page (index 2)
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (context) => QuestionPage(initialPage: 2)),
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