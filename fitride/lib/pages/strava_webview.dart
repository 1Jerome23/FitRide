import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'recommendation.dart';

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

  String userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.106 Safari/537.36";

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(userAgent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (String url) {
          if (url.startsWith('https://fitride.trycloudflare.com/callback')) {
            widget.onRedirect(url);
            Navigator.pop(context);
            _handleRedirect(url);
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  void _handleRedirect(String url) {
    final Uri uri = Uri.parse(url);
    final String? code = uri.queryParameters['code'];

    if (code != null) {
      _exchangeAuthorizationCodeForTokens(code);
    }
  }

  Future<void> _exchangeAuthorizationCodeForTokens(String code) async {
    final response = await http.post(
      Uri.parse('https://www.strava.com/oauth/token'),
      body: {
        'client_id': '146485',
        'client_secret': '6e8f87ec4856b0793c009aaf3dc17ff9a941f50f',
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': 'https://fitride.trycloudflare.com/callback', 
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final String accessToken = data['access_token'];
      final String refreshToken = data['refresh_token'];

      await _saveTokensToFirestore(accessToken, refreshToken);
    } else {
      print('Error exchanging authorization code: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to authorize Strava. Please try again.')),
      );
    }
  }

  Future<void> _saveTokensToFirestore(String accessToken, String refreshToken) async {
    final User? user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User is not logged in. Please log in first.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('user_tokens').doc(user.uid).set({
        'access_token': accessToken,
        'refresh_token': refreshToken,
      });

      print('Tokens saved in Firestore');
    } catch (e) {
      print('Error saving tokens to Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save tokens. Please try again.')),
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RecommendationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Strava Authentication'),
      ),
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: StravaWebView(
        initialUrl: 'https://www.strava.com/oauth/mobile/authorize?client_id=146485&redirect_uri=https://fitride.trycloudflare.com/callback&response_type=code&scope=activity:read_allapproval_prompt=force&login=true',
        onRedirect: (url) {
          print('Redirect URL: $url');
        },
      ),
    );
  }
}
