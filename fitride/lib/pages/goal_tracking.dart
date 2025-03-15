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

int _currentWeekNumber = 1;
Map<int, Map<String, dynamic>> _weeklyGoalData = {};
Map<int, List<Map<String, dynamic>>> _weeklySubgoalData = {};

class WeeklyProgress {
  final int weekNumber;
  final DateTime weekStartDate;
  final DateTime weekEndDate;

  int sessionsCompleted = 0;
  double totalDuration = 0.0;

  // High Intensity Cycling tracking
  double weekStartWeight = 0.0;
  double weekEndWeight = 0.0;
  double caloriesBurned = 0.0;

  // Endurance tracking
  double bestDistance = 0.0;
  double bestPace = 0.0;
  DateTime? bestDistanceDate;

  // Subgoal progress
  double subgoalStartValue = 0.0;
  double subgoalCurrentValue = 0.0;
  double subgoalTargetValue = 0.0;
  String subgoalType = "";

  WeeklyProgress(
      {required this.weekNumber,
      required this.weekStartDate,
      required this.weekEndDate});

  Map<String, dynamic> toMap() {
    return {
      'weekNumber': weekNumber,
      'weekStartDate': weekStartDate,
      'weekEndDate': weekEndDate,
      'sessionsCompleted': sessionsCompleted,
      'totalDuration': totalDuration,
      'weekStartWeight': weekStartWeight,
      'weekEndWeight': weekEndWeight,
      'caloriesBurned': caloriesBurned,
      'bestDistance': bestDistance,
      'bestPace': bestPace,
      'bestDistanceDate': bestDistanceDate,
      'subgoalStartValue': subgoalStartValue,
      'subgoalCurrentValue': subgoalCurrentValue,
      'subgoalTargetValue': subgoalTargetValue,
      'subgoalType': subgoalType,
    };
  }

