import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart';
import 'recommendation.dart';
import 'profile.dart';
import 'login_register.dart';

String? getCurrentUserUID() {
  User? user = FirebaseAuth.instance.currentUser;
  return user?.uid;
}

class GoalTrackingPage extends StatefulWidget {
  const GoalTrackingPage({super.key});

  @override
  _GoalTrackingPageState createState() => _GoalTrackingPageState();
}

class _GoalTrackingPageState extends State<GoalTrackingPage> {
  int _selectedIndex = 2;
  String? _selectedGoal;
  String? _goalType;
  double? _targetDistance;
  List<Widget> _goalCards = [];

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  void _loadGoals() async {
    String? uid = getCurrentUserUID();
    if (uid != null) {
      final goalsSnapshot = await FirebaseFirestore.instance
          .collection('goals')
          .where('uid', isEqualTo: uid)
          .get();

      setState(() {
        _goalCards = goalsSnapshot.docs.map((doc) {
          double targetDistance = doc['targetDistance'];
          String goalId = doc['goalId'];
          String goalType = doc['goalType'];
          return GoalCard(goalId: goalId, targetDistance: targetDistance, goalType: goalType);
        }).toList();
      });
    }
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

  void _saveGoal() async {
    String? uid = getCurrentUserUID();
    if (uid != null && _goalType != null && _targetDistance != null) {
      String goalId = DateTime.now().millisecondsSinceEpoch.toString();

      await FirebaseFirestore.instance.collection('goals').doc(goalId).set({
        'uid': uid,
        'goalId': goalId,
        'goalName': 'Cycling Distance Goal',
        'goalType': _goalType,
        'targetDistance': _targetDistance,
        'distanceCycled': 0.0,
        'distanceLeft': _targetDistance,
      });

      setState(() {
        _goalCards.add(
          GoalCard(goalId: goalId, targetDistance: _targetDistance!, goalType: _goalType!),
        );
      });
    }
  }

  void _showGoalSettingDialog() {
    setState(() {
      _selectedGoal = null;
      _goalType = null;
      _targetDistance = null;
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Set a Goal",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "What goal would you like to set?",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButton<String>(
                    value: _selectedGoal,
                    isExpanded: true,
                    dropdownColor: Colors.grey[800],
                    style: GoogleFonts.poppins(color: Colors.white),
                    underline: Container(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedGoal = newValue;
                      });
                    },
                    items: <String>["Set a cycling distance"]
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Goal Frequency",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _goalType == "Daily" ? Colors.orange : Colors.grey[800],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: RadioListTile<String>(
                          title: Text(
                            "Daily",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          value: "Daily",
                          groupValue: _goalType,
                          onChanged: (String? value) {
                            setState(() {
                              _goalType = value;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _goalType == "Weekly" ? Colors.orange : Colors.grey[800],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: RadioListTile<String>(
                          title: Text(
                            "Weekly",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          value: "Weekly",
                          groupValue: _goalType,
                          onChanged: (String? value) {
                            setState(() {
                              _goalType = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  "Target Distance (km)",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _targetDistance = double.tryParse(value);
                    });
                  },
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    hintText: "Enter distance",
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        "Cancel",
                        style: GoogleFonts.poppins(color: Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        _saveGoal();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        "Set Goal",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey[900],
        elevation: 0,
        title: Text(
          "FitRide",
          style: GoogleFonts.poppins(
            color: Colors.orange,
            fontSize: 28,
            fontWeight: FontWeight.bold,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[900]!, Colors.grey[800]!],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Goals",
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Track your cycling progress",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        onPressed: _showGoalSettingDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          "Create New Goal",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ..._goalCards,
                  ],
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
          selectedItemColor: Colors.orange,
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

class GoalCard extends StatelessWidget {
  final String goalId;
  final double targetDistance;
  final String goalType;

  const GoalCard({required this.goalId, required this.targetDistance, required this.goalType});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.withOpacity(0.2), Colors.orange.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
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
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_bike_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Cycling Distance Goal",
                        style: GoogleFonts.poppins(
                          fontSize: 20,                           fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Target Distance: ${targetDistance.toStringAsFixed(2)} km",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.orange,
                  ),
                  onPressed: () {
                    // Add code to delete goal from Firebase here
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: 0.0, // Replace with actual progress calculation
              backgroundColor: Colors.grey[600],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
            const SizedBox(height: 8),
            Text(
              "Progress: 0% of the target distance",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            Text (
              "Goal Type: $goalType",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[400],
                )
            )
          ],
        ),
      ),
    );
  }
}
