import 'dart:convert';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:spider_doctor/features/services/repository/api_config.dart';

class IntegratedApiService {
  late IO.Socket _socket;
  bool _isConnected = false;

  IntegratedApiService() {
    _initSocket();
  }

  void _initSocket() {
    _socket = IO.io(
      ApiConfig.wsUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setReconnectionDelay(5000)
          .disableAutoConnect()
          .build(),
    );
    _socket.connect();

    _socket.onConnect((_) {
      print("✅ Connected to WebSocket server");
      _isConnected = true;
    });

    _socket.onDisconnect((_) {
      print("⚠️ Disconnected from WebSocket server");
      _isConnected = false;
    });

    _socket.onConnectError((data) {
      print("❌ WebSocket connect error: $data");
    });

    _socket.connect();
  }

  /// Send patient data and listen for analysis result
  Future<Map<String, dynamic>> analyzePatient(Map<String, dynamic> body) async {
    if (!_isConnected) {
      await Future.delayed(Duration(milliseconds: 200));
      if (!_isConnected) {
        throw Exception("WebSocket not connected");
      }
    }

    // Future to wait for server response
    final completer = Completer<Map<String, dynamic>>();

    // Listen once for the response
    _socket.once('patient_analysis_result', (data) {
      if (data is String) {
        completer.complete(jsonDecode(data));
      } else {
        completer.complete(Map<String, dynamic>.from(data));
      }
    });

    // Emit patient data to server
    _socket.emit('send_patient_data', body);

    return completer.future;
  }

  void dispose() {
    _socket.dispose();
  }
}