  factory WeeklyProgress.fromMap(Map<String, dynamic> map) {
    WeeklyProgress progress = WeeklyProgress(
      weekNumber: map['weekNumber'] ?? 0,
      weekStartDate:
          (map['weekStartDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      weekEndDate:
          (map['weekEndDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );

    progress.sessionsCompleted = map['sessionsCompleted'] ?? 0;
    progress.totalDuration = map['totalDuration']?.toDouble() ?? 0.0;
    progress.weekStartWeight = map['weekStartWeight']?.toDouble() ?? 0.0;
    progress.weekEndWeight = map['weekEndWeight']?.toDouble() ?? 0.0;
    progress.caloriesBurned = map['caloriesBurned']?.toDouble() ?? 0.0;
    progress.bestDistance = map['bestDistance']?.toDouble() ?? 0.0;
    progress.bestPace = map['bestPace']?.toDouble() ?? 0.0;
    progress.bestDistanceDate =
        (map['bestDistanceDate'] as Timestamp?)?.toDate();
    progress.subgoalStartValue = map['subgoalStartValue']?.toDouble() ?? 0.0;
    progress.subgoalCurrentValue =
        map['subgoalCurrentValue']?.toDouble() ?? 0.0;
    progress.subgoalTargetValue = map['subgoalTargetValue']?.toDouble() ?? 0.0;
    progress.subgoalType = map['subgoalType'] ?? "";

    return progress;
  }
}

class _GoalTrackingPageState extends State<GoalTrackingPage>
    with SingleTickerProviderStateMixin {
  Map<int, Map<String, dynamic>> _weeklyProgressData = {};
  bool _isLoadingWeeklyData = false;

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
  String subgoalType = ""; 
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
  TextEditingController _updateMetabolicRateController =TextEditingController();

  static const Color primaryOrange = Color(0xFFFF8B3D);
  static const Color primaryBlack = Color(0xFF1A1A1A);
  static const Color primaryGray = Color(0xFF676767);
  late DateTime _weekStartDate;
  late DateTime _weekEndDate;

  Future<void> _fetchAllWeeklyGoalData() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || userGoal == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _currentWeekNumber = getCurrentWeekNumber();
      print("Current week number: $_currentWeekNumber");

      String goalId = userGoal!['id'] ?? "";
      if (goalId.isEmpty) {
        print("Goal ID is empty");
        return;
      }

      QuerySnapshot weeklySnapshot = await FirebaseFirestore.instance
          .collection('weekly_progress')
          .where('uid', isEqualTo: uid)
          .where('goalId', isEqualTo: goalId)
          .orderBy('weekNumber', descending: true)
          .get();

      _weeklyGoalData.clear();

      for (var doc in weeklySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        int weekNum = data['weekNumber'] ?? 0;

        if (weekNum > 0) {
          data['docId'] = doc.id;
          _weeklyGoalData[weekNum] = data;

          print("Loaded weekly data for week $weekNum");
        }
      }

      if (hasActiveSubgoal) {
        await _fetchWeeklySubgoalData(uid, goalId);
      }

      if (!_weeklyGoalData.containsKey(_currentWeekNumber)) {
        _initializeCurrentWeekData(uid, goalId);
      }
    } catch (e) {
      print("Error fetching weekly data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

// Initialize data structure for the current week
  void _initializeCurrentWeekData(String uid, String goalId) {
    DateTime weekStart = _getWeekStartDate();
    DateTime weekEnd = _getWeekEndDate();

    Map<String, dynamic> weekData = {
      'uid': uid,
      'goalId': goalId,
      'weekNumber': _currentWeekNumber,
      'weekStartDate': Timestamp.fromDate(weekStart), 
      'weekEndDate': Timestamp.fromDate(weekEnd), 
      'timestamp': FieldValue.serverTimestamp(),
      'sessionsCompleted': 0,
      'totalDuration': 0.0,
      'totalDistance': 0.0,
      'uniqueDays': [],
    };

    if (userGoal?['goalType'] == 'High Intensity Cycling') {
      weekData['weekStartWeight'] = _currentUserWeight;
      weekData['weekEndWeight'] = _currentUserWeight;
      weekData['caloriesBurned'] = 0.0;
      weekData['targetWeight'] = targetWeight;
      weekData['initialWeight'] =
          userGoal?['initialWeight'] ?? _currentUserWeight;
    } else if (userGoal?['goalType'] == 'Endurance') {
      weekData['bestDistance'] = 0.0;
      weekData['bestPace'] = 0.0;
      weekData['targetDistance'] = userGoal?['targetDistance'] ?? 0.0;
    } else if (userGoal?['goalType'] == 'Leisure') {
      weekData['targetDaysPerWeek'] = userGoal?['daysPerWeek'] ?? 3;
      weekData['targetDuration'] = userGoal?['sessionDuration'] ?? 30.0;
    }

    if (hasActiveSubgoal) {
      weekData['subgoalType'] = subgoalType;
      weekData['subgoalTargetValue'] = subgoalTargetValue;
      weekData['subgoalCurrentValue'] = 0.0;
      weekData['subgoalBaseline'] = _getSubgoalBaselineValue();
    }

    _weeklyGoalData[_currentWeekNumber] = weekData;

    print("Initialized data for week $_currentWeekNumber");
  }

  double _getSubgoalBaselineValue() {
    switch (subgoalType) {
      case "distance":
        return baselineDistance;
      case "pace":
        return baselinePace;
      case "duration":
        return baselineDuration;
      default:
        return 0.0;
    }
  }

// Fetch subgoal data by week
  Future<void> _fetchWeeklySubgoalData(String uid, String goalId) async {
    try {
      _weeklySubgoalData.clear();

      QuerySnapshot subgoalSnapshot = await FirebaseFirestore.instance
          .collection('cycling_subgoals')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in subgoalSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Calculate which week this subgoal belongs to
        DateTime startDate = (data['startDate'] as Timestamp).toDate();
        int weekNum = _calculateWeekNumber(startDate);

        // Initialize the week's subgoal list if needed
        if (!_weeklySubgoalData.containsKey(weekNum)) {
          _weeklySubgoalData[weekNum] = [];
        }
        data['docId'] = doc.id;
        _weeklySubgoalData[weekNum]!.add(data);

        print("Added subgoal to week $weekNum: ${data['subgoalType']}");
      }
    } catch (e) {
      print("Error fetching subgoal data: $e");
    }
  }

// Calculate which week number a given date belongs to
  int _calculateWeekNumber(DateTime date) {
    if (_goalCreationDate == null) return 1;

    // Calculate days since goal creation
    int daysSinceCreation = date.difference(_goalCreationDate).inDays;

    // Calculate week number (using integer division which rounds down)
    int weekNumber = daysSinceCreation ~/ 7;

    // Add 1 to make it 1-based (week 1, week 2, etc.) rather than 0-based
    return weekNumber + 1;
  }

// Update the weekly progress with latest activity data
  Future<void> _updateWeeklyProgressData() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || userGoal == null) return;

    // Ensure we have the current week's data
    if (!_weeklyGoalData.containsKey(_currentWeekNumber)) {
      String goalId = userGoal!['id'] ?? "";
      _initializeCurrentWeekData(uid, goalId);
    }

    // Get the current week's data
    Map<String, dynamic> weekData = _weeklyGoalData[_currentWeekNumber]!;

    // Update common fields
    weekData['sessionsCompleted'] = _weeklyActivities.length;
    weekData['totalDuration'] = _totalWeeklyDuration;
    weekData['totalDistance'] = _totalWeeklyDistance;
    weekData['uniqueDays'] = _uniqueDays.toList();

    // Update goal-specific fields
    switch (userGoal!['goalType']) {
      case 'Leisure':
        weekData['dayProgress'] = _weeklyDaysProgress;
        break;

      case 'High Intensity Cycling':
        // Only update end weight if current weight is valid
        if (_currentUserWeight > 0) {
          weekData['weekEndWeight'] = _currentUserWeight;
        }

        // Calculate calories burned from activities
        double totalCalories = 0.0;
        for (var activity in _weeklyActivities) {
          if (activity.containsKey('calories_burned')) {
            totalCalories += safeParseDouble(activity['calories_burned']);
          }
        }
        weekData['caloriesBurned'] = totalCalories;

        // Calculate weight loss progress
        if (weekData['weekStartWeight'] > 0 && weekData['weekEndWeight'] > 0) {
          weekData['weeklyWeightChange'] =
              weekData['weekEndWeight'] - weekData['weekStartWeight'];
        }
        break;

      case 'Endurance':
        weekData['bestDistance'] = _bestDistance;

        // Calculate pace if we have valid duration and distance
        if (_bestDistance > 0 && _getBestActivityDuration() > 0) {
          double pace =
              _getBestActivityDuration() / _bestDistance; // minutes per km
          weekData['bestPace'] = pace;
        }

        if (_bestDistanceDate != null) {
          weekData['bestDistanceDate'] = _bestDistanceDate;
        }
        break;
    }

    // Update subgoal progress if there's an active subgoal
    if (hasActiveSubgoal) {
      weekData['subgoalType'] = subgoalType;
      weekData['subgoalTargetValue'] = subgoalTargetValue;

      // Set current value based on subgoal type
      switch (subgoalType) {
        case "distance":
          // Average distance per activity this week
          weekData['subgoalCurrentValue'] = _weeklyActivities.isEmpty
              ? 0.0
              : _totalWeeklyDistance / _weeklyActivities.length;
          break;

        case "pace":
          // Calculate average pace this week
          if (_totalWeeklyDistance > 0 && _totalWeeklyDuration > 0) {
            double avgPace = _totalWeeklyDuration / _totalWeeklyDistance;
            weekData['subgoalCurrentValue'] = avgPace;
          }
          break;

        case "duration":
          // Average duration per activity
          weekData['subgoalCurrentValue'] = _weeklyActivities.isEmpty
              ? 0.0
              : _totalWeeklyDuration / _weeklyActivities.length;
          break;

        case "maintain":
          // Just count the number of activities as a progress indicator
          weekData['subgoalCurrentValue'] = _weeklyActivities.length.toDouble();
          break;
      }

      // Calculate progress percentage for the subgoal
      if (weekData['subgoalBaseline'] != null &&
          weekData['subgoalTargetValue'] != null &&
          weekData['subgoalCurrentValue'] != null) {
        double baseline = weekData['subgoalBaseline'];
        double target = weekData['subgoalTargetValue'];
        double current = weekData['subgoalCurrentValue'];

        // Different calculation based on subgoal type
        if (subgoalType == "pace") {
          // For pace, lower is better (improvement is baseline → target where baseline > target)
          if (baseline > target) {
            double progress = (baseline - current) / (baseline - target);
            weekData['subgoalProgress'] = progress.clamp(0.0, 1.0);
          }
        } else {
          // For distance and duration, higher is better (improvement is baseline → target where baseline < target)
          if (target > baseline) {
            double progress = (current - baseline) / (target - baseline);
            weekData['subgoalProgress'] = progress.clamp(0.0, 1.0);
          }
        }
      }
    }

    // Save to Firestore
    await _saveWeeklyProgressToFirestore(weekData);
  }

// Save weekly progress data to Firestore
  Future<void> _saveWeeklyProgressToFirestore(
      Map<String, dynamic> weekData) async {
    try {
      // Check if this document already exists (by docId)
      if (weekData.containsKey('docId')) {
        // Update existing document
        await FirebaseFirestore.instance
            .collection('weekly_progress')
            .doc(weekData['docId'])
            .update(weekData);

        print("Updated weekly progress for week ${weekData['weekNumber']}");
      } else {
        // Create new document
        DocumentReference docRef = await FirebaseFirestore.instance
            .collection('weekly_progress')
            .add(weekData);

        // Store the doc ID for future updates
        weekData['docId'] = docRef.id;

        print(
            "Created new weekly progress record for week ${weekData['weekNumber']}");
      }
    } catch (e) {
      print("Error saving weekly progress: $e");
    }
  }

// Add method to get week-over-week progress comparison
  Map<String, dynamic> getWeekOverWeekProgress() {
    Map<String, dynamic> comparison = {};

    // Current week data
    Map<String, dynamic>? currentWeekData = _weeklyGoalData[_currentWeekNumber];

    // Previous week data
    Map<String, dynamic>? previousWeekData =
        _weeklyGoalData[_currentWeekNumber - 1];

    if (currentWeekData == null) {
      return {'hasComparison': false};
    }

    comparison['hasComparison'] = previousWeekData != null;
    comparison['currentWeek'] = _currentWeekNumber;

    // Common metrics for all goal types
    comparison['currentSessionsCount'] =
        currentWeekData['sessionsCompleted'] ?? 0;
    comparison['currentTotalDuration'] =
        currentWeekData['totalDuration'] ?? 0.0;
    comparison['currentTotalDistance'] =
        currentWeekData['totalDistance'] ?? 0.0;
    comparison['currentUniqueDays'] =
        currentWeekData['uniqueDays']?.length ?? 0;

    if (previousWeekData != null) {
      // Add previous week data
      comparison['previousSessionsCount'] =
          previousWeekData['sessionsCompleted'] ?? 0;
      comparison['previousTotalDuration'] =
          previousWeekData['totalDuration'] ?? 0.0;
      comparison['previousTotalDistance'] =
          previousWeekData['totalDistance'] ?? 0.0;
      comparison['previousUniqueDays'] =
          previousWeekData['uniqueDays']?.length ?? 0;

      // Calculate changes
      comparison['sessionsChange'] = (comparison['currentSessionsCount'] -
          comparison['previousSessionsCount']);
      comparison['durationChange'] = (comparison['currentTotalDuration'] -
          comparison['previousTotalDuration']);
      comparison['distanceChange'] = (comparison['currentTotalDistance'] -
          comparison['previousTotalDistance']);
      comparison['daysChange'] =
          (comparison['currentUniqueDays'] - comparison['previousUniqueDays']);

      // Goal-specific comparisons
      if (userGoal?['goalType'] == 'High Intensity Cycling') {
        comparison['currentWeight'] = currentWeekData['weekEndWeight'] ?? 0.0;
        comparison['previousWeight'] = previousWeekData['weekEndWeight'] ?? 0.0;
        comparison['weightChange'] =
            comparison['currentWeight'] - comparison['previousWeight'];

        comparison['currentCaloriesBurned'] =
            currentWeekData['caloriesBurned'] ?? 0.0;
        comparison['previousCaloriesBurned'] =
            previousWeekData['caloriesBurned'] ?? 0.0;
        comparison['caloriesChange'] = comparison['currentCaloriesBurned'] -
            comparison['previousCaloriesBurned'];
      } else if (userGoal?['goalType'] == 'Endurance') {
        comparison['currentBestDistance'] =
            currentWeekData['bestDistance'] ?? 0.0;
        comparison['previousBestDistance'] =
            previousWeekData['bestDistance'] ?? 0.0;
        comparison['bestDistanceChange'] = comparison['currentBestDistance'] -
            comparison['previousBestDistance'];

        comparison['currentBestPace'] = currentWeekData['bestPace'] ?? 0.0;
        comparison['previousBestPace'] = previousWeekData['bestPace'] ?? 0.0;
        comparison['bestPaceChange'] =
            comparison['currentBestPace'] - comparison['previousBestPace'];
      }
    }

    return comparison;
  }

// Method to get all active subgoals for the current week
  List<Map<String, dynamic>> getCurrentWeekSubgoals() {
    if (!_weeklySubgoalData.containsKey(_currentWeekNumber)) {
      return [];
    }

    return _weeklySubgoalData[_currentWeekNumber]!;
  }

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

  Map<String, dynamic>? getProgressForWeek(int weekNumber) {
    return _weeklyProgressData[weekNumber];
  }

// Method to get current week progress
  Map<String, dynamic>? getCurrentWeekProgress() {
    int currentWeek = getCurrentWeekNumber();
    return getProgressForWeek(currentWeek);
  }

  // Helper function to safely parse double values from various types
  double safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  DateTime _goalCreationDate = DateTime.now();

  DateTime _getWeekStartDate() {
    DateTime now = DateTime.now();

    int daysSinceCreation = now.difference(_goalCreationDate).inDays;

    int weekNumber = daysSinceCreation ~/ 7;

    return DateTime(_goalCreationDate.year, _goalCreationDate.month,
        _goalCreationDate.day + (weekNumber * 7), 0, 0, 0, 0);
  }

  DateTime _getWeekEndDate() {
    return _getWeekStartDate().add(Duration(
        days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
  }

  @override
  void initState() {
    super.initState();
    _currentWeekNumber = 1;
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

  Future<void> _fetchWeeklyProgressData() async {
    setState(() {
      _isLoadingWeeklyData = true;
    });

    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isLoadingWeeklyData = false;
      });
      return;
    }

    try {
      // Get the current week number
      int currentWeek = getCurrentWeekNumber();

      // Fetch progress data for all weeks up to the current one
      QuerySnapshot progressSnapshot = await FirebaseFirestore.instance
          .collection('weekly_progress')
          .where('uid', isEqualTo: uid)
          .where('goalId', isEqualTo: userGoal?['id'])
          .get();

      // Clear existing data
      _weeklyProgressData.clear();

      // Process the results
      for (var doc in progressSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        int weekNum = data['weekNumber'] ?? 0;

        if (weekNum > 0) {
          _weeklyProgressData[weekNum] = data;
        }
      }

      // If current week data doesn't exist, initialize it
      if (!_weeklyProgressData.containsKey(currentWeek)) {
        DateTime weekStart = _getWeekStartDate();
        DateTime weekEnd = _getWeekEndDate();

        _weeklyProgressData[currentWeek] = {
          'uid': uid,
          'goalId': userGoal?['id'],
          'weekNumber': currentWeek,
          'weekStartDate': weekStart,
          'weekEndDate': weekEnd,
          'sessionsCompleted': 0,
          'totalDuration': 0.0,
          'subgoalType': subgoalType,
          'subgoalStartValue': 0.0,
          'subgoalCurrentValue': 0.0,
          'subgoalTargetValue': subgoalTargetValue,
        };

        // Initialize goal-specific data
        if (userGoal?['goalType'] == 'High Intensity Cycling') {
          _weeklyProgressData[currentWeek]!['weekStartWeight'] =
              _currentUserWeight;
          _weeklyProgressData[currentWeek]!['weekEndWeight'] =
              _currentUserWeight;
          _weeklyProgressData[currentWeek]!['caloriesBurned'] = 0.0;
        } else if (userGoal?['goalType'] == 'Endurance') {
          _weeklyProgressData[currentWeek]!['bestDistance'] = 0.0;
          _weeklyProgressData[currentWeek]!['bestPace'] = 0.0;
        }
      }

      print(
          "Weekly progress data loaded. Weeks available: ${_weeklyProgressData.keys.toList()}");
    } catch (e) {
      print("Error fetching weekly progress data: $e");
    } finally {
      setState(() {
        _isLoadingWeeklyData = false;
      });
    }
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

          if (goalData != null) {
            Timestamp goalCreationTimestamp =
                goalData['timestamp'] as Timestamp;
            _goalCreationDate = goalCreationTimestamp.toDate();

            _weekStartDate = _getWeekStartDate();
            _weekEndDate = _getWeekEndDate();

            // Calculate the current week number
            _currentWeekNumber = getCurrentWeekNumber();
            print("Current Week Number: $_currentWeekNumber");

            // Also store the goal ID in the goal data
            goalData['id'] = mostRecentGoalDoc.id;

            // Fetch all weekly progress data
            await _fetchAllWeeklyGoalData();
          }

          print("Current Week Number: ${getCurrentWeekNumber()}");

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
          // After fetching the goal and before setting state
          await _fetchWeeklyProgressData();

          // After fetching activities
          await _updateWeeklyProgressData();
          await _updateWeeklyProgressData();

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

// Helper widget to build a comparison row
  Widget _buildComparisonRow(
      String label, num current, num previous, String unit, IconData icon,
      {bool invertComparison = false}) {
    num change = current - previous;
    bool isPositiveChange = invertComparison ? change < 0 : change > 0;
    bool isNegativeChange = invertComparison ? change > 0 : change < 0;
    bool isUnchanged = change == 0;

    Color changeColor = isPositiveChange
        ? Colors.green
        : isNegativeChange
            ? Colors.red
            : Colors.grey;

    IconData changeIcon = isPositiveChange
        ? Icons.arrow_upward
        : isNegativeChange
            ? Icons.arrow_downward
            : Icons.remove;

    String changeText = (change == 0)
        ? "No change"
        : "${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} $unit";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey[700]),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: primaryBlack,
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "${current.toStringAsFixed(1)} $unit",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryBlack,
                        ),
                      ),
                      TextSpan(
                        text:
                            " (previous: ${previous.toStringAsFixed(1)} $unit)",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: changeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: changeColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(changeIcon, size: 12, color: changeColor),
                SizedBox(width: 4),
                Text(
                  changeText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: changeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Method to display weekly progress history
  void _showWeeklyProgressHistory() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Weekly Progress History",
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
            child: _isLoadingWeeklyData
                ? Center(child: CircularProgressIndicator(color: primaryOrange))
                : _weeklyProgressData.isEmpty
                    ? Center(child: Text("No weekly progress data available"))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _weeklyProgressData.length,
                        itemBuilder: (context, index) {
                          // Get weeks sorted in descending order (newest first)
                          final weeks = _weeklyProgressData.keys.toList()
                            ..sort((a, b) => b.compareTo(a));
                          final weekNum = weeks[index];
                          final weekData = _weeklyProgressData[weekNum]!;

                          final weekStart =
                              (weekData['weekStartDate'] as Timestamp?)
                                      ?.toDate() ??
                                  DateTime.now();
                          final weekEnd =
                              (weekData['weekEndDate'] as Timestamp?)
                                      ?.toDate() ??
                                  DateTime.now();

                          // Format week date range
                          final dateRangeStr =
                              "${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(weekEnd)}";

                          // Display different data based on goal type
                          Widget progressContent;

                          switch (userGoal?['goalType']) {
                            case 'Leisure':
                              progressContent = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Sessions: ${weekData['sessionsCompleted'] ?? 0}",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    "Total Duration: ${(weekData['totalDuration'] ?? 0.0).toStringAsFixed(1)} mins",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                              break;

                            case 'High Intensity Cycling':
                              final startWeight =
                                  weekData['weekStartWeight'] ?? 0.0;
                              final endWeight =
                                  weekData['weekEndWeight'] ?? 0.0;
                              final weightChange = endWeight - startWeight;

                              // Determine color for weight change (green for weight loss, red for weight gain)
                              final weightChangeColor = weightChange <= 0
                                  ? Colors.green[700]
                                  : Colors.red[700];

                              progressContent = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Weight: ${startWeight.toStringAsFixed(1)} → ${endWeight.toStringAsFixed(1)} kg",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        "Change: ",
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        "${weightChange.toStringAsFixed(1)} kg",
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          color: weightChangeColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "Calories Burned: ${(weekData['caloriesBurned'] ?? 0.0).toStringAsFixed(0)}",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                              break;

                            case 'Endurance':
                              progressContent = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Best Distance: ${(weekData['bestDistance'] ?? 0.0).toStringAsFixed(1)} km",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (weekData['bestPace'] != null &&
                                      weekData['bestPace'] > 0)
                                    Text(
                                      "Pace: ${(weekData['bestPace'] ?? 0.0).toStringAsFixed(1)} min/km",
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              );
                              break;

                            default:
                              progressContent = Text(
                                "No data available",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Colors.black,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                          }

// Additional subgoal progress if available
                          if (weekData['subgoalType'] != null &&
                              weekData['subgoalType'].toString().isNotEmpty) {
                            String subgoalDesc = "Subgoal: ";

                            switch (weekData['subgoalType']) {   
                              case "distance":
                                subgoalDesc +=
                                    "Distance ${(weekData['subgoalCurrentValue'] ?? 0.0).toStringAsFixed(1)}/${(weekData['subgoalTargetValue'] ?? 0.0).toStringAsFixed(1)} km";
                                break;
                              case "pace":
                                subgoalDesc +=
                                    "Pace ${(weekData['subgoalCurrentValue'] ?? 0.0).toStringAsFixed(1)}/${(weekData['subgoalTargetValue'] ?? 0.0).toStringAsFixed(1)} min/km";
                                break;
                              case "duration":
                                subgoalDesc +=
                                    "Duration ${(weekData['subgoalCurrentValue'] ?? 0.0).toStringAsFixed(0)}/${(weekData['subgoalTargetValue'] ?? 0.0).toStringAsFixed(0)} mins";
                                break;
                              case "maintain":
                                subgoalDesc +=
                                    "Maintaining consistent performance";
                                break;
                            }

                            // Calculate progress percentage for display
                            double progress = 0.0;
                            if (weekData['subgoalProgress'] != null) {
                              progress = weekData['subgoalProgress'];
                            }

                            // Determine progress color
                            Color progressColor = progress >= 0.8
                                ? Colors.green[700]!
                                : progress >= 0.5
                                    ? Colors.orange[700]!
                                    : Colors.blue[700]!;

                            progressContent = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                progressContent,
                                Divider(height: 16, thickness: 0.5),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        subgoalDesc,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    // Add progress indicator
                                    if (weekData['subgoalProgress'] != null)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: progressColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: progressColor, width: 1),
                                        ),
                                        child: Text(
                                          "${(progress * 100).toInt()}%",
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            color: progressColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          }
                          // Returns the card for each week
                          return Container(
                            margin: EdgeInsets.only(bottom: 10),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: weekNum == getCurrentWeekNumber()
                                  ? primaryOrange.withOpacity(0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: weekNum == getCurrentWeekNumber()
                                    ? primaryOrange
                                    : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Week $weekNum",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: primaryBlack),
                                    ),
                                    Text(
                                      dateRangeStr,
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                progressContent,
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
      },
    );
  }

  // This method gets the current week number based on the goal creation date
  int getCurrentWeekNumber() {
    if (_goalCreationDate == null) {
      return 1; // Default to week 1 if no goal creation date is available
    }

    DateTime now = DateTime.now();

    // Calculate days since goal creation
    int daysSinceCreation = now.difference(_goalCreationDate).inDays;

    // Calculate week number (using integer division which rounds down)
    int weekNumber = daysSinceCreation ~/ 7;

    // Add 1 to make it 1-based (week 1, week 2, etc.) rather than 0-based
    return weekNumber + 1;
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
                  color: Colors.orangeAccent,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 6.0,
                      color: Colors.orange.withOpacity(0.3),
                    ),
                  ],
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
              fontFamily: 'Inter',
              fontSize: 14,
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
                // Progress indicators layout
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress status text with percentage
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Progress",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: progressPercent >= 1.0
                                  ? Colors.green[50]
                                  : progressPercent >= 0.5
                                      ? Colors.orange[50]
                                      : Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: progressPercent >= 1.0
                                      ? Colors.green[300]!
                                      : progressPercent >= 0.5
                                          ? Colors.orange[300]!
                                          : Colors.blue[300]!,
                                  width: 1),
                            ),
                            child: Text(
                              "${(progressPercent * 100).toInt()}%",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: progressPercent >= 1.0
                                    ? Colors.green[700]
                                    : progressPercent >= 0.5
                                        ? Colors.orange[700]
                                        : Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // Enhanced animated progress bar
                      Stack(
                        children: [
                          // Markers for baseline and target
                          Container(
                            height: 12,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: ProgressMarkerPainter(
                                baselinePosition: 0.0,
                                targetPosition: 1.0,
                                containerWidth:
                                    MediaQuery.of(context).size.width -
                                        80, // Adjust based on your padding
                              ),
                            ),
                          ),

                          // Background track
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),

                          // Animated progress fill
                          TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                  begin: 0.0, end: progressPercent),
                              duration: Duration(milliseconds: 1500),
                              curve: Curves.easeOutCubic,
                              builder: (context, animatedProgress, child) {
                                return Container(
                                  height: 12,
                                  width:
                                      (MediaQuery.of(context).size.width - 64) *
                                          animatedProgress,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: progressPercent >= 1.0
                                          ? [
                                              Colors.green[400]!,
                                              Colors.green[600]!
                                            ]
                                          : progressPercent >= 0.5
                                              ? [
                                                  Colors.orange[300]!,
                                                  Colors.orange[500]!
                                                ]
                                              : [
                                                  Colors.blue[300]!,
                                                  Colors.blue[500]!
                                                ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (progressPercent >= 1.0
                                                ? Colors.green
                                                : progressPercent >= 0.5
                                                    ? Colors.orange
                                                    : Colors.blue)
                                            .withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                          // Current value marker
                          TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                  begin: 0.0, end: progressPercent),
                              duration: Duration(milliseconds: 1500),
                              curve: Curves.easeOutCubic,
                              builder: (context, animatedProgress, child) {
                                return Positioned(
                                  left:
                                      (MediaQuery.of(context).size.width - 64) *
                                              animatedProgress -
                                          7,
                                  top: -3,
                                  child: Container(
                                    width: 14,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: progressPercent >= 1.0
                                            ? Colors.green[600]!
                                            : progressPercent >= 0.5
                                                ? Colors.orange[600]!
                                                : Colors.blue[600]!,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                        ],
                      ),

                      SizedBox(height: 16),

                      // Value comparison section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Last Week",
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                              SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[400],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    baselineValueText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                "Current",
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                              SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: progressPercent >= 1.0
                                          ? Colors.green[600]
                                          : progressPercent >= 0.5
                                              ? Colors.orange[600]
                                              : Colors.blue[600],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    currentValueText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Target",
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                              SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.green[800],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    targetValueText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Status message
                      if (subgoalType != "maintain") ...[
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: progressPercent >= 1.0
                                ? Colors.green[50]
                                : progressPercent >= 0.75
                                    ? Colors.lime[50]
                                    : progressPercent >= 0.5
                                        ? Colors.orange[50]
                                        : Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                progressPercent >= 1.0
                                    ? Icons.check_circle_outline
                                    : progressPercent >= 0.75
                                        ? Icons.thumb_up_outlined
                                        : progressPercent >= 0.5
                                            ? Icons.trending_up
                                            : Icons.directions_run,
                                size: 16,
                                color: progressPercent >= 1.0
                                    ? Colors.green[700]
                                    : progressPercent >= 0.75
                                        ? Colors.lime[700]
                                        : progressPercent >= 0.5
                                            ? Colors.orange[700]
                                            : Colors.blue[700],
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  progressPercent >= 1.0
                                      ? "Goal achieved! Great work!"
                                      : progressPercent >= 0.75
                                          ? "Almost there! Keep it up!"
                                          : progressPercent >= 0.5
                                              ? "Good progress! You're over halfway."
                                              : "Keep going! You're making progress.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: progressPercent >= 1.0
                                        ? Colors.green[700]
                                        : progressPercent >= 0.75
                                            ? Colors.lime[700]
                                            : progressPercent >= 0.5
                                                ? Colors.orange[700]
                                                : Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                // For "maintain" type goals
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_outlined,
                          color: Colors.teal[700], size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Consistency Goal",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[700],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              currentValueText,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.teal[800]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          SizedBox(height: 16),

          Divider(),

          Text(
            "Action Plan:",
            style: TextStyle(
              fontFamily: 'Inter',
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
                fontFamily: 'Inter',
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
      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchGoalHistory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Loading state
              return Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Goal History",
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 22,
                        color: primaryBlack,
                      ),
                    ),
                    SizedBox(height: 24),
                    Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryOrange),
                      ),
                    ),
                  ],
                ),
              );
            } else if (snapshot.hasError) {
              // Error state
              return Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Goal History",
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 22,
                        color: primaryBlack,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Error loading goals: ${snapshot.error}",
                      style: TextStyle(color: Colors.red),
                    ),
                    SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        "Close",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          color: primaryGray,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              // Empty state
              return Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Goal History",
                      style: TextStyle(
                        fontFamily: 'Fredoka-SemiBold',
                        fontSize: 22,
                        color: primaryBlack,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "No goal history found.",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: primaryGray,
                      ),
                    ),
                    SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        "Close",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          color: primaryGray,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              // Data loaded successfully
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with gradient
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xffFFA500), Color(0xffFF8C00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Goal History",
                          style: TextStyle(
                            fontFamily: 'Fredoka-SemiBold',
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content area with list
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                        IconData goalIcon = Icons.flag_outlined;

                        if (goalType == 'Leisure') {
                          goalIcon = Icons.pedal_bike_outlined;
                          final daysPerWeek = goal['daysPerWeek'] ?? 'N/A';
                          final sessionDuration = goal['sessionDuration'] ?? 'N/A';
                          details = "$daysPerWeek days/week, $sessionDuration min/session";
                        } else if (goalType == 'High Intensity Cycling') {
                          goalIcon = Icons.speed_outlined;
                          final targetWeight = goal['targetWeight'] ?? 'N/A';
                          details = "Target weight: $targetWeight kg";
                        } else if (goalType == 'Endurance') {
                          goalIcon = Icons.timer_outlined;
                          final targetDistance = goal['targetDistance'] ?? 'N/A';
                          details = "Target distance: $targetDistance km";
                        }

                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: index == 0
                                ? Color(0xffFFA500).withOpacity(0.1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: index == 0
                                  ? Color(0xffFFA500).withOpacity(0.3)
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                            boxShadow: index == 0 ? [
                              BoxShadow(
                                color: Color(0xffFFA500).withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              )
                            ] : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: index == 0 
                                    ? Color(0xffFFA500).withOpacity(0.2)
                                    : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  goalIcon,
                                  size: 20,
                                  color: index == 0 
                                    ? Color(0xffFFA500)
                                    : Colors.grey[700],
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            goalType,
                                            style: TextStyle(
                                              fontFamily: 'Fredoka-SemiBold',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: primaryBlack,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (index == 0)
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Color(0xffFFA500),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              "Current",
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
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
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      details,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Close button
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Close",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
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
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with icon
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xffFFA500), Color(0xffFF8C00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.monitor_weight_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Update Your Progress",
                          style: TextStyle(
                            fontFamily: 'Fredoka-SemiBold',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Weight field with icon
                _buildInputField(
                  controller: _updateWeightController,
                  labelText: "Current Weight (kg)",
                  hintText: "Enter your current weight",
                  icon: Icons.scale_outlined,
                  iconColor: Color(0xffFFA500),
                ),
                
                SizedBox(height: 16),
                
                // Body fat field with icon
                _buildInputField(
                  controller: _updateBodyFatController,
                  labelText: "Body Fat Percentage (%)",
                  hintText: "Enter your body fat %",
                  icon: Icons.percent_rounded,
                  iconColor: Color(0xffFF7E00),
                ),
                
                SizedBox(height: 16),
                
                // Metabolic rate field with icon
                _buildInputField(
                  controller: _updateMetabolicRateController,
                  labelText: "Basal Metabolic Rate (kcal)",
                  hintText: "Enter your BMR",
                  icon: Icons.local_fire_department_outlined,
                  iconColor: Color(0xffFF5900),
                ),
                
                SizedBox(height: 24),
                
                // Motivation text
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Regular tracking helps you stay on top of your goals and measure your progress accurately.",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Action buttons with better styling
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _updateUserMetrics();
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xffFFA500),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Save",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
      );
    },
  );
}

