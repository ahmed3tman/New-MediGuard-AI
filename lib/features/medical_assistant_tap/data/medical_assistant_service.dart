import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Medical Assistant Service - إرسال الرسائل والصوت إلى API
class MedicalAssistantService {
  /// Send text message to API
  static Future<String> sendMessage(
    String message, {
    Map<String, dynamic>? patientData,
  }) async {
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        debugPrint("❌ BASE_URL not found in .env file");
        return "خطأ: لم يتم تكوين عنوان API";
      }

      final url = Uri.parse('$baseUrl/chat');
      debugPrint("📤 Sending text message to: $url");

      // استخراج patient_id الصحيح
      final patientId =
          patientData?['deviceId'] ?? patientData?['patientId'] ?? 'unknown';

      debugPrint("👤 Patient ID: $patientId");

      // بناء body فقط بالحقول المطلوبة (message + patient_id فقط)
      final body = {'message': message, 'patient_id': patientId};

      debugPrint('📦 Request Body: ${jsonEncode(body)}');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('انتهى وقت الاتصال');
            },
          );

      debugPrint("📥 Response Status: ${response.statusCode}");
      debugPrint("📥 Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        debugPrint("✅ API Response Parsed: $result");

        final reply =
            result['reply'] ?? result['response'] ?? result['message'] ?? '';
        debugPrint("💬 Final Reply: $reply");
        return reply;
      } else {
        debugPrint("❌ API Error [${response.statusCode}]: ${response.body}");
        return "خطأ في الاتصال بالخادم (${response.statusCode}): ${response.body}";
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error sending message: $e");
      debugPrint("Stack trace: $stackTrace");
      return "حدث خطأ في إرسال الرسالة: $e";
    }
  }

  /// Send audio message to API and receive text + audio response
  static Future<Map<String, dynamic>> sendAudio(
    String audioFilePath, {
    required String patientId,
  }) async {
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        debugPrint("❌ BASE_URL not found in .env file");
        return {"error": "خطأ: لم يتم تكوين عنوان API"};
      }

      final audioFile = File(audioFilePath);
      if (!audioFile.existsSync()) {
        return {"error": "ملف الصوت غير موجود"};
      }

      final url = Uri.parse('$baseUrl/chat-audio');
      debugPrint("📤 Sending audio to: $url");

      final audioBytes = await audioFile.readAsBytes();
      final base64Audio = base64Encode(audioBytes);

      final body = {
        'audio_base64': base64Audio,
        'patient_id': patientId,
        'file_ext': 'wav',
      };

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              throw Exception('انتهى وقت الاتصال');
            },
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        debugPrint("✅ Audio API Response: ${result.keys}");

        // Save reply audio if exists
        String? botAudioPath;
        if (result['reply_audio'] != null) {
          final replyAudioBytes = base64Decode(result['reply_audio']);
          final tempFile = File(
            '${Directory.systemTemp.path}/bot_reply_${DateTime.now().millisecondsSinceEpoch}.mp3',
          );
          await tempFile.writeAsBytes(replyAudioBytes);
          botAudioPath = tempFile.path;
          debugPrint("💾 Saved reply audio: $botAudioPath");
        }

        return {
          'transcript': result['transcript'],
          'reply': result['reply'],
          'reply_audio_path': botAudioPath,
        };
      } else {
        debugPrint(
          "❌ Audio API Error [${response.statusCode}]: ${response.body}",
        );
        return {"error": "خطأ في الاتصال بالخادم (${response.statusCode})"};
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error sending audio: $e");
      debugPrint("Stack trace: $stackTrace");
      return {"error": "حدث خطأ في إرسال الرسالة الصوتية: $e"};
    }
  }
}
