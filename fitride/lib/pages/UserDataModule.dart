import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase initialization
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FitRidePage(),
    );
  }
}

class FitRidePage extends StatefulWidget {
  @override
  _FitRidePageState createState() => _FitRidePageState();
}

class _FitRidePageState extends State<FitRidePage> {
  late List<Map<String, String>> dates;
  late String selectedDate;
  String weight = "-";
  String bodyFat = "-";
  String exertionLevel = "-";
  String sleep = "-";
  String water = "-";

  @override
  void initState() {
    super.initState();
    dates = _generateDateList();
    selectedDate =
        "${DateFormat.E().format(DateTime.now())} ${DateFormat.d().format(DateTime.now())}";
    _fetchUserData(); // Fetch user data when the page is initialized
  }

  List<Map<String, String>> _generateDateList() {
    List<Map<String, String>> dateList = [];
    DateTime today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime date = today.subtract(Duration(days: i));
      dateList.add({
        "day": DateFormat.E().format(date),
        "date": DateFormat.d().format(date),
        "fullDate": DateFormat('yyyy-MM-dd')
            .format(date), // Store full date for Firebase
      });
    }
    return dateList;
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      String uid = user.uid;
      String fullDate = dates.firstWhere(
        (date) => selectedDate == "${date['day']} ${date['date']}",
      )['fullDate']!;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('testAfterCycle')
          .doc(uid)
          .collection('dailyData')
          .doc(fullDate)
          .get();

      if (userDoc.exists) {
        setState(() {
          weight = userDoc['weight']?.toString() ?? "-";
          bodyFat = userDoc['body_fat']?.toString() ?? "-";
          exertionLevel = userDoc['exertion_level']?.toString() ?? "-";
          sleep = userDoc['sleep']?.toString() ?? "-";
          water = userDoc['water']?.toString() ?? "-";
        });
      } else {
        setState(() {
          weight = "No data found";
          bodyFat = "No data found";
          exertionLevel = "No data found";
          sleep = "No data found";
          water = "No data found";
        });
      }
    } catch (e) {
      setState(() {
        weight = "Error fetching data";
        bodyFat = "Error fetching data";
        exertionLevel = "Error fetching data";
        sleep = "Error fetching data";
        water = "Error fetching data";
      });
      print("Error fetching user data: $e");
    }
  }

  void _showEditDialog() {
    TextEditingController weightController =
        TextEditingController(text: weight);
    TextEditingController bodyFatController =
        TextEditingController(text: bodyFat);
    TextEditingController exertionController =
        TextEditingController(text: exertionLevel);
    TextEditingController sleepController = TextEditingController(text: sleep);
    TextEditingController waterController = TextEditingController(text: water);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            "Edit User Data",
            style: GoogleFonts.roboto(color: Colors.orange),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _buildEditField("Weight (kg)", weightController),
                _buildEditField("Body Fat (%)", bodyFatController),
                _buildEditField("Exertion Level (1-10)", exertionController),
                _buildEditField("Sleep (hours)", sleepController),
                _buildEditField("Water (liters)", waterController),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.roboto(color: Colors.orange),
              ),
            ),
            TextButton(
              onPressed: () async {
                // Validate exertion level
                final exertionLevelValue =
                    int.tryParse(exertionController.text);
                if (exertionLevelValue == null ||
                    exertionLevelValue < 1 ||
                    exertionLevelValue > 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Exertion level must be between 1 and 10.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return; // Stop further execution if validation fails
                }

                // Save changes to Firebase
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  String uid = user.uid;
                  String fullDate = dates.firstWhere(
                    (date) => selectedDate == "${date['day']} ${date['date']}",
                  )['fullDate']!;

                  try {
                    await FirebaseFirestore.instance
                        .collection('testAfterCycle')
                        .doc(uid)
                        .collection('dailyData')
                        .doc(fullDate)
                        .set({
                      'weight': double.tryParse(weightController.text),
                      'body_fat': double.tryParse(bodyFatController.text),
                      'exertion_level': exertionLevelValue,
                      'sleep': double.tryParse(sleepController.text),
                      'water': double.tryParse(waterController.text),
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    // Update local state
                    setState(() {
                      weight = weightController.text;
                      bodyFat = bodyFatController.text;
                      exertionLevel = exertionController.text;
                      sleep = sleepController.text;
                      water = waterController.text;
                    });

                    Navigator.pop(context);
                  } catch (e) {
                    print("Error updating user data: $e");
                  }
                }
              },
              child: Text(
                "Save",
                style: GoogleFonts.roboto(color: Colors.orange),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.roboto(color: Colors.orange),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.orange),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.orange),
          ),
        ),
        style: GoogleFonts.roboto(color: Colors.white),
        controller: controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.orange),
          onPressed: () {
            // Navigate back to HomePage
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => HomePage(),
              ),
            );
          },
        ),
        backgroundColor: Colors.black,
        actions: [
          Icon(Icons.pedal_bike, color: Colors.orange, size: 28),
        ],
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: dates.length,
                  itemBuilder: (context, index) {
                    final date = dates[index];
                    bool isSelected =
                        selectedDate == "${date['day']} ${date['date']}";

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedDate = "${date['day']} ${date['date']}";
                        });
                        _fetchUserData(); // Fetch data for the selected date
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0),
                        width: 60,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.orange : Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              date['day']!,
                              style: GoogleFonts.roboto(
                                color: isSelected ? Colors.white : Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              date['date']!,
                              style: GoogleFonts.roboto(
                                color: isSelected ? Colors.white : Colors.black,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
              // Edit Button
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.edit, color: Colors.orange),
                  onPressed: _showEditDialog,
                ),
              ),
              SizedBox(height: 20),
              // Expanded User Data Section
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "User Data",
                        style: GoogleFonts.roboto(
                          color: Colors.orange,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      _buildDataRow("Weight", "$weight kg"),
                      _buildDataRow("Body Fat", "$bodyFat %"),
                      _buildDataRow("Exertion Level", exertionLevel),
                      _buildDataRow("Sleep", "$sleep hours"),
                      _buildDataRow("Water", "$water liters"),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: GoogleFonts.roboto(
              color: Colors.grey[400],
              fontSize: 18,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.roboto(
              color: Colors.orange,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
