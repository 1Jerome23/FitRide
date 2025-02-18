import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitride/pages/strava_webview.dart';
import 'strava_webview.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:fitride/pages/home_page.dart';

class QuestionPage extends StatefulWidget {
  const QuestionPage({Key? key}) : super(key: key);

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage>
    with SingleTickerProviderStateMixin {
  final LiquidController _controller = LiquidController();
  int _currentPage = 0;
  bool _stravaAuthSuccessful = false;
  bool _showManualInput = false;
  
  // Add controllers for new fields
  final TextEditingController weightController = TextEditingController();
  final TextEditingController bodyWaterController = TextEditingController();
  final TextEditingController bodyFatController = TextEditingController();

  int _selectedIndex = 3;
  bool _isLoading = true;
  String name = "Loading...";
  String email = "Loading...";
  String? _imagePath;
  
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  
  final TextEditingController ageController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  String? _healthCondition;

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

  @override
  void initState() {
    super.initState();
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
              pageBuilder: (context, animation, secondaryAnimation) => HomePage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: Duration(milliseconds: 500),
            ),
          );
        });
      });
    }
  }

  Future<void> submitScaleData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit your data')),
      );
      return;
    }

    try {
      Map<String, dynamic> scaleData = {
        'uid': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'weight': weightController.text,
        'bodyWater': bodyWaterController.text,
        'bodyFat': bodyFatController.text,
      };

      await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid)  // Using user.uid as the document ID
          .set(scaleData, SetOptions(merge: true));  // merge: true is key here

      _controller.animateToPage(
        page: _currentPage + 1,
        duration: 600,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit data: $e')),
      );
    }
  }

  Future<void> submitUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit your data')),
      );
      return;
    }

    try {
      Map<String, dynamic> userData = {
        'uid': user.uid,
        'timestamp': FieldValue.serverTimestamp(), 
        'age': ageController.text,
        'height': heightController.text,
        'healthCondition': _healthCondition,
      };

      await FirebaseFirestore.instance
          .collection('userData')
          .doc(user.uid) 
          .set(userData, SetOptions(merge: true)); 

      _controller.animateToPage(
        page: _currentPage + 1,
        duration: 600,
      );
    } catch (e) {
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

    final String authorizationUrl = Uri.parse("https://www.strava.com/oauth/authorize")
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
      // Handle the result from the StravaWebView
      if (result != null && result is Map<String, dynamic>) {
        bool success = result['success'] ?? false;
        String message = result['message'] ?? 'Authentication process completed';
        
        // Show a snackbar with the message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        
        // Update state to show the Next button if authentication was successful
        if (success) {
          setState(() {
            _stravaAuthSuccessful = true;
          });
        }
      }
    });
  }

  Widget buildDataEntryPage() {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Color(0xFFFFF8EE), // Light orange/cream background color
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
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w700
                  ),
                ),
                Text(
                  "It will help us to know more about you!",
                  style: TextStyle(color: primaryGray, fontSize: 12),
                ),
                SizedBox(height: media.width * 0.05),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Column(
                    children: [
                      // Age Input
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
                                  hintStyle: TextStyle(color: primaryGray),
                                ),
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 15),

                      // Height Input with CM box
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
                                        hintStyle: TextStyle(color: primaryGray),
                                      ),
                                      style: TextStyle(color: Colors.black),
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
                              "CM",
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),

                      // Health Conditions
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Pre-existing Conditions",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 10),
                          ..._healthConditions.map((condition) => Container(
                            margin: EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: _healthCondition == condition['label'] 
                                  ? primaryOrange.withOpacity(0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: _healthCondition == condition['label']
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
                              title: Text(condition['label']),
                              subtitle: Text(condition['description']),
                              onTap: () => setState(() => 
                                _healthCondition = condition['label']
                              ),
                            ),
                          )).toList(),
                        ],
                      ),
                      SizedBox(height: media.width * 0.07),
                      
                      // Next Button
                      Container(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: submitUserData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryOrange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            "Next",
                            style: TextStyle(color: Colors.white, fontSize: 16),
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

  Widget buildStravaAuthPage() {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Color(0xFFEEF9FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 100),
              Image.asset(
                'assets/strava_logo.png',
                height: media.width * 0.4, 
              ),
              SizedBox(height: 30),
              Text(
                "Authorize Strava",
                style: TextStyle(
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
                        color: primaryGray,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "⚠️ This is a requirement to use FitRide",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: primaryOrange,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),
              Container(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    _authorizeStrava();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFC4C02), // Strava orange
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
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Only show Next button after successful Strava authentication
              if (_stravaAuthSuccessful) ...[
                SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      _controller.animateToPage(
                        page: 1, // Index of buildDataEntryPage
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
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildXiaomiScalePage() {
    var media = MediaQuery.of(context).size;
    
    // Previous code remains the same until the manual input section in buildXiaomiScalePage...

if (_showManualInput) {
      return Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  Image.asset(
                    "assets/profile2.png",
                    width: MediaQuery.of(context).size.width,
                    fit: BoxFit.fitWidth,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.width * 0.05),
                  Text(
                    "Enter your measurements",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w700
                    ),
                  ),
                  Text(
                    "It will help us track your progress!",
                    style: TextStyle(color: primaryGray, fontSize: 12),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.width * 0.05),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: Column(
                      children: [
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
                                          hintStyle: TextStyle(color: primaryGray),
                                        ),
                                        style: TextStyle(color: Colors.black),
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
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
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
                                        "assets/water.png",
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: bodyWaterController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: "Body Water",
                                          hintStyle: TextStyle(color: primaryGray),
                                        ),
                                        style: TextStyle(color: Colors.black),
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
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
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
                                          hintStyle: TextStyle(color: primaryGray),
                                        ),
                                        style: TextStyle(color: Colors.black),
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
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: MediaQuery.of(context).size.width * 0.07),

                        // Next Button
                        Container(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: submitScaleData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryOrange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Text(
                              "Next",
                              style: TextStyle(color: Colors.white, fontSize: 16),
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

    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 100),
              Image.asset(
                'assets/xiaomi_logo.png',
                height: media.width * 0.3,
              ),
              SizedBox(height: 30),
              Text(
                "Connect Xiaomi Scale",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  "Connect your Xiaomi Smart Scale to automatically sync your body metrics",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primaryGray,
                    fontSize: 16,
                  ),
                ),
              ),
              SizedBox(height: 40),
              Container(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    // Implement Xiaomi scale connection logic here
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    "Connect Scale",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showManualInput = true;
                  });
                },
                child: Text(
                  "Don't have this device? Try manual input",
                  style: TextStyle(
                    color: primaryOrange,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildStravaAuthPage(),
      buildXiaomiScalePage(),
      buildDataEntryPage(),
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