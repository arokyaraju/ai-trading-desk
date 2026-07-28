import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashUtil {
  static String generateAppIdHash(
      String appId,
      String secretKey,
      ) {

    final input = '$appId:$secretKey';

    return sha256.convert(utf8.encode(input)).toString();
  }
}