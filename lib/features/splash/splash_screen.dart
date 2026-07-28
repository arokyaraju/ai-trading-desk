import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/config/session.dart';
import '../../core/storage/session_storage.dart';
import '../../fyers/auth/auth_service.dart';
import '../../market/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // TEMP: forces a fresh login by wiping any stale/invalid stored
    // session. Remove this line once login succeeds normally.
    await SessionStorage.clear();
    Session.clear();

    final appId = await SessionStorage.getAppId();
    final token = await SessionStorage.getAccessToken();
    final refresh = await SessionStorage.getRefreshToken();

    if (appId != null) {
      Session.appId = appId;
    }
    if (token != null) {
      Session.accessToken = token;
    }
    if (refresh != null) {
      Session.refreshToken = refresh;
    }

    if (Session.accessToken.isEmpty) {
      final newToken = await _authService.login();

      if (newToken == null) {
        debugPrint("Login failed or was cancelled.");
        // TODO: show an error/retry screen instead of proceeding blind.
      } else {
        // Previously this token was returned but never stored anywhere —
        // Session.accessToken stayed empty even on a successful login.
        Session.accessToken = newToken;
        await SessionStorage.saveSession(
          appId: Session.appId,
          accessToken: newToken,
          refreshToken: Session.refreshToken,
        );

        // Also write to a shared file so the Python bridge (fyers_bridge.py)
        // can read the same fresh token instead of keeping its own stale
        // hardcoded copy. Adjust this path if your bridge folder differs.
        try {
          final file = File(
            'C:\\Users\\Admin\\market_watch\\bridge\\access_token.txt',
          );
          await file.writeAsString(newToken);
        } catch (e) {
          debugPrint('Could not write shared token file: $e');
        }
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(accessToken: Session.accessToken),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}