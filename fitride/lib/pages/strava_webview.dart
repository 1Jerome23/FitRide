import 'package:fitride/pages/profile.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class StravaWebView extends StatefulWidget {
  final String initialUrl;
  final void Function(String) onRedirect;

  const StravaWebView({
    Key? key,
    required this.initialUrl,
    required this.onRedirect,
  }) : super(key: key);

  @override
  _StravaWebViewState createState() => _StravaWebViewState();
}

class _StravaWebViewState extends State<StravaWebView> {
  late final WebViewController _controller;
  bool _isExchangingCode = false; 

  String userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.6834.163 Safari/537.36";

 @override
void initState() {
  super.initState();
  _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setUserAgent(userAgent)
    ..setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) {
          print("Navigating to: ${request.url}");
          if (request.url.startsWith('https://fitride.uk/callback')) {
            Uri uri = Uri.parse(request.url);
            String? authCode = uri.queryParameters['code'];
            if (authCode != null && !_isExchangingCode) {
              print("Extracted Auth Code: $authCode");
              _isExchangingCode = true; 
              _exchangeAuthorizationCodeForTokens(authCode).then((success) {
                if (success && mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePage()),
                  );
                }
              });
              return NavigationDecision.prevent; 
            } else {
              print("Authorization failed: No valid code found.");
            }
          }
          return NavigationDecision.navigate;
        },
      ),
    )
    ..loadRequest(Uri.parse(widget.initialUrl));
}

  Future<bool> _exchangeAuthorizationCodeForTokens(String code) async {
    const String clientId = "146485";
    const String clientSecret =
        "6e8f87ec4856b0793c009aaf3dc17ff9a941f50f"; 

    try {
      final response = await http.post(
        Uri.parse('https://www.strava.com/oauth/token'),
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String expiresAt = data['expires_at'].toString();
        final String accessToken = data['access_token'].toString();
        final String refreshToken = data['refresh_token'].toString();
        final String userId = data['athlete']['id'].toString();

        if (userId != null) {
          await FirebaseFirestore.instance
              .collection('user_tokens')
              .doc(userId)
              .set({
            'expires_at': expiresAt,
            'access_token': accessToken,
            'refresh_token': refreshToken,
          });

          print('Tokens saved in Firestore');
          await _fetchStravaData(userId, accessToken);
          await _subscribeToStravaWebhook();
          return true; 
        } else {
          print('User is not authenticated.');
          return false;
        }
      } else {
        print('Error exchanging authorization code: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error during token exchange: $e');
      return false;
    } finally {
      _isExchangingCode = false; 
    }
  }

Future<void> _fetchStravaData(String userId, String accessToken) async {
    if (userId != null) {
      try {
        final athleteResponse = await http.get(
          Uri.parse('https://www.strava.com/api/v3/athlete'),
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (athleteResponse.statusCode == 200) {
          final Map<String, dynamic> athleteData = json.decode(athleteResponse.body);
          print("Athlete Data: $athleteData");

          await _saveAthleteDataToFirestore(userId, athleteData);
        } else {
          print('Error fetching athlete data: ${athleteResponse.body}');
        }

        final activitiesResponse = await http.get(
          Uri.parse('https://www.strava.com/api/v3/athlete/activities'),
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (activitiesResponse.statusCode == 200) {
          final List<dynamic> activitiesData = json.decode(activitiesResponse.body);
          print("Activities Data: $activitiesData");

          await _saveActivitiesDataToFirestore(userId, activitiesData);
        } else {
          print('Error fetching activities: ${activitiesResponse.body}');
        }
      } catch (e) {
        print('Error fetching Strava data: $e');
      } finally {
        setState(() {
        });
      }
    }
  }

  Future<void> _saveAthleteDataToFirestore(String userId, Map<String, dynamic> athleteData) async {
    try {
      await FirebaseFirestore.instance.collection('athletes').doc(userId).set({
        'athlete_name': '${athleteData['firstname']} ${athleteData['lastname']}',
        'sex': athleteData['sex'] ?? '',
        'country': athleteData['country'] ?? '',
        'city': athleteData['city'] ?? '',
        'weight': athleteData['weight'] ?? '',
        'bio': athleteData['bio'] ?? '',
        'created_at': athleteData['created_at'] ?? '',
        'updated_at': athleteData['updated_at'] ?? '',
      });
      print('Athlete data saved to Firestore.');
    } catch (e) {
      print('Error saving athlete data to Firestore: $e');
    }
  }

 Future<void> _saveActivitiesDataToFirestore(String userId, List<dynamic> activitiesData) async {
  try {
    final batch = FirebaseFirestore.instance.batch();

    for (var activity in activitiesData) {

      double distanceInKm = (activity['distance'] ?? 0) / 1000; 
      double averageSpeedInKmh = (activity['average_speed'] ?? 0) * 3.6;
      double averageHeartRate = (activity['average_heartrate'] ?? 0); 
      double caloriesBurned = (activity['calories'] ?? 0);  

      final activityRef = FirebaseFirestore.instance.collection('activities').doc();
      batch.set(activityRef, {
        'user_id': userId,
        'name': activity['name'] ?? 'Unnamed Activity',
        'distance': distanceInKm, 
        'start_date': activity['start_date'] ?? '',
        'type': activity['type'] ?? '',
        'average_speed': averageSpeedInKmh,
        'average_heartrate': averageHeartRate,
        'calories_burned': caloriesBurned,  
      });
    }

    await batch.commit();
    print('Activities data saved to Firestore.');
  } catch (e) {
    print('Error saving activities data to Firestore: $e');
  }
}

Future<void> _subscribeToStravaWebhook() async {
  final String clientId = "146485";
  final String clientSecret = "6e8f87ec4856b0793c009aaf3dc17ff9a941f50f";
  final String callbackUrl = 'https://fitride.uk/webhook'; 
  final String verifyToken = 'STRAVA';

  try {
    print('Creating webhook subscription...');
    print('Request Body: ${{
      'client_id': clientId,
      'client_secret': clientSecret,
      'callback_url': callbackUrl,
      'verify_token': verifyToken,
    }}');

    final response = await http.post(
      Uri.parse('https://www.strava.com/api/v3/push_subscriptions'),
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'callback_url': callbackUrl,
        'verify_token': verifyToken,
      },
    );

    print('Response Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 201) {
      print('Webhook subscription created successfully: ${response.body}');
    } else {
      print('Error creating webhook subscription: ${response.body}');
    }
  } catch (e) {
    print('Error during webhook subscription: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Strava Authentication')),
      body: WebViewWidget(controller: _controller),
    );
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitRide',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StravaWebView(
        initialUrl:
            'https://www.strava.com/oauth/mobile/authorize?client_id=146485&redirect_uri=https://fitride.uk/callback&response_type=code&scope=activity:read_all&approval_prompt=force&login=true',
        onRedirect: (authCode) {
          print('Authorization Code: $authCode');
        },
      ),
    );
  }
}
