class Session {
  Session._();

  static String appId = "77WFZ67AWG-200";
  static String accessToken = "";
  static String refreshToken = "";

  static bool get isLoggedIn => accessToken.isNotEmpty;

  static void clear() {
    appId = "";
    accessToken = "";
    refreshToken = "";
  }
}