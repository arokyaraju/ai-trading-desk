import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/session.dart';
import '../../core/storage/session_storage.dart';

class TokenService {
  static Future<String?> generateAccessToken({
    required String appId,
    required String authCode,
    required String hash,
  }) async {
    final response = await http.post(
      Uri.parse(
        "https://api-t1.fyers.in/api/v3/validate-authcode",
      ),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "grant_type": "authorization_code",
        "appIdHash": hash,
        "code": authCode,
      }),
    );

    print("Status : ${response.statusCode}");
    print(response.body);

    if (response.statusCode != 200) {
      return null;
    }

    final json = jsonDecode(response.body);

    Session.appId = appId;
    Session.accessToken = json["access_token"] ?? "";
    Session.refreshToken = json["refresh_token"] ?? "";

    await SessionStorage.saveSession(
      appId: Session.appId,
      accessToken: Session.accessToken,
      refreshToken: Session.refreshToken,
    );

    return Session.accessToken;
  }
}