// Helper method to build consistent input fields with fully rounded icon backgrounds
Widget _buildInputField({
  required TextEditingController controller,
  required String labelText,
  required String hintText,
  required IconData icon,
  required Color iconColor,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey[300]!, width: 1),
    ),
    child: Row(
      children: [
        // Fully rounded icon container
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: labelText,
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.grey[400],
              ),
              labelStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.grey[700],
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        SizedBox(width: 12),
      ],
    ),
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

    // Add a state variable to track whether the main goal card is expanded
    bool isMainGoalExpanded = true;

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
              margin: const EdgeInsets.only(top: 10),
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showWeeklyProgressHistory,
                icon: const Icon(Icons.history, color: Colors.white),
                label: const Text(
                  "View Weekly Progress History",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[700],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // Make the main goal card collapsible
            StatefulBuilder(
              builder: (context, setState) {
                return Container(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with collapse button
                      InkWell(
                        onTap: () {
                          setState(() {
                            isMainGoalExpanded = !isMainGoalExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
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
                              Icon(
                                isMainGoalExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: primaryOrange,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Collapsible content
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        crossFadeState: isMainGoalExpanded
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),

                              if (goalType != 'Endurance')
                                Container(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      "Week ${getCurrentWeekNumber()}",
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                      ),
                                    ),
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
                                helpText:
                                    _getDurationHelperText(durationTarget),
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

                              const SizedBox(height: 16),

                              // Weekly Activities Summary - only for non-endurance goals
                              if (_weeklyActivities.isNotEmpty) ...[
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                    const Text(
                                      "For maximum calorie burn, incorporate interval training into your rides. Alternate between high intensity sprints and recovery periods.",
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
                        secondChild: const SizedBox(height: 0),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // For other goal types (Leisure or Endurance)
    return FadeTransition(
      opacity: _fadeAnimation,
      child: StatefulBuilder(
        builder: (context, setState) {
          return Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with collapse button
                InkWell(
                  onTap: () {
                    setState(() {
                      isMainGoalExpanded = !isMainGoalExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
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
                        Icon(
                          isMainGoalExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: primaryOrange,
                          size: 30,
                        ),
                      ],
                    ),
                  ),
                ),

                // Collapsible content
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: isMainGoalExpanded
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // Current Week Display based on goal type
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
                  secondChild: const SizedBox(height: 0),
                ),
              ],
            ),
          );
        },
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

class ProgressMarkerPainter extends CustomPainter {
  final double baselinePosition;
  final double targetPosition;
  final double containerWidth;

  ProgressMarkerPainter({
    required this.baselinePosition,
    required this.targetPosition,
    required this.containerWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Draw baseline marker
    canvas.drawLine(
      Offset(baselinePosition * containerWidth, 0),
      Offset(baselinePosition * containerWidth, size.height),
      paint,
    );

    // Draw target marker
    final targetPaint = Paint()
      ..color = Colors.green[800]!
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(targetPosition * containerWidth, 0),
      Offset(targetPosition * containerWidth, size.height),
      targetPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
