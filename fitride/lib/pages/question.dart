import 'package:fitride/pages/goal_tracking.dart';
import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitride/pages/strava_webview.dart';
import 'dart:async';
import 'package:fitride/pages/home_page.dart';

class QuestionPage extends StatefulWidget {
  final int initialPage;

  const QuestionPage({
    Key? key,
    this.initialPage = 0,
  }) : super(key: key);

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage>
    with SingleTickerProviderStateMixin {
  final LiquidController _controller = LiquidController();
  int _currentPage = 0;
  bool _stravaAuthSuccessful = false;
  String? _selectedGoal;

  final TextEditingController ageController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  String? _healthCondition;

  String? _heartRateLimit;

  String? _selectedGender;

  final TextEditingController weightController = TextEditingController();
  final TextEditingController basalMetabolicRateController =
      TextEditingController();
  final TextEditingController bodyFatController = TextEditingController();
  final TextEditingController targetWeightController = TextEditingController();

  final TextEditingController daysPerWeekController = TextEditingController();
  final TextEditingController sessionDurationController =
      TextEditingController();

  final TextEditingController targetDistanceController =
      TextEditingController();
  final TextEditingController targetDurationController =
      TextEditingController();

  String name = "Loading...";
  String email = "Loading...";

  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  static const Color primaryBlack = Color(0xFF1A1A1A);
  static const Color primaryGray = Color(0xFF676767);
  static const Color primaryOrange = Color(0xFFFF8B3D);

  final List<Map<String, dynamic>> _healthConditions = [
    {
      'image': 'assets/none.png',
      'label': 'None',
      'description': 'No pre-existing conditions'
    },
    {
      'image': 'assets/disease.png',
      'label': 'Cardiovascular or Respiratory',
      'description': 'Heart or breathing-related conditions'
    },
  ];

  final List<String> _heartRateOptions = [
    'No limitations',
    'Stay below 120 BPM',
    'Stay below 140 BPM',
    'Stay below 160 BPM',
    'Must monitor continuously',
    'Other (consult with doctor)'
  ];


  final List<Map<String, dynamic>> _goalOptions = [
    {
      'image': 'assets/leisure.png',
      'label': 'Leisure',
      'description': 'Casual cycling for enjoyment and light exercise'
    },
    {
      'image': 'assets/weight_loss.png',
      'label': 'High Intensity Cycling',
      'description': 'Focus on calorie burning and weight loss'
    },
    {
      'image': 'assets/endurance.png',
      'label': 'Endurance',
      'description': 'Build stamina for longer rides and events'
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialPage > 0) {
        _controller.jumpToPage(page: widget.initialPage);
      }
    });

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    basalMetabolicRateController.dispose();
    bodyFatController.dispose();
    targetWeightController.dispose();
    daysPerWeekController.dispose();
    sessionDurationController.dispose();
    targetDistanceController.dispose();
    targetDurationController.dispose();
    super.dispose();
  }

  void onPageChangedCallback(int activePageIndex) {
    setState(() {
      _currentPage = activePageIndex;
    });

    if (activePageIndex == 3) {
      Timer(Duration(seconds: 5), () {
        _animationController.forward().then((_) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  GoalTrackingPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: Duration(milliseconds: 500),
            ),
          );
        });
      });
    }
  }

 Future<void> submitAllUserData() async {
  // Validate required fields
  if (ageController.text.isEmpty ||
      heightController.text.isEmpty ||
      _selectedGender == null ||
      _healthCondition == null ||
      _selectedGoal == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill in all required fields')),
    );
    return;
  }

  // Check if the user is logged in
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please log in to submit your data')),
    );
    return;
  }

  try {
    // Prepare userData map
    Map<String, dynamic> userData = {
      'uid': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'age': ageController.text,
      'height': heightController.text,
      'gender': _selectedGender, 
      'healthCondition': _healthCondition,
    };

    // Add additional fields based on health condition
    if (_healthCondition != 'None') {
      userData['heartRateLimit'] = _heartRateLimit;
    }
    DateTime baseLineStartDate = DateTime.now();
    DateTime baseLineEndDate = baseLineStartDate.add(const Duration(days: 28));
    
    Map<String, dynamic> goalData = {
      'uid': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'goalType': _selectedGoal,
      'baseline_StartDate': baseLineStartDate, 
      'baseline_EndDate': baseLineEndDate, 
      'baseline_complete': false, 
    };

    // Add goal-specific fields based on the selected goal
    if (_selectedGoal == 'Leisure') {
      goalData['daysPerWeek'] = int.tryParse(daysPerWeekController.text) ?? 0;
      goalData['sessionDuration'] =
          int.tryParse(sessionDurationController.text) ?? 0;
    } else if (_selectedGoal == 'High Intensity Cycling') {
      double initialWeight = double.tryParse(weightController.text) ?? 0.0;

      userData['weight'] = weightController.text;
      userData['basalMetabolicRate'] = basalMetabolicRateController.text;
      userData['bodyFat'] = bodyFatController.text;

      goalData['targetWeight'] = targetWeightController.text;
      goalData['initialWeight'] = initialWeight;
      goalData['daysPerWeek'] = int.tryParse(daysPerWeekController.text) ?? 0;
      goalData['sessionDuration'] =
          int.tryParse(sessionDurationController.text) ?? 0;
      goalData[''];
    } else if (_selectedGoal == 'Endurance') {
      goalData['targetDistance'] = targetDistanceController.text;
      goalData['targetDuration'] = targetDurationController.text;
      goalData['daysPerWeek'] = int.tryParse(daysPerWeekController.text) ?? 0;
    }

    // Create a batch write for Firestore
    WriteBatch batch = FirebaseFirestore.instance.batch();

    DocumentReference userDataRef =
        FirebaseFirestore.instance.collection('userData').doc();
    batch.set(userDataRef, userData);

    DocumentReference goalsRef =
        FirebaseFirestore.instance.collection('goals').doc();
    batch.set(goalsRef, goalData);

    // Commit the batch write
    await batch.commit();

    // Navigate to the next page
    _controller.animateToPage(
      page: _currentPage + 1,
      duration: 600,
    );
  } catch (e) {
    // Show an error message if something goes wrong
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to submit data: $e')),
    );
  }
}

  void _authorizeStrava() {
    final String clientId = "146485";
    final String redirectUri = 'https://fitride.uk/callback';
    final String responseType = "code";
    final String approvalPrompt = "force";
    final String scope = "activity:read_all";
    final String login = "true";

    final String authorizationUrl =
        Uri.parse("https://www.strava.com/oauth/authorize")
            .replace(queryParameters: {
      "client_id": clientId,
      "redirect_uri": redirectUri,
      "response_type": responseType,
      "approval_prompt": approvalPrompt,
      "scope": scope,
      "login": login,
    }).toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StravaWebView(
          initialUrl: authorizationUrl,
          onRedirect: (url) {
            final Uri parsedUrl = Uri.parse(url);
            final authCode = parsedUrl.queryParameters['code'];

            if (authCode != null && authCode.isNotEmpty) {
              print('Authorization Code: $authCode');
            } else {
              print('Authorization failed: No code found in redirect URL.');
            }
          },
        ),
      ),
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        bool success = result['success'] ?? false;
        String message =
            result['message'] ?? 'Authentication process completed';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: Duration(seconds: 5),
          ),
        );

        if (success) {
          setState(() {
            _stravaAuthSuccessful = true;
          });
        }
      }
    });
  }

  Widget buildStravaAuthPage() {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Color(0xFFEEF9FF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: media.height * 0.05),
                Image.asset(
                  'assets/strava_logo.png',
                  height: media.width * 0.3,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 20),
                Text(
                  "Authorize Strava",
                  style: TextStyle(
                    fontFamily: "Fredoka-SemiBold",
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Text(
                        "Connect your Strava account to sync your activities and track your progress",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Inter",
                          color: primaryGray,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Before proceeding, kindly enable Strava to get your heart rate. To do this,\nGo to Strava > Profile > Settings > Data Permissions > Health-Related Data > click 'Allow'",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Inter",
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "⚠️ This is a requirement to use FitRide",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Inter",
                          color: primaryOrange,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      _authorizeStrava();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFC4C02),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 10),
                        Text(
                          "Connect with Strava",
                          style: TextStyle(
                            fontFamily: "Inter",
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_stravaAuthSuccessful) ...[
                  SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        _controller.animateToPage(
                          page: 1,
                          duration: 600,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        "Next",
                        style: TextStyle(
                          fontFamily: "Inter",
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildDataEntryPage() {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Color(0xFFFFF8EE),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                Image.asset(
                  "assets/profile.png",
                  width: media.width,
                  fit: BoxFit.fitWidth,
                ),
                SizedBox(height: media.width * 0.05),
                Text(
                  "Enter your data below",
                  style: TextStyle(
                      fontFamily: "Fredoka-SemiBold",
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  "It will help us to know more about you!",
                  style: TextStyle(
                      fontFamily: "Inter", color: primaryGray, fontSize: 12),
                ),
                SizedBox(height: media.width * 0.05),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              padding: EdgeInsets.all(15),
                              child: Image.asset(
                                "assets/age.png",
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: ageController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Age",
                                  hintStyle: TextStyle(
                                      fontFamily: "Inter", color: primaryGray),
                                ),
                                style: TextStyle(
                                    fontFamily: "Inter", color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 15),

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    padding: EdgeInsets.all(15),
                                    child: Image.asset(
                                      "assets/height.png",
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: heightController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: "Height",
                                        hintStyle: TextStyle(
                                            fontFamily: "Inter",
                                            color: primaryGray),
                                      ),
                                      style: TextStyle(
                                          fontFamily: "Inter",
                                          color: Colors.black),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryOrange,
                                  primaryOrange.withOpacity(0.7)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              "CM",
                              style: TextStyle(
                                  fontFamily: "Inter",
                                  color: Colors.white,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),

                      // Gender Selection
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              padding: EdgeInsets.all(15),
                              child: Image.asset(
                                "assets/gender.png",
                              ),
                            ),
                            Expanded(
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedGender,
                                    hint: Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Text(
                                        "Select Gender",
                                        style: TextStyle(
                                          fontFamily: "Inter",
                                          color: primaryGray,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    isExpanded: true,
                                    alignment: AlignmentDirectional.centerStart,
                                    icon: Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: _selectedGender != null ? primaryOrange : primaryGray,
                                      size: 24,
                                    ),
                                    dropdownColor: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    items: ['Male', 'Female'].map((String gender) {
                                      return DropdownMenuItem<String>(
                                        value: gender,
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 4),
                                          child: Text(
                                            gender,
                                            style: TextStyle(
                                              fontFamily: "Inter",
                                              color: primaryBlack,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedGender = newValue;
                                      });
                                    },
                                    selectedItemBuilder: (BuildContext context) {
                                      return ['Male', 'Female'].map<Widget>((String gender) {
                                        return Padding(
                                          padding: EdgeInsets.only(left: 4),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              gender,
                                              style: TextStyle(
                                                fontFamily: "Inter",
                                                color: primaryBlack,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 15),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Pre-existing Conditions",
                            style: TextStyle(
                              fontFamily: "Fredoka-SemiBold",
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 10),
                          ..._healthConditions
                              .map((condition) => Container(
                                    margin: EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color:
                                          _healthCondition == condition['label']
                                              ? primaryOrange.withOpacity(0.1)
                                              : Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: _healthCondition ==
                                                condition['label']
                                            ? primaryOrange
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 5,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      leading: Image.asset(
                                        condition['image'],
                                        width: 30,
                                        height: 30,
                                      ),
                                      title: Text(condition['label'],
                                          style: TextStyle(
                                            fontFamily: "Inter",
                                          )),
                                      subtitle: Text(condition['description'],
                                          style: TextStyle(
                                            fontFamily: "Inter",
                                          )),
                                      onTap: () => setState(() =>
                                          _healthCondition =
                                              condition['label']),
                                    ),
                                  ))
                              .toList(),
                        ],
                      ),

                      if (_healthCondition != null &&
                          _healthCondition != 'None') ...[
                        SizedBox(height: 15),
                        Text(
                          "Additional Health Information",
                          style: TextStyle(
                            fontFamily: "Fredoka-SemiBold",
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 10),

                        // Heart rate limitations 
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "What is your heart rate limitation while cycling?",
                                style: TextStyle(
                                  fontFamily: "Inter",
                                  fontSize: 14,
                                  color: primaryBlack,
                                ),
                              ),
                              SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(text: _heartRateLimit),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        setState(() {
                                          _heartRateLimit = value;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText: "Enter heart rate limit",
                                        hintStyle: TextStyle(
                                          fontFamily: "Inter",
                                          color: primaryGray,
                                          fontSize: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                            color: _heartRateLimit != null
                                                ? primaryOrange
                                                : Colors.grey.shade300,
                                            width: _heartRateLimit != null ? 2 : 1,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                            color: _heartRateLimit != null
                                                ? primaryOrange
                                                : Colors.grey.shade300,
                                            width: _heartRateLimit != null ? 2 : 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                            color: primaryOrange,
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10,
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontFamily: "Inter",
                                        color: primaryBlack,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    width: 50,
                                    height: 50,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [primaryOrange, primaryOrange.withOpacity(0.7)],
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Text(
                                      "BPM",
                                      style: TextStyle(
                                        fontFamily: "Inter",
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                        SizedBox(height: 15),

                      SizedBox(height: media.width * 0.07),

                      // Modified Next button - just navigate without submitting data
                      Container(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            // Just navigate to the next page without submitting
                            _controller.animateToPage(
                              page: _currentPage + 1,
                              duration: 600,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryOrange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            "Next",
                            style: TextStyle(
                                fontFamily: "Inter",
                                color: Colors.white,
                                fontSize: 16),
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
      ),
    );
  }

  Widget buildGoalsPage() {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Color(0xFFFFEEDD),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                Image.asset(
                  "assets/goals.png",
                  width: 300,
                  height: 300,
                  fit: BoxFit.fitWidth,
                ),
                SizedBox(height: media.width * 0.01),
                Text(
                  "Set Your Cycling Goals",
                  style: TextStyle(
                    fontFamily: "Fredoka-SemiBold",
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  "Choose a goal to personalize your cycling experience with us!",
                  style: TextStyle(
                    fontFamily: "Inter",
                    color: primaryGray,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: media.width * 0.05),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 500),
                  child: _selectedGoal == null
                      ? _buildGoalSelection(media)
                      : _buildGoalQuestions(media),
                ),
                SizedBox(height: 20),
                if (_selectedGoal != null) ...[
                  // Updated button text and function
                  Container(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          submitAllUserData, // Using the combined function
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        "Save and Continue", // Updated text
                        style: TextStyle(
                          fontFamily: "Inter",
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedGoal = null;
                      });
                    },
                    child: Text(
                      "Go Back",
                      style: TextStyle(
                        fontFamily: "Inter",
                        color: primaryOrange,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalSelection(Size media) {
    return Column(
      key: ValueKey<String>('goal_selection'),
      children: _goalOptions
          .map((goal) => GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedGoal = goal['label'];
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 15),
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        goal['image'],
                        width: 50,
                        height: 50,
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal['label'],
                              style: TextStyle(
                                fontFamily: "Fredoka-SemiBold",
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: primaryBlack,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              goal['description'],
                              style: TextStyle(
                                fontFamily: "Inter",
                                fontSize: 14,
                                color: primaryGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: primaryOrange,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildGoalQuestions(Size media) {
    switch (_selectedGoal) {
      case 'Leisure':
        return _buildLeisureQuestions(media);
      case 'High Intensity Cycling':
        return _buildHighIntensityQuestions(media);
      case 'Endurance':
        return _buildEnduranceQuestions(media);
      default:
        return Container();
    }
  }

  Widget _buildLeisureQuestions(Size media) {
    return Column(
      key: ValueKey<String>('leisure_questions'),
      children: [
        Container(
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Text(
                "Leisure Cycling",
                style: TextStyle(
                  fontFamily: "Fredoka-SemiBold",
                  fontSize: 25,
                  color: primaryOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5),
              Text(
                "Enjoy casual rides while still maintaining good health",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 12,
                  color: primaryGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        SizedBox(height: 20),

        // Days per week
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "How many days per week do you plan to cycle?",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: primaryBlack,
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: daysPerWeekController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Enter a number between 1-7",
                  hintStyle: TextStyle(
                    fontFamily: "Inter",
                    color: primaryGray,
                    fontSize: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                ),
                style: TextStyle(
                  fontFamily: "Inter",
                  color: primaryBlack,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 15),

        // Session duration
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "How long would you like to cycle in week?",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: primaryBlack,
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: sessionDurationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Enter duration",
                        hintStyle: TextStyle(
                            fontFamily: "Inter",
                            color: primaryGray,
                            fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      ),
                      style: TextStyle(
                        fontFamily: "Inter",
                        color: primaryBlack,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryOrange, primaryOrange.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "MINS",
                      style: TextStyle(
                          fontFamily: "Inter",
                          color: Colors.white,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHighIntensityQuestions(Size media) {
    return Column(
      key: ValueKey<String>('high_intensity_questions'),
      children: [
        Container(
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Text(
                "High Intensity Cycling",
                style: TextStyle(
                  fontFamily: "Fredoka-SemiBold",
                  fontSize: 25,
                  color: primaryOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5),
              Text(
                "Focus on calorie burning and weight loss through intense cycling sessions",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 14,
                  color: primaryGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        SizedBox(height: 20),

        // Current Measurements Section
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Current Measurements",
                style: TextStyle(
                  fontFamily: "Fredoka-SemiBold",
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: primaryBlack,
                ),
              ),
              SizedBox(height: 15),

              // Weight
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            padding: EdgeInsets.all(15),
                            child: Image.asset(
                              "assets/weight.png",
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: weightController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Weight",
                                hintStyle: TextStyle(
                                    fontFamily: "Inter", color: primaryGray),
                              ),
                              style: TextStyle(
                                  fontFamily: "Inter", color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryOrange, primaryOrange.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "KG",
                      style: TextStyle(
                          fontFamily: "Inter",
                          color: Colors.white,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),

              // Basal Metabolic Rate
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            padding: EdgeInsets.all(15),
                            child: Image.asset(
                              "assets/fire.png",
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: basalMetabolicRateController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Basal Metabolic Rate",
                                hintStyle: TextStyle(
                                    fontFamily: "Inter", color: primaryGray),
                              ),
                              style: TextStyle(
                                  fontFamily: "Inter", color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryOrange, primaryOrange.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "KCAL",
                      style: TextStyle(
                          fontFamily: "Inter",
                          color: Colors.white,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                "Tip: If you don't have a body composition scale, you can estimate your Basal Metabolic Rate (BMR) using the Mifflin-St Jeor Equation:\n\nFor men: BMR = (10 × weight in kg) + (6.25 × height in cm) - (5 × age in years) + 5\nFor women: BMR = (10 × weight in kg) + (6.25 × height in cm) - (5 × age in years) - 161",
                style: TextStyle(
                  fontFamily: "Inter",
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 15),

              // Body Fat
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            padding: EdgeInsets.all(15),
                            child: Image.asset(
                              "assets/fat.png",
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: bodyFatController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Body Fat",
                                hintStyle: TextStyle(
                                    fontFamily: "Inter", color: primaryGray),
                              ),
                              style: TextStyle(
                                  fontFamily: "Inter", color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryOrange, primaryOrange.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "%",
                      style: TextStyle(
                          fontFamily: "Inter",
                          color: Colors.white,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
              // Removed body fat calculation tip here
            ],
          ),
        ),
        SizedBox(height: 15),

        // Target Weight
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "What is your target weight?",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: primaryBlack,
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: targetWeightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Enter target weight",
                        hintStyle: TextStyle(
                            fontFamily: "Inter",
                            color: primaryGray,
                            fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      ),
                      style: TextStyle(
                        fontFamily: "Inter",
                        color: primaryBlack,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryOrange, primaryOrange.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "KG",
                      style: TextStyle(
                          fontFamily: "Inter",
                          color: Colors.white,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 15),

        // Days per week
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "How many days per week do you plan to cycle?",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: primaryBlack,
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: daysPerWeekController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Enter a number between 1-7",
                  hintStyle: TextStyle(
                      fontFamily: "Inter", color: primaryGray, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                ),
                style: TextStyle(
                  fontFamily: "Inter",
                  color: primaryBlack,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 15),

        // Session duration
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "How long do you want to cycle in a week?",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: primaryBlack,
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: sessionDurationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Enter duration",
                        hintStyle: TextStyle(
                            fontFamily: "Inter",
                            color: primaryGray,
                            fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      ),
                      style: TextStyle(
                        fontFamily: "Inter",
                        color: primaryBlack,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryOrange, primaryOrange.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "MINS",
                      style: TextStyle(
                          fontFamily: "Inter",
                          color: Colors.white,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnduranceQuestions(Size media) {
    return Column(
      key: ValueKey<String>('endurance_questions'),
      children: [
        Container(
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Text(
                "Endurance Cycling",
                style: TextStyle(
                  fontFamily: "Fredoka-SemiBold",
                  fontSize: 25,
                  color: primaryOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5),
              Text(
                "Build stamina and endurance for longer rides and cycling events",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 14,
                  color: primaryGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        SizedBox(height: 20),

        // Target distance
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "What is your target cycling distance?",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: primaryBlack,
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: targetDistanceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Enter distance",
                        hintStyle: TextStyle(
                            fontFamily: "Inter",
                            color: primaryGray,
                            fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      ),
                      style: TextStyle(
                        fontFamily: "Inter",
                        color: primaryBlack,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryOrange, primaryOrange.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "KM",
                      style: TextStyle(
                          fontFamily: "Inter",
                          color: Colors.white,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 15),

        // Target duration
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "What is the maximum time you want to complete this distance in?",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: primaryBlack,
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: targetDurationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Enter time",
                        hintStyle: TextStyle(
                            fontFamily: "Inter",
                            color: primaryGray,
                            fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      ),
                      style: TextStyle(
                        fontFamily: "Inter",
                        color: primaryBlack,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryOrange, primaryOrange.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "MINS",
                      style: TextStyle(
                          fontFamily: "Inter",
                          color: Colors.white,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 15),

        // Days per week
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "How many days per week do you plan to cycle?",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: primaryBlack,
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: daysPerWeekController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Enter a number between 1-7",
                  hintStyle: TextStyle(
                      fontFamily: "Inter", color: primaryGray, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                ),
                style: TextStyle(
                  fontFamily: "Inter",
                  color: primaryBlack,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildWelcomePage() {
    var media = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Scaffold(
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF6F00),
                    Color(0xFFFF8C00),
                    Color(0xFFFFA500),
                    Color(0xFFFFB84D),
                  ],
                  stops: [0.1, 0.4, 0.7, 0.9],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: media.width * 0.3,
                        height: media.width * 0.3,
                      ),
                      Text(
                        "Welcome to FitRide!",
                        style: TextStyle(
                          fontFamily: 'Fredoka-Bold',
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(2, 2),
                              blurRadius: 4,
                              color: Colors.black.withOpacity(0.2),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Your journey to fitness begins now",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          fontFamily: "Fredoka-SemiBold",
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          )
          );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildStravaAuthPage(),
      buildDataEntryPage(),
      buildGoalsPage(),
      buildWelcomePage(),
    ];

    return Scaffold(
      body: LiquidSwipe(
        pages: pages,
        liquidController: _controller,
        onPageChangeCallback: onPageChangedCallback,
        enableSideReveal: false,
        fullTransitionValue: 880,
        enableLoop: false,
        waveType: WaveType.liquidReveal,
      ),
    );
  }
}
