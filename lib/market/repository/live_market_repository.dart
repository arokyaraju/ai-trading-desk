import '../../fyers/websocket/fyers_websocket_service.dart';

class LiveMarketRepository {
  final FyersWebSocketService socket = FyersWebSocketService();

  void Function(Map<String, dynamic>)? onMessage;
  void Function()? onConnected;
  void Function()? onDisconnected;
  void Function(Object error)? onError;

  void connect({
    required String appId,
    required String accessToken,
    required List<String> symbols,
  }) {
    socket.onMessage = (data) {
      onMessage?.call(data);
    };

    socket.onConnected = () {
      onConnected?.call();
    };

    socket.onDisconnected = () {
      onDisconnected?.call();
    };

    socket.onError = (error) {
      onError?.call(error);
    };

    socket.connect(
      appId: appId,
      accessToken: accessToken,
      symbols: symbols,
    );
  }

  void disconnect() {
    socket.disconnect();
  }

  bool get isConnected => socket.isConnected;
}