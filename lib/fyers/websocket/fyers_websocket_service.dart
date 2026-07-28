import 'dart:convert';

import 'package:web_socket_channel/io.dart';

class FyersWebSocketService {
  IOWebSocketChannel? _channel;

  void Function(Map<String, dynamic>)? onMessage;
  void Function()? onConnected;
  void Function()? onDisconnected;
  void Function(Object error)? onError;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  void connect({
    required String appId,
    required String accessToken,
    required List<String> symbols,
  }) {
    if (_channel != null) {
      disconnect();
    }

    // Connects to the local Python bridge, not Fyers directly.
    const bridgeUrl = "ws://127.0.0.1:9000";

    _channel = IOWebSocketChannel.connect(Uri.parse(bridgeUrl));

    // Fires once the raw socket handshake to the bridge succeeds — this is
    // the actual "connected" signal, independent of whether any tick data
    // has arrived yet (which won't happen while the market is closed).
    _channel!.ready.then((_) {
      if (!_isConnected) {
        _isConnected = true;
        onConnected?.call();
      }
    }).catchError((error) {
      print("WebSocket Connect Error: $error");
      _isConnected = false;
      onError?.call(error);
    });

    _channel!.stream.listen(
      (event) {
        try {
          final data = jsonDecode(event);

          if (data is Map<String, dynamic>) {
            onMessage?.call(data);
          }
        } catch (e) {
          print("WebSocket Parse Error: $e");
        }
      },
      onDone: () {
        print("WebSocket Closed");
        _isConnected = false;
        _channel = null;
        onDisconnected?.call();
      },
      onError: (error) {
        print("WebSocket Error: $error");
        _isConnected = false;
        onError?.call(error);
      },
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }
}