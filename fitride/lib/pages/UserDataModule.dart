import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting

void main() {
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
  late String selectedDate; // For tracking the selected date

  @override
  void initState() {
    super.initState();

    // Initialize the dates, including today as the latest date
    dates = _generateDateList();
    selectedDate =
        "${DateFormat.E().format(DateTime.now())} ${DateFormat.d().format(DateTime.now())}";
  }

  // Generate a list of the past 7 days, ending on today's date
  List<Map<String, String>> _generateDateList() {
    List<Map<String, String>> dateList = [];
    DateTime today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime date = today.subtract(Duration(days: i));
      dateList.add({
        "day": DateFormat.E().format(date), // Mon, Tue, etc.
        "date": DateFormat.d().format(date), // Numeric date
      });
    }
    return dateList;
  }

  // Show a date picker for selecting an older date
  Future<void> _showCalendar() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020), // Limit to recent years
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.orange, // Header background color
              onPrimary: Colors.black, // Header text color
              surface: Colors.black, // Surface color
              onSurface: Colors.white, // Text color
            ),
            dialogBackgroundColor: Colors.black,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate =
            "${DateFormat.E().format(pickedDate)} ${DateFormat.d().format(pickedDate)}";
        print("Selected Date: $selectedDate"); // Debugging
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "FitRide",
                    style: GoogleFonts.roboto(
                      color: Colors.orange,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.pedal_bike,
                    color: Colors.orange,
                    size: 28,
                  ),
                ],
              ),
              SizedBox(height: 20),
              // Greeting Section
              Text(
                "Hello, Name!",
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Here is the data we've gathered from you!",
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 20),
              // Scrollable Date Selector
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
                          print("Selected Date: $selectedDate"); // Debugging
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0),
                        width: 60,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.orange : Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            ),
                          ],
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
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _showCalendar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  "More",
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              Spacer(),
              // Data Cards
              buildDataCard("Weight", "80kg"),
              buildDataCard("Height", "170cm"),
              buildDataCard("BMI", "27.68"),
              SizedBox(height: 10),
              // Status Button
              Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Overweight",
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Start Journey Button
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  "Start Journey!",
                  style: GoogleFonts.roboto(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Function to build Data Cards
  Widget buildDataCard(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.roboto(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
