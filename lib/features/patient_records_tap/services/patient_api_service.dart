import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../patient_detail/model/patient_vital_signs.dart';
import '../../edit_patient_info/model/patient_info_model.dart';

class PatientApiService {
  static IO.Socket? _socket;
  static bool _isConnected = false;
  static String? _lastSentHash;

  /// Initialize WebSocket connection (called once)
  static void initSocket() {
    if (_socket != null && _isConnected) return;

    final wsUrl = dotenv.env['WS_URL'];
    if (wsUrl == null || wsUrl.isEmpty) {
      debugPrint("❌ WS_URL not found in .env");
      return;
    }

    _socket = IO.io(
      wsUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setReconnectionDelay(5000)
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint("✅ Connected to WebSocket server");
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint("⚠️ Disconnected from WebSocket server");
    });

    _socket!.onConnectError((data) {
      _isConnected = false;
      debugPrint("❌ WebSocket connect error: $data");
    });
  }

  /// Remove null or empty values
  static Map<String, dynamic> _removeNulls(Map<String, dynamic> data) {
    final cleaned = <String, dynamic>{};
    data.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is Map<String, dynamic>) {
        final nested = _removeNulls(value);
        if (nested.isNotEmpty) cleaned[key] = nested;
      } else if (value is List && value.isEmpty) {
        return;
      } else {
        cleaned[key] = value;
      }
    });
    return cleaned;
  }

  /// Build patient + vitals payload
  static Map<String, dynamic> _buildPayload({
    required PatientInfo? patientInfo,
    required PatientVitalSigns vitalSigns,
  }) {
    final ecgList = vitalSigns.ecgReadings.map((r) => r.value).toList();

    final systolic = vitalSigns.bloodPressure['systolic'] ?? 0;
    final diastolic = vitalSigns.bloodPressure['diastolic'] ?? 0;

    final vitals = <String, dynamic>{};
    // Keep keys the same as backend expects, but send values as objects
    // so backend code that calls `.get(...)` on each field works.
    if (vitalSigns.heartRate > 0) {
      vitals["hr"] = {"value": vitalSigns.heartRate.toInt()};
    }
    if (vitalSigns.spo2 > 0) {
      vitals["spo2"] = {"value": vitalSigns.spo2.toInt()};
    }
    if (vitalSigns.temperature > 0) {
      vitals["temp"] = {"value": vitalSigns.temperature};
    }
    if (systolic > 0 && diastolic > 0) {
      final bpValue = {"systolic": systolic, "diastolic": diastolic};
      vitals["bp"] = bpValue;
    }
    if (vitalSigns.respiratoryRate > 0) {
      vitals["respiratory_rate"] = {
        "value": vitalSigns.respiratoryRate.toInt(),
      };
    }

    final body = {
      "patient_id": patientInfo?.deviceId ?? vitalSigns.deviceId,
      "name": patientInfo?.patientName ?? vitalSigns.patientName,
      "age": patientInfo?.age,
      "gender": patientInfo?.gender.name,
      "chronic_conditions": patientInfo?.chronicDiseases ?? [],
      "notes": patientInfo?.notes,
      "ecg_signal": ecgList.isNotEmpty ? ecgList : null,
      "vitals": vitals,
    };

    return _removeNulls(body);
  }

  /// Send patient data through WebSocket
  static Future<Map<String, dynamic>> sendToApi({
    required PatientInfo? patientInfo,
    required PatientVitalSigns vitalSigns,
    bool forceUpdate = false,
  }) async {
    initSocket();

    // إعادة المحاولة حتى 5 مرات (كل 500ms)
    int retry = 0;
    while (!_isConnected && retry < 5) {
      await Future.delayed(const Duration(milliseconds: 500));
      retry++;
    }
    if (!_isConnected) {
      debugPrint("❌ WebSocket not connected after retries");
      return {"error": "WebSocket not connected"};
    }

    final payload = _buildPayload(
      patientInfo: patientInfo,
      vitalSigns: vitalSigns,
    );

    // Safety: some backends expect vitals values to be objects (e.g. {"value": 74})
    // If any numeric fields slipped through as plain ints, wrap them here.
    try {
      final vitals = payload['vitals'];
      if (vitals is Map<String, dynamic>) {
        final keys = List<String>.from(vitals.keys);
        for (final k in keys) {
          final v = vitals[k];
          if (v is int || v is double) {
            vitals[k] = {"value": v};
          }
        }
      }
    } catch (e) {
      debugPrint('Error normalizing vitals: $e');
    }

    debugPrint("\uD83D\uDCCB Payload to API: ${jsonEncode(payload)}");

    final payloadHash = payload.toString().hashCode.toString();
    if (!forceUpdate && payloadHash == _lastSentHash) {
      debugPrint("⏭️ Skipping - no data changes detected");
      return {};
    }

    final completer = Completer<Map<String, dynamic>>();

    _socket!.once("patient_analysis_result", (data) {
      try {
        if (data is String) {
          completer.complete(jsonDecode(data));
        } else {
          completer.complete(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        completer.completeError("Invalid response format: $e");
      }
    });

    debugPrint("📤 Sending patient data via WebSocket...");
    _socket!.emit("send_patient_data", payload);

    _lastSentHash = payloadHash;

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => {"error": "Response timeout"},
    );
  }

  static void resetCache() {
    _lastSentHash = null;
  }

  static void dispose() {
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}
