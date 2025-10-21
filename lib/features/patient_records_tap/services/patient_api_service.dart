import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../patient_detail/model/patient_vital_signs.dart';
import '../../edit_patient_info/model/patient_info_model.dart';

/// Service to send patient data + vitals to API automatically
class PatientApiService {
  static String? _lastSentHash;

  /// Remove null and empty values from nested maps
  static Map<String, dynamic> _removeNulls(Map<String, dynamic> data) {
    final cleaned = <String, dynamic>{};

    data.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is Map<String, dynamic>) {
        final nested = _removeNulls(value);
        if (nested.isNotEmpty) cleaned[key] = nested;
      } else if (value is List && value.isEmpty) {
        // تجاهل القوائم الفارغة
        return;
      } else {
        cleaned[key] = value;
      }
    });

    return cleaned;
  }

  /// Build JSON payload from patient info + vital signs
  static Map<String, dynamic> _buildPayload({
    required PatientInfo? patientInfo,
    required PatientVitalSigns vitalSigns,
  }) {
    // Extract ECG signal as list of doubles
    final ecgList = vitalSigns.ecgReadings
        .map((reading) => reading.value)
        .toList();

    // Extract blood pressure
    final systolic = vitalSigns.bloodPressure['systolic'] ?? 0;
    final diastolic = vitalSigns.bloodPressure['diastolic'] ?? 0;

    final body = {
      "patient_id": patientInfo?.deviceId ?? vitalSigns.deviceId,
      "name": patientInfo?.patientName ?? vitalSigns.patientName,
      "age": patientInfo?.age,
      "gender": patientInfo?.gender.name,
      "chronic_conditions": patientInfo?.chronicDiseases ?? [],
      "notes": patientInfo?.notes,
      "ecg_signal": ecgList.isNotEmpty ? ecgList : null,
      "vitals": {
        "spo2": vitalSigns.spo2 > 0
            ? {"value": vitalSigns.spo2.toInt(), "unit": "%"}
            : null,
        "bp": (systolic > 0 && diastolic > 0)
            ? {"systolic": systolic, "diastolic": diastolic, "unit": "mmHg"}
            : null,
        "hr": vitalSigns.heartRate > 0
            ? {"value": vitalSigns.heartRate.toInt(), "unit": "bpm"}
            : null,
        "temp": vitalSigns.temperature > 0
            ? {"value": vitalSigns.temperature, "unit": "C"}
            : null,
        "respiratory_rate": vitalSigns.respiratoryRate > 0
            ? {
                "value": vitalSigns.respiratoryRate.toInt(),
                "unit": "breaths/min",
              }
            : null,
      },
    };

    return _removeNulls(body);
  }

  /// Send patient data to API endpoint from .env
  static Future<Map<String, dynamic>?> sendToApi({
    required PatientInfo? patientInfo,
    required PatientVitalSigns vitalSigns,
    bool forceUpdate = false,
  }) async {
    try {
      // Build payload
      final payload = _buildPayload(
        patientInfo: patientInfo,
        vitalSigns: vitalSigns,
      );

      // Create hash to avoid duplicate sends
      final payloadHash = payload.toString().hashCode.toString();
      if (!forceUpdate && payloadHash == _lastSentHash) {
        debugPrint("⏭️  Skipping API call - no data changes detected");
        return null;
      }

      // Get BASE_URL from .env
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        debugPrint("❌ BASE_URL not found in .env file");
        return {"error": "BASE_URL not configured"};
      }

      final url = Uri.parse('$baseUrl/api/analyze');
      debugPrint("📤 Sending patient data to: $url");
      debugPrint("📦 Payload: ${jsonEncode(payload)}");

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Request timeout - API took too long to respond');
            },
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        _lastSentHash = payloadHash;
        debugPrint("✅ API Response: $result");
        return result;
      } else {
        debugPrint("❌ API Error [${response.statusCode}]: ${response.body}");
        return {
          "error": "API returned status ${response.statusCode}",
          "details": response.body,
        };
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error sending to API: $e");
      debugPrint("Stack trace: $stackTrace");
      return {"error": e.toString()};
    }
  }

  /// Reset the hash cache (useful for forced updates)
  static void resetCache() {
    _lastSentHash = null;
  }
}
