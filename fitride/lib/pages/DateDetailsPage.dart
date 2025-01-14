import 'package:flutter/material.dart';

class DateDetailsPage extends StatelessWidget {
  final String date;

  DateDetailsPage({required this.date});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          "Date Details",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Text(
          "You selected: $date",
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
