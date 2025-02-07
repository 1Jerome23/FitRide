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
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.106 Safari/537.36";

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
        final String accessToken = data['access_token'];
        final String refreshToken = data['refresh_token'];
        final userId = FirebaseAuth.instance.currentUser?.uid;

        if (userId != null) {
          await FirebaseFirestore.instance
              .collection('user_tokens')
              .doc(userId)
              .set({
            'access_token': accessToken,
            'refresh_token': refreshToken,
          });

          print('Tokens saved in Firestore');
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
