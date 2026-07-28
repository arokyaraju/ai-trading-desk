import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'routes.dart';

class MarketWatchApp extends StatelessWidget {
  const MarketWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Market Watch",
      theme: AppTheme.darkTheme,
      initialRoute: Routes.splash,
      routes: Routes.routes,
    );
  }
}