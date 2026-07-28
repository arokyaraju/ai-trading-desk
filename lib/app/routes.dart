import 'package:flutter/material.dart';

import '../features/splash/splash_screen.dart';

class Routes {
  static const splash = "/";

  static final routes = <String, WidgetBuilder>{
    splash: (_) => const SplashScreen(),
  };
}