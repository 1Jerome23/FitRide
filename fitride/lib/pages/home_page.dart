import 'package:fitride/pages/UserDataModule.dart';
import 'package:fitride/pages/login_register.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';  
import 'question.dart'; // Import QuestionPage


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitRide',
      theme: ThemeData(
        primaryColor: Color(0xFFF89C23),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Color(0xFFF89C23),
          secondary: Color(0xFFF89C23),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: GoogleFonts.openSansTextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor: Colors.black,
                displayColor: Colors.black,
              ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFF89C23),
          elevation: 5,
          titleTextStyle: GoogleFonts.poppins(
            textStyle: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFFF89C23),
          unselectedItemColor: Colors.grey,
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: Color(0xFFF89C23),
          textTheme: ButtonTextTheme.primary, 
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFF89C23), 
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: HomePage(),
    );
  }
}


class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late SharedPreferences _prefs;
  String _name = '';
  String _weatherMessage = '';
  String _weatherImage = '';
  bool isLoading = true;
  bool locationError = false;
  bool weatherError = false;
  int _selectedIndex = 0;
  List<String> cyclingRecommendations = [
    "Make sure to stay hydrated during your ride!",
    "Always wear a helmet for safety.",
    "Start with a warm-up before any cycling session.",
    "Track your progress to stay motivated!",
    "Plan your cycling route ahead for a smooth ride.",
    "Don’t forget to take breaks during long rides.",
    "Check your tire pressure before heading out."
  ];
  int _currentRecommendationIndex = 0;
  bool _isFirstLogin = false;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
    _loadRecommendationIndex();
    _startRecommendationTimer();
    _checkFirstLogin();
    _initializePreferences();
  }


  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = _prefs.getString('userName') ?? '';
    });
  }

  Future<void> _checkFirstLogin() async {
    _prefs = await SharedPreferences.getInstance();
    bool isFirstLogin = _prefs.getBool('isFirstLogin') ?? true;

    if (isFirstLogin) {
      _prefs.setBool('isFirstLogin', false); 
      WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstLoginDialog());
    }
  }

  void _showFirstLoginDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Welcome!"),
          content: Text("We noticed this is your first time using the application."),
          actions: <Widget>[
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => QuestionPage()), // Redirect to QuestionPage
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchWeather() async {
    Position? position = await _getCurrentLocation();
    if (position != null) {
      final response = await http.get(Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current_weather=true',
      ));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('current_weather') &&
            data['current_weather'].containsKey('weathercode')) {
          final weather = data['current_weather']['weathercode'];
          setState(() {
            if (weather == 1) {
              _weatherMessage = "It's sunny today! It's a good day to take a ride.";
              _weatherImage = 'assets/sunny.png';
            } else if (weather == 2) {
              _weatherMessage = "It's rainy today. Stay safe if you're heading out!";
              _weatherImage = 'assets/images/rainy.png';
            } else if (weather == 3) {
              _weatherMessage = "It's cloudy today.";
              _weatherImage = 'assets/cloudy.png';
            } else {
              _weatherMessage = "Stormy weather ahead. Stay safe!";
              _weatherImage = 'assets/images/stormy.png';
            }
            isLoading = false;
          });
        } else {
          setState(() {
            _weatherMessage = "Weather data is incomplete.";
            weatherError = true;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          _weatherMessage = "Unable to fetch weather data.";
          weatherError = true;
          isLoading = false;
        });
      }
    } else {
      setState(() {
        locationError = true;
        isLoading = false;
      });
    }
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _weatherMessage = "Location services are disabled. Please enable them.";
      });
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        setState(() {
          _weatherMessage = "Location permissions are denied. Please grant permissions.";
        });
        return null;
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _loadRecommendationIndex() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentRecommendationIndex = _prefs.getInt('recommendationIndex') ?? 0;
    });
  }

  Future<void> _saveRecommendationIndex(int index) async {
    _prefs.setInt('recommendationIndex', index);
  }

  void _startRecommendationTimer() {
    Timer.periodic(Duration(seconds: 10), (timer) {
      _showNextRecommendation();
    });
  }

  void _showNextRecommendation() {
    setState(() {
      _currentRecommendationIndex = (_currentRecommendationIndex + 1) % cyclingRecommendations.length;
    });
    _saveRecommendationIndex(_currentRecommendationIndex);
  }

 Widget _greeting() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Hello, $_name!',
        style: GoogleFonts.poppins(
          textStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      Text(
        'Welcome to FitRide',
        style: GoogleFonts.poppins(
          textStyle: TextStyle(fontSize: 16, color: Colors.black),
        ),
      ),
      SizedBox(height: 20),
      isLoading
          ? CircularProgressIndicator()
          : locationError
              ? Column(
                  children: [
                    Text(
                      _weatherMessage,
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _fetchWeather,
                      child: Text("Enable Location & Retry"),
                    ),
                  ],
                )
              : weatherError
                  ? Column(
                      children: [
                        Text(
                          _weatherMessage,
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _fetchWeather,
                          child: Text("Retry"),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _weatherMessage,
                            style: TextStyle(fontSize: 16, color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 20),
                          Image.asset(_weatherImage, height: 200),
                        ],
                      ),
                    ),
      SizedBox(height: 30),
      
      ElevatedButton(
        onPressed: () {
          _showRecordWeatherDialog();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFF89C23),
        ),
        child: Text("Record the weather today?"),
      ),
      
      SizedBox(height: 20),

      Text(
        'Cycling Recommendation:',
        style: GoogleFonts.poppins(
          textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      SizedBox(height: 10),
      Text(
        cyclingRecommendations[_currentRecommendationIndex],
        style: TextStyle(fontSize: 16, color: Colors.black),
      ),
      SizedBox(height: 20),
    ],
  );
}
void _showRecordWeatherDialog() {
showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          'Confirmation',
          style: TextStyle(color: Colors.black), 
        ),
        content: Text(
          'Only record the weather when you\'re gonna have an activity for more accurate data analysis tailored for you!',
          style: TextStyle(color: Colors.black),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'No',
              style: TextStyle(color: Colors.black), 
            ),
          ),
          TextButton(
            onPressed: () {
              _recordWeather();
              Navigator.of(context).pop(); 
            },
            child: Text(
              'Yes',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      );
    },
  );
}
void _recordWeather() async {
  User? user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("User is not authenticated! Please log in.")),
    );
    return;
  }

  String userUID = user.uid;  

  Position? position = await _getCurrentLocation();
  if (position == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Unable to fetch location. Please enable location services.")),
    );
    return;
  }

  final response = await http.get(Uri.parse(
    'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current_weather=true',
  ));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);

    final temperature = data['current_weather']['temperature'].toString();
    final humidity = data['current_weather']['humidity'].toString();
    final airQuality = data['current_weather']['weathercode'] == 1
        ? "Good"
        : "Moderate";  

    final weatherData = {
      'temperature': temperature,
      'humidity': humidity,
      'airQuality': airQuality,
      'userUID': userUID,
      'date': DateTime.now().toIso8601String(),
    };

    FirebaseFirestore.instance.collection('weatherData').add(weatherData).then((value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Weather recorded successfully to Firebase!")),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to record weather: $error")),
      );
    });
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to fetch weather data.")),
    );
  }
}

 void _onItemTapped(int index) {
  setState(() {
    _selectedIndex = index;
  });

  switch (index) {
    case 0:
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
      break;
    case 1:
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HomePage()), // Recommendation page
      );
      break;
    case 2:
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FitRidePage()), // Data page
      );
      break;
    case 3:
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HomePage()), // Profile page
      );
      break;
  }
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false, 
      backgroundColor: Theme.of(context).primaryColor,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // FitRide Title Section
          Text(
            "FitRide",
            style: GoogleFonts.roboto(
              color: Colors.orange,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: _logout, 
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.pedal_bike,
                color: Colors.orange,
                size: 28,
              ),
            ),
          ),
        ],
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
          label: 'Data',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(20.0),
      child: _greeting(), 
    ),
  );
}

void _logout() async {

  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  await FirebaseAuth.instance.signOut();

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => LoginPage()), 
  );
}


}