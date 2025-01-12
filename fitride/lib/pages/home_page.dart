import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

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
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          titleLarge: TextStyle(color: Colors.white),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFF89C23), 
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFFF89C23),  
          unselectedItemColor: Colors.grey,      
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: Color(0xFFF89C23),      
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

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _fetchWeather();
  }

  // Load user preferences
  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = _prefs.getString('userName') ?? '';
    });

    // If name is not set, ask for it
    if (_name.isEmpty) {
      _askForName();
    }
  }

  // Ask the user for their name
  void _askForName() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController nameController = TextEditingController();
        return AlertDialog(
          title: Text('Enter your name'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(hintText: 'Your name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _saveName(nameController.text);
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Save name to SharedPreferences
  Future<void> _saveName(String name) async {
    _prefs.setString('userName', name);
    setState(() {
      _name = name;
    });
  }

  // Fetch weather based on the user's current location
  Future<void> _fetchWeather() async {
    Position? position = await _getCurrentLocation();
    if (position != null) {
      final response = await http.get(Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current_weather=true'
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

  // Get the current location using Geolocator
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

  void _retryFetchWeather() {
    setState(() {
      isLoading = true;
      locationError = false;
      weatherError = false;
      _weatherMessage = '';
      _weatherImage = ''; 
    });
    _fetchWeather();
  }

  Widget _greeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, $_name!',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const Text(
          'Welcome to FitRide',
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
        SizedBox(height: 20),
        isLoading
            ? const CircularProgressIndicator()
            : locationError
                ? Column(
                    children: [
                      Text(
                        _weatherMessage,
                        style: const TextStyle(fontSize: 16, color: Colors.black),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _retryFetchWeather,
                        child: const Text("Enable Location & Retry"),
                      ),
                    ],
                  )
                : weatherError
                    ? Column(
                        children: [
                          Text(
                            _weatherMessage,
                            style: const TextStyle(fontSize: 16, color: Colors.black),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _retryFetchWeather,
                            child: const Text("Retry"),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Text(
                            _weatherMessage,
                            style: const TextStyle(fontSize: 16, color: Colors.black),
                          ),
                          SizedBox(height: 20),
                          Image.asset(_weatherImage, height: 200),  // Display weather image
                        ],
                      ),
      ],
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FitRide'),
        backgroundColor: Theme.of(context).primaryColor,
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
            icon: Icon(Icons.record_voice_over),
            label: 'Record',
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
}
