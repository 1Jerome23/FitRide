import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class UpdateMetricsPage extends StatefulWidget {
  const UpdateMetricsPage({Key? key}) : super(key: key);

  @override
  _UpdateMetricsPageState createState() => _UpdateMetricsPageState();
}

class _UpdateMetricsPageState extends State<UpdateMetricsPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _metabolicRateController = TextEditingController();
  
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _metabolicRateController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userData = await getLatestUserData();
      
      if (userData != null) {
        setState(() {
          _userData = userData;
          
          // Pre-fill with last values if available
          if (userData.containsKey('weight')) {
            _weightController.text = userData['weight'].toString();
          }
          
          if (userData.containsKey('bodyFat')) {
            _bodyFatController.text = userData['bodyFat'].toString();
          }
          
          if (userData.containsKey('basalMetabolicRate')) {
            _metabolicRateController.text = userData['basalMetabolicRate'].toString();
          }
        });
      }
    } catch (e) {
      log('Error loading user data: $e');
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading your data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> getLatestUserData() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;
      
      final String uid = currentUser.uid;
      
      // Check if we have recent metrics data
      final metricsSnapshot = await FirebaseFirestore.instance
          .collection('user_metrics')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      // If we have recent metrics data, use that
      if (metricsSnapshot.docs.isNotEmpty) {
        return metricsSnapshot.docs.first.data();
      }
      
      // Otherwise, fall back to user profile data
      final userSnapshot = await FirebaseFirestore.instance
          .collection('userData')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (userSnapshot.docs.isEmpty) return null;
      
      return userSnapshot.docs.first.data();
    } catch (e) {
      log('Error getting user data: $e');
      return null;
    }
  }

  Future<void> saveUserMetrics({
    required double weight,
    required double bodyFat,
    required double metabolicRate,
  }) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      final String uid = currentUser.uid;
      
      // Get latest user data for all fields
      final userSnapshot = await FirebaseFirestore.instance
          .collection('userData')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (userSnapshot.docs.isEmpty) {
        log('No user data found');
        return;
      }
      
      final userData = userSnapshot.docs.first.data();
      
      // Create new metrics document with all original fields
      Map<String, dynamic> newData = Map.from(userData);
      
      // Update only the metrics fields
      newData['timestamp'] = Timestamp.now();
      newData['weight'] = weight;
      newData['bodyFat'] = bodyFat;
      newData['basalMetabolicRate'] = metabolicRate; // Using correct field name
      
      // Create new document in the same userData collection
      await FirebaseFirestore.instance.collection('userData').add(newData);
      
      log('User metrics saved successfully');
      
      // Schedule the next notification
      await scheduleWeeklyMetricsUpdate();
    } catch (e) {
      log('Error saving user metrics: $e');
      throw e; // Rethrow to handle in the UI
    }
  }

  Future<void> scheduleWeeklyMetricsUpdate() async {
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
          FlutterLocalNotificationsPlugin();
      
      // Request notification permissions for Android
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
              
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
      
      // Check if we already scheduled the notification
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isScheduled = prefs.getBool('metrics_notification_scheduled') ?? false;
      
      if (!isScheduled) {
        // Cancel any existing notifications with this ID
        await flutterLocalNotificationsPlugin.cancel(0);
        
        // Schedule the notification for one week from now
        final now = tz.TZDateTime.now(tz.local);
        final scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + 7,
          10, // 10 AM
        );
        
        const AndroidNotificationDetails androidPlatformChannelSpecifics =
            AndroidNotificationDetails(
          'metrics_update_channel',
          'Metrics Update Channel',
          channelDescription: 'This channel is used for weekly metrics update reminders.',
          importance: Importance.high,
          priority: Priority.high,
        );
        
        const NotificationDetails platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics,
        );
        
        await flutterLocalNotificationsPlugin.zonedSchedule(
          0,
          'Time to Update Your Metrics',
          'Please update your weight, body fat, and metabolic rate for better tracking.',
          scheduledDate,
          platformChannelSpecifics,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'update_metrics',
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        
        // Mark as scheduled
        await prefs.setBool('metrics_notification_scheduled', true);
        
        log('Weekly metrics update notification scheduled for $scheduledDate');
      }
    } catch (e) {
      log('Error scheduling notification: $e');
    }
  }
  
  Future<void> _saveMetrics() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        await saveUserMetrics(
          weight: double.parse(_weightController.text),
          bodyFat: double.parse(_bodyFatController.text),
          metabolicRate: double.parse(_metabolicRateController.text),
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your metrics have been updated!')),
          );
          
          // Navigate back after successful save
          Navigator.pop(context);
        }
      } catch (e) {
        log('Error saving metrics: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving your metrics: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Your Metrics'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Update your health metrics to track your progress',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    const SizedBox(height: 24),
                    
                    // Weight field
                    TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white24,
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                      ],
                      style: const TextStyle(color: Colors.black),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your weight';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Body Fat Percentage field
                    TextFormField(
                      controller: _bodyFatController,
                      decoration: const InputDecoration(
                        labelText: 'Body Fat (%)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white24,
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                      ],
                      style: const TextStyle(color: Colors.black),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your body fat percentage';
                        }
                        final bodyFat = double.tryParse(value);
                        if (bodyFat == null) {
                          return 'Please enter a valid number';
                        }
                        if (bodyFat < 0 || bodyFat > 100) {
                          return 'Body fat percentage must be between 0 and 100';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Metabolic Rate field
                    TextFormField(
                      controller: _metabolicRateController,
                      decoration: const InputDecoration(
                        labelText: 'Metabolic Rate (calories/day)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white24,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(color: Colors.black),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your metabolic rate';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveMetrics,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('SAVE METRICS', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}