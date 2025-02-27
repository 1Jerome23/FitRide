import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
  String weight = "0";
  String bodyFat = "0";
  String bodyWater = "0";
  String hydration = "0";
  String levelOfExertion = "0";
  String averageHeartrate = "0";
  String averageSpeed = "0";
  String caloriesBurned = "0";
  String distance = "0";
  String sessionDuration = "0";
  String daysPerWeek = "0";
  String targetDistance = "0";
  String targetWeight = "0";
  String targetDuration = "0";
  String goalType = "-";
  String currentLevel = "0";
  String healthCondition = "-";
  String height = "0";
  bool showAllData = false;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    dates = _generateDateList();
    selectedDate =
    "${DateFormat.E().format(DateTime.now())} ${DateFormat.d().format(DateTime.now())}";
    _selectedDay = _focusedDay;
    _fetchUserData();
  }

  List<Map<String, String>> _generateDateList() {
    List<Map<String, String>> dateList = [];
    DateTime today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime date = today.subtract(Duration(days: i));
      dateList.add({
        "day": DateFormat.E().format(date),
        "date": DateFormat.d().format(date),
        "fullDate": DateFormat('yyyy-MM-dd').format(date),
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

      // Fetch data from goals collection
      DocumentSnapshot goalsDoc = await FirebaseFirestore.instance
          .collection('goals')
          .doc(uid)
          .get();

      // Fetch data from userData collection
      DocumentSnapshot userDataDoc = await FirebaseFirestore.instance
          .collection('userData')
          .doc(uid)
          .get();

      // Fetch data from after_exercise collection for the selected date
      DocumentSnapshot afterExerciseDoc = await FirebaseFirestore.instance
          .collection('after_exercise')
          .doc(uid)
          .collection('logs')
          .doc(fullDate)
          .get();

      // Fetch data from activities collection for the selected date
      DocumentSnapshot activitiesDoc = await FirebaseFirestore.instance
          .collection('activities')
          .doc(uid)
          .collection('logs')
          .doc(fullDate)
          .get();

      if (goalsDoc.exists) {
        setState(() {
          goalType = goalsDoc['goalType'] ?? "-";
          currentLevel = goalsDoc['currentLevel'] ?? "0";
          sessionDuration = goalsDoc['sessionDuration']?.toString() ?? "0";
          daysPerWeek = goalsDoc['daysPerWeek']?.toString() ?? "0";
          targetDistance = goalsDoc['targetDistance']?.toString() ?? "0";
          targetWeight = goalsDoc['targetWeight']?.toString() ?? "0";
          targetDuration = goalsDoc['targetDuration']?.toString() ?? "0";
        });
      }

      if (userDataDoc.exists) {
        setState(() {
          weight = userDataDoc['weight']?.toString() ?? "0";
          bodyFat = userDataDoc['bodyFat']?.toString() ?? "0";
          bodyWater = userDataDoc['bodyWater']?.toString() ?? "0";
          healthCondition = userDataDoc['healthCondition'] ?? "-";
          height = userDataDoc['height']?.toString() ?? "0";
        });
      }

      if (afterExerciseDoc.exists) {
        setState(() {
          hydration = afterExerciseDoc['Hydration']?.toString() ?? "0";
          levelOfExertion = afterExerciseDoc['levelOfExertion']?.toString() ?? "0";
        });
      }

      if (activitiesDoc.exists) {
        setState(() {
          averageHeartrate = activitiesDoc['average_heartrate']?.toString() ?? "0";
          averageSpeed = activitiesDoc['average_speed']?.toString() ?? "0";
          caloriesBurned = activitiesDoc['calories_burned']?.toString() ?? "0";
          distance = activitiesDoc['distance']?.toString() ?? "0";
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  void _showEditDialog() {
    TextEditingController weightController = TextEditingController(text: weight);
    TextEditingController bodyFatController = TextEditingController(text: bodyFat);
    TextEditingController bodyWaterController = TextEditingController(text: bodyWater);
    TextEditingController hydrationController = TextEditingController(text: hydration);
    TextEditingController exertionController = TextEditingController(text: levelOfExertion);
    TextEditingController heartrateController = TextEditingController(text: averageHeartrate);
    TextEditingController speedController = TextEditingController(text: averageSpeed);
    TextEditingController caloriesController = TextEditingController(text: caloriesBurned);
    TextEditingController distanceController = TextEditingController(text: distance);
    TextEditingController sessionDurationController = TextEditingController(text: sessionDuration);
    TextEditingController daysPerWeekController = TextEditingController(text: daysPerWeek);
    TextEditingController targetDistanceController = TextEditingController(text: targetDistance);
    TextEditingController targetWeightController = TextEditingController(text: targetWeight);
    TextEditingController targetDurationController = TextEditingController(text: targetDuration);
    TextEditingController goalTypeController = TextEditingController(text: goalType);
    TextEditingController currentLevelController = TextEditingController(text: currentLevel);
    TextEditingController healthConditionController = TextEditingController(text: healthCondition);
    TextEditingController heightController = TextEditingController(text: height);

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
                _buildEditField("Hydration (liters)", hydrationController),
                _buildEditField("Level of Exertion (1-10)", exertionController),
                _buildEditField("Average Heartrate (bpm)", heartrateController),
                _buildEditField("Average Speed (km/h)", speedController),
                _buildEditField("Calories Burned (kcal)", caloriesController),
                _buildEditField("Distance (km)", distanceController),
                _buildEditField("Session Duration (mins)", sessionDurationController),
                _buildEditField("Days Per Week", daysPerWeekController),
                _buildEditField("Target Distance (km)", targetDistanceController),
                _buildEditField("Target Weight (kg)", targetWeightController),
                _buildEditField("Target Duration (mins)", targetDurationController),
                _buildEditField("Goal Type", goalTypeController),
                _buildEditField("Current Level", currentLevelController),
                _buildEditField("Health Condition", healthConditionController),
                _buildEditField("Height (cm)", heightController),
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
                final exertionLevelValue = int.tryParse(exertionController.text);
                if (exertionLevelValue == null || exertionLevelValue < 1 || exertionLevelValue > 10) {
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
                    // Update goals collection
                    await FirebaseFirestore.instance
                        .collection('goals')
                        .doc(uid)
                        .set({
                      'goalType': goalTypeController.text,
                      'currentLevel': currentLevelController.text,
                      'sessionDuration': int.tryParse(sessionDurationController.text),
                      'daysPerWeek': int.tryParse(daysPerWeekController.text),
                      'targetDistance': double.tryParse(targetDistanceController.text),
                      'targetWeight': double.tryParse(targetWeightController.text),
                      'targetDuration': int.tryParse(targetDurationController.text),
                    });

                    // Update userData collection
                    await FirebaseFirestore.instance
                        .collection('userData')
                        .doc(uid)
                        .set({
                      'weight': double.tryParse(weightController.text),
                      'bodyFat': double.tryParse(bodyFatController.text),
                      'bodyWater': double.tryParse(bodyWaterController.text),
                      'healthCondition': healthConditionController.text,
                      'height': double.tryParse(heightController.text),
                    });

                    // Update after_exercise collection
                    await FirebaseFirestore.instance
                        .collection('after_exercise')
                        .doc(uid)
                        .collection('logs')
                        .doc(fullDate)
                        .set({
                      'Hydration': double.tryParse(hydrationController.text),
                      'levelOfExertion': exertionLevelValue,
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    // Update activities collection
                    await FirebaseFirestore.instance
                        .collection('activities')
                        .doc(uid)
                        .collection('logs')
                        .doc(fullDate)
                        .set({
                      'average_heartrate': double.tryParse(heartrateController.text),
                      'average_speed': double.tryParse(speedController.text),
                      'calories_burned': double.tryParse(caloriesController.text),
                      'distance': double.tryParse(distanceController.text),
                      'start_date': DateTime.now().toIso8601String(),
                    });

                    // Update local state
                    setState(() {
                      weight = weightController.text;
                      bodyFat = bodyFatController.text;
                      bodyWater = bodyWaterController.text;
                      hydration = hydrationController.text;
                      levelOfExertion = exertionController.text;
                      averageHeartrate = heartrateController.text;
                      averageSpeed = speedController.text;
                      caloriesBurned = caloriesController.text;
                      distance = distanceController.text;
                      sessionDuration = sessionDurationController.text;
                      daysPerWeek = daysPerWeekController.text;
                      targetDistance = targetDistanceController.text;
                      targetWeight = targetWeightController.text;
                      targetDuration = targetDurationController.text;
                      goalType = goalTypeController.text;
                      currentLevel = currentLevelController.text;
                      healthCondition = healthConditionController.text;
                      height = heightController.text;
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
        child: Column(
          children: [
            // Calendar (Expanded to take more space)
            Expanded(
              flex: 2, // Takes 2/3 of the screen
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      "Calendar",
                      style: GoogleFonts.roboto(
                        color: Colors.orange,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    // TableCalendar
                    Expanded(
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedDay, day);
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        onFormatChanged: (format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          weekendTextStyle: TextStyle(color: Colors.orange),
                          defaultTextStyle: TextStyle(color: Colors.white),
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false, // Hide format button
                          titleTextStyle: TextStyle(color: Colors.orange),
                          leftChevronIcon:
                          Icon(Icons.chevron_left, color: Colors.orange),
                          rightChevronIcon:
                          Icon(Icons.chevron_right, color: Colors.orange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            // User Data Section
            Expanded(
              flex: 1, // Takes 1/3 of the screen
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "User Data",
                          style: GoogleFonts.roboto(
                            color: Colors.orange,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.orange),
                              onPressed: _showEditDialog,
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  showAllData = !showAllData;
                                });
                              },
                              child: Text(
                                showAllData ? "Hide All" : "View All",
                                style: GoogleFonts.roboto(
                                  color: Colors.orange,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDataRow("Weight", "$weight kg"),
                            _buildDataRow("Body Fat", "$bodyFat %"),
                            _buildDataRow("Body Water", "$bodyWater %"),
                            if (showAllData) ...[
                              _buildDataRow("Hydration", "$hydration liters"),
                              _buildDataRow("Level of Exertion", levelOfExertion),
                              _buildDataRow("Average Heartrate", "$averageHeartrate bpm"),
                              _buildDataRow("Average Speed", "$averageSpeed km/h"),
                              _buildDataRow("Calories Burned", "$caloriesBurned kcal"),
                              _buildDataRow("Distance", "$distance km"),
                              _buildDataRow("Session Duration", "$sessionDuration mins"),
                              _buildDataRow("Days Per Week", daysPerWeek),
                              _buildDataRow("Target Distance", "$targetDistance km"),
                              _buildDataRow("Target Weight", "$targetWeight kg"),
                              _buildDataRow("Target Duration", "$targetDuration mins"),
                              _buildDataRow("Goal Type", goalType),
                              _buildDataRow("Current Level", currentLevel),
                              _buildDataRow("Health Condition", healthCondition),
                              _buildDataRow("Height", "$height cm"),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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