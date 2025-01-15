import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class GoalTrackingPage extends StatelessWidget {
  const GoalTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF383838), // Background color #383838
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'FitRide',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title at the top
            Text(
              'Progress and Goal Tracking',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),

            // First Card: Calories Burned
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Left side: Text information
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Calories to Burn: 200',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'You are now 70% successful!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Right side: Radial gauge
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 120,
                        width: 120,
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                        ),
                        child: SfRadialGauge(
                          axes: [
                            RadialAxis(
                              pointers: [
                                RangePointer(
                                  value: 70,
                                  width: 10,
                                  cornerStyle: CornerStyle.bothCurve,
                                  gradient: SweepGradient(
                                    colors: [Color(0xFFFFC434), Color(0xFFFF8209)],
                                    stops: [0.1, 0.75],
                                  ),
                                )
                              ],
                              axisLineStyle: AxisLineStyle(
                                thickness: 10,
                                color: Colors.grey.shade300,
                              ),
                              startAngle: 150,
                              endAngle: 390,
                              showLabels: false,
                              showTicks: false,
                              annotations: [
                                GaugeAnnotation(
                                  widget: Text(
                                    '70%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Colors.black,
                                    ),
                                  ),
                                  angle: 270,
                                  positionFactor: 0.1,
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Second Card: Target Weight
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Left side: Text information
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Weight',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            '55kg',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'You are currently at 70kg. Keep it up!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Right side: Radial gauge
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 120,
                        width: 120,
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                        ),
                        child: SfRadialGauge(
                          axes: [
                            RadialAxis(
                              pointers: [
                                RangePointer(
                                  value: 40,
                                  width: 10,
                                  cornerStyle: CornerStyle.bothCurve,
                                  gradient: SweepGradient(
                                    colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
                                    stops: [0.1, 0.75],
                                  ),
                                )
                              ],
                              axisLineStyle: AxisLineStyle(
                                thickness: 10,
                                color: Colors.grey.shade300,
                              ),
                              startAngle: 150,
                              endAngle: 390,
                              showLabels: false,
                              showTicks: false,
                              annotations: [
                                GaugeAnnotation(
                                  widget: Text(
                                    '40%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Colors.black,
                                    ),
                                  ),
                                  angle: 270,
                                  positionFactor: 0.1,
                                )
                              ],
                            )
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
}
