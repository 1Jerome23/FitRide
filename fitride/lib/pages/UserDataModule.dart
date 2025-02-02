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
  String currentWeight = "-";
  String currentHeight = "-";
  String bodyFat = "-";
  String bodyWater = "-";
  String exertionLevel = "-";
  String age = "-";
  String restingHeartRate = "-";
  String preExistingConditions = "-";
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
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('User Questionnaires')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          age = userDoc['age']?.toString() ?? "-";
          currentWeight = userDoc['weight']?.toString() ?? "-";
          bodyFat = userDoc['bodyFat']?.toString() ?? "-";
          bodyWater = userDoc['bodyWater']?.toString() ?? "-";
          exertionLevel = userDoc['exertionLevel']?.toString() ?? "-";
          restingHeartRate = userDoc['restingHeartRate']?.toString() ??
              "-"; // Fetch resting heart rate
          preExistingConditions = userDoc['preExistingConditions'] ??
              "-"; // Fetch pre-existing conditions
        });
      } else {
        setState(() {
          age = "No data found";
          currentWeight = "No data found";
          bodyFat = "No data found";
          bodyWater = "No data found";
          exertionLevel = "No data found";
          restingHeartRate = "No data found"; // Default value
          preExistingConditions = "No data found"; // Default value
        });
      }
    } catch (e) {
      setState(() {
        age = "Error fetching data";
        currentWeight = "Error fetching data";
        bodyFat = "Error fetching data";
        bodyWater = "Error fetching data";
        exertionLevel = "Error fetching data";
        restingHeartRate = "Error fetching data"; // Error handling
        preExistingConditions = "Error fetching data"; // Error handling
      });
      print("Error fetching user data: $e");
    }
  }

  void _showEditDialog() {
    TextEditingController ageController = TextEditingController(text: age);
    TextEditingController weightController =
        TextEditingController(text: currentWeight);
    TextEditingController bodyFatController =
        TextEditingController(text: bodyFat);
    TextEditingController bodyWaterController =
        TextEditingController(text: bodyWater);
    TextEditingController exertionController =
        TextEditingController(text: exertionLevel);
    TextEditingController restingHeartRateController =
        TextEditingController(text: restingHeartRate); // New controller
    TextEditingController preExistingConditionsController =
        TextEditingController(text: preExistingConditions); // New controller

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
                _buildEditField("Age", ageController),
                _buildEditField("Weight (kg)", weightController),
                _buildEditField("Body Fat (%)", bodyFatController),
                _buildEditField("Body Water (%)", bodyWaterController),
                _buildEditField("Exertion Level (1-10)", exertionController),
                _buildEditField("Resting Heart Rate",
                    restingHeartRateController), // New field
                _buildEditField("Pre-existing Conditions",
                    preExistingConditionsController), // New field
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
                  try {
                    await FirebaseFirestore.instance
                        .collection('User Questionnaires')
                        .doc(uid)
                        .update({
                      'age': int.tryParse(ageController.text),
                      'weight': double.tryParse(weightController.text),
                      'bodyFat': double.tryParse(bodyFatController.text),
                      'bodyWater': double.tryParse(bodyWaterController.text),
                      'exertionLevel': exertionLevelValue,
                      'restingHeartRate': int.tryParse(
                          restingHeartRateController
                              .text), // Save resting heart rate
                      'preExistingConditions': preExistingConditionsController
                          .text, // Save pre-existing conditions
                    });

                    // Update local state
                    setState(() {
                      age = ageController.text;
                      currentWeight = weightController.text;
                      bodyFat = bodyFatController.text;
                      bodyWater = bodyWaterController.text;
                      exertionLevel = exertionController.text;
                      restingHeartRate = restingHeartRateController
                          .text; // Update resting heart rate
                      preExistingConditions = preExistingConditionsController
                          .text; // Update pre-existing conditions
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
                builder: (context) =>
                    HomePage(), // Replace with your HomePage widget
              ),
            );
          },
        ),
        // title: Text(
        //   'FitRide',
        //   style: GoogleFonts.roboto(color: Colors.orange, fontSize: 24),
        // ),
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
                      _buildDataRow("Age", age),
                      _buildDataRow("Weight", "$currentWeight kg"),
                      _buildDataRow("Body Fat", "$bodyFat %"),
                      _buildDataRow("Body Water", "$bodyWater %"),
                      _buildDataRow("Exertion Level", exertionLevel),
                      _buildDataRow("Resting Heart Rate",
                          "$restingHeartRate bpm"), // New field
                      _buildDataRow("Pre-existing Conditions",
                          preExistingConditions), // New field
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
