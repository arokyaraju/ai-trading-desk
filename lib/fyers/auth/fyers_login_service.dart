import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../../core/config/fyers_config.dart';

class FyersLoginService {
  static String buildLoginUrl() {
    return "https://api-t1.fyers.in/api/v3/generate-authcode"
        "?client_id=${FyersConfig.appId}"
        "&redirect_uri=${Uri.encodeComponent(FyersConfig.redirectUri)}"
        "&response_type=code"
        "&state=market_watch";
  }

  /// Opens the Fyers login page in the system browser, then runs a
  /// local HTTP server on 127.0.0.1:8080 to catch the redirect and
  /// pull out the fresh auth_code.
  static Future<String?> loginAndGetAuthCode() async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      8080,
    );

    final completer = Completer<String?>();

    final sub = server.listen((request) async {
      final authCode = request.uri.queryParameters['auth_code'];

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(
          '<html><body><h3>Login complete. You can close this tab.</h3></body></html>',
        );
      await request.response.close();

      if (!completer.isCompleted) {
        completer.complete(authCode);
      }
    });

    final loginUrl = Uri.parse(buildLoginUrl());
    final launched = await launchUrl(
      loginUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      await sub.cancel();
      await server.close(force: true);
      return null;
    }

    final authCode = await completer.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () => null,
    );

    await sub.cancel();
    await server.close(force: true);

    return authCode;
  }
}