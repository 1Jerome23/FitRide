import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StravaWebView extends StatefulWidget {
  final String initialUrl;
  final void Function(String) onRedirect;
  final Function(bool success, String message)? onAuthComplete;

  const StravaWebView({
    Key? key,
    required this.initialUrl,
    required this.onRedirect,
    this.onAuthComplete,
  }) : super(key: key);

  @override
  _StravaWebViewState createState() => _StravaWebViewState();
}
Future<String?> getStravaUserId() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? stravaUserId = prefs.getString('stravaUserId');

  if (stravaUserId == null) {
    print("Strava User ID not found in SharedPreferences. Checking Firestore...");
    User? user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('user_tokens')
          .doc(user.uid)
          .get();
          
      if (snapshot.exists) {
        stravaUserId = snapshot.get('stravaUserId');
        if (stravaUserId != null) {
          await prefs.setString('stravaUserId', stravaUserId);
          print("Retrieved Strava User ID from Firestore: $stravaUserId");
        }
      }
    }
  }
  
  print("Final Strava User ID: $stravaUserId");
  return stravaUserId;
}


class _StravaWebViewState extends State<StravaWebView> {
  late final WebViewController _controller;
  bool _isExchangingCode = false; 

  String userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.6834.163 Safari/537.36";


@override
void initState() {
  super.initState();

  _eraseCookies().then((_) {
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
                  if (mounted) {
                    Navigator.pop(context, {
                      'success': success,
                      'message': success
                          ? 'Strava authentication successful!'
                          : 'Failed to authenticate with Strava. Please try again.'
                    });

                    if (widget.onAuthComplete != null) {
                      widget.onAuthComplete!(
                        success,
                        success
                            ? 'Strava authentication successful!'
                            : 'Failed to authenticate with Strava. Please try again.'
                      );
                    }
                  }
                });
                return NavigationDecision.prevent;
              } else {
                print("Authorization failed: No valid code found.");
                if (mounted) {
                  Navigator.pop(context, {
                    'success': false,
                    'message': 'Authorization failed: No valid code found.'
                  });

                  if (widget.onAuthComplete != null) {
                    widget.onAuthComplete!(
                        false, 'Authorization failed: No valid code found.');
                  }
                }
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));

    setState(() {}); // Trigger rebuild after initializing `_controller`
  });
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
        final String stravaUserId = data['athlete']['id'].toString();
        final String expiresAt = data['expires_at'].toString();
        final String accessToken = data['access_token'].toString();
        final String refreshToken = data['refresh_token'].toString();
        final String userId = data['athlete']['id'].toString();
        print("Strava User ID: $stravaUserId");

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('stravaUserId', stravaUserId);
        if (userId != null) {
          await FirebaseFirestore.instance
              .collection('user_tokens')
              .doc(userId)
              .set({
            'stravaUserId': stravaUserId,
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

  Future<void> _eraseCookies() async {
  final WebViewCookieManager cookieManager = WebViewCookieManager();
  await cookieManager.clearCookies();
  print("All WebView cookies erased. Strava login should now require fresh credentials.");
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
        'app_id': FirebaseAuth.instance.currentUser?.uid ??'',

      });
      print('Athlete data saved to Firestore.');
    } catch (e) {
      print('Error saving athlete data to Firestore: $e');
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
      appBar: AppBar(
        title: const Text('Strava Authentication'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, {
              'success': false,
              'message': 'Authentication cancelled'
            });
          },
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}