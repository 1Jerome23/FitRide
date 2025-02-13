import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class Globals {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static final ValueNotifier<String?> fcmTokenNotifier = ValueNotifier<String?>(null);
}
