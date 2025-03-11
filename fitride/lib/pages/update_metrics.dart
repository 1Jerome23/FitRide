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

class _UpdateMetricsPageState extends State<UpdateMetricsPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _metabolicRateController = TextEditingController();
  
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  
  final Color orangeColor = const Color(0xffFFA500);
  final Color darkGrey = const Color(0xFF303030);
  
  AnimationController? _animationController;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _animationController!.forward();
  }
  
  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _metabolicRateController.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Clear cache by forcing a fresh Firestore query
      FirebaseFirestore.instance.clearPersistence();
      
      final userData = await getLatestUserData();
      
      if (userData != null) {
        log('Retrieved user data: $userData');
        
        // Clear controllers first
        _weightController.clear();
        _bodyFatController.clear();
        _metabolicRateController.clear();
        
        setState(() {
          _userData = userData;
          
          if (userData.containsKey('weight')) {
            _weightController.text = userData['weight'].toString();
            log('Weight loaded: ${_weightController.text}');
          }
          
          if (userData.containsKey('bodyFat')) {
            _bodyFatController.text = userData['bodyFat'].toString();
            log('Body Fat loaded: ${_bodyFatController.text}');
          }
          
          if (userData.containsKey('basalMetabolicRate')) {
            // Debug the value and type
            log('BMR from Firebase: ${userData['basalMetabolicRate']}');
            log('BMR type: ${userData['basalMetabolicRate'].runtimeType}');
            
            // Always treat as number for display consistency with other fields
            var bmrValue = userData['basalMetabolicRate'];
            if (bmrValue is String) {
              // If it's stored as string, convert to number first then back to string
              _metabolicRateController.text = double.tryParse(bmrValue)?.toString() ?? bmrValue;
            } else {
              // If it's already a number (int or double), just convert to string
              _metabolicRateController.text = bmrValue.toString();
            }
            
            log('Metabolic Rate loaded: ${_metabolicRateController.text}');
          } else {
            log('basalMetabolicRate field not found in user data');
          }
        });
      } else {
        log('No user data retrieved');
      }
    } catch (e) {
      log('Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading your data: $e'),
            backgroundColor: Colors.red,
          ),
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
      log('Getting data for user: $uid');
      
      // Use no-cache option to force a refresh from the server
      final userSnapshot = await FirebaseFirestore.instance
          .collection('userData')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get(GetOptions(source: Source.server)); // Force server refresh
      
      if (userSnapshot.docs.isEmpty) {
        log('No documents found for user');
        return null;
      }
      
      log('Document ID: ${userSnapshot.docs.first.id}');
      log('Document data: ${userSnapshot.docs.first.data()}');
      
      // Explicitly check for the basalMetabolicRate field
      var data = userSnapshot.docs.first.data();
      if (data.containsKey('basalMetabolicRate')) {
        log('Found basalMetabolicRate in latest document: ${data['basalMetabolicRate']}');
      } else {
        log('WARNING: basalMetabolicRate not found in latest document!');
      }
      
      return data;
    } catch (e) {
      log('Error getting user data: $e');
      return null;
    }
  }

  Future<bool> saveUserMetrics({
    required double weight,
    required double bodyFat,
    required double metabolicRate,
  }) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        log('No current user found');
        return false;
      }
      
      final String uid = currentUser.uid;
      log('Saving metrics for user: $uid');
      log('Values to save - Weight: $weight, Body Fat: $bodyFat, BMR: $metabolicRate');
      
      final userSnapshot = await FirebaseFirestore.instance
          .collection('userData')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (userSnapshot.docs.isEmpty) {
        log('No user data found');
        return false;
      }
      
      final userData = userSnapshot.docs.first.data();
      log('Previous data: $userData');
      
      Map<String, dynamic> newData = Map.from(userData);

      // Update the values - keep weight and bodyFat as numbers since that's working
      newData['timestamp'] = Timestamp.now();
      newData['weight'] = weight; // Keep as number
      newData['bodyFat'] = bodyFat; // Keep as number
      newData['basalMetabolicRate'] = metabolicRate; // Store as number to match others
      
      log('New data to save: $newData');
      
      // Add as a new document, not updating the existing one
      DocumentReference docRef = await FirebaseFirestore.instance.collection('userData').add(newData);
      log('Saved new document with ID: ${docRef.id}');
      
      // Verify the data was saved correctly by reading it back
      DocumentSnapshot savedDoc = await docRef.get();
      if (savedDoc.exists) {
        var savedData = savedDoc.data() as Map<String, dynamic>;
        if (savedData.containsKey('basalMetabolicRate')) {
          log('Verified basalMetabolicRate was saved: ${savedData['basalMetabolicRate']}');
        } else {
          log('ERROR: basalMetabolicRate field missing from saved document!');
          return false;
        }
      }
      
      log('User metrics saved successfully');
      
      await scheduleWeeklyMetricsUpdate();
      return true;
    } catch (e) {
      log('Error saving user metrics: $e');
      throw e; 
    }
  }

  Future<void> scheduleWeeklyMetricsUpdate() async {
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
          FlutterLocalNotificationsPlugin();
      
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
              
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isScheduled = prefs.getBool('metrics_notification_scheduled') ?? false;
      
      if (!isScheduled) {
        await flutterLocalNotificationsPlugin.cancel(0);
        
        final now = tz.TZDateTime.now(tz.local);
        final scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + 7,
          10, 
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
        
        await prefs.setBool('metrics_notification_scheduled', true);
        
        log('Weekly metrics update notification scheduled for $scheduledDate');
      }
    } catch (e) {
      log('Error scheduling notification: $e');
    }
  }
  
  Future<void> _saveMetrics() async {
    if (_formKey.currentState!.validate()) {
      log('Form validated. Values - Weight: ${_weightController.text}, Body Fat: ${_bodyFatController.text}, BMR: ${_metabolicRateController.text}');
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        double weight = double.parse(_weightController.text);
        double bodyFat = double.parse(_bodyFatController.text);
        double metabolicRate = double.parse(_metabolicRateController.text);
        
        log('Parsed values - Weight: $weight, Body Fat: $bodyFat, BMR: $metabolicRate');
        
        // Add direct field check and update
        bool success = await saveUserMetrics(
          weight: weight,
          bodyFat: bodyFat,
          metabolicRate: metabolicRate,
        );
        
        if (!success) {
          throw Exception("Failed to save metrics - no data was updated");
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Your metrics have been updated!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Instead of just popping, we'll pop and pass back a result to trigger a refresh
          Navigator.pop(context, true);  // Pass true to indicate data was updated
        }
      } catch (e) {
        log('Error saving metrics: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving your metrics: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      log('Form validation failed');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        title: const Text(
          "Update Metrics",
          style: TextStyle(
            fontFamily: 'Fredoka-SemiBold',
            color: Color(0xffFFA500),
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: orangeColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(orangeColor),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    
                    Container(
                      margin: EdgeInsets.only(bottom: 15),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: orangeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.monitor_weight_outlined,
                              color: orangeColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Your Health Metrics",
                            style: TextStyle(
                              fontFamily: 'Fredoka-SemiBold',
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _weightController,
                            labelText: 'Weight (kg)',
                            icon: Icons.monitor_weight,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                            ],
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
                          
                          _buildTextField(
                            controller: _bodyFatController,
                            labelText: 'Body Fat (%)',
                            icon: Icons.percent,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                            ],
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
                          
                          _buildTextField(
                            controller: _metabolicRateController,
                            labelText: 'Metabolic Rate (calories/day)',
                            icon: Icons.local_fire_department,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              log('Validating BMR: $value');
                              if (value == null || value.isEmpty) {
                                log('BMR validation failed: empty');
                                return 'Please enter your metabolic rate';
                              }
                              if (int.tryParse(value) == null) {
                                log('BMR validation failed: not an integer: $value');
                                return 'Please enter a valid number';
                              }
                              log('BMR validation passed: $value');
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 25),
                    
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [orangeColor.withOpacity(0.8), orangeColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: orangeColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: _isLoading ? null : _saveMetrics,
                          child: Center(
                            child: _isLoading
                                ? CircularProgressIndicator(color: Colors.white)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.save_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        "SAVE METRICS",
                                        style: TextStyle(
                                          fontFamily: 'Fredoka-SemiBold',
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required TextInputType keyboardType,
    required List<TextInputFormatter> inputFormatters,
    required String? Function(String?) validator,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            fontFamily: 'Inter',
            color: Colors.grey[700],
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: orangeColor,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: TextStyle(
          fontFamily: 'Inter',
          color: Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
      ),
    );
  }
}