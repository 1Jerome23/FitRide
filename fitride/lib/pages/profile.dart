import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 3;
  String name = "Loading...";
  String email = "Loading...";
  String? _imagePath;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadImagePath(); 
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      try {
        DocumentSnapshot athleteDoc = await FirebaseFirestore.instance
            .collection('athletes')
            .doc(currentUser.uid)
            .get();

        if (athleteDoc.exists) {
          setState(() {
            name = athleteDoc['athlete_name'] ?? 'Your Name';
          });
        } else {
          setState(() {
            name = 'Your Name';
          });
        }
      } catch (e) {
        print('Error fetching athlete data: $e');
        setState(() {
          name = 'Your Name';
        });
      }

      setState(() {
        email = currentUser.email ?? 'your.email@example.com';
      });

      prefs.setString('email', email);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          "FitRide",
          style: GoogleFonts.roboto(
            color: Colors.orange,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              'assets/logobike.png',
              height: 40,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _imagePath == null
                      ? null
                      : FileImage(File(_imagePath!)), 
                  child: _imagePath == null
                      ? Icon(Icons.person, size: 50, color: Colors.grey[700])
                      : null,
                ),
              ),
              SizedBox(height: 10),
              Text(
                name,
                style: GoogleFonts.lato(fontSize: 18, color: Colors.black),
              ),
              Text(
                email,
                style: GoogleFonts.lato(fontSize: 16, color: Colors.black),
              ),
              SizedBox(height: 30),
              _buildProfileButton("Set Your Goal", Icons.arrow_forward, () {
                // Navigate to Set Your Goal page
              }),
              _buildProfileButton("Edit Your Goal", Icons.arrow_forward, () {
                // Navigate to Edit Your Goal page
              }),
             _buildProfileButton("Change Password", Icons.arrow_forward, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChangePasswordPage()),
                );
              }),
              _buildProfileButton("Health Summary", Icons.arrow_forward, () {
                // Navigate to Health Summary page
              }),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _logout,
                child: Text("Log Out"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: GoogleFonts.lato(fontSize: 18, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.data_usage),
            label: 'Goal/Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildProfileButton(String text, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          padding: EdgeInsets.symmetric(vertical: 15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black),
            SizedBox(width: 10),
            Text(
              text,
              style: GoogleFonts.lato(fontSize: 16, color: Colors.black, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}
