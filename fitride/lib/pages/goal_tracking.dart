import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'recommendation.dart';
import 'profile.dart';
import 'login_register.dart';
import 'package:intl/intl.dart';
import 'question.dart';
import 'dart:math';
import 'package:confetti/confetti.dart';

class GoalTrackingPage extends StatefulWidget {
  const GoalTrackingPage({super.key});

  @override
  _GoalTrackingPageState createState() => _GoalTrackingPageState();
}

class _GoalTrackingPageState extends State<GoalTrackingPage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 2;
  Map<String, dynamic>? userGoal;
  bool _isLoading = true;
  bool _hasActivityAfterGoal = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late ConfettiController _confettiController;
  bool _hasShownCompletionDialog = false;

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
  bool hasActiveSubgoal = false;
  String subgoalType = ""; // "distance", "pace", "duration", or "maintain"
  double subgoalTargetValue = 0.0;
  DateTime subgoalStartDate = DateTime.now();
  DateTime subgoalEndDate = DateTime.now().add(Duration(days: 7));
  List<String> subgoalSuggestions = [];
  List<String> subgoalWarnings = [];

  // Baseline values for comparisons
  double baselineDistance = 0.0;
  double baselinePace = 0.0;
  double baselineDuration = 0.0;

  TextEditingController _updateWeightController = TextEditingController();
  TextEditingController _updateBodyFatController = TextEditingController();
  TextEditingController _updateMetabolicRateController =
      TextEditingController();

  static const Color primaryOrange = Color(0xFFFF8B3D);
  static const Color primaryBlack = Color(0xFF1A1A1A);
  static const Color primaryGray = Color(0xFF676767);
  late DateTime _weekStartDate;
  late DateTime _weekEndDate;
  // Method to fetch active subgoal when loading the page
  Future<void> _fetchActiveSubgoal() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      QuerySnapshot subgoalQuery = await FirebaseFirestore.instance
          .collection('cycling_subgoals')
          .where('userId', isEqualTo: uid)
          .where('endDate', isGreaterThan: DateTime.now())
          .orderBy('endDate', descending: false)
          .limit(1)
          .get();

      if (subgoalQuery.docs.isNotEmpty) {
        DocumentSnapshot subgoalDoc = subgoalQuery.docs.first;
        var data = subgoalDoc.data() as Map<String, dynamic>;

        setState(() {
          hasActiveSubgoal = true;
          subgoalType = data['subgoalType'];
          subgoalTargetValue = data['targetValue'];
          subgoalStartDate = data['startDate'].toDate();
          subgoalEndDate = data['endDate'].toDate();

          // Load stored suggestions and warnings
          if (data.containsKey('suggestions')) {
            subgoalSuggestions = List<String>.from(data['suggestions']);
          }

          if (data.containsKey('warnings')) {
            subgoalWarnings = List<String>.from(data['warnings']);
          }

          // Load baseline values if available
          if (data.containsKey('baselineDistance')) {
            baselineDistance = data['baselineDistance'];
          }
          if (data.containsKey('baselinePace')) {
            baselinePace = data['baselinePace'];
          }
          if (data.containsKey('baselineDuration')) {
            baselineDuration = data['baselineDuration'];
          }
        });
        print("Active subgoal found and loaded: $subgoalType");
      } else {
        setState(() {
          hasActiveSubgoal = false;
        });
        print("No active subgoal found");
      }
    } catch (e) {
      print("Error fetching active subgoal: $e");
    }
  }
  DateTime _goalCreationDate = DateTime.now();

  DateTime _getWeekStartDate() {
    DateTime now = DateTime.now();
    
    int daysSinceCreation = now.difference(_goalCreationDate).inDays;
    
    int weekNumber = daysSinceCreation ~/ 7;
    
    return DateTime(
      _goalCreationDate.year,
      _goalCreationDate.month,
      _goalCreationDate.day + (weekNumber * 7),
      0, 0, 0, 0
    );
  }

  DateTime _getWeekEndDate() {
    return _getWeekStartDate().add(Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
  }

  @override
  void initState() {
    super.initState();

    _weekStartDate = DateTime.now();
    _weekEndDate = DateTime.now().add(Duration(days: 7));
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 5));

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserGoalAndActivities();

    Future.delayed(Duration(milliseconds: 1500), () {
      if (userGoal != null) {
        if (userGoal!['goalType'] == 'Endurance') {
          _checkEnduranceGoalCompletion();
        } else if (userGoal!['goalType'] == 'High Intensity Cycling') {
          _checkHighIntensityCyclingGoalCompletion();
        }
      }
    });
  }

  @override
  void didUpdateWidget(GoalTrackingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    Future.delayed(Duration(milliseconds: 1000), () {
      if (userGoal != null) {
        if (userGoal!['goalType'] == 'Endurance') {
          _checkEnduranceGoalCompletion();
        } else if (userGoal!['goalType'] == 'High Intensity Cycling') {
          _checkHighIntensityCyclingGoalCompletion();
        }
      }
    });
  }

  @override
  void dispose() {
    _updateWeightController.dispose();
    _updateBodyFatController.dispose();
    _animationController.dispose();
    _confettiController.dispose();
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

  Future<void> _loadUserGoalAndActivities() async {
    setState(() {
      _isLoading = true;
    });

    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        print("Current user UID: $uid");

        QuerySnapshot goalsSnapshot = await FirebaseFirestore.instance
            .collection('goals')
            .where('uid', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .get();

        print("Goals found: ${goalsSnapshot.docs.length}");

        if (goalsSnapshot.docs.isNotEmpty) {
          DocumentSnapshot mostRecentGoalDoc = goalsSnapshot.docs.first;
          Map<String, dynamic>? goalData =
              mostRecentGoalDoc.data() as Map<String, dynamic>?;

          print("Most recent goal data: $goalData");

        Timestamp goalCreationTimestamp = goalData!['timestamp'] as Timestamp;
        _goalCreationDate = goalCreationTimestamp.toDate();
        
        _weekStartDate = _getWeekStartDate();
        _weekEndDate = _getWeekEndDate();

          if (goalData!['goalType'] == 'High Intensity Cycling') {
            try {
              final userDataQuery = await FirebaseFirestore.instance
                  .collection('userData')
                  .where('uid', isEqualTo: uid)
                  .orderBy('timestamp', descending: true)
                  .limit(1)
                  .get();

              if (!goalData.containsKey('initialWeight')) {
                await FirebaseFirestore.instance
                    .collection('goals')
                    .doc(mostRecentGoalDoc.id)
                    .update({'initialWeight': _currentUserWeight});

                goalData['initialWeight'] = _currentUserWeight;
              }

              if (userDataQuery.docs.isNotEmpty) {
                final userData = userDataQuery.docs.first.data();
                print("Latest user data found: $userData");

                var weightValue = userData['weight'];
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

            if (userIdNumber == null &&
                athleteDoc.data().containsKey('user_id')) {
              userIdNumber = athleteDoc.data()['user_id'] as int?;
            }

            if (userIdNumber == null) {
              final numericPart =
                  RegExp(r'(\d+)').firstMatch(athleteId)?.group(1);
              userIdNumber =
                  numericPart != null ? int.tryParse(numericPart) : null;
            }

            print("Athlete Document ID: $athleteId");
            print("Converted User ID Number: $userIdNumber");

            if (userIdNumber != null) {
              final goalCreationTimestamp = goalData['timestamp'] as Timestamp;

              final allActivitiesSnapshot = await FirebaseFirestore.instance
                  .collection('activities')
                  .where('user_id', isEqualTo: userIdNumber)
                  .where('start_date', isGreaterThan: goalCreationTimestamp)
                  .get();

              print(
                  "Activities found after goal creation: ${allActivitiesSnapshot.docs.length}");

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

                  final sortedActivities = allActivitiesSnapshot.docs
                      .map((doc) => doc.data())
                      .toList()
                    ..sort((a, b) {
                      final dateA = (a['start_date'] as Timestamp).toDate();
                      final dateB = (b['start_date'] as Timestamp).toDate();
                      return dateB.compareTo(dateA);
                    });

                  if (sortedActivities.isNotEmpty) {
                    _latestActivity = sortedActivities.first;
                    _latestActivityDate =
                        (_latestActivity!['start_date'] as Timestamp).toDate();

                    var latestDistanceValue = _latestActivity!['distance'];
                    if (latestDistanceValue is int) {
                      _latestDistance = latestDistanceValue.toDouble();
                    } else if (latestDistanceValue is double) {
                      _latestDistance = latestDistanceValue;
                    } else if (latestDistanceValue is String) {
                      _latestDistance =
                          double.tryParse(latestDistanceValue) ?? 0.0;
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

                    if (distance > _bestDistance) {
                      _bestDistance = distance;
                      _bestDistanceDate =
                          (data['start_date'] as Timestamp).toDate();
                      _bestDistanceActivity = data;
                      print(
                          "New best distance: $_bestDistance on ${_bestDistanceDate}");
                    }
                  }
                }

                final weeklyActivitiesSnapshot = await FirebaseFirestore
                    .instance
                    .collection('activities')
                    .where('user_id', isEqualTo: userIdNumber)
                    .where('start_date',
                        isGreaterThanOrEqualTo:
                            Timestamp.fromDate(_weekStartDate))
                    .where('start_date',
                        isLessThanOrEqualTo: Timestamp.fromDate(_weekEndDate))
                    .get();

                print(
                    "Weekly activities found: ${weeklyActivitiesSnapshot.docs.length}");

                double totalDuration = 0;
                double totalDistance = 0;

                _weeklyActivities = weeklyActivitiesSnapshot.docs.map((doc) {
                  final data = doc.data();

                  DateTime activityDate =
                      (data['start_date'] as Timestamp).toDate();
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
                _averageSessionDuration = _weeklyActivities.isEmpty
                    ? 0
                    : totalDuration / _weeklyActivities.length;
                _totalWeeklyDistance = totalDistance;
                _checkEnduranceGoalCompletion();
              }
            }
          } else {
            print("No matching athlete found, but goal exists");
          }
          if (userGoal != null &&
              userGoal!['goalType'] == 'High Intensity Cycling') {
            await _fetchActiveSubgoal();
          }
          setState(() {
            userGoal = goalData;
            _hasActivityAfterGoal = hasActivity;
            _isLoading = false;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (userGoal != null) {
                if (userGoal!['goalType'] == 'Endurance') {
                  _checkEnduranceGoalCompletion();
                } else if (userGoal!['goalType'] == 'High Intensity Cycling') {
                  _checkHighIntensityCyclingGoalCompletion();
                }
              }
            });
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

  Widget _buildActiveSubgoalCard() {
    if (!hasActiveSubgoal) return SizedBox.shrink();

    // Calculate days remaining
    int daysRemaining = subgoalEndDate.difference(DateTime.now()).inDays;
    if (daysRemaining < 0) daysRemaining = 0;

    // Calculate progress based on weekly averages and current activity data
    double progressPercent = 0.0;
    String currentValueText = "";
    String targetValueText = "";
    String baselineValueText = "";

    // Calculate current week's performance metrics
    double currentWeekAvgDistance = 0.0;
    double currentWeekAvgPace = 0.0;
    double currentWeekAvgDuration = 0.0;

    if (_weeklyActivities.isNotEmpty) {
      double totalDistance = 0.0;
      double totalDuration = 0.0;
      List<double> paces = [];

      for (var activity in _weeklyActivities) {
        // Get distance
        double distance = 0.0;
        if (activity['distance'] != null) {
          var distanceValue = activity['distance'];
          if (distanceValue is int) {
            distance = distanceValue.toDouble();
          } else if (distanceValue is double) {
            distance = distanceValue;
          } else if (distanceValue is String) {
            distance = double.tryParse(distanceValue) ?? 0.0;
          }
        }
        totalDistance += distance;

        // Get duration in minutes
        double duration = 0.0;
        if (activity['elapsed_time'] != null) {
          var timeValue = activity['elapsed_time'];
          if (timeValue is int) {
            duration = timeValue.toDouble() / 60.0;
          } else if (timeValue is double) {
            duration = timeValue / 60.0;
          } else if (timeValue is String) {
            duration = (double.tryParse(timeValue) ?? 0.0) / 60.0;
          }
        }
        totalDuration += duration;

        // Calculate pace (minutes per km)
        if (distance > 0 && duration > 0) {
          double pace = duration / distance;
          paces.add(pace);
        }
      }

      // Calculate averages
      if (_weeklyActivities.isNotEmpty) {
        currentWeekAvgDistance = totalDistance / _weeklyActivities.length;
        currentWeekAvgDuration = totalDuration / _weeklyActivities.length;

        if (paces.isNotEmpty) {
          currentWeekAvgPace = paces.reduce((a, b) => a + b) / paces.length;
        }
      }
    }

    // Calculate progress based on subgoal type
    switch (subgoalType) {
      case "distance":
        // Calculate progress using weekly averages
        if (baselineDistance > 0 && subgoalTargetValue > baselineDistance) {
          progressPercent = (currentWeekAvgDistance - baselineDistance) /
              (subgoalTargetValue - baselineDistance);

          if (progressPercent < 0) progressPercent = 0;
          if (progressPercent > 1) progressPercent = 1;
        } else {
          progressPercent = currentWeekAvgDistance > 0 ? 0.5 : 0.0;
        }

        currentValueText = "${currentWeekAvgDistance.toStringAsFixed(1)} km";
        baselineValueText = "${baselineDistance.toStringAsFixed(1)} km";
        targetValueText = "${subgoalTargetValue.toStringAsFixed(1)} km";
        break;

      case "pace":
        if (baselinePace > 0 && baselinePace > subgoalTargetValue) {
          progressPercent = (baselinePace - currentWeekAvgPace) /
              (baselinePace - subgoalTargetValue);

          if (progressPercent < 0) progressPercent = 0;
          if (progressPercent > 1) progressPercent = 1;
        } else {
          progressPercent = currentWeekAvgPace > 0 ? 0.5 : 0.0;
        }

        currentValueText = "${currentWeekAvgPace.toStringAsFixed(1)} min/km";
        baselineValueText = "${baselinePace.toStringAsFixed(1)} min/km";
        targetValueText = "${subgoalTargetValue.toStringAsFixed(1)} min/km";
        break;

      case "duration":
        if (baselineDuration > 0 && subgoalTargetValue > baselineDuration) {
          progressPercent = (currentWeekAvgDuration - baselineDuration) /
              (subgoalTargetValue - baselineDuration);

          if (progressPercent < 0) progressPercent = 0;
          if (progressPercent > 1) progressPercent = 1;
        } else {
          progressPercent = currentWeekAvgDuration > 0 ? 0.5 : 0.0;
        }

        currentValueText = "${currentWeekAvgDuration.toStringAsFixed(0)} min";
        baselineValueText = "${baselineDuration.toStringAsFixed(0)} min";
        targetValueText = "${subgoalTargetValue.toStringAsFixed(0)} min";
        break;

      case "maintain":
        progressPercent = 0.75;

        currentValueText = "Maintaining consistent performance";
        baselineValueText = "";
        targetValueText = "";
        break;
    }

    // Get goal title
    String goalTitle = "";

    switch (subgoalType) {
      case "distance":
        goalTitle =
            "Increase weekly average distance to ${subgoalTargetValue.toStringAsFixed(1)} km";
        break;
      case "pace":
        goalTitle =
            "Improve weekly average pace to ${subgoalTargetValue.toStringAsFixed(1)} min/km";
        break;
      case "duration":
        goalTitle =
            "Extend weekly average duration to ${subgoalTargetValue.toStringAsFixed(0)} minutes";
        break;
      case "maintain":
        goalTitle = "Maintain current cycling performance";
        break;
    }

    Color progressColor =
        progressPercent >= 1.0 ? Colors.green[500]! : Colors.orange[500]!;

    return Container(
      margin: EdgeInsets.only(top: 20, bottom: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "This Week's Cycling Goal",
                style: TextStyle(
                  fontFamily: 'Fredoka-SemiBold',
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange[300]!, width: 1),
                ),
                child: Text(
                  "$daysRemaining days left",
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          Text(
            goalTitle,
            style: TextStyle(
              fontFamily: 'Lato',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          SizedBox(height: 16),

          // Progress visualization with baseline included
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subgoalType != "maintain") ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Last Week's Avg: $baselineValueText",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      "Target Avg: $targetValueText",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Current Avg: $currentValueText",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ],
                ),
                SizedBox(height: 8),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentValueText,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ],
                ),
                SizedBox(height: 8),
              ],
              Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    height: 8,
                    width: MediaQuery.of(context).size.width * progressPercent,
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                subgoalType == "maintain"
                    ? "Maintaining consistent performance"
                    : "${(progressPercent * 100).toInt()}% of goal achieved",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          Divider(),

          Text(
            "Action Plan:",
            style: TextStyle(
              fontFamily: 'Lato',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          SizedBox(height: 8),

          // Suggestions list
          Column(
            children: subgoalSuggestions
                .map((suggestion) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 16, color: Colors.green[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),

          // Warnings if available
          if (subgoalWarnings.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              "Important Notes:",
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Column(
              children: subgoalWarnings
                  .map((warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_outlined,
                                size: 16, color: Colors.orange[700]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                warning,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[800]),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _checkEnduranceGoalCompletion() {
    print("⭐ Checking endurance goal completion...");

    if (userGoal == null) {
      print("No user goal found");
      return;
    }

    if (userGoal!['goalType'] != 'Endurance') {
      print("Not an endurance goal: ${userGoal!['goalType']}");
      return;
    }

    if (_hasShownCompletionDialog) {
      print("Dialog already shown this session");
      return;
    }

    double targetDistance = 0;
    var distanceValue = userGoal!['targetDistance'];
    if (distanceValue is int) {
      targetDistance = distanceValue.toDouble();
    } else if (distanceValue is double) {
      targetDistance = distanceValue;
    } else if (distanceValue is String) {
      targetDistance = double.tryParse(distanceValue) ?? 0;
    }

    double targetDuration = 0;
    if (userGoal!.containsKey('sessionDuration')) {
      var durationValue = userGoal!['sessionDuration'];
      if (durationValue is int) {
        targetDuration = durationValue.toDouble();
      } else if (durationValue is double) {
        targetDuration = durationValue;
      } else if (durationValue is String) {
        targetDuration = double.tryParse(durationValue) ?? 0.0;
      }
    }

    bool isDistanceComplete = _bestDistance >= targetDistance;
    bool isDurationComplete = _bestDistanceActivity != null &&
        _getBestActivityDuration() >= targetDuration;

    print("Goal completion status:");
    print(
        "⭐ Best distance: $_bestDistance, Target: $targetDistance, Complete: $isDistanceComplete");
    print(
        "⭐ Best duration: ${_getBestActivityDuration()}, Target: $targetDuration, Complete: $isDurationComplete");

    if (isDistanceComplete && isDurationComplete) {
      print("⭐⭐⭐ GOAL COMPLETED! Showing celebration dialog!");
      _hasShownCompletionDialog = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGoalCompletionDialog();
      });
    } else {
      print("Not all conditions are met for goal completion");
    }
  }

  void _checkHighIntensityCyclingGoalCompletion() {
    print("⭐ Checking high intensity cycling goal completion...");

    if (userGoal == null) {
      print("No user goal found");
      return;
    }

    if (userGoal!['goalType'] != 'High Intensity Cycling') {
      print("Not a high intensity cycling goal: ${userGoal!['goalType']}");
      return;
    }

    if (_hasShownCompletionDialog) {
      print("Dialog already shown this session");
      return;
    }

    double targetWeight = 0;
    var targetWeightValue = userGoal!['targetWeight'];
    if (targetWeightValue is int) {
      targetWeight = targetWeightValue.toDouble();
    } else if (targetWeightValue is double) {
      targetWeight = targetWeightValue;
    } else if (targetWeightValue is String) {
      targetWeight = double.tryParse(targetWeightValue) ?? 0;
    }

    bool isWeightGoalComplete =
        _currentUserWeight > 0 && _currentUserWeight <= targetWeight;

    print("Weight goal completion status:");
    print(
        "⭐ Current weight: $_currentUserWeight, Target: $targetWeight, Complete: $isWeightGoalComplete");

    if (isWeightGoalComplete) {
      print("⭐⭐⭐ WEIGHT GOAL COMPLETED! Showing celebration dialog!");
      _hasShownCompletionDialog = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWeightGoalCompletionDialog();
      });
    } else {
      print("Weight goal not yet achieved");
    }
  }

  void _showWeightGoalCompletionDialog() {
    if (!mounted) {
      print("Widget not mounted, can't show dialog");
      return;
    }

    try {
      _confettiController.play();

      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        transitionDuration: Duration(milliseconds: 300),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.elasticOut,
              ),
            ),
            child: child,
          );
        },
        pageBuilder: (BuildContext context, Animation animation,
            Animation secondaryAnimation) {
          return Material(
            type: MaterialType.transparency,
            child: Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConfettiWidget(
                          confettiController: _confettiController,
                          blastDirectionality: BlastDirectionality.explosive,
                          particleDrag: 0.05,
                          emissionFrequency: 0.05,
                          numberOfParticles: 20,
                          gravity: 0.2,
                          shouldLoop: false,
                          colors: const [
                            Colors.green,
                            Colors.blue,
                            Colors.pink,
                            Colors.orange,
                            Colors.purple,
                            Colors.yellow,
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 30),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green, Colors.teal],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/trophy.png',
                                  width: 100,
                                  height: 100,
                                ),
                                SizedBox(height: 16),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        "TARGET WEIGHT ACHIEVED!",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'Fredoka-SemiBold',
                                          fontSize: 28,
                                          color: Colors.yellow,
                                          letterSpacing: 1.2,
                                          shadows: [
                                            Shadow(
                                              offset: Offset(2, 2),
                                              blurRadius: 4.0,
                                              color:
                                                  Colors.black.withOpacity(0.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Congratulations on your weight loss success!",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "Your Weight Loss Journey",
                                    style: TextStyle(
                                      fontFamily: 'Fredoka-SemiBold',
                                      fontSize: 20,
                                      color: primaryBlack,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Weight Goal Achieved!",
                                          style: TextStyle(
                                            fontFamily: 'Fredoka-SemiBold',
                                            fontSize: 16,
                                            color: primaryBlack,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "Current Weight: ${_currentUserWeight.toStringAsFixed(1)} kg",
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            color: primaryBlack,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          "Target Weight: ${targetWeight.toStringAsFixed(1)} kg",
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            color: primaryBlack,
                                          ),
                                        ),
                                        SizedBox(height: 16),
                                        Center(
                                          child: Text(
                                            "Through consistent high intensity cycling and dedication to your fitness routine, you've successfully reached your target weight. This is a significant achievement that demonstrates your commitment to a healthier lifestyle.",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14,
                                              color: primaryBlack,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Your Cycling Stats",
                                          style: TextStyle(
                                            fontFamily: 'Fredoka-SemiBold',
                                            fontSize: 16,
                                            color: primaryBlack,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "Weekly Cycling Days: ${_weeklyDaysProgress.toStringAsFixed(0)} days",
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            color: primaryBlack,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          "Weekly Cycling Duration: ${_totalWeeklyDuration.toStringAsFixed(0)} minutes",
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            color: primaryBlack,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          "Total Distance This Week: ${_totalWeeklyDistance.toStringAsFixed(1)} km",
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            color: primaryBlack,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "What's Next?",
                                      style: TextStyle(
                                        fontFamily: 'Fredoka-SemiBold',
                                        fontSize: 18,
                                        color: primaryBlack,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    "Maintaining your weight is just as important as losing it. Consider setting a maintenance goal to keep your healthy habits going, or challenge yourself with a new fitness target.",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: primaryGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(20),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          QuestionPage(initialPage: 2)),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Set New Goal",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ).catchError((error) {
        print("Error showing dialog: $error");
      });
    } catch (e) {
      print("Exception during dialog: $e");
    }
  }

  void _showGoalCompletionDialog() {
    _confettiController.play();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.elasticOut,
            ),
          ),
          child: child,
        );
      },
      pageBuilder: (BuildContext context, Animation animation,
          Animation secondaryAnimation) {
        return Material(
          type: MaterialType.transparency,
          child: Center(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        particleDrag: 0.05,
                        emissionFrequency: 0.05,
                        numberOfParticles: 20,
                        gravity: 0.2,
                        shouldLoop: false,
                        colors: const [
                          Colors.green,
                          Colors.blue,
                          Colors.pink,
                          Colors.orange,
                          Colors.purple,
                          Colors.yellow,
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 30),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryOrange,
                                const Color.fromARGB(255, 248, 149, 69)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/trophy.png',
                                width: 100,
                                height: 100,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "GOAL COMPLETED!",
                                style: TextStyle(
                                  fontFamily: 'Fredoka-Bold',
                                  fontSize: 28,
                                  color: Colors.yellow,
                                  letterSpacing: 1.2,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(2, 2),
                                      blurRadius: 4.0,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Congratulations on your achievement!",
                                style: TextStyle(
                                  fontFamily: 'Fredoka-Regular',
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    "Your Endurance Journey",
                                    style: TextStyle(
                                      fontFamily: 'Fredoka-SemiBold',
                                      fontSize: 20,
                                      color: primaryBlack,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),

                                // Best performance details
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              "Best Performance",
                                              style: TextStyle(
                                                fontFamily: 'Fredoka-SemiBold',
                                                fontSize: 16,
                                                color: primaryBlack,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              "Distance: ${_bestDistance.toStringAsFixed(1)} km",
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 14,
                                                color: primaryBlack,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              "Duration: ${_getBestActivityDuration().toStringAsFixed(1)} minutes",
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 14,
                                                color: primaryBlack,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              "Date: ${_bestDistanceDate != null ? DateFormat('MMM d, yyyy').format(_bestDistanceDate!) : 'N/A'}",
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 14,
                                                color: primaryBlack,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 24),

                                // Achievement details
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            "You've successfully reached your target distance of ${userGoal!['targetDistance']} km and completed it within your target duration of ${userGoal!['targetDuration']} minutes.",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14,
                                              color: primaryBlack,
                                            ),
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            "This achievement shows your dedication to cycling and your endurance capabilities. Keep pushing your limits!",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14,
                                              color: primaryBlack,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 24),

                                Text(
                                  "What's Next?",
                                  style: TextStyle(
                                    fontFamily: 'Fredoka-SemiBold',
                                    fontSize: 18,
                                    color: primaryBlack,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  "Set a new goal to continue your cycling journey. Challenge yourself with a longer distance or shorter duration to improve your performance even further.",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: primaryGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(20),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        QuestionPage(initialPage: 2)),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryOrange,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Set New Goal",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        // Navigate directly to the goals page (index 2)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => QuestionPage(initialPage: 2)),
        );
      } catch (e) {
        print('Error resetting goal: $e');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to reset goal. Please try again.')));
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGoalHistory() async {
    List<Map<String, dynamic>> goalHistory = [];
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      try {
        QuerySnapshot goalsSnapshot = await FirebaseFirestore.instance
            .collection('goals')
            .where('uid', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .get();

        goalHistory = goalsSnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
      } catch (e) {
        print('Error fetching goal history: $e');
      }
    }

    return goalHistory;
  }

  void _showGoalHistoryDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchGoalHistory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  "Goal History",
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 22,
                    color: primaryBlack,
                  ),
                ),
                content: SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryOrange),
                    ),
                  ),
                ),
              );
            } else if (snapshot.hasError) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  "Goal History",
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 22,
                    color: primaryBlack,
                  ),
                ),
                content: Text(
                  "Error loading goals: ${snapshot.error}",
                  style: TextStyle(color: Colors.red),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text("Close"),
                  ),
                ],
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  "Goal History",
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 22,
                    color: primaryBlack,
                  ),
                ),
                content: const Text("No goal history found."),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text("Close"),
                  ),
                ],
              );
            } else {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  "Goal History",
                  style: TextStyle(
                    fontFamily: 'Fredoka-SemiBold',
                    fontSize: 22,
                    color: primaryBlack,
                  ),
                ),
                content: Container(
                  width: double.maxFinite,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final goal = snapshot.data![index];
                      final goalType = goal['goalType'] ?? 'Unknown';
                      final createdAt = goal['timestamp'] != null
                          ? (goal['timestamp'] as Timestamp).toDate()
                          : DateTime.now();

                      String details = '';

                      if (goalType == 'Leisure') {
                        final daysPerWeek = goal['daysPerWeek'] ?? 'N/A';
                        final sessionDuration =
                            goal['sessionDuration'] ?? 'N/A';
                        details =
                            "$daysPerWeek days/week, $sessionDuration min/session";
                      } else if (goalType == 'High Intensity Cycling') {
                        final targetWeight = goal['targetWeight'] ?? 'N/A';
                        details = "Target weight: $targetWeight kg";
                      } else if (goalType == 'Endurance') {
                        final targetDistance = goal['targetDistance'] ?? 'N/A';
                        details = "Target distance: $targetDistance km";
                      }

                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: index == 0
                              ? primaryOrange.withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: index == 0
                                ? primaryOrange.withOpacity(0.3)
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  goalType,
                                  style: TextStyle(
                                    fontFamily: 'Fredoka-SemiBold',
                                    fontSize: 16,
                                    color: primaryBlack,
                                  ),
                                ),
                                if (index == 0)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: primaryOrange,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "Current",
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Created: ${DateFormat('MMM d, yyyy').format(createdAt)}",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: primaryGray,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              details,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: primaryBlack,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: primaryGray,
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        );
      },
    );
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

  double _getWeightLossProgress() {
    if (_currentUserWeight <= 0) {
      return 0.0;
    }

    double initialWeight = 0.0;
    if (userGoal != null && userGoal!.containsKey('initialWeight')) {
      var initialWeightValue = userGoal!['initialWeight'];
      if (initialWeightValue is int) {
        initialWeight = initialWeightValue.toDouble();
      } else if (initialWeightValue is double) {
        initialWeight = initialWeightValue;
      } else if (initialWeightValue is String) {
        initialWeight = double.tryParse(initialWeightValue) ?? 0.0;
      }
    }

    if (initialWeight <= 0) {
      return 0.0;
    }

    double weightLost = initialWeight - _currentUserWeight;
    double weightToLose = initialWeight - targetWeight;

    if (weightToLose <= 0) return 0.0;

    double progress = (weightLost / weightToLose) * 100.0;

    return progress.clamp(0.0, 100.0);
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

    String bestDateStr = _bestDistanceDate != null
        ? DateFormat('MMM d, yyyy').format(_bestDistanceDate!)
        : "your first ride";

    if (_bestDistance < targetDistance) {
      double remaining = targetDistance - _bestDistance;
      String progressText =
          "Your best performance was ${_bestDistance.toStringAsFixed(1)} km on $bestDateStr.";

      if (_latestActivityDate != null &&
          _latestActivityDate != _bestDistanceDate) {
        if (_latestDistance < _bestDistance) {
          String latestDateStr =
              DateFormat('MMM d, yyyy').format(_latestActivityDate!);
          progressText +=
              " Your latest ride on $latestDateStr was ${_latestDistance.toStringAsFixed(1)} km. Keep training to beat your personal best!";
        }
      }

      return progressText +
          " You need ${remaining.toStringAsFixed(1)} more km to reach your target.";
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

    return duration / 60.0;
  }

  String _getBestDurationHelperText(double targetDuration) {
    if (_bestDistanceActivity == null) return "";

    double bestDuration = _getBestActivityDuration();
    String bestDateStr = _bestDistanceDate != null
        ? DateFormat('MMM d, yyyy').format(_bestDistanceDate!)
        : "your first ride";

    if (bestDuration > targetDuration) {
      return "Your best distance ride took longer than your target duration. Try to improve your speed while maintaining distance.";
    } else {
      return "Great job! You completed your best distance ride in ${bestDuration.toStringAsFixed(1)} minutes on $bestDateStr, which is within your target duration.";
    }
  }

  void _showUpdateWeightDialog() {
    _updateWeightController.text = "";
    _updateBodyFatController.text = "";
    _updateMetabolicRateController.text = "";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Update Your Progress",
            style: TextStyle(
              fontFamily: 'Fredoka-SemiBold',
              fontSize: 22,
              color: primaryBlack,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _updateWeightController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: "Current Weight (kg)",
                  labelStyle: const TextStyle(color: Colors.black),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _updateBodyFatController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: "Body Fat Percentage (%)",
                  labelStyle: const TextStyle(color: Colors.black),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _updateMetabolicRateController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: "Metabolic Rate",
                  labelStyle: const TextStyle(color: Colors.black),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                _updateUserMetrics();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                "Save",
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

  Future<void> _updateUserMetrics() async {
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      double newWeight = double.tryParse(_updateWeightController.text) ?? 0;
      double newBodyFat = double.tryParse(_updateBodyFatController.text) ?? 0;
      double newMetabolicRate =
          double.tryParse(_updateMetabolicRateController.text) ?? 0;

      final userDataQuery = await FirebaseFirestore.instance
          .collection('userData')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      Map<String, dynamic> newData = {
        'uid': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'weight': newWeight,
        'bodyFat': newBodyFat,
        'basalMetabolicRate': newMetabolicRate,
      };

      if (userDataQuery.docs.isNotEmpty) {
        Map<String, dynamic> existingData = userDataQuery.docs.first.data();
        existingData.forEach((key, value) {
          if (key != 'uid' &&
              key != 'timestamp' &&
              key != 'weight' &&
              key != 'bodyFat') {
            newData[key] = value;
          }
        });
      }

      await FirebaseFirestore.instance.collection('userData').add(newData);

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Progress updated successfully!')));

      await _loadUserGoalAndActivities();
    } catch (e) {
      print('Error updating metrics: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update progress: $e')));
    }
  }

  Widget _buildProgressCard(String title, double progress, double target,
      String unit, Color color, IconData icon,
      {String? helpText}) {
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
                  // Prevents title from overflowing
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Fredoka-SemiBold',
                      fontSize: 16,
                      color: primaryBlack,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
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

            // Progress Bar
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    double barWidth = min(constraints.maxWidth * percentage,
                        constraints.maxWidth);
                    return Container(
                      height: 8,
                      width: barWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.7)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (unit != "%")
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Current: ${progress.toStringAsFixed(1)} $unit",
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: primaryGray,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "Target: ${target.toStringAsFixed(1)} $unit",
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: primaryGray,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),

            // Special Case: Weight Progress
            if (unit == "%" && title == "Weight Progress")
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Current: ${_currentUserWeight.toStringAsFixed(1)} kg",
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: primaryGray,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "Target: ${targetWeight.toStringAsFixed(1)} kg",
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: primaryGray,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),

            // Help Text (Prevent Overflow)
            if (helpText != null) ...[
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    width: constraints.maxWidth,
                    child: Text(
                      helpText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: primaryGray,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  );
                },
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

    final weekRangeStr =
        "${DateFormat('MMM d').format(_weekStartDate)} - ${DateFormat('MMM d').format(_weekEndDate)}";

    double daysTarget = 7.0; // Default value
    double durationTarget = 30.0; // Default value

    if (userGoal!.containsKey('daysPerWeek')) {
      var daysValue = userGoal!['daysPerWeek'];
      if (daysValue is int) {
        daysTarget = daysValue.toDouble();
      } else if (daysValue is double) {
        daysTarget = daysValue;
      } else if (daysValue is String) {
        daysTarget = double.tryParse(daysValue) ?? 7.0;
      }
      print(
          "Days target parsed as: $daysTarget from ${userGoal!['daysPerWeek']}");
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
      print(
          "Duration target parsed as: $durationTarget from ${userGoal!['sessionDuration']}");
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
      print(
          "Target weight: $targetWeight, Current weight: $_currentUserWeight");
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
      daysHelperText =
          "You need $remaining more day${remaining > 1 ? 's' : ''} this week to reach your goal.";
    } else {
      daysHelperText = "Great job! You've reached your weekly cycling goal.";
    }

    String durationHelperText = '';
    if (_averageSessionDuration < durationTarget) {
      double needed = durationTarget - _averageSessionDuration;
      durationHelperText =
          "Try to increase your session duration by about ${needed.round()} mins.";
    } else {
      durationHelperText = "Excellent! You're meeting your duration targets.";
    }

    if (goalType == 'High Intensity Cycling') {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Update Weight Button
            Container(
              margin: const EdgeInsets.only(bottom: 5, top: 15),
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showUpdateWeightDialog,
                icon: const Icon(Icons.update, color: Colors.white),
                label: const Text(
                  "Update Weight & Body Fat",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // Add the subgoal card here
            if (hasActiveSubgoal) _buildActiveSubgoalCard(),

            Container(
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
                    Column(
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

                        if (goalType != 'Endurance')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
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
                            durationTarget,
                            "mins",
                            Colors.blue,
                            Icons.timer,
                            helpText: _getDurationHelperText(durationTarget),
                          ),
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
                            _getWeightLossProgress(),
                            100,
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
                            durationTarget,
                            "mins",
                            Colors.blue,
                            Icons.timer,
                            helpText: _getDurationHelperText(durationTarget),
                          ),
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
                              helpText:
                                  _getBestDurationHelperText(durationTarget),
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
                        if (_weeklyActivities.isNotEmpty &&
                            goalType != 'Endurance') ...[
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
                        if (goalType == 'Endurance' &&
                            _latestActivityDate != null &&
                            _latestActivityDate != _bestDistanceDate) ...[
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
                  ],
                ),
              ),
            ),
          ],
        ),
      );
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  durationTarget,
                  "mins",
                  Colors.blue,
                  Icons.timer,
                  helpText: _getDurationHelperText(durationTarget),
                ),
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
                _buildProgressCard(
                  "Weight Progress",
                  _getWeightLossProgress(),
                  100,
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
                  durationTarget,
                  "mins",
                  Colors.blue,
                  Icons.timer,
                  helpText: _getDurationHelperText(durationTarget),
                ),
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
              if (goalType == 'Endurance' &&
                  _latestActivityDate != null &&
                  _latestActivityDate != _bestDistanceDate) ...[
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
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadUserGoalAndActivities();
                  return Future.value();
                },
                color: primaryOrange,
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
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
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  QuestionPage(initialPage: 2)),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryOrange,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showGoalHistoryDialog,
                            icon:
                                const Icon(Icons.history, color: Colors.white),
                            label: const Text(
                              "View Goal History",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
