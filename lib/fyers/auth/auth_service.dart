import '../../core/config/fyers_config.dart';
import '../../core/utils/hash_util.dart';

import 'fyers_login_service.dart';
import 'token_service.dart';

class AuthService {
  Future<String?> login() async {
    final authCode = await FyersLoginService.loginAndGetAuthCode();

    if (authCode == null) {
      return null;
    }

    return TokenService.generateAccessToken(
      appId: FyersConfig.appId,
      authCode: authCode,
      hash: HashUtil.generateAppIdHash(
        FyersConfig.appId,
        FyersConfig.secretKey,
      ),
    );
  }
}