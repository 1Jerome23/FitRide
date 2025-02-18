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
  String bodyWater = "-";
  String foodTaken = "-";
  String hydration = "-";
  String levelofExertion = "-";
  String averageHeartrate = "-";
  String averageSpeed = "-";
  String caloriesBurned = "-";
  String distance = "-";
  String type = "-";

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

      // Fetch data from User Questionnaire collection
      DocumentSnapshot userQuestionnaireDoc = await FirebaseFirestore.instance
          .collection('User Questionnaire')
          .doc(uid)
          .get();

      // Fetch data from after_exercise collection for the selected date
      DocumentSnapshot afterExerciseDoc = await FirebaseFirestore.instance
          .doc(uid)
          .collection('after_exercise')
          .doc(fullDate)
          .get();

      // Fetch data from activities collection for the selected date
      DocumentSnapshot activitiesDoc = await FirebaseFirestore.instance
          .collection('activities')
          .doc(uid)
          .collection('after_exercise')
          .doc(fullDate)
          .get();

      if (userQuestionnaireDoc.exists) {
        setState(() {
          weight = userQuestionnaireDoc['weight']?.toString() ?? "-";
          bodyFat = userQuestionnaireDoc['bodyFat']?.toString() ?? "-";
          bodyWater = userQuestionnaireDoc['bodyWater']?.toString() ?? "-";
        });
      } else {
        setState(() {
          weight = "No data found";
          bodyFat = "No data found";
          bodyWater = "No data found";
        });
      }

      if (afterExerciseDoc.exists) {
        setState(() {
          foodTaken = afterExerciseDoc['foodTaken']?.toString() ?? "-";
          hydration = afterExerciseDoc['hydration']?.toString() ?? "-";
          levelofExertion =
              afterExerciseDoc['levelofExertion']?.toString() ?? "-";
        });
      } else {
        setState(() {
          foodTaken = "No data found";
          hydration = "No data found";
          levelofExertion = "No data found";
        });
      }

      if (activitiesDoc.exists) {
        setState(() {
          averageHeartrate =
              activitiesDoc['average_heartrate']?.toString() ?? "-";
          averageSpeed = activitiesDoc['average_speed']?.toString() ?? "-";
          caloriesBurned = activitiesDoc['calories_burned']?.toString() ?? "-";
          distance = activitiesDoc['distance']?.toString() ?? "-";
          type = activitiesDoc['type']?.toString() ?? "-";
        });
      } else {
        setState(() {
          averageHeartrate = "No data found";
          averageSpeed = "No data found";
          caloriesBurned = "No data found";
          distance = "No data found";
          type = "No data found";
        });
      }
    } catch (e) {
      setState(() {
        weight = "No data found";
        bodyFat = "No data found";
        bodyWater = "No data found";
        foodTaken = "No data found";
        hydration = "No data found";
        levelofExertion = "No data found";
        averageHeartrate = "No data found";
        averageSpeed = "No data found";
        caloriesBurned = "No data found";
        distance = "No data found";
        type = "No data found";
      });
      print("Error fetching user data: $e");
    }
  }

  void _showEditDialog() {
    TextEditingController weightController =
        TextEditingController(text: weight);
    TextEditingController bodyFatController =
        TextEditingController(text: bodyFat);
    TextEditingController bodyWaterController =
        TextEditingController(text: bodyWater);
    TextEditingController foodTakenController =
        TextEditingController(text: foodTaken);
    TextEditingController hydrationController =
        TextEditingController(text: hydration);
    TextEditingController exertionController =
        TextEditingController(text: levelofExertion);
    TextEditingController heartrateController =
        TextEditingController(text: averageHeartrate);
    TextEditingController speedController =
        TextEditingController(text: averageSpeed);
    TextEditingController caloriesController =
        TextEditingController(text: caloriesBurned);
    TextEditingController distanceController =
        TextEditingController(text: distance);
    TextEditingController typeController = TextEditingController(text: type);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            "Update User Data",
            style: GoogleFonts.roboto(color: Colors.orange),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditField("Weight (kg)", weightController),
                _buildEditField("Body Fat (%)", bodyFatController),
                _buildEditField("Body Water (%)", bodyWaterController),
                _buildEditField("Food Taken", foodTakenController),
                _buildEditField("Hydration (liters)", hydrationController),
                _buildEditField("Level of Exertion (1-10)", exertionController),
                _buildEditField("Average Heartrate (bpm)", heartrateController),
                _buildEditField("Average Speed (km/h)", speedController),
                _buildEditField("Calories Burned", caloriesController),
                _buildEditField("Distance (km)", distanceController),
                _buildEditField("Weight Training", typeController),
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
                    // Update User Questionnaire collection
                    await FirebaseFirestore.instance
                        .collection('User Questionnaire')
                        .doc(uid)
                        .set({
                      'weight': double.tryParse(weightController.text),
                      'bodyFat': double.tryParse(bodyFatController.text),
                      'bodyWater': double.tryParse(bodyWaterController.text),
                    });

                    // Update after_exercise collection
                    await FirebaseFirestore.instance
                        .collection('after_exercise')
                        .doc(uid)
                        .collection('dailyData')
                        .doc(fullDate)
                        .set({
                      'foodTaken': foodTakenController.text,
                      'hydration': double.tryParse(hydrationController.text),
                      'levelofExertion': exertionLevelValue,
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    // Update activities collection
                    await FirebaseFirestore.instance
                        .collection('activities')
                        .doc(uid)
                        .collection('dailyData')
                        .doc(fullDate)
                        .set({
                      'average_heartrate':
                          double.tryParse(heartrateController.text),
                      'average_speed': double.tryParse(speedController.text),
                      'calories_burned':
                          double.tryParse(caloriesController.text),
                      'distance': double.tryParse(distanceController.text),
                      'type': typeController.text,
                      'start_date': DateTime.now()
                          .toIso8601String(), // Automatically set the date
                    });

                    // Update local state
                    setState(() {
                      weight = weightController.text;
                      bodyFat = bodyFatController.text;
                      bodyWater = bodyWaterController.text;
                      foodTaken = foodTakenController.text;
                      hydration = hydrationController.text;
                      levelofExertion = exertionController.text;
                      averageHeartrate = heartrateController.text;
                      averageSpeed = speedController.text;
                      caloriesBurned = caloriesController.text;
                      distance = distanceController.text;
                      type = typeController.text;
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar
              SizedBox(
                height: 60,
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
                        width: 50,
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
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              date['date']!,
                              style: GoogleFonts.roboto(
                                color: isSelected ? Colors.white : Colors.black,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
              // Edit Button
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.edit, color: Colors.orange),
                  onPressed: _showEditDialog,
                ),
              ),
              SizedBox(height: 16),
              // Expanded User Data Section
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "User Data",
                          style: GoogleFonts.roboto(
                            color: Colors.orange,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildDataRow("Weight", "$weight kg"),
                        _buildDataRow("Body Fat", "$bodyFat %"),
                        _buildDataRow("Body Water", "$bodyWater %"),
                        _buildDataRow("Food Taken", foodTaken),
                        _buildDataRow("Hydration", "$hydration liters"),
                        _buildDataRow("Level of Exertion", levelofExertion),
                        _buildDataRow(
                            "Average Heartrate", "$averageHeartrate bpm"),
                        _buildDataRow("Average Speed", "$averageSpeed km/h"),
                        _buildDataRow(
                            "Calories Burned", "$caloriesBurned kcal"),
                        _buildDataRow("Distance", "$distance km"),
                        _buildDataRow("Type", type),
                      ],
                    ),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: GoogleFonts.roboto(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.roboto(
              color: Colors.orange,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
