import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'goal_tracking.dart';
import 'login_register.dart';
import 'recommendation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:fitride/pages/change_password.dart';
import 'strava_webview.dart';
import 'package:fitride/pages/health_summary.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 3;
  String name = "Loading...";
  String email = "Loading...";
  String? _imagePath;
  String currentQuote = "";
  
  AnimationController? _animationController;
  bool isRefreshing = false;

  final ImagePicker _picker = ImagePicker();
  
  // Define custom colors
  final Color orangeColor = const Color(0xffFFA500);
  final Color darkGrey = const Color(0xFF303030);
  
  // Motivational quotes
  final List<String> quotes = [
    "Every ride is a chance to become stronger than yesterday.",
    "Push your limits today, and tomorrow they'll be your warm-up.",
    "The road to fitness is paved with consistency, not perfection."
  ];
  
  List accountArr = [
    {"image": "assets/strava_logo.png", "name": "Authorize Strava", "tag": "1"},
    {"image": "assets/change_pw.png", "name": "Change Password", "tag": "2"},
    {"image": "assets/health_summary.png", "name": "Health Summary", "tag": "3"},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadImagePath();
    _setRandomQuote();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Start animation
    _animationController!.forward();
  }
  
  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }
  
  void _setRandomQuote() {
    final random = DateTime.now().millisecondsSinceEpoch % quotes.length;
    setState(() {
      currentQuote = quotes[random];
    });
  }
  
  // Refresh quote and trigger animations
  void _refreshQuote() {
    setState(() {
      isRefreshing = true;
    });
    
    // Reset and start animation
    _animationController?.reset();
    _setRandomQuote();
    _animationController?.forward().then((_) {
      setState(() {
        isRefreshing = false;
      });
    });
  }

  Future<void> _loadUserData() async {
    // Get current logged-in user
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      String uid = currentUser.uid;
      print('Current user UID: $uid');
      
      try {
        // First approach: Try querying with where clause
        print('Attempting to find athlete with app_id = $uid');
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('athletes')
            .where('app_id', isEqualTo: uid)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // Found a match with the query
          DocumentSnapshot athleteDoc = querySnapshot.docs.first;
          final data = athleteDoc.data() as Map<String, dynamic>?;
          
          print('Found athlete document with matching app_id. Data: ${data?.toString()}');
          
          if (data != null && data.containsKey('athlete_name')) {
            setState(() {
              name = data['athlete_name'];
              email = currentUser.email ?? 'your.email@example.com';
            });
            return;
          }
        } 
        
        // Second approach: Get all documents and manually compare
        print('No match found with query. Fetching all athletes...');
        QuerySnapshot allDocs = await FirebaseFirestore.instance
            .collection('athletes')
            .get();
        
        print('Retrieved ${allDocs.docs.length} athletes documents');
        
        // Try to find a document with matching app_id through manual comparison
        for (var doc in allDocs.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            // Print fields to help debug
            print('Document ID: ${doc.id}, Fields: ${data.keys.join(', ')}');
            
            if (data.containsKey('app_id')) {
              String appId = data['app_id'].toString();
              print('Comparing app_id: "$appId" with uid: "$uid"');
              
              // Try several matching approaches
              if (appId == uid || 
                  appId.trim() == uid ||
                  appId.toLowerCase() == uid.toLowerCase()) {
                  
                print('Found matching document with app_id: $appId');
                
                setState(() {
                  name = data['athlete_name'] ?? 'Your Name';
                  email = currentUser.email ?? 'your.email@example.com';
                });
                return;
              }
            }
          }
        }
        
        // If we get here, no matching document was found
        print('No athlete document found matching the user ID');
        setState(() {
          name = 'Your Name';
          email = currentUser.email ?? 'your.email@example.com';
        });
      } catch (e) {
        print('Error loading athlete data: $e');
        setState(() {
          name = 'Your Name';
          email = currentUser.email ?? 'your.email@example.com';
        });
      }
    } else {
      setState(() {
        name = 'Your Name';
        email = 'your.email@example.com';
      });
    }
  }

  Future<void> _loadImagePath() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _imagePath = prefs.getString('profileImagePath');
    });
  }

  Future<void> _saveImagePath(String path) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileImagePath', path);
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
      await _saveImagePath(pickedFile.path);
    }
  }

  Future<void> _editProfile() async {
    // Show a dialog to edit name only
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        String updatedName = name;
        
        return AlertDialog(
          title: Text(
            "Edit Profile Name",
            style: TextStyle(
              fontFamily: 'Fredoka-SemiBold',
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: "Name",
                  labelStyle: TextStyle(color: Colors.grey[700]),
                  hintText: "Enter your name",
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: orangeColor, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: TextStyle(
                  color: Colors.black87,
                  fontFamily: 'Inter',
                  fontSize: 16,
                ),
                onChanged: (value) {
                  updatedName = value;
                },
                controller: TextEditingController(text: name),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontFamily: 'Inter',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, updatedName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: orangeColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Save",
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    ).then((value) async {
      if (value != null && value != name) {
        // Update name in Firestore
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          try {
            await FirebaseFirestore.instance
                .collection('athletes')
                .doc(currentUser.uid)
                .update({'athlete_name': value});
                
            setState(() {
              name = value;
            });
            
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Name updated successfully!'),
                backgroundColor: Colors.green,
              )
            );
          } catch (e) {
            print('Error updating name: $e');
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update name. Please try again.'),
                backgroundColor: Colors.red,
              )
            );
          }
        }
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => GoalTrackingPage()),
        );
        break;
      case 3:
        // Already on profile page
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
    );
  }

  _navigateToPage(String tag) {
    switch (tag) {
      case "1":
        _authorizeStrava();
        break;
      case "2":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChangePasswordPage()),
        );
        break;
      case "3":
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => HealthSummary()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Simple animated motivation card
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      orangeColor.withOpacity(0.8),
                      orangeColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: orangeColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Daily Motivation",
                            style: TextStyle(
                              fontFamily: 'Fredoka-SemiBold',
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          InkWell(
                            onTap: _refreshQuote,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: AnimatedOpacity(
                          opacity: isRefreshing ? 0.0 : 1.0,
                          duration: Duration(milliseconds: 500),
                          child: Text(
                            '"$currentQuote"',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              Row(
                children: [
                  GestureDetector(
                    onTap: () {}, // Main image tap does nothing
                    child: Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                orangeColor.withOpacity(0.7),
                                orangeColor,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: orangeColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(3), // Gradient border
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(35),
                            child: _imagePath == null
                                ? Container(
                                    color: Colors.white,
                                    child: Icon(Icons.person, size: 40, color: orangeColor.withOpacity(0.7)),
                                  )
                                : Image.file(
                                    File(_imagePath!),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.add_a_photo,
                                size: 16,
                                color: orangeColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    width: 15,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Fredoka-SemiBold',
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          email,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 25,
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: orangeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.account_circle_outlined,
                            color: orangeColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Account Settings",
                          style: TextStyle(
                            fontFamily: 'Fredoka-SemiBold',
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: accountArr.length,
                      itemBuilder: (context, index) {
                        var iObj = accountArr[index] as Map? ?? {};
                        return _buildSettingRow(
                          iObj["name"].toString(),
                          iObj["tag"].toString(),
                          iObj["image"].toString(),
                        );
                      },
                    )
                  ],
                ),
              ),
              const SizedBox(
                height: 25,
              ),
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [orangeColor.withOpacity(0.8), orangeColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: orangeColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: _logout,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Log Out",
                          style: TextStyle(
                            fontFamily: 'Fredoka-SemiBold',
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.grey[900],
            currentIndex: _selectedIndex,
            selectedItemColor: orangeColor,
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              fontFamily: "Inter",
            ),
            unselectedLabelStyle: const TextStyle(
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

  Widget _buildSettingRow(String title, String tag, String imagePath) {
    return InkWell(
      onTap: () {
        _navigateToPage(tag);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Image.asset(
              imagePath,
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: orangeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                color: orangeColor,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